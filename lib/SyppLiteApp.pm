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

package SyppLiteApp;
use Mojo::Base 'Mojolicious';

use SyppLite;
use SyppApp::Config;

has syconfig => sub { SyppApp::Config->new() };
has sypp     => sub { SyppLite->new() };
has version  => '';

sub startup {
    my $self = shift;
    push @{$self->commands->namespaces}, 'SyppLite::Command';
    print STDERR $self->dumper($self->dumper);
    $self->version($self->sypp->version);
}

sub run { __PACKAGE__->new->start }

1;
