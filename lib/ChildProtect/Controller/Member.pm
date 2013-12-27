package ChildProtect::Controller::Member;
use Mojo::Base 'Mojolicious::Controller';
use lib '../../';
use ChildProtect::User qw(:const_flags);
use WZ;


sub auth
{
    my $self = shift;
    $self->redirect_to('/?' . $self->req->query_params->to_string) &&
        return 0
            unless $self->user_exists;

    return 1;
}

sub index
{
    my $self = shift;
    $self->render(
        template => 'member/index',
        user     => $self->user,
    );
}

sub change_password
{
    my $self = shift;
    my $req = $self->req;
    my $u = $self->user;

    $self->stash(template => 'member/change-password');

    ('POST' ne $req->method) && $self->render(user => $u);

    my $bp = $req->body_params->to_hash;
    my ($oldpassword, $password, $confirmpassword) =
        map { defined $_ ? substr($_, 0, 255) : undef }
            @$bp{qw/oldpassword password confirmpassword/};

    if (
        ($oldpassword && $password && $confirmpassword) &&
        ($password ne $oldpassword) && ($password eq $confirmpassword) &&
        $u->check_password($oldpassword) &&
        $u->pwd($password)
    ) {
        $u->set_flag( - USER_MUST_UPDATE);
        if ($u->update)
        {
            $self->stash(message => 'Password has been successfully changed');
            return $self->index;
        }
    }

    $self->render(
        template => 'member/change-password',
        user     => $u,
        error    => 'Password mismatch. Please, check your input.'
    );
}

1;
__END__