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

package Sypp;
use Mojo::Base -base;

use Data::Dumper;
use Cwd 'abs_path';
use File::Basename;
use File::Path qw( mkpath );
use Carp ();

use solv;

use Mojo::Log;

use Sypp::Repo::Rpm;
use Sypp::Repo::System;

has repos     => sub { [] };
has repodirs  => sub { Carp::croak 'repodirs are required' };
has cachedir  => './cache/';
has pool      => sub { solv::Pool->new };
has sysrepo   => sub { Carp::croak 'sysrepo is not initialized' };

has log       => sub { Mojo::Log->new };
has dumper    => sub { Carp::croak 'dumper is required if debug is enabled' };
has debug     => 0;
has verbosity => 0;

has version   => '';

use Data::Dumper;

sub init {
    my $self = shift;
}

sub refresh {
    my $self = shift;
    $self->refresh_repos;
    $self->repos || die 'No repos defined';
    $self->refresh_pool;
    $self->pool || die 'Cannot init seolv::pool';
}

sub refresh_repos {
    my $self = shift;
    my @repos;
    my @reposdirs = @{$self->repodirs};
    $self->log->error($self->dumper('PLUGIN::REPO', 'reposdirs', \@reposdirs)) if $self->debug;

    for my $reposdir (@reposdirs) {
        next unless -d $reposdir;
        my $dir;
        next unless opendir($dir, $reposdir);
        for my $reponame (sort(grep {/\.repo$/} readdir($dir))) {
            my $cfg = new Config::IniFiles('-file' => "$reposdir/$reponame");
            $self->app->log->error($self->dumper('PLUGIN::REPO', 'cfg', $cfg)) if $self->debug;
            for my $alias ($cfg->Sections()) {
                my $repoattr = {'alias' => $alias, 'enabled' => 0, 'priority' => 99, 'autorefresh' => 1, 'type' => 'rpm-md', 'metadata_expire' => 900};
                for my $p ($cfg->Parameters($alias)) {
                    $repoattr->{$p} = $cfg->val($alias, $p);
                }
                my $repo;
                if ($repoattr->{type} eq 'rpm-md') {
                    $repo = Sypp::Repo::Rpm->new($alias, 'repomd', $repoattr);
                }
                next unless $repo;
                $repo->cacheroot($self->cachedir);
                $repo->verbosity($self->verbosity);
                push @repos, $repo;
            }
        }
    }
    $self->log->error($self->dumper('PLUGIN::REPO', '@repos', \@repos)) if $self->debug;
    @{$self->repos} = @repos;

    my $sysrepo = Sypp::Repo::System->new('@System', 'system');
    $sysrepo->cacheroot($self->cachedir);
    $self->sysrepo($sysrepo);
}

sub _load_stub {
  my ($repodata) = @_;
  my $repo = $repodata->{repo}->{appdata};
  return $repo ? $repo->load_ext($repodata) : 0;
}

sub refresh_pool {
    my $self = shift;
    my $pool = $self->pool;
    $pool->setarch();
    $pool->set_loadcallback(\&_load_stub);
    $self->sysrepo->load($pool);
    for my $r (@{$self->repos}) {
        $r->load($pool); # TODO if $r->enabled;
    }
    $pool->addfileprovides();
    $pool->createwhatprovides();
    $pool->set_namespaceproviders($solv::NAMESPACE_LANGUAGE, $pool->Dep('de'), 1);
}

sub install {
    my ($self, @args) = @_;
    
    1;
}

