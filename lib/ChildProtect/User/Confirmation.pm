package ChildProtect::User::Confirmation;

use strict;
use warnings;
use Carp;
use Digest::MD5;
use String::Random;
require Exporter;

require WZ;
require ChildProtect::User;
require WZ::Validate;


# User confirmation codes
use constant CONFIRM_USR_ACTIVATE  => 1;
use constant CONFIRM_USR_RESETPASS => 2;

my @CONFIRM_CODES = (
    CONFIRM_USR_ACTIVATE,
    CONFIRM_USR_RESETPASS,
);

my @Export_const_codes = qw(
    CONFIRM_USR_ACTIVATE CONFIRM_USR_RESETPASS
);

our @ISA          = qw(Exporter);
our @EXPORT_OK    = (@Export_const_codes);
our %EXPORT_TAGS  = (
    const_codes => \@Export_const_codes,
);

my $CACHE_TTL = 900;  #15 min.
my $StringRandom = String::Random->new;


sub new
{
    my ($class, @args) = @_;
    my $self = bless {
        @args,
    }, ref $class || $class;

    unless ($self->{user})
    {
        my $user_id = $self->{user_id}
            or Carp::croak('User or user ID is not specified');
        my $user = ChildProtect::User->new(id => $user_id);
        $user && $user->exists or return 0;
        $self->{user} = $user;
    }

    $self->{cache} ||= WZ->cache('CHPT:User:Cf');
    $self;
}

sub confirm
{
    my ($self, $action_code, $confirm_code) = @_;
    my $user_id = $self->{user}->id or return 0;
    validate_codes($action_code, $confirm_code) or return 0;
    my $cache_key = "$user_id:$action_code";
    my $real_hash = $self->{hash} || $self->{cache}->get($cache_key);

    if (!$real_hash)
    {
        ($real_hash) = $self->{user}->dbh->selectrow_array(
            <<SQL_END, undef, $user_id, $action_code);

        SELECT HEX(hash)
        FROM user_confirm WHERE user_id = ? AND action = ?
SQL_END

        $self->{cache}->set($cache_key, $real_hash, $CACHE_TTL);
    }

    return 0 if !$real_hash;

    if ($self->make_hash($cache_key, $confirm_code) eq $real_hash)
    {
        $self->{user}->dbh->do(
            <<SQL_END, undef, $user_id, $action_code);

        DELETE FROM user_confirm WHERE user_id = ? AND action = ?
SQL_END

        $self->{cache}->delete($cache_key);

        return 1;
    }

    return 0;
}

sub add
{
    my ($self, $action_code) = @_;
    my $user_id = $self->{user}->id or return 0;
    my $cache_key = "$user_id:$action_code";
    my $confirm_code = $self->generate_confirmation_code;
    my $hash = $self->{hash} = $self->make_hash($cache_key, $confirm_code)
        or return 0;

    my $cnt = $self->{user}->dbh->do(
        <<SQL_END, undef, $user_id, $action_code, $hash);

        INSERT INTO user_confirm (user_id, action, hash, created_time)
        VALUES (?, ?, UNHEX(?), NOW())
        ON DUPLICATE KEY UPDATE hash = VALUES(hash), created_time = NOW()
SQL_END

    if ($cnt && ($cnt > 0))
    {
        $self->{cache}->set($cache_key, $hash, $CACHE_TTL);
        return $confirm_code;
    }

    return 0;
}

sub generate_confirmation_code
{
    my $self = shift;
    $self->{cc} = $StringRandom->randregex('\w{32}');
}

sub make_hash
{
    my ($self, $useraction, $confirm_code) = @_;
    $useraction && $confirm_code or return 0;
    uc( Digest::MD5->new->add($useraction, $confirm_code)->hexdigest );
}

sub validate_codes
{
    my ($action_code, $confirm_code) = @_;

    (   WZ::Validate::id($action_code) &&
        $confirm_code &&
        ($confirm_code =~ m/^[A-Za-z0-9_\-\.\/]{32}$/) &&
        grep({$action_code == $_} @CONFIRM_CODES)
    )
        and return 1;

    return 0;
}

sub user { $_[0]->{user} }

1;
__END__