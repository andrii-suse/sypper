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

package Sypp::Repo::Rpm;
use Mojo::Base 'Sypp::Repo';

sub find {
    my ($self, $what) = @_;
    my $di = $self->{handle}->Dataiterator_meta($solv::REPOSITORY_REPOMD_TYPE, $what, $solv::Dataiterator::SEARCH_STRING);
    $di->prepend_keyname($solv::REPOSITORY_REPOMD);
    for my $d (@$di) {
        my $dp = $d->parentpos();
        my $filename = $dp->lookup_str($solv::REPOSITORY_REPOMD_LOCATION);
        next unless $filename;
        my $chksum = $dp->lookup_checksum($solv::REPOSITORY_REPOMD_CHECKSUM);
        if (!$chksum) {
            print "no $filename file checksum!\n";
            return (undef, undef);
        }
        return ($filename, $chksum);
    }
    return (undef, undef);
}

sub add_ext {
    my ($self, $repodata, $what, $ext) = @_;
    my ($filename, $chksum) = $self->find($what);
    ($filename, $chksum) = $self->find('prestodelta') if !$filename && $what eq 'deltainfo';
    return unless $filename;
    my $handle = $repodata->new_handle();
    $repodata->set_poolstr($handle, $solv::REPOSITORY_REPOMD_TYPE, $what);
    $repodata->set_str($handle, $solv::REPOSITORY_REPOMD_LOCATION, $filename);
    $repodata->set_checksum($handle, $solv::REPOSITORY_REPOMD_CHECKSUM, $chksum);
    $self->add_ext_keys($ext, $repodata, $handle);
    $repodata->add_flexarray($solv::SOLVID_META, $solv::REPOSITORY_EXTERNAL, $handle);
}

sub add_exts {
    my ($self) = @_;
    my $repodata = $self->{handle}->add_repodata(0);
    $repodata->extend_to_repo();
    $self->add_ext($repodata, 'deltainfo', 'DL');
    $self->add_ext($repodata, 'filelists', 'FL');
    $repodata->internalize();
}

sub load_ext {
    my ($self, $repodata) = @_;
    my $repomdtype = $repodata->lookup_str($solv::SOLVID_META, $solv::REPOSITORY_REPOMD_TYPE);
    my $ext;
    if ($repomdtype eq 'filelists') {
        $ext = 'FL';
    } elsif ($repomdtype eq 'deltainfo') {
        $ext = 'DL';
    } else {
        return 0;
    }
    print("[" . $self->alias . ":$ext: ");
    STDOUT->flush();
    if ($self->usecachedrepo($ext)) {
        print "cached]\n";
        return 1;
    }
    print "fetching]\n";
    my $filename = $repodata->lookup_str($solv::SOLVID_META, $solv::REPOSITORY_REPOMD_LOCATION);
    my $filechksum = $repodata->lookup_checksum($solv::SOLVID_META, $solv::REPOSITORY_REPOMD_CHECKSUM);
    my $f = $self->download($filename, 1, $filechksum);
    return 0 unless $f;
    if ($ext eq 'FL') {
        $self->{handle}->add_rpmmd($f, 'FL', $solv::Repo::REPO_USE_LOADING|$solv::Repo::REPO_EXTEND_SOLVABLES|$solv::Repo::REPO_LOCALPOOL);
    } elsif ($ext eq 'DL') {
        $self->{handle}->add_deltainfoxml($f, $solv::Repo::REPO_USE_LOADING);
    }
    $self->writecachedrepo($ext, $repodata);
    return 1;
}

sub load {
    my ($self, $pool) = @_;
    return 1 if $self->SUPER::load($pool);
    STDOUT->flush();
    my $f = $self->download("repodata/repomd.xml");
    if (!$f) {
        print "no repomd.xml file, skipped\n";
        $self->{handle}->free(1);
        delete $self->{handle};
        return undef;
    }
    $self->{cookie} = $self->calc_cookie_fp($f);
    if ($self->usecachedrepo(undef, 1)) {
        print "cached\n";
        return 1;
    }
    $self->{handle}->add_repomdxml($f, 0);
    print "fetching\n";
    my ($filename, $filechksum) = $self->find('primary');
    if ($filename) {
        $f = $self->download($filename, 1, $filechksum, 1);
        if ($f) {
            $self->{handle}->add_rpmmd($f, undef, 0);
        }
        return undef if $self->{incomplete};
    }
    ($filename, $filechksum) = $self->find('updateinfo');
    if ($filename) {
        $f = $self->download($filename, 1, $filechksum, 1);
        if ($f) {
            $self->{handle}->add_updateinfoxml($f, 0);
        }
    }
    $self->add_exts();
    $self->writecachedrepo();
    $self->{handle}->create_stubs();
    return 1;
}


1;
