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

package SyppLite::Command;
use Mojo::Base 'Mojolicious::Command';

sub eat {
    my ($self, $args) = @_;
    my @args = @$args;
    my ($verbosity, $concurrency, $interactive);
    my $force;

    my @newargs;

    while (my $a = shift @args) {
        my $incr = 0;
        $incr++ if substr($a,0,2) eq "-v";
        $incr++ if substr($a,0,3) eq "-vv";
        $incr++ if substr($a,0,4) eq "-vvv";
        $incr++ if substr($a,0,5) eq "-vvvv";
        $incr++ if $a eq "--verbose";
        if ($incr) {
            $verbosity = ($verbosity // 0) + $incr;
        } elsif ($a eq '-c' || $a eq '--concurrency') {
            $concurrency = eval {int(shift @args)};
        } elsif ($a eq '-n' || $a eq '--non-interactive') {
            $interactive = 0;
        } elsif ($a eq '-f' || $a eq '--force') {
            $force = 1;
        } else {
            push @newargs, $a;
        }
    }
    $self->app->sypp->verbosity($verbosity)     if $verbosity;
    $self->app->sypp->concurrency($concurrency) if defined $concurrency;
    $self->app->sypp->force($force)             if defined $force;
    $self->app->sypp->interactive($interactive) if defined $interactive;
    $self->app->sypp->interactive(1)        unless defined $interactive;

    @$args = @newargs if $verbosity || defined $concurrency || $force || defined $interactive;
}

1;