sub download {
    my ($self, @args) = @_;
    my $flags = $solv::Selection::SELECTION_NAME | $solv::Selection::SELECTION_PROVIDES | $solv::Selection::SELECTION_GLOB;
    $flags |= $solv::Selection::SELECTION_CANON | $solv::Selection::SELECTION_DOTARCH | $solv::Selection::SELECTION_REL;
    my $pool = $self->pool;
    my @jobs;
    # print STDERR $self->dumper(\@argv);
    for my $arg (@args) {
        print STDERR "ARG: $arg\n\n";
        my $sel = $pool->select($arg, $flags);


        die("nothing matches '$arg'\n") if $sel->isempty();
        push @jobs, $sel->jobs($solv::Job::SOLVER_INSTALL);
    };
    my $solver = $pool->Solver();
    $solver->set_flag($solv::Solver::SOLVER_FLAG_SPLITPROVIDES, 1);
    while (1) {
        my @problems = $solver->solve(\@jobs);
        last unless @problems;
        for my $problem (@problems) {
            print "Problem $problem->{id}/".@problems.":\n";
            print $problem->str()."\n";
            my @solutions = $problem->solutions();
            for my $solution (@solutions) {
                print "  Solution $solution->{id}:\n";
                for my $element ($solution->elements(1)) {
                    print "  - ".$element->str()."\n";
                }
                print "\n";
            }
            my $sol;
            while (1) {
                print "Please choose a solution: ";
                $sol = <STDIN>;
                chomp $sol;
                last if $sol eq 's' || $sol eq 'q' || ($sol =~ /^\d+$/ && $sol >= 1 && $sol <= @solutions);
            }
            next if $sol eq 's';
            exit(1) if $sol eq 'q';
            my $solution = $solutions[$sol - 1];
            for my $element ($solution->elements()) {
                my $newjob = $element->Job();
                if ($element->type == $solv::Solver::SOLVER_SOLUTION_JOB) {
                    $jobs[$element->{jobidx}] = $newjob;
                } else {
                    push @jobs, $newjob if $newjob && !grep {$_ == $newjob} @jobs;
                }
            }
        }
    }
    my $trans = $solver->transaction();
    undef $solver;
    if ($trans->isempty()) {
        print "Nothing to do.\n";
        exit 0;
    }
    print "\nTransaction summary:\n\n";
    for my $c ($trans->classify($solv::Transaction::SOLVER_TRANSACTION_SHOW_OBSOLETES|$solv::Transaction::SOLVER_TRANSACTION_OBSOLETE_IS_UPGRADE)) {
        if ($c->{type} == $solv::Transaction::SOLVER_TRANSACTION_ERASE) {
            print "$c->{count} erased packages:\n";
        } elsif ($c->{type} == $solv::Transaction::SOLVER_TRANSACTION_INSTALL) {
            print "$c->{count} installed packages:\n";
        } elsif ($c->{type} == $solv::Transaction::SOLVER_TRANSACTION_REINSTALLED) {
            print "$c->{count} reinstalled packages:\n";
        } elsif ($c->{type} == $solv::Transaction::SOLVER_TRANSACTION_DOWNGRADED) {
            print "$c->{count} downgraded packages:\n";
        } elsif ($c->{type} == $solv::Transaction::SOLVER_TRANSACTION_CHANGED) {
            print "$c->{count} changed packages:\n";
        } elsif ($c->{type} == $solv::Transaction::SOLVER_TRANSACTION_UPGRADED) {
            print "$c->{count} upgraded packages:\n";
        } elsif ($c->{type} == $solv::Transaction::SOLVER_TRANSACTION_VENDORCHANGE) {
            printf "$c->{count} vendor changes from '%s' to '%s':\n", $c->{fromstr}, $c->{tostr};
        } elsif ($c->{type} == $solv::Transaction::SOLVER_TRANSACTION_ARCHCHANGE) {
            printf "$c->{count} arch changes from '%s' to '%s':\n", $c->{fromstr}, $c->{tostr};
        } else {
            next;
        }
        for my $p ($c->solvables()) {
            if ($c->{type} == $solv::Transaction::SOLVER_TRANSACTION_UPGRADED || $c->{type} == $solv::Transaction::SOLVER_TRANSACTION_DOWNGRADED) {
                my $other = $trans->othersolvable($p);
                printf "  - %s -> %s\n", $p->str(), $other->str();
            } else {
                printf "  - %s\n", $p->str();
            }
        }
        print "\n";
    }
    printf "install size change: %d K\n\n", $trans->calc_installsizechange();

    my @newpkgs = $trans->newsolvables();
    my %newpkgsfps;
    if (@newpkgs) {
        my $downloadsize = 0;
        $downloadsize += $_->lookup_num($solv::SOLVABLE_DOWNLOADSIZE) for @newpkgs;
        printf "Downloading %d packages, %d K\n", scalar(@newpkgs), $downloadsize / 1024;
        for my $p (@newpkgs) {
            my $repo = $p->{repo}->{appdata};
            my ($location) = $p->lookup_location();
            next unless $location;
            my $dest = $self->cachedir . '/packages/' . ($repo->alias // 'noalias') . '/' . $location;
            my $destdir = dirname($dest);
            -d $destdir || mkpath($destdir) || die "Cannot create path {$destdir}";
            $location = $repo->packagespath() . $location;
            my $chksum = $p->lookup_checksum($solv::SOLVABLE_CHECKSUM);
            my $f = $repo->download($location, 1, $chksum, undef, $dest);
            die("\n" . $repo->alias . ": $location not found in repository\n") unless $f;
            my $fileno = $f->fileno;
            $f->cloexec(0);
            $newpkgsfps{$p->{id}} = $f;
            print ".";
            STDOUT->flush();
        }
        print "\n";
    }
    print "Committing transaction:\n\n";
    $trans->order();
    for my $p ($trans->steps()) {
        my $steptype = $trans->steptype($p, $solv::Transaction::SOLVER_TRANSACTION_RPM_ONLY);
        if ($steptype == $solv::Transaction::SOLVER_TRANSACTION_ERASE) {
            print "erase ".$p->str()."\n";
            next unless $p->lookup_num($solv::RPM_RPMDBID);
            my $evr = $p->{evr};
            $evr =~ s/^[0-9]+://;	# strip epoch
            system('rpm', '-e', '--nodeps', '--nodigest', '--nosignature', "$p->{name}-$evr.$p->{arch}") && die("rpm failed: $?\n");
        } elsif ($steptype == $solv::Transaction::SOLVER_TRANSACTION_INSTALL || $steptype == $solv::Transaction::SOLVER_TRANSACTION_MULTIINSTALL) {
            print "install ".$p->str()."\n";
            my $f = $newpkgsfps{$p->{id}};
            my $mode = $steptype == $solv::Transaction::SOLVER_TRANSACTION_INSTALL ? '-U' : '-i';
            $f->cloexec(0);
            print STDERR Dumper($p);
            system('echo', 'rpm', $mode, '--force', '--nodeps', '--nodigest', '--nosignature', "/dev/fd/".$f->fileno()) && die("rpm failed: $?\n");
            delete $newpkgsfps{$p->{id}};
        }
    }
}

sub list {
    my @res;
    for my $r (@{shift->repos}) {
        my $name    = $r->name;
        my $alias   = $r->alias;
        my $baseurl = $r->baseurl;

        my %repo = ( name => $name, alias => $alias, baseurl => $baseurl );
        push @res, \%repo;
    }
    return \@res;
}

1;
