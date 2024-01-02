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

package SyppWeb;
use Mojo::Base 'SyppApp';

sub new {
    my $self = shift->SUPER::new;
    # setting pid_file in startup will not help, need to set it earlier
    $self->config->{hypnotoad}{pid_file} = $ENV{SYPPER_HYPNOTOAD_PID} // '/run/syppd/hypnotoad.pid';

    my $started = 0;
    for (my $i = 0; my @r = caller($i); $i++) {
        next unless $r[3] =~ m/Hypnotoad/;
        $self->_setup_webui;
        $started = 1;
        last;
    }

    $self->hook(before_command => sub {
        my ($command, $arg) = @_;
        $self->_setup_webui if ref($command) =~ m/daemon|prefork/;
    }) unless $started;

    $self;
}

# This method will run once at server start
sub startup {
    my $self = shift;

    # my $secret = random_string(16);
    $self->config->{hypnotoad}{listen}   = [$ENV{MOJO_LISTEN} // 'http://*:8080'];
    $self->config->{hypnotoad}{proxy}    = $ENV{MOJO_REVERSE_PROXY} // 0,
    $self->config->{hypnotoad}{workers}  = $ENV{SYPPER_WORKERS},
    # $self->config->{_openid_secret} = $secret;
    # $self->secrets([$secret]);

    $self->SUPER::startup(@_);
}

sub _setup_webui {
    my $self = shift;

    # Optional initialization with access to the app
    my $r = $self->routes->namespaces(['SyppWeb::Controller']);
    $r->get('/favicon.ico' => sub { my $c = shift; $c->render_static('favicon.ico') });
    $r->get('/' => sub { shift->render(text => 'it works') });

    my $current_version = $self->version;
    $r->get('/version')->to(cb => sub {
        shift->render(text => $current_version);
    }) if $current_version;

    my $rest   = $r->any('/rest');
    my $rest_r = $rest->any('/')->to(namespace => 'SyppWeb::Controller::Rest');
    $rest_r->get('/repo')->to('repo#list');

    # $self->plugin(AssetPack => {pipes => [qw(Sass Css JavaScript Fetch Combine)]});
    # $self->asset->process;
    # if (my $country_image_dir = $self->mcconfig->country_image_dir) {
    #    my $static = $self->static;
    #    push @{$static->paths}, $country_image_dir;
    # }
    $self->log->info("server started:  $current_version");
}

sub detect_current_version() {
    my $self = shift;
    eval {
        my $ver = `git rev-parse --short HEAD 2>/dev/null || :`;
        $ver = `rpm -q sypp 2>/dev/null | grep -Po -- '[0-9]+\.[0-9a-f]+' | head -n 1 || :` unless $ver;
        $ver;
    } or $self->log->error('Cannot determine version') and return undef;
    
}

sub run { __PACKAGE__->new->start }

1;
