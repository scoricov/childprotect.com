package WZ::DB;

use strict;
use warnings;
use DBI 1.616;
use Try::Tiny;
require Time::HiRes;
require Carp;

our $CONNECT_ONLOAD = 0;
our $AUTO_COMMIT    = 1;
our $USE_RESULT     = 0;
our $PERSISTENT     = 1;
our $CONN_MAX_TRIES = 3;
our $CONN_TRY_DELAY = 500_000;
our $DEFAULT_MODEL  = 'default';
my  (@DB_CREDENTIALS, @DBH, %DB_MAP, $DSN_POSTFIX);


sub get_id
{
    my ($model, $sharding_coderef, @args) = @_;
    my $db_map = _get_model_map($model);
    my ($db_offset, $db_count) = @$db_map;
    return $db_offset unless $sharding_coderef;

    my $slice = $sharding_coderef->($db_count, @args) || 0;
        # sharding code should return value between
        # 0 .. $db_count - 1

    return $db_offset + $slice;
        # should return value between
        # $db_offset .. $db_offset + $db_count - 1
}

sub get_ids($)
{
    my $db_map = _get_model_map(shift);
    my ($db_offset, $db_count) = @$db_map;
    return ($db_offset .. $db_offset + $db_count - 1);
}

sub get_credentials($)
{
    my $db_id = shift;
    my $credentials = $DB_CREDENTIALS[$db_id]
        or Carp::croak(
            sprintf 'Database credentials with ID "%s" not found', $db_id
        );
    return @$credentials;
}

sub get_dbh($)
{
    my $db_id = shift;
    my $dbh   = $DBH[$db_id];

    $dbh && $dbh->ping && return $dbh;

    if ($dbh)
    {
        try { $dbh->disconnect };
        $dbh = undef;
    }

    my $cnt_tries = 0;
    my ($hostname, $database, $username, $password, $charset) =
        get_credentials($db_id);
    my $mysql_enable_utf8 = ($charset && ($charset =~ m/^utf-?8/i)) ? 1 : 0;

    $CONN_MAX_TRIES ||= 1;

    while (!$dbh && ($cnt_tries < $CONN_MAX_TRIES))
    {
        Time::HiRes::usleep($CONN_TRY_DELAY) if ($cnt_tries && $CONN_TRY_DELAY);
        $cnt_tries ++;

        $dbh = DBI->connect(
            "dbi:mysql:$database;host=$hostname$DSN_POSTFIX",
            $username, $password, {
                RaiseError            => 1,
                HandleError           => sub { Carp::carp(shift) },
                AutoCommit            => $AUTO_COMMIT,
                mysql_auto_reconnect  => 1,
                mysql_connect_timeout => 1, # 1 second
                mysql_enable_utf8     => $mysql_enable_utf8,
                mysql_use_result      => $USE_RESULT,
                FetchHashKeyName      => 'NAME_lc',
            }
        );
    }

    $dbh or Carp::croak(
        sprintf 'Failed to connect to MySQL database "%s@%s" with ' .
            'username "%s". Error: %s',
        $database, $hostname, $username, $DBI::errstr
    );

    if ($charset && !$mysql_enable_utf8)
    {
        $dbh->do("SET NAMES $charset");
        $dbh->do("SET CHARACTER SET $charset");
    }

    # $dbh->trace('SQL');

    return $DBH[$db_id] = $dbh;
}

sub configure
{
    my %args = @_;
    for my $model (keys %args)
    {
        my $credentials = $args{$model} or next;
        set_credentials($model, %$credentials);

        if ($CONNECT_ONLOAD)
        {
            get_dbh($_) for (get_ids($model));
        }
    }
}

sub set_credentials
{
    my ($model, %credentials) = @_;
    $model = $DEFAULT_MODEL unless defined $model;
    %credentials or Carp::croak("Empty credentials for model '$model'");

    my $db_offset = int($#DBH + 1);
    my $db_count = 0;

    if (my $db_map = $DB_MAP{$model})
    {
        Carp::carp(
            sprintf 'Credentials for database model "%s" are already set',
                    $model
        );
        return $db_map;
    }

    foreach (sort { $a <=> $b } keys %credentials)
    {
        push @DBH,            0;
        my $creds = $credentials{$_};
        $creds = parse_credentials($creds) unless ref $creds;
        push @DB_CREDENTIALS, $creds;
        $db_count++;
    }

    return $DB_MAP{$model} = [$db_offset, $db_count];
}

sub parse_credentials
{
    my @credentials = split(/\s*,\s*/, shift);
    return \@credentials;
}

sub _get_model_map
{
    my $model = shift;
    $DB_MAP{$model} or Carp::croak("Unknown database model '$model'");
}

#
# Class methods
#

sub import
{
    my ($class, @args) = @_;
    init(@args) if @args;
}

sub new
{
    my ($class, $db_id, $is_persistent) = @_;
    bless [
        $db_id,
        get_dbh($db_id),
        $is_persistent // $PERSISTENT
    ], ref $class || $class;
}

sub get
{
    my ($class, $model, @sharding) = @_;
    $class->new(
        get_id(defined $model ? $model : $DEFAULT_MODEL, @sharding)
    );
}

#
# Object methods
#

sub dbh
{
    my $self = shift;
    return $self->[1] ||= get_dbh( $self->[0] );
}

sub DESTROY
{
    my $self = shift;
    if (!($self->[2]) && (my $dbh = $self->[1]))
    {
        try { $dbh->disconnect };
    }
}

BEGIN {
    @DB_CREDENTIALS = ();
    @DBH            = ();
    %DB_MAP         = ();
    $DSN_POSTFIX    = '';
}

1;
__END__