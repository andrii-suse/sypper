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

package Sypp::Request;
use Mojo::Base -base;

has alias    => '';
has baseurls => sub { [] };
has mirrors  => sub { [] };
has files    => sub { [] };
has verbosity => 0;

sub subpath {
    if (my $alias = shift->alias) {
        return "/$alias";
    }
    return '';
}

sub urls {
    my $self = shift;
    die 'Too many arguments in Request::urls' if @_;
    return ( @{$self->mirrors}, @{$self->baseurls} );
}

sub baseurl {
    my @urls = @{shift->baseurls};
    die 'No baseurl specified' unless @urls;
    return $urls[0];
}

sub load {
    my ($self, $f) = @_;
    my @lines;
    my $n = 0;

    my $file = Mojo::File->new($f);
    $self->alias($file->basename('.' . $file->extname));
    open my $fd, $f or die "Could not open $f: $!";
    my $line = <$fd>;
    chomp $line;
    $line =~ s!/$!!;
    push @{$self->baseurls}, $line if $line;

    while( $line = <$fd>)  {
        chomp $line;
        push @{$self->files}, $line;
    }
    close $fd;
}

sub load_mirrors {
    my $self = shift;
    my $baseurl = $self->baseurl;
    $baseurl =~ s!/$!!;
    my $url = $baseurl . '/?mirrorlist';
    my $ua  = Mojo::UserAgent->new->max_redirects(5)->connect_timeout(4)->request_timeout(4);
    print STDERR "[INF] refresh_mirrors url: {" . $url . "}\n" if $self->verbosity > 2;

    my $res;
    eval {
        $res = $ua->get($url, {'User-Agent' => 'Sypp/refresh_mirrors'})->result;
    };
    print STDERR "[INF] res: " . ($res && $res->code ? $res->code : "undef") . "\n" if $self->verbosity > 2;
    return undef unless $res && $res->code && $res->code < 300 && $res->code >= 200;

    my $json;
    eval { $json = $res->json; };
    print STDERR "no json\n" if $self->verbosity > 2 && !$json;
    return undef unless $json;

    my @urls;
    my $limit = 15;
    # first add mirrors with mtime
    for my $hash (@$json) {
        last if @urls > $limit;
        my $mtime = $hash->{mtime};
        next unless $mtime;
        (my $url = $hash->{url}) =~ s!\/?$!!;
        push @urls, $url if $url;
    }
    # then without mtime if needed
    for my $hash (@$json) {
        last if @urls > $limit;
        my $mtime = $hash->{mtime};
        next if $mtime;
        (my $url = $hash->{url}) =~ s!\/?$!!;
        push @urls, $url if $url;
    }
    print STDERR "no mirrors\n" if $self->verbosity > 2 && 0 == scalar(@urls);
    @{$self->mirrors} = (@urls, @{$self->mirrors});
};

1;
