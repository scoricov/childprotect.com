package ChildProtect::Tokens;

use strict;
use warnings;

require Carp;
require WZ;
require WZ::Validate;

my $MAX_BULK_TOKENS = 64;
my $MAX_LIST_TOKENS = 10000;


sub new
{
    my ($class, @args) = @_;
    my $self = bless {
        @args,
    }, ref $class || $class;

    $self->{db} ||= WZ->db;
    $self->{user} or Carp::croak('User is not defined');
    $self->{user_id} = $self->{user}->id
        or Carp::croak('User ID is not defined');

    return $self;
}

sub submit
{
    my ($self, $tokens, $date) = @_;
    my $blk_cnt = @$tokens or return 0;
    ($blk_cnt <= $MAX_BULK_TOKENS) or return;
    ($date) = validate_dates_period($date) or return;
    validate_footprints($tokens) or return;

    my $dbh     = $self->{db}->dbh;
    my $user_id = $self->{user_id};
    my $sql_values = $date
        ? "('$date', $user_id, ?),"
        : "(CURRENT_DATE(), $user_id, ?),";
    $sql_values = $sql_values x $blk_cnt; chop($sql_values);

    my $cnt = $dbh->do(<<SQL_END, undef, _pack_tokens($tokens));

    INSERT IGNORE INTO token (submitted, user_id, footprint)
    VALUES $sql_values
SQL_END

    if ($cnt && ($cnt > 0))
    {
        $dbh->do(<<SQL_END, undef, $cnt, $user_id);

        UPDATE user SET tokens_submitted = tokens_submitted + ?
        WHERE id = ?
SQL_END

        return $cnt;
    }

    return 0;
}

sub report_deletion
{
    my ($self, $footprints, $date) = @_;
    my $blk_cnt = @$footprints or return 0;
    ($blk_cnt <= $MAX_BULK_TOKENS) or return;
    ($date) = validate_dates_period($date) or return;
    validate_footprints($footprints) or return;

    my $dbh = $self->{db}->dbh;
    my $sql_in = '?,' x $blk_cnt; chop($sql_in);
    my $ids = $dbh->selectcol_arrayref(
        <<SQL_END, undef, _pack_footprints($footprints));

    SELECT id FROM token
    WHERE footprint IN ($sql_in)
    LIMIT $MAX_BULK_TOKENS
SQL_END

    ($ids && @$ids) or return 0;

    my $user_id = $self->{user_id};
    my $sql_values = $date
        ? "('$date', $user_id, ?),"
        : "(CURRENT_DATE(), $user_id, ?),";
    $sql_values = $sql_values x @$ids; chop($sql_values);

    my $cnt = $dbh->do(<<SQL_END, undef, @$ids);

    INSERT IGNORE INTO token_deleted
    (deleted, user_id, token_id)
    VALUES $sql_values
SQL_END

    if ($cnt && ($cnt > 0))
    {
        $dbh->do(<<SQL_END, undef, $cnt, $user_id);

        UPDATE user SET tokens_deleted = tokens_deleted + ?
        WHERE id = ?
SQL_END

        return $cnt;
    }

    return 0;
}

sub list_deleted
{
    my ($self, $date1, $date2) = @_;
    ($date1, $date2) = validate_dates_period($date1, $date2) or return;

    my $tokens = $self->{db}->dbh->selectall_arrayref(
        <<SQL_END, undef, $self->{user_id}, $date1, $date2);

    SELECT t.footprint, d.deleted
    FROM token_deleted d
    JOIN token t ON t.id = d.token_id
    WHERE d.user_id = ? AND d.deleted BETWEEN ? AND ?
    LIMIT $MAX_LIST_TOKENS
SQL_END

    return _extract_tokens($tokens);
}

sub list_foreign
{
    my ($self, $date1, $date2) = @_;
    ($date1, $date2) = validate_dates_period($date1, $date2) or return;

    my $user_id = $self->{user_id};
    my $tokens = $self->{db}->dbh->selectall_arrayref(
        <<SQL_END, undef, $user_id, $user_id, $date1, $date2);

    SELECT t.footprint, t.submitted
    FROM token t
    LEFT JOIN token_deleted d ON d.token_id = t.id AND d.user_id = ?
    WHERE t.user_id != ? AND d.user_id IS NULL AND t.submitted BETWEEN ? AND ?
    LIMIT $MAX_LIST_TOKENS
SQL_END

    return _extract_tokens($tokens);
}

sub list_submitted
{
    my ($self, $date1, $date2) = @_;
    ($date1, $date2) = validate_dates_period($date1, $date2) or return;

    my $tokens = $self->{db}->dbh->selectall_arrayref(
        <<SQL_END, undef, $self->{user_id}, $date1, $date2);

    SELECT t.footprint, t.submitted
    FROM token t
    WHERE t.user_id = ? AND t.submitted BETWEEN ? AND ?
    LIMIT $MAX_LIST_TOKENS
SQL_END

    return _extract_tokens($tokens);
}

sub validate_dates_period
{
    my ($date1, $date2) = @_;
    my $empty_date1;

    if ($date1)
    {
        ( WZ::Validate::date($date1) && !WZ::Validate::date_future($date1) )
            or return;
    }
    else
    {
        $empty_date1 = 1;
    }

    if ($date2)
    {
        ( WZ::Validate::date($date2) &&
          ( $empty_date1 || WZ::Validate::date_period($date1, $date2) )
        ) or return;

        $date1 = $date2 if ($empty_date1);
    }
    elsif ($empty_date1)
    {
        $date1 = $date2 = WZ::Validate::get_current_date();
    }
    else
    {
        $date2 = $date1;
    }

    return ($date1, $date2);
}

sub validate_footprints
{
    my $footprints = $_[0];

    for (@$footprints)
    {
        'ARRAY' eq ref or return 0;
        my ($md5, $fsize) = @$_[0, 1];

        $md5 && ($md5 =~ /^[0-9a-f]{32}$/i)
            or return 0;

        (  $fsize &&
          ($fsize =~ /^\d{1,20}$/) &&
          ($fsize > 0) && ($fsize < 18446744073709551615)
        )
            or return 0;
    }

    return 1;
}

sub _pack_tokens
{
    my $tokens = $_[0] or Carp::croak('Invalid tokens list to be packed');
    return map { pack('H32Q', @$_[0, 1]) } @$tokens;
}

*_pack_footprints = *_pack_tokens;  #  Yet.

sub _extract_tokens
{
    my $tokens = $_[0] or return 0;
    return [ map { [ (unpack('H32Q', $_->[0])), $_->[1] ] } @$tokens ];
}

1;
__END__