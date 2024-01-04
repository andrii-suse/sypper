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

package SyppApp::Command::download;
use Mojo::Base 'Mojolicious::Command';

has description => 'download packages';
has usage       => sub { shift->extract_usage };

sub run {
    my ($self, @args) = @_;
    my $verbosity = 0;
    my @newargs;

    foreach my $a (@args) {
        my $incr = 0;
        $incr++ if substr($a,0,2) eq "-v";
        $incr++ if substr($a,0,3) eq "-vv";
        $incr++ if substr($a,0,4) eq "-vvv";
        $incr++ if $a eq "--verbose";
        if ($incr) {
            $verbosity = $verbosity + $incr;
        } else {
            push @newargs, $a;
        }
    }

    $self->app->sypp->verbosity($verbosity) if $verbosity;
    $self->app->sypp->refresh;
    $self->app->sypp->download(@newargs);
}

1;

=encoding utf8

=head1 NAME

SyppApp::Command::download - Sypp download package

=head1 SYNOPSIS

  Usage: APPLICATION download [package]

    script/syppper download vim

=head1 DESCRIPTION

=cut
