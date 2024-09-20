# Copyright (C) 2024 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# SyppLite is Sypp without repos and solv dependency
# Instead, it uses "request" files which start with baseurl
# and follow with files to download from that url
package SyppLite;
use Mojo::Base -base;

use Cwd qw(abs_path);
use File::Basename;
use File::Path qw( mkpath );
use Carp ();

use Mojo::File;
use Mojo::Log;
use Mojo::UserAgent;

use Sypp::Request;

has concurrency => 4;
has releasever  => undef;
has log       => sub { Mojo::Log->new };
has debug     => 0;
has verbosity => 0;
has force     => 0;
has interactive => 0;
has cachedir  => '.';

has version   => '';


sub get {
    my ($self, @args) = @_;
    my @requests = $self->build_requests(@args);
    my $ret = $self->get_requests(@requests);
    return $ret;
}

sub build_requests {
    my $self = shift;
    my @requests;
    foreach my $f (@_) {
        print STDERR "[INF] Loading file $f...\n" if $self->verbosity > 2;
        my $file;
        my @lines;
        my $r = Sypp::Request->new;
        $r->verbosity($self->verbosity);
        eval {
            print STDERR "[INF] Parsing {$f}...\n" if $self->verbosity > 2;
            $r->load($f);
            1;
        } or do {
            print STDERR "[CRI] Cannot pase {$f}: " . $@;
            return ();
        };
        eval {
            print STDERR "[INF] Loading mirrors for {$f}...\n" if $self->verbosity > 2;
            $r->load_mirrors;
            1;
	} or do {
            print STDERR "[INF] Cannot load mirrors for {$f}: " . $@;
        };
        push @requests, $r;
    }
    return @requests;
}

