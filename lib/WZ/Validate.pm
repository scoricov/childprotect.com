package WZ::Validate;

use strict;
use warnings;
use utf8;

use POSIX;
use Scalar::Util qw(looks_like_number);
use Math::BigInt;
use Try::Tiny;
use Regexp::Common 2011121001 qw/net whitespace URI/;
require Email::Valid;
require Date::Calc;


#  Support domain names starting with digits
#  Bug: https://rt.cpan.org/Public/Bug/Display.html?id=23626
my $RE_net_domain_nospace_str =
    '([A-Za-z0-9](?:(?:[-A-Za-z0-9]){0,61}[A-Za-z0-9])?' .
    '(?:\\.[A-Za-z0-9](?:(?:[-A-Za-z0-9]){0,61}[A-Za-z0-9])?)*)';
my $RE_net_domain_nospace = qr/$RE_net_domain_nospace_str/;


sub id
{
    defined($_[0]) && $_[0] =~ m/^[1-9]\d{0,9}$/
}

sub tinyint
{
    defined($_[0]) && $_[0] =~ m/^[0-9]|(?:[1-9]|1\d|2[0-4])\d|25[0-5]$/
}

sub int
{
    (defined($_[0]) && $_[0] =~ m/^\d{1,20}$/) || return;
    my $int = CORE::int($_[0]);
    $int =~ m/\D/ && return;
    $_[0] = $int;
    1;
}

sub date
{
    defined $_[0] or return;
    ($_[0]) = $_[0] =~ m/^(((19|20)?[0-9][0-9]\-(0?[469]|11)\-(0?[1-9]|[12][0-9]|30))|((19|20)?[0-9][0-9]\-(0?[13578]|1[02])\-(0?[1-9]|[12][0-9]|3[01]))|(((19)?([13579][26]|[02468][048])|(20)?[02468][48]|(20)?[13579][26])\-0?2\-(0?[1-9]|[012][0-9]))|(((19)?(([13579][01345789])|([02468][1235679]))|(20)?0[1235679]|(20)?1[01345789])\-0?2\-(0?[1-9]|[012][0-8])))$/
}

sub get_current_date
{
    my @now  = localtime();
    my @date = ($now[5] + 1900, $now[4] + 1, $now[3]);
    return wantarray ? @date : join('-', @date);
}

sub date_period
{
    my ($d1, $d2) = @_;
    ($d1 && $d2) or return 1;
    my $delta = Date::Calc::Delta_Days(split('-', $d1, 3), split('-', $d2, 3));
    ($delta < 0) ? 0 : 1;
}

sub date_expired
{
    my $date = shift or return 0;
    my @current_date = get_current_date();
    my $delta = Date::Calc::Delta_Days(@current_date, split('-', $date, 3));
    ($delta < 0) ? 1 : 0;
}

sub date_future
{
    my $date = shift or return 0;
    my @current_date = get_current_date();
    my $delta = Date::Calc::Delta_Days(@current_date, split('-', $date, 3));
    ($delta > 0) ? 1 : 0;
}

sub email
{
    my $email = shift or return;
    $email =~ m/^\p{ASCII}{3,255}$/ or return;
    my $result;
    try { $result = Email::Valid->address($email) };
    return $result;
}

sub db_credentials
{
    defined($_[0]) && length($_[0]) || return;
    my %creds = map { /(\d{1,2})\s*=\s*(.+)/ } split(/\s*;\s*/, $_[0])
        or return;
    $_[0] = \%creds;
}

# natural or zero
sub natz
{
    CORE::int($_[0]) or return;
    ($_[0] >= 0) or return;
    1;
}

# natural
sub nat
{
    CORE::int($_[0]) or return;
    ($_[0] > 0) or return;
    1;
}

sub bigint
{
    num($_[0]) or return;

    my ($int, $leftover) = POSIX::strtod($_[0]);
    return if $leftover;

    if(length($int) > 10)
    {
        my $i = Math::BigInt->new($_[0]);
        return unless $i->is_int();
        ($_[0]) = $i->bstr() =~ /(.+)/;
        return 1;
    }

    return unless (($int + 0) == ($_[0] + 0));
    return if $_[0] =~ /[^0-9\-]/;

    ($_[0]) = $int =~ /([\d\-]+)/;
    $_[0] = $_[0] + 0;
    1;
}

# inreger range. arguments: value, min, max, correct
sub int_range
{
    bigint($_[0]) or return;
    my $out_of_range = 0;

    if (defined $_[1])
    {
        $out_of_range = ($_[0] < $_[1]);
    }

    if (defined $_[2])
    {
        $out_of_range = ($_[0] > $_[2]);
    }

    if ($out_of_range)
    {
        return unless defined $_[3];
        $_[0] = $_[3];
    }

    1;
}

sub num
{
    defined($_[0]) && looks_like_number($_[0]) || return;
    ($_[0]) = $_[0] =~ /([\d\.\-+e]+)/;
    $_[0] = $_[0] + 0;
    1;
}

sub bool
{
    defined($_[0]) && $_[0] =~ m/^0|1$/;
}

sub bw_source
{
    defined($_[0]) && $_[0] =~ m/^[0-9\.\_\-a-z]{1,128}$/i
}

sub hostname
{
    defined($_[0]) && $_[0] =~ m/^$RE_net_domain_nospace$/;
}

sub ipv4_address
{
    defined($_[0]) && $_[0] =~ m/^$RE{net}{IPv4}$/
}

sub ipv4_subnet
{
    defined($_[0]) && $_[0] =~ m/^$RE{net}{IPv4}(\/\d{1,2})?$/
}

sub ipv4_host_address
{
    defined($_[0]) &&
    $_[0] =~ m/^($RE_net_domain_nospace|$RE{net}{IPv4})$/
}

sub hw_port
{
    defined($_[0]) && $_[0] =~ m/^[[:alpha:][:punct:][:xdigit:]]{1,40}$/;
}

sub md5_list
{
    my $md5_list = shift or return;
    /^[0-9a-f]{32}$/i or return for (@$md5_list);
    1;
}

sub uri_http
{
    defined($_[0]) && $_[0] =~ m/^$RE{URI}{HTTP}$/;
}

1;
__END__