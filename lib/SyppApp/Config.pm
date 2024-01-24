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
# You should have received a copy of the GNU General Public License

package SyppApp::Config;

use Mojo::Base -base, -signatures;

use Config::IniFiles;

has repodirs => sub { [] };
has cachedir => undef;

sub refresh($self, $cfgfile=undef) {
    my $repodirs;
    if (my $root = $ENV{SYPP_ROOT}) {
        $repodirs = $ENV{SYPP_ROOT} . '/repos.d';
    } else {
        $repodirs = $ENV{SYPP_REPO_DIRS} // $ENV{SYPP_REPO_DIR} // '/etc/zypp/repos.d';
    }
    if ($repodirs) {
        @{$self->repodirs} = split /[:,\s]+/, $repodirs;
    }
    if (my $cachedir = $ENV{SYPP_CACHEDIR}) {
        $self->cachedir($cachedir);
    } elsif ( 0 == $> ) {
        $self->cachedir('/var/cache/zypp'); # do not run sypper as root, but if you do - it will use zypp cache
    }
}

1;