sub get_requests {
    my ($self, @requests) = @_;

    my @allgood = (1); # must use list to manupulate concurently, otherwise each promise may get own copy
    my $nothingtodo = 1; # for the case when everything is in the cache
    my $current = 0; # to track pending active concurrent requests

    print "[INF] Processing " . scalar(@requests) . " request(s)...\n" if $self->verbosity;
    my ($request, @files);
    $request = shift @requests;
    if ($request) {
        @files = @{$request->files};
    }

    for (my $i = 0; $i < $self->concurrency; $i++) {
        my $ii = $i;
        my (@urls, $file, $dest);
        @urls = $request->urls if $request; # each iteration should keep own copy of @urls
        # skip already cached files
        while (1) {
            print STDERR "[I$ii] No more requests\n" if !$request && $self->verbosity > 3;
            last unless $request;
            # print STDERR "[I$ii] Looking into request " . $request->alias . "...\n" if $self->verbosity > 3;
            # @urls = $request->urls;
            # @files = @{$request->files};
            # print STDERR "[I$ii] Files to process " . scalar(@files) . "...\n" if $self->verbosity > 3;
            $file = shift @files;
            if (!$file) {
                $request = shift @requests;
                if ($request) {
                    print STDERR "[I$ii] Looking into request " . $request->alias . "...\n" if $self->verbosity > 3;
                    @urls = $request->urls;
                    @files = @{$request->files};
                }
                next;
            }
            print STDERR "[I$ii] Looking into file $file...\n" if $self->verbosity > 3;
            $dest = $self->cachedir . $request->subpath . '/' . $file;
            if (!$self->force) {
                my $file_exists = 0;
                while ($file) {
                    $file_exists = 1 if -r $dest;
                    print STDERR "[I$ii] File $dest exist: $file_exists\n" if $self->verbosity > 3;
                    print STDERR "[I$ii] skipping $file (already cached)\n" if $file_exists && $self->verbosity;
                    last unless $file_exists;
                    print STDERR "[I$ii] Picking next file in " . $request->alias .   " ...\n" if $self->verbosity;
                    $file = shift @files;
                    $dest = $self->cachedir . $request->subpath . '/' . $file if $file;
                }
            }
            print STDERR "[I$ii] Selected file $file...\n" if $self->verbosity > 3 && $file;
            print STDERR "[I$ii] Will pick next request...\n" if $self->verbosity > 3 && !$file;
            last if $file;
        }
        next unless $file;
        $nothingtodo = 0;
        my $url = shift @urls;
        $url = $url . '/' . $file;
        print STDERR "[I$i] Built url {$url}\n" if $self->verbosity;
        my $ua = Mojo::UserAgent->new->request_timeout(300)->connect_timeout(6)->max_redirects(10);
        my ($next, $then, $catch);
        my $started = time();
        $current++;
        $next = sub {
            unless ($file && @allgood) {
                $current--;
                Mojo::IOLoop->stop unless $current;
                return;
            }
            print STDERR "[I$ii] Picking next url for $file...\n" if $self->verbosity > 3 && $file;
            $url = shift @urls;
            unless ($url) {
                print STDERR "[CRI] Couldn't download $file from " . $request->alias . "\n";
                shift @allgood;
                return Mojo::IOLoop->reset;
            }
            $url = $url . '/' . $file;
            $started = time();
            print STDERR "[I$ii] trying $url\n" if $self->verbosity;
            return $ua->get_p($url)->then($then, $catch);
        };

        $then = sub {
            my $tx = shift;
            my $elapsed = int(1000*(time() - $started));
            my $code = $tx->res->code // 0;
            print STDERR "[I$ii] ($code) from " . $tx->req->url . "\n" if $self->verbosity;
            if ($code == 200) {
                eval {
                    my $destdir = dirname($dest);
                    -d $destdir || mkpath($destdir) || die "Cannot create path {$destdir}";
                    $tx->res->content->asset->move_to($dest);
                    1;
                } or do {
                    print STDERR "[CRI] Cannot save $dest: $@\n";
                    shift @allgood;
                    return Mojo::IOLoop->reset;
                };

                # select next file to download
                while(1) {
                    unless ($request) {
                        $file = undef;
                        last;
                    }
                    @urls = $request->urls;
                    $file = shift @files;
                    print STDERR "[I$ii] Looking into file $file...\n" if $file && $self->verbosity > 3;
                    if (!$file) {
                        print STDERR "[I$ii] Picking next request...\n" if $self->verbosity > 3;
                        $request = shift @requests;
                        last unless $request;
                        print STDERR "[I$ii] Looking into request $request...\n" if $self->verbosity > 3;
                        @files = @{$request->files};
                        next;
                    }
                    $dest = $self->cachedir . $request->subpath . '/' . $file;

                    if (!$self->force) {
                        my $file_exists = 0;
                        while ($file) {
                            $file_exists = 1 if -r $dest;
                            print STDERR "[I$ii] File $dest exist: $file_exists\n" if $self->verbosity > 3;
                            print STDERR "[I$ii] Skipping $file (already cached)\n" if $file_exists && $self->verbosity;
                            last unless $file_exists;
                            $file = shift @files;
                            last unless $file;
                            $dest = $self->cachedir . $request->subpath . '/' . $file;
                            print STDERR "[I$ii] Looking into file $file...\n" if $self->verbosity > 3 && $file;
                        }
                    }
                    last if $file;
                }
            }

            $next->();
        };

        $catch = sub {
            my $err = shift // '<mpty>';
            my $elapsed = int(1000*(time() - $started));
            print STDERR "[WRN] error {$err} from $url\n" if $self->verbosity && @allgood;
            $next->();
        };

        print STDERR "[I$ii] trying $url\n" if $self->verbosity;
        $ua->get_p($url)->then($then, $catch);
    };
    unless ($nothingtodo) {
        print "Starting poll\n" if $self->verbosity;
        STDOUT->flush();
        Mojo::IOLoop->start;
    }
    Carp::croak "[CRI] Critical error detected. Aborting\n" unless @allgood;
    print "\n";
    if (@allgood) {
        print "[INF] finish processing all requests\n";
        return 0;
    }
    return 1;
}

sub run { __PACKAGE__->new->start }

1;
