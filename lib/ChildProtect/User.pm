package ChildProtect::User;

use strict;
use warnings;
use Carp;
use Digest::MD5;
use String::Random;
require Exporter;

require WZ;
require WZ::Validate;


# User Flags
use constant USER_DISABLED      => 1;
use constant USER_NOT_CONFIRMED => 2;
use constant USER_MUST_UPDATE   => 4;


my @Export_const_flags = qw(
    USER_DISABLED USER_NOT_CONFIRMED USER_MUST_UPDATE
);

our @ISA          = qw(Exporter);
our @EXPORT_OK    = (@Export_const_flags);
our %EXPORT_TAGS  = (
    const_flags => \@Export_const_flags,
);

my $MAX_LOGIN_TRIES     = 10;
my $LOGIN_BLOCKOUT_TIME = 300;
my $CACHE_TTL           = 300;
my $MIN_PASSWORD_LENGTH = 10;
my $MAX_PASSWORD_LENGTH = 64;
my @FIELDS_LOAD = qw/
    id email name url flag api_key
    last_login_time last_login_host
    tokens_submitted tokens_deleted
/;
my @FIELDS_UPDATE = qw/email name url flag api_key pwd/;
my @FIELDS_CREATE = qw/email name url flag api_key/;

my $SQL_FIELDS_LOAD   = join(', ', @FIELDS_LOAD);
my $SQL_FIELDS_UPDATE = join(', ', @FIELDS_UPDATE);
my $SQL_FIELDS_CREATE = join(', ', @FIELDS_CREATE);

my $StringRandom = String::Random->new;


sub new
{
    my ($class, @args) = @_;
    my $self = bless {
        @args,
    }, ref $class || $class;

    $self->{cache} ||= WZ->cache('CHPT:User');
    $self;
}

sub exists
{
    my $self = shift;
    defined $self->{exists} and return $self->{exists};
    $self->{exists} = $self->load;
    return $self->{exists} ? $self : 0;
}

sub load
{
    my $self = shift;
    my $dbh   = $self->dbh;
    my $rec;
    my $sql_fields = join(', ', @FIELDS_LOAD);

    if (WZ::Validate::id($self->id))
    {
        $rec = $self->cache->get($self->id);

        if (!$rec)
        {
            $rec = $self->dbh->selectrow_hashref(<<SQL_END, undef, $self->id);

        SELECT $SQL_FIELDS_LOAD
        FROM user WHERE id = ? AND deleted = 0 LIMIT 1
SQL_END

            $self->cache->set($self->id, $rec, $CACHE_TTL);
        }
    }
    elsif (WZ::Validate::email($self->email))
    {
        $rec = $self->dbh->selectrow_hashref(
            <<SQL_END, undef, $self->email);

        SELECT $SQL_FIELDS_LOAD
        FROM user WHERE email = ? AND deleted = 0 LIMIT 1
SQL_END
    }

    if ($rec && %$rec)
    {
        @$self{@FIELDS_LOAD} = @$rec{@FIELDS_LOAD};
        return 1;
    }

    0;
}

sub create
{
    my $self = shift;

    defined $self->{email} || return 0;
    defined $self->{name}  || return 0;
    $self->{flag} ||= 0;

    $self->new(
        email => $self->{email},
        db    => $self->db,
    )->exists and return 0;

    my $sql_phs = '?,' x @FIELDS_CREATE; chop $sql_phs;
    $self->dbh->do(<<SQL_END, undef, @$self{@FIELDS_CREATE}) or return 0;

    INSERT INTO user
    (created_time, $SQL_FIELDS_CREATE)
    VALUES (NOW(), $sql_phs)
SQL_END

    my $new_id =
        $self->dbh->last_insert_id(undef, undef, 'user', 'id')
            or return 0;

    $self->{exists} = 1;
    $self->{id} = $new_id;
}

sub update
{
    my $self = shift;

    $self->id or return 0;

    my $sql_set = '';
    my @values = ($self->id);

    for my $col (@FIELDS_UPDATE)
    {
        if (exists $self->{$col})
        {
            my $sql_col_set = ('pwd' eq $col) ? "$col = UNHEX(?)" : "$col = ?";
            $sql_set = $sql_col_set . ", " . $sql_set;
            unshift @values, $self->{$col};
        }
    }

    my $cnt = $self->dbh->do(<<SQL_END, undef, @values);

    UPDATE user
    SET $sql_set modified_time = NOW()
    WHERE id = ? AND deleted = 0
SQL_END

    my $res = ($cnt && ($cnt > 0)) ? 1 : 0;
    $self->cache->delete($self->id) if $res;
    $res;
}

sub delete
{
    my $self = shift;

    $self->id or return 0;

    my @values = ($self->id);
    my $cnt = $self->dbh->do(<<SQL_END, undef, @values);

    UPDATE user
    SET deleted = 1, modified_time = NOW()
    WHERE id = ? AND deleted = 0
SQL_END

    my $res = ($cnt && ($cnt > 0)) ? 1 : 0;
    $self->cache->delete($self->id) if $res;
    $res;
}

