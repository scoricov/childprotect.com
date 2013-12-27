package ChildProtect::Controller::Public;
use Mojo::Base 'Mojolicious::Controller';
require WZ::Validate;
require WZ::Sanitize;
use WZ;
use ChildProtect::User qw(:const_flags);
use ChildProtect::User::Confirmation qw(:const_codes);


sub redirect_logout
{
    my $self = shift;
    $self->logout;
    $self->redirect_to('/?' . $self->req->query_params->to_string);
}

sub redirect_member
{
    my $self = shift;
    $self->redirect_to('/member/?' . $self->req->query_params->to_string) &&
        return 0
            if $self->user_exists;

    return 1;
}

sub index
{
    my $self = shift;
    $self->render(template => 'index');
}

sub login
{
    my $self = shift;
    my $req = $self->req;
    my $bp = $req->body_params->to_hash;
    my ($email, $password) =
        map { defined $_ ? substr($_, 0, 255) : undef } @$bp{qw/email password/};

    $self->authenticate($email, $password, $self->tx->remote_address) &&
        $self->redirect_to('/member/?' . $req->query_params->to_string) &&
            return 1;

    $self->stash(error => 'Wrong email or password.');
    $self->index;
}

sub signup
{
    my $self = shift;
    my $bp = $self->req->body_params->to_hash;
    my ($email, $name, $url) =
        map { defined $_ ? substr($_, 0, 512) : undef } @$bp{qw/email name url/};

    $self->stash(template => 'signup', user => 0);

    # Validation & sanitization
    $name = in_label($name);
    defined($name) && length($name) &&
    WZ::Validate::uri_http($url) &&
    WZ::Validate::email($email)
        or return $self->render(error => 'Invalid parameters');

    my $u = ChildProtect::User->new(
        email => $email,
        name  => $name,
        url   => $url,
        flag  => USER_NOT_CONFIRMED,
    );

    $u && $u->generate_api_key
        or return $self->render(error => 'Failed to create the user');

    $u->create
        or return $self->render(
            error => 'User with the same email address already exists');

    my $confirmation = ChildProtect::User::Confirmation->new(user => $u);
    my $confirmation_code = $confirmation->add(CONFIRM_USR_ACTIVATE)
        or return $self->render(
            code => 500, error => 'Failed to register the user');

    WZ->mailer->send(
        'signup-confirmation' => {
            user => $u,
            url  =>
                $self->url_for($self->app->config->{base_url} . 'signup-confirm')
                    ->query(
                        c => $confirmation_code,
                        u => $u->id,
                    ),
        },
        to => $u->email,
    );

    $self->render(user => $u);
}

sub signup_confirm
{
    my $self = shift;
    my $qp = $self->req->query_params->to_hash;
    my ($confirmation_code, $user_id) =
        map { defined $_ ? substr($_, 0, 32) : undef } @$qp{qw/c u/};

    $self->stash(template => 'signup-confirm');

    if (
        my $confirmation =
            ChildProtect::User::Confirmation->new(user_id => $user_id)
    ) {
        if ($confirmation->confirm(CONFIRM_USR_ACTIVATE, $confirmation_code))
        {
            my $u = $confirmation->user;
            my $password = $u->generate_pwd
                or $self->render(error => 'Failed to generate a password.');
            $u->set_flag( - USER_NOT_CONFIRMED);
            $u->update
                or $self->render(error => 'Failed to update the user.');

            WZ->mailer->send(
                'signup-welcome' => {
                    user     => $u,
                    password => $password,
                    url      => $self->app->config->{base_url},
                },
                to => $u->email,
            );

            return $self->render(user => $u);
        }
    }

    $self->render(error => 'The confirmation code is invalid or expired.');
}

sub in_label
{
    defined $_[0] or return;
    $_[0] = WZ::Sanitize::trim($_[0]);
    $_[0] = WZ::Sanitize::xml_escape($_[0]);
}

1;
__END__