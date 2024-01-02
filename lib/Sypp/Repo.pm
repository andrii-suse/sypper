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

package Sypp::Repo;
use Mojo::Base -base;

use POSIX;
use Carp ();
use Data::Dumper;
use Cwd;
use File::Basename;

has [qw(alias name baseurl type enabled)];

has cacheroot => sub { Carp::croak 'cacheroot is not set' };

sub new {
    my ($class, $alias, $type, $attr) = @_;
    my $r = { %{$attr || {}} };
    my $self = bless $r, $class;
    $self->alias($alias);
    $self->type($type);
    $self->baseurl($r->{baseurl});
    $self->name   ($r->{name});
    $self->enabled($r->{enabled});
    return $self;
};

sub calc_cookie_fp {
  my ($self, $fp) = @_;
  my $chksum = solv::Chksum->new($solv::REPOKEY_TYPE_SHA256);
  $chksum->add("1.1");
  $chksum->add_fp($fp);
  return $chksum->raw();
}

sub calc_cookie_file {
  my ($self, $filename) = @_;
  my $chksum = solv::Chksum->new($solv::REPOKEY_TYPE_SHA256);
  $chksum->add("1.1");
  $chksum->add_stat($filename);
  return $chksum->raw();
}

sub calc_cookie_ext {
  my ($self, $f, $cookie) = @_;
  my $chksum = solv::Chksum->new($solv::REPOKEY_TYPE_SHA256);
  $chksum->add("1.1");
  $chksum->add($cookie);
  $chksum->add_fstat(fileno($f));
  return $chksum->raw();
}

sub packagespath {
  my ($self) = @_;
  return '';
}

sub cachepath {
    my ($self, $ext) = @_;
    my $path = $self->alias;
    $path =~ s/^\./_/s;
    $path .= $ext ? "_$ext.solvx" : '.solv';
    $path =~ s!/!_!gs;
    return $self->cacheroot . "/$path";
} 


