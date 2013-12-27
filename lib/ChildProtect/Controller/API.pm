package ChildProtect::Controller::API;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Date;
use ChildProtect::Tokens;
use ChildProtect::User;
use Digest::SHA qw(hmac_sha256_base64);
use utf8;


sub auth
{
    my $self        = shift;
    my $req         = $self->req;
    my $params      = $req->query_params->to_hash;
    my $auth_header = $req->headers->authorization;
    my ($key_id, $signature, $timestamp);
    my $time        = time();
    my $exp_time    = 0;
    my $user;

    if ( $auth_header && (my $date_header = $req->headers->date) &&
        ( ($key_id, $signature) = ($req->headers->authorization =~
            m/^ChildProtect (\d{1,10})\:((?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?)$/
        ) )
    )
    {
        my $date = Mojo::Date->new($date_header);
        if ($exp_time = $date->epoch)
        {
            $exp_time  += 780;
            $timestamp  = $date_header;    #  $date->to_string;
        }
    }
    else
    {
        $signature = delete $params->{Signature};
        $key_id    = delete $params->{KeyId};
        $timestamp = delete $params->{Expires} // 0;
        $exp_time  = int($timestamp);
    }

    unless ($signature && $key_id && $timestamp)
    {
        $self->render(status => 403, json => { error => 'INVALID_REQUEST' });
        return 0;
    }

    my $time_delta = int($exp_time) - $time;
    if ($time_delta > 900)
    {
        $self->render(
            status => 403, json => { error => 'WRONG_EXPIRATION' });
        return 0;
    }
    elsif ($time_delta <= 0)
    {
        $self->render(status => 403, json => { error => 'EXPIRED_REQUEST' });
        return 0;
    }

    if (
        ($user = ChildProtect::User->new(id => $key_id)) &&
        $user->exists && $user->is_valid
    ) {
        $self->stash(user => $user);

        my $data =
            $req->method . "\n" .
            $req->url->path . "\n" .
            $timestamp;

        utf8::encode($data);

        $signature =~ s/\={1,2}$//;  # remove trailing equal signs of Base64
        my $local_signature = hmac_sha256_base64($data, $user->api_key);
        return 1 if ($local_signature eq $signature);
    }

    $self->render(status => 403, json => { error => 'AUTHENTICATION_FAILED' });
    return 0;
}

sub put_tokens
{
    my $self    = shift;
    my $params  = $self->req->json;
    my $tokens_list = extract_body_tokens($params)
        or return
            $self->render(status => 200, json => { error => 'INVALID_REQUEST' });

    my $tokens = ChildProtect::Tokens->new(user => $self->stash('user'));

    if ($tokens_list &&
        defined( my $cnt = $tokens->submit($tokens_list) )
    ) {
        return $cnt
            ? $self->render(status => 202, json => { accepted => $cnt })
            : $self->render(status => 200, json => { accepted => 0    });
    }

    $self->render(status => 200, json => { error => 'INVALID_PARAMETERS' });
}

sub put_token
{
    my $self    = shift;
    my $params  = $self->req->json;
    my $footprint = extract_param_footprint($self->param('footprint'))
        or return
            $self->render(status => 200, json => { error => 'INVALID_REQUEST' });

    my $tokens = ChildProtect::Tokens->new(user => $self->stash('user'));

    if ($footprint &&
        defined( my $cnt = $tokens->submit([ $footprint ]) )
    ) {
        return $cnt
            ? $self->render(status => 202, json => { accepted => $cnt })
            : $self->render(status => 200, json => { accepted => 0    });
    }

    $self->render(status => 200, json => { error => 'INVALID_PARAMETERS' });
}

sub put_tokens_deleted
{
    my $self    = shift;
    my $params  = $self->req->json;
    my $tokens_list = extract_body_tokens($params)
        or return
            $self->render(status => 200, json => { error => 'INVALID_REQUEST' });

    my $tokens = ChildProtect::Tokens->new(user => $self->stash('user'));

    if ($tokens_list &&
        defined( my $cnt = $tokens->report_deletion($tokens_list) )
    ) {
        return $cnt
            ? $self->render(status => 202, json => { accepted => $cnt })
            : $self->render(status => 200, json => { accepted => 0    });
    }

    $self->render(status => 200, json => { error => 'INVALID_PARAMETERS' });
}

sub delete_token
{
    my $self    = shift;
    my $params  = $self->req->params->to_hash;
    my $footprint = extract_param_footprint($self->param('footprint'))
        or return
            $self->render(status => 200, json => { error => 'INVALID_REQUEST' });

    my $tokens  = ChildProtect::Tokens->new(user => $self->stash('user'));

    if ($footprint &&
        defined( my $cnt = $tokens->report_deletion([ $footprint ]) )
    ) {
        return $cnt
            ? $self->render(status => 202, json => { accepted => $cnt })
            : $self->render(status => 200, json => { accepted => 0    });
    }

    $self->render(status => 200, json => { error => 'INVALID_PARAMETERS' });
}

sub get_tokens_submitted
{
    my $self    = shift;
    my $params  = $self->req->params->to_hash;
    my $tokens  = ChildProtect::Tokens->new(user => $self->stash('user'));

    if (
        my $list = $tokens->list_submitted($params->{date1}, $params->{date2})
    ) {
        return $self->render(status => 200, json => { tokens => $list })
    }

    $self->render(status => 200, json => { error => 'INVALID_PARAMETERS' });
}

sub get_tokens_deleted
{
    my $self    = shift;
    my $params  = $self->req->params->to_hash;
    my $tokens  = ChildProtect::Tokens->new(user => $self->stash('user'));

    if (
        my $list = $tokens->list_deleted($params->{date1}, $params->{date2})
    ) {
        return $self->render(status => 200, json => { tokens => $list })
    }

    $self->render(status => 200, json => { error => 'INVALID_PARAMETERS' });
}

sub get_tokens_foreign
{
    my $self    = shift;
    my $params  = $self->req->params->to_hash;
    my $tokens  = ChildProtect::Tokens->new(user => $self->stash('user'));

    if (
        my $list = $tokens->list_foreign($params->{date1}, $params->{date2})
    ) {
        return $self->render(status => 200, json => { tokens => $list })
    }

    $self->render(status => 200, json => { error => 'INVALID_PARAMETERS' });
}

sub get_counters
{
    my $self = shift;
    my $user = $self->stash('user');

    $self->render(status => 200, json => {
        submitted => $user->tokens_submitted // 0,
        deleted   => $user->tokens_deleted   // 0
    } );
}

sub extract_param_footprint
{
    my $footprint_str = $_[0] or return 0;
    my $footprint = [ split(':', $footprint_str, 2) ];
    return $footprint;
}

sub extract_body_tokens
{
    my $params = $_[0];
    ('HASH' eq ref $params) or return 0;
    my $tokens = $params->{tokens};
    ('ARRAY' eq ref $tokens) or return 0;
    return $tokens;
}

1;
__END__
