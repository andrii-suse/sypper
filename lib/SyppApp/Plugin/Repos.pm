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
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301

package SyppApp::Plugin::Repos;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $args ) = @_;

    my $sypp = $app->sypp;

    $app->helper( 'repos.refresh' => sub {
        return $sypp->refresh(@_);
    });

    $app->helper( 'repos.list' => sub {
        return $sypp->list(@_);
    });

    $app->helper( 'repos.download' => sub {
        return $sypp->download(@_);
    });
    $app->helper( 'repos.install' => sub {
        return $sypp->install(@_);
    });
}

1;
