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

package SyppApp;
use Mojo::Base 'Mojolicious';

use Sypp;
use SyppApp::Config;

has syconfig => sub { SyppApp::Config->new() };
has sypp     => sub { Sypp->new() };
has version  => '';

sub startup {
    my $self = shift;
    push @{$self->commands->namespaces}, 'SyppApp::Command';
    push @{$self->plugins->namespaces},  'SyppApp::Plugin';
    print STDERR $self->dumper($self->dumper);
    # $self->sypp->dumper($self->dumper);
    $self->plugin('Repos');
    $self->refresh_config;
    $self->version($self->sypp->version);
}

sub refresh_config {
    my ($self) = @_;
    $self->syconfig->refresh;
    $self->sypp->repodirs($self->syconfig->repodirs);
    if (my $cachedir = $self->syconfig->cachedir) {
        $self->sypp->cachedir($cachedir);
    }
}

sub run { __PACKAGE__->new->start }

1;
