package WZ::Cache;

use strict;
use warnings;
use Data::Dumper;

require Carp;
use Cache::Memcached::Fast 0.19;


sub new
{
    my ($class, @args) = @_;
    my $self      = bless { @args }, ref $class || $class;
    my $namespace = ($self->{namespace} // 'WZ') . ':';
    my $prefix    = $self->{prefix} // '';
    my $servers   = $self->{servers};

    $servers && @$servers
        or Carp::croak('One or more memcached servers should be specified');

    if ($self->{memcached})
    {
        $self->prefix($namespace . $prefix);
        return $self;
    }

    $self->prefix($prefix);
    $self->{memcached} = Cache::Memcached::Fast->new( {
        servers            => $servers,
        namespace          => $namespace,
        connect_timeout    => 0.2,
        io_timeout         => 0.5,
        close_on_error     => 0,
        compress_threshold => 100_000,
        compress_ratio     => 0.8,
        max_failures       => 0,
        failure_timeout    => 2,
        nowait             => 1,
        hash_namespace     => 1,
        utf8               => 1,
        max_size           => 1048576,  # 1Mb
    } )
        or Carp::croak('Failed to connect to Memcached server');

    $self;
}

sub freeze_keyref
{
    my ($class, $keyref) = @_;
    $keyref or return '';

    local $Data::Dumper::Purity = 0;
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Useqq  = 0;
    local $Data::Dumper::Terse  = 1;
    local $Data::Dumper::Quotekeys = 0;
    local $Data::Dumper::Pair = ',';
    local $Data::Dumper::Maxdepth = 0;
    local $Data::Dumper::Sortkeys = 1;

    my $key = Dumper($keyref);
    $key =~ s/[\s\r\n\t]/\+/g;

    if ($key =~ m/[\p{IsWord}\/|\[\]\{\}\-\.\,]{1,250}/)
    {
        return $key;
    }

    return '';
}

sub prefix
{
    my ($self, $prefix) = @_;
    if (defined $prefix)
    {
        return $self->{prefix} = length($prefix) ? "$prefix:" : '';
    }

    $self->{prefix};
}

# TODO:
# implemet *_multi behavior if @_ > 1

sub get
{
    my ($self, $key) = @_;
    defined $key or return 0;
    $self->{memcached}->get($self->{prefix} . $key);
}

sub set
{
    my ($self, $key, $value, $ttl) = @_;
    defined $key or return 0;
    defined $value or return $self->delete($key);
    $ttl //= $self->{ttl};
    $self->{memcached}->set($self->{prefix} . $key, $value, $ttl);
}

sub delete
{
    my ($self, $key) = @_;
    defined $key or return 0;
    $self->{memcached}->delete($self->{prefix} . $key);
}

sub clear  { shift->{memcached}->flush_all }

*remove = *delete;

sub memcached { shift->{memcached} }

1;
__END__