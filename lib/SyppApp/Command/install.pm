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

package SyppApp::Command::install;
use Mojo::Base 'Mojolicious::Command';

has description => 'install packages';
has usage       => sub { shift->extract_usage };

sub run {
    my ($self, @args) = @_;
    
    return $self->app->install(@args);
}

1;

=encoding utf8

=head1 NAME

SyppApp::Command::install - Solv install package

=head1 SYNOPSIS

  Usage: APPLICATION install [packages]

    script/syppper install vim

=head1 DESCRIPTION

=cut
