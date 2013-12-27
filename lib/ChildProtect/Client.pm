package ChildProtect::Client;

use v5.12;
use strict;
use warnings;
use utf8;
require Carp;

use Mojo::UserAgent;
use Mojo::URL;
use Mojo::Date;
use Mojo::JSON;
use Digest::SHA qw(hmac_sha256_base64);
require WZ::Validate;
require ChildProtect::Tokens;


sub new
{
    my ($class, @args) = @_;
    my $self = bless {
        api_url     => 'https://api.childprotect.com/',
        api_version => 2,
        auth_header => 1,
        @args,
        last_error => undef,
    }, ref $class || $class;

    $self->{api_url}    or Carp::croak('API URL is not specified');
    $self->{api_key_id} or Carp::croak('API key ID is not specified');
    $self->{api_key}    or Carp::croak('API key is not specified');
    $self->{api_url} .= '/' unless ($self->{api_url} =~ m/\/$/);

    return $self;
}

sub make_request
{
    my ($self, $method, $path, $params) = @_;
    $path or return 0;
    $method = $method ? uc($method) : 'GET';

    my $auth_header = $self->{auth_header};
    my $ua = Mojo::UserAgent->new(name => 'ChildProtect API Client');
    my $url = Mojo::URL->new(
        $self->{api_url} . 'REST/' . $self->{api_version} . '/' . $path
    );
    my $tx;
    my $timestamp = time();

    if ($auth_header)
    {
        $timestamp = Mojo::Date->new($timestamp)->to_string;
    }
    else
    {
        $timestamp += 120;
    }

    if (('POST' eq $method) || ('PUT' eq $method))
    {
        $tx = $ua->build_tx($method => $url);
        $tx->req->body(Mojo::JSON->encode($params)) if $params;
    }
    else
    {
        $url->query->params([ %$params ]) if $params;
        $tx = $ua->build_tx($method => $url);
    }

    my $data =
        $tx->req->method . "\n" .
        $tx->req->url->path . "\n" .
        $timestamp;

    utf8::encode($data);

    # Add trailing '=' to the signature to pass Base64 validation
    my $signature = hmac_sha256_base64($data, $self->{api_key}) . '=';
    my $req = $tx->req;

    if ($auth_header)
    {
        my $headers = $req->headers;
        $headers->authorization(
            'ChildProtect ' . $self->{api_key_id} . ':' . $signature
        );
        $headers->date($timestamp);
    }
    else
    {
        my $q = $req->url->query;
        $q->param(Signature => $signature);
        $q->param(Expires   => $timestamp);
        $q->param(KeyId     => $self->{api_key_id});
    }

    $ua->start($tx);

    if (my $res = $tx->success)
    {
        my $result = $res->json
            or Carp::carp('Received invalid API response');
        $self->{last_error} = $result->{error} // '';
        return $result;
    }
    else
    {
        my ($message, $code) = $tx->error;
        Carp::carp("Error: $message");
        return 0;
    }
}

sub put_tokens
{
    my ($self, $params) = @_;
    $self->make_request(
        PUT => 'tokens',
        { _accept_tokens($params) },
    );
}

sub put_token
{
    my ($self, $params) = @_;
    $self->make_request(PUT => 'tokens/' . _accept_footprint($params));
}

sub delete_tokens
{
    my ($self, $params) = @_;
    $self->make_request(
        PUT => 'tokens-deleted',
        { _accept_tokens($params) },
    );
}

sub delete_token
{
    my ($self, $params) = @_;
    $self->make_request(DELETE => 'tokens/' . _accept_footprint($params));
}

sub get_tokens_submitted
{
    my ($self, $params) = @_;
    $self->make_request(
        GET => 'tokens-submitted',
        { _accept_dates($params) },
    );
}

sub get_tokens_deleted
{
    my ($self, $params) = @_;
    $self->make_request(
        GET => 'tokens-deleted',
        { _accept_dates($params) },
    );
}

sub get_tokens
{
    my ($self, $params) = @_;
    $self->make_request(
        GET => 'tokens',
        { _accept_dates($params) },
    );
}

sub get_counters
{
    my ($self) = @_;
    $self->make_request(GET => 'counters');
}

sub last_error
{
    my $self = shift;
    my $last_error = $self->{last_error};
    $self->{last_error} = undef;
    return $last_error;
}

sub _accept_params
{
    my ($params, @wishlist) = @_;
    return {
        map { $_ => $params->{$_} } grep { defined $params->{$_} } @wishlist
    };
}

sub _accept_footprint
{
    my $params = $_[0];
    my $md5   = $params->{md5}
        or Carp::croak('Undefined token attribute: md5');
    my $fsize = $params->{fsize}
        or Carp::croak('Undefined token attribute: fsize');
    return "$md5:$fsize";
}

sub _accept_tokens
{
    my $params = $_[0];
    my $tokens = $params->{tokens} or Carp::croak('Undefined tokens list');
    ChildProtect::Tokens::validate_footprints($tokens)
        or Carp::croak('Invalid token footprints');
    return (tokens => $tokens);
}

sub _accept_dates
{
    my $params = $_[0];
    my ($date1, $date2) =
        ChildProtect::Tokens::validate_dates_period(@$params{qw/date1 date2/})
            or Carp::croak('Invalid dates period');
    return (date1 => $date1, date2 => $date2);
}

1;
__END__