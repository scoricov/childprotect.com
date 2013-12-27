package ChildProtect;

use v5.12;
use Mojolicious 2.035;
use Mojo::Base 'Mojolicious';
use Mojolicious::Plugin::Authentication;
use WZ;
use ChildProtect::User;


sub startup
{
    my $self = shift;

    if (defined $ENV{CHILDPROTECTCOM_HOME})
    {
        app->home->parse( $ENV{CHILDPROTECTCOM_HOME} );
    }

    WZ->home($self->home);

    (ref $self)->attr('config');
    my $cfg = WZ->conf('childprotect');
    $self->config($cfg);

    WZ->db;

    $self->renderer->root( $self->home->rel_dir('templates') );
    $self->renderer->default_handler('ep');

    my $mode = $cfg->{mode};
    $self->mode($mode) if defined $mode;
    my $debug_ui = ($mode && ('development' eq $mode)) ? 1 : 0;

    my $static_serve = ($cfg->{static}{serve} // 1);
    my $static_magic = $cfg->{static}{magic} ? '2172410052' : '';
    my $static_url   = $cfg->{static}{url_prefix};

    if ($static_serve)
    {
        # Serve static
        $self->static->root( $self->home->rel_dir('public') );
    }

    $self->hook(before_dispatch => sub {
        my $self = shift;

        $self->stash(
            stma       => $static_magic,
            static_url => $static_url,
            base_url   => $cfg->{base_url},
            debug      => $debug_ui,
            message    => '',
            error      => '',
        );

        if ($static_serve)
        {
            my $path = $self->req->url->path;
            if ($path =~ s/\/\d{10}\//\//)
            {
                $self->req->url->path($path);
            }
        }
    } );

    $self->sessions->cookie_name('childprotect');
    $self->sessions->default_expiration(3600); # set expiration to 1 hour
    $self->secret('Lw1SpjLvGDl060Tg4GbtF8GVefIbm9lGi8p0b');

    $self->plugin('authentication' => {
        'session_key' => 'childprotect',
        'load_user'   => sub
        {
            my $u = ChildProtect::User->new(id => $_[1]);
            $u->exists ? $u : 0
        },
        'validate_user' => sub
        {
            my $u = ChildProtect::User->new(email => $_[1]);
            $u->login(@_[2, 3]) ? $u->id : undef;
        },
    });

    my $r = $self->routes;
    $r->namespace('ChildProtect::Controller');

    $r->get('/logout')->to('Public#redirect_logout');

    # Public
    my $r_pub = $r->bridge('/')->to('Public#redirect_member');
    $r_pub->get('/')->to('Public#index');
    $r_pub->post('/signup')->to('Public#signup');
    $r_pub->get('/signup-confirm')->to('Public#signup_confirm');
    $r_pub->post('/login')->to('Public#login');
    $r_pub->get('/login')->to('Public#index');

    # API
    my $r_api = $r->bridge('/REST/2')->to('API#auth');
    $r_api->put('tokens')->to('API#put_tokens');
    $r_api->put('tokens/:footprint')->to('API#put_token');
    $r_api->put('tokens-deleted')->to('API#put_tokens_deleted');
    $r_api->delete('tokens/:footprint')->to('API#delete_token');
    $r_api->get('tokens')->to('API#get_tokens_foreign');
    $r_api->get('tokens-submitted')->to('API#get_tokens_submitted');
    $r_api->get('tokens-deleted')->to('API#get_tokens_deleted');
    $r_api->get('counters')->to('API#get_counters');

    # Member's private area
    my $r_priv = $r->bridge('/member')->to('Member#auth');
    $r_priv->get('/')->to('Member#index');
    $r_priv->route('/change-password')->via(qw/GET POST/)
        ->to('Member#change_password');
}

1;
__END__
