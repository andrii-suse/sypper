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

package SyppWeb::Controller::Rest::Repo;
use Mojo::Base 'Mojolicious::Controller';

my $DEBUG = $ENV{SY_DEBUG_ALL} || $ENV{SY_DEBUG_CONTROLLER_REPOS};

sub list {
    my ($self) = @_;

    my $list = $self->repos->list;
    print STDERR $self->dumper($list) if $DEBUG;

    $self->render(json => $list);
};

1;