sub load {
    my ($self, $pool) = @_;
    print "repo: '" . $self->alias() . "' is about to load\n";
    $self->{handle} = $pool->add_repo($self->alias);
    $self->{handle}->{appdata} = $self;
    $self->{handle}->{priority} = 99 - ($self->{priority} // 0);
    my $dorefresh = 1; # TODO $self->{autorefresh};
    if ($dorefresh) {
        my @s = stat($self->cachepath);
        $dorefresh = 0 if @s && ($self->{metadata_expire} == -1 || time() - $s[9] < $self->{metadata_expire});
    }
    $self->{cookie} = '';
    $self->{extcookie} = '';
    if (!$dorefresh && $self->usecachedrepo()) {
        print "repo: '" . $self->alias . "' cached\n";
        return 1;
    }
    return 0;
}

sub load_ext {
    return 0;
}

sub download_url {
    my ($self, $file) = @_;
    if (!$self->baseurl) {
        print $self->alias . ": no baseurl\n";
        return undef;
    }
    my $url = $self->baseurl;
    $url =~ s!/$!!;
    $url .= "/$file";
    return $url;
}

sub download {
    my ($self, $file, $uncompress, $chksum, $markincomplete) = @_;
    if (!$self->baseurl) {
        print $self->alias . ": no baseurl\n";
        return undef;
    }
    my $url = $self->baseurl;
    $url =~ s!/$!!;
    $url .= "/$file";
#    my $dir = $self->cacheroot . '/' . dirname($file);
#    print STDERR Dumper('filexxx:', $file, $self->cacheroot, getcwd(), $dir);
#    system ("mkdir -p $dir 2> /dev/null") == 0 
#        or die "failed to create $dir. exiting...\n";
    open(my $f, '+>', undef) || die;
    fcntl($f, Fcntl::F_SETFD, 0);		# turn off CLOEXEC
#    my $st = system('curl', '-f', '-s', '-L', '-o', $self->cacheroot . '/' . $file, '--', $url);
    my $st = system('curl', '-f', '-s', '-L', '-o', "/dev/fd/" . fileno($f), '--', $url);
    if (POSIX::lseek(fileno($f), 0, POSIX::SEEK_END) == 0 && ($st == 0 || !$chksum)) {
      return undef;
    }
    POSIX::lseek(fileno($f), 0, POSIX::SEEK_SET);
    if ($st) {
        print "$file: download error #$st\n";
        $self->{incomplete} = 1 if $markincomplete;
        return undef;
    }
    if ($chksum) {
        my $fchksum = solv::Chksum->new($chksum->{type});
        $fchksum->add_fd(fileno($f));
        if ($fchksum != $chksum) {
            print "$file: checksum error\n";
            $self->{incomplete} = 1 if $markincomplete;
            return undef;
        }
    }
    if ($uncompress) {
        return solv::xfopen_fd($file, fileno($f));
    } else {
        return solv::xfopen_fd(undef, fileno($f));
    }
}

sub usecachedrepo {
    my ($self, $ext, $mark) = @_;
    my $cookie = $ext ? $self->{extcookie} : $self->{cookie};
    my $cachepath = $self->cachepath($ext);
    my $fextcookie;
    if (sysopen(my $f, $cachepath, POSIX::O_RDONLY)) {
        sysseek($f, -32, Fcntl::SEEK_END);
        my $fcookie = '';
        return undef if sysread($f, $fcookie, 32) != 32;
        return undef if $cookie && $fcookie ne $cookie;
        if ($self->type ne 'system' && !$ext) {
            sysseek($f, -32 * 2, Fcntl::SEEK_END);
            return undef if sysread($f, $fextcookie, 32) != 32;
        }
        sysseek($f, 0, Fcntl::SEEK_SET);
        my $fd = solv::xfopen_fd(undef, fileno($f));
        my $flags = $ext ? $solv::Repo::REPO_USE_LOADING|$solv::Repo::REPO_EXTEND_SOLVABLES : 0;
        $flags |= $solv::Repo::REPO_LOCALPOOL if $ext && $ext ne 'DL';
        if (!$self->{handle}->add_solv($fd, $flags)) {
           return undef;
        }
        $self->{cookie} = $fcookie unless $ext;
        $self->{extcookie} = $fextcookie if $fextcookie;
        utime undef, undef, $f if $mark;
        return 1;
    }
    return undef;
}

sub writecachedrepo {
    my ($self, $ext, $repodata) = @_;
    return if $self->{incomplete};
    # mkdir("/var/cache/solv", 0755) unless -d "/var/cache/solv";
    my ($f, $tmpname);
    eval {
        ($f, $tmpname) = File::Temp::tempfile(".newsolv-XXXXXX", 'DIR' => $self->cacheroot);
    };
    return unless $f;
    chmod 0444, $f;
    my $ff = solv::xfopen_fd(undef, fileno($f));
    if (!$repodata) {
        $self->{handle}->write($ff);
    } elsif ($ext) {
        $repodata->write($ff);
    } else {
        $self->{handle}->write_first_repodata($ff);
    }
    undef $ff;	# also flushes
    if ($self->type ne 'system' && !$ext) {
        $self->{extcookie} ||= $self->calc_cookie_ext($f, $self->{cookie});
        syswrite($f, $self->{extcookie});
    }
    syswrite($f, $ext ? $self->{extcookie} : $self->{cookie});
    close($f);
    if ($self->{handle}->iscontiguous()) {
        $f = solv::xfopen($tmpname);
        if ($f) {
            if (!$ext) {
                $self->{handle}->empty();
                die("internal error, cannot reload solv file\n") unless $self->{handle}->add_solv($f, $repodata ? 0 : $solv::Repo::SOLV_ADD_NO_STUBS);
            } else {
                $repodata->extend_to_repo();
                my $flags = $solv::Repo::REPO_EXTEND_SOLVABLES;
                $flags |= $solv::Repo::REPO_LOCALPOOL if $ext ne 'DL';
                $repodata->add_solv($f, $flags);
            }
        }
    }
    my $res = rename($tmpname, $self->cachepath($ext));
    print STDERR Dumper('xxxx', $res, $self->cachepath($ext), getcwd());
}

my %langtags = (
    $solv::SOLVABLE_SUMMARY     => $solv::REPOKEY_TYPE_STR,
    $solv::SOLVABLE_DESCRIPTION => $solv::REPOKEY_TYPE_STR,
    $solv::SOLVABLE_EULA        => $solv::REPOKEY_TYPE_STR,
    $solv::SOLVABLE_MESSAGEINS  => $solv::REPOKEY_TYPE_STR,
    $solv::SOLVABLE_MESSAGEDEL  => $solv::REPOKEY_TYPE_STR,
    $solv::SOLVABLE_CATEGORY    => $solv::REPOKEY_TYPE_ID,
);

sub add_ext_keys {
    my ($self, $ext, $repodata, $handle) = @_;
    if ($ext eq 'DL') {
        $repodata->add_idarray($handle, $solv::REPOSITORY_KEYS, $solv::REPOSITORY_DELTAINFO);
        $repodata->add_idarray($handle, $solv::REPOSITORY_KEYS, $solv::REPOKEY_TYPE_FLEXARRAY);
    } elsif ($ext eq 'DU') {
        $repodata->add_idarray($handle, $solv::REPOSITORY_KEYS, $solv::SOLVABLE_DISKUSAGE);
        $repodata->add_idarray($handle, $solv::REPOSITORY_KEYS, $solv::REPOKEY_TYPE_DIRNUMNUMARRAY);
    } elsif ($ext eq 'FL') {
        $repodata->add_idarray($handle, $solv::REPOSITORY_KEYS, $solv::SOLVABLE_FILELIST);
        $repodata->add_idarray($handle, $solv::REPOSITORY_KEYS, $solv::REPOKEY_TYPE_DIRSTRARRAY);
    } else {
        for my $langid (sort { $a <=> $b } keys %langtags) {
            $repodata->add_idarray($handle, $solv::REPOSITORY_KEYS, $self->{handle}->{pool}->id2langid($langid, $ext, 1));
            $repodata->add_idarray($handle, $solv::REPOSITORY_KEYS, $langtags{$langid});
        }
    }
}

1;