sub check_password
{
    my ($self, $password) = @_;

    $self->id or return 0;
    $self->check_password_hash($self->make_pwd_hash($password))
        or return 0;

    1;
}

sub check_password_hash
{
    my ($self, $challenge_pwd) = @_;
    $self->id or return 0;
    my $real_pwd = $self->{pwd};

    ($real_pwd) = $self->dbh->selectrow_array(
        <<SQL_END, undef, $self->id) unless defined $real_pwd;

    SELECT HEX(pwd)
    FROM user
    WHERE id = ? AND deleted = 0 LIMIT 1
SQL_END

    defined($real_pwd) && ($challenge_pwd eq $real_pwd) || return 0;
    $self->{pwd} = $real_pwd;
    1;
}

sub login
{
    my ($self, $password, $hostname) = @_;
    my $cnt_tries;

    $self->{logged_in} && return 1;

    if ($hostname)
    {
        $cnt_tries = ($self->cache->get("h:$hostname") // 0) + 1;
        return 0 if ($cnt_tries> $MAX_LOGIN_TRIES);
    }

    unless (
        defined($password) &&
        $self->exists &&
        $self->is_valid &&
        $self->check_password($password)
    ) {
        # Increment unsuccessfull challenges counter
        if ($hostname)
        {
            $self->cache->set("h:$hostname", $cnt_tries, $LOGIN_BLOCKOUT_TIME);
        }

        return 0;
    }

    $self->dbh->do(
        <<SQL_END, undef, $hostname, $self->id) or return $self->{logged_in} = 0;

    UPDATE user
    SET last_login_time = NOW(), last_login_host = ?
    WHERE id = ?
SQL_END

    $self->{logged_in} = 1;
}

sub has_flag
{
    my ($self, @test) = @_;
    $self->_is_flag('flag', @test);
}

sub is_valid
{
    my $self = shift;
    my $flag = $self->{flag};

    $flag & $_ and return for (USER_DISABLED, USER_NOT_CONFIRMED);

    1;
}

sub account
{
    my $self = shift;
    return $self->{account} if $self->{account};
    my $account_id = $self->{account_id} or return;

    # mind the different DBH
    $self->{account} =
        $self->dbh->selectrow_hashref(<<SQL_END, undef, $account_id) || undef;

    SELECT number, name, title, type
    FROM account
    WHERE id = ? AND deleted = 0 AND status = 1
    LIMIT 1
SQL_END
}

sub pwd
{
    my ($self, $password) = @_;
    defined($password) or return $self->{pwd};
    (length($password) >= $MIN_PASSWORD_LENGTH) || return 0;
    $self->{pwd} = $self->make_pwd_hash($password);
}

sub generate_pwd
{
    my $self = shift;
    my $password = $StringRandom->randpattern('sss!ssss!s');
    return $self->pwd($password) ? $password : undef;
}

sub generate_api_key
{
    my $self = shift;
    $self->{api_key} = $StringRandom->randregex('\w{24}');
}

sub make_pwd_hash
{
    my ($self, $password) = @_;
    defined($password) or return;

    uc( Digest::MD5->new
            ->add( substr($password, 0, $MAX_PASSWORD_LENGTH) )
                ->hexdigest
    );
}

sub set_flag
{
    my ($self, $add_flag) = @_;
    $add_flag or return;
    my $flag = $self->{flag} // 0;

    return $self->{flag} = $flag + $add_flag
        if (
            (($add_flag > 0) && ($flag | $add_flag)) ||
            (($add_flag < 0) && ($flag & abs($add_flag)))
        );

    0;
}

sub cache        { $_[0]->{cache}              }
sub db           { $_[0]->{db} ||= WZ->db      }
sub dbh          { $_[0]->db->dbh              }
sub id           { $_[0]->{id}                 }
sub email        { $_[0]->{email}              }
sub name         { $_[0]->{name}               }
sub url          { $_[0]->{url}                }
sub api_key      { $_[0]->{api_key}            }
sub flag         { defined $_[1] ? $_[0]->{flag} = $_[1] : $_[0]->{flag} }
sub logged_in    { $_[0]->{logged_in}          }

sub tokens_submitted { $_[0]->{tokens_submitted} }
sub tokens_deleted   { $_[0]->{tokens_deleted}   }

sub display_name
{
    my $self = shift;
    $self->{name} // '' . ' <' . $self->{email} . '>';
}

sub get
{
    my $self = shift;
    $self->exists or return 0;

    my %body;
    @body{@FIELDS_LOAD} = @$self{@FIELDS_LOAD};

    if (my $account = $self->account)
    {
        $body{account} = $account;
    }

    \%body;
}

sub _is_flag
{
    my ($self, $attr_name, @test_flags) = @_;
    my $flag = $self->{$attr_name} || 0;

    @test_flags or return $flag ? 1 : 0;

    for (@test_flags)
    {
        ($_ & $flag) and return 1;
    }

    0;
}

1;
__END__