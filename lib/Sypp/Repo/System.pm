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

package Sypp::Repo::System;
use Mojo::Base 'Sypp::Repo';
use Data::Dumper;

sub load {
    my ($self, $pool, $force) = @_;

    $self->{handle} = $pool->add_repo($self->alias);
    $self->{handle}->{appdata} = $self;
    $pool->{installed} = $self->{handle};
    print "rpm database: ";
    $self->{cookie} = $self->calc_cookie_file('/var/lib/rpm/Packages');
    my $dorefresh = $force;
    if (!$force) {
        my $metadata_expire = $self->{metadata_expire} // 900;
        my @s = stat($self->cachepath);
        $dorefresh = 1 if !@s || ($metadata_expire != -1 && time() - $s[9] > $metadata_expire);
    }
    if (!$dorefresh && $self->usecachedrepo()) {
        print "cached\n";
        return 1;
    }
    print "reading\n";
    if (defined(&solv::Repo::add_products)) {
        $self->{handle}->add_products("/etc/products.d", $solv::Repo::REPO_NO_INTERNALIZE);
    }
    my $f = solv::xfopen($self->cachepath());
    $self->{handle}->add_rpmdb_reffp($f, $solv::Repo::REPO_REUSE_REPODATA);
    $self->writecachedrepo();
    return 1;
}

1;
