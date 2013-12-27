package WZ;

use strict;

require Mojo::Home;
require WZ::Config;
require WZ::Cache;
require WZ::Mailer;
use WZ::DB;

my %INSTANCES;


sub instance
{
    my $class = shift;
    $INSTANCES{$class}   = $class->new(@_) if (@_);
    $INSTANCES{$class} ||= $class->new;
}

sub new
{
    my ($class, @args) = @_;
    my $self = bless {}, ref $class || $class;

    if (@args && !(@args % 2))
    {
        $self->{conf} = WZ::Config->new(@args)->conf;
    }

    return $self;
}

sub conf
{
    my ($wz, $name) = @_;
    ref $wz or $wz = $wz->instance;
    $wz->{conf} ||= WZ::Config->new( name => $name )->conf;
}

*cfg = *conf;

sub home
{
    my ($wz, $home) = @_;
    ref $wz or $wz = $wz->instance;

    if ($home)
    {
        if (ref $home)
        {
            return $wz->{home} = $home;
        }
        else
        {
            my $mojo_home = Mojo::Home->new;
            $mojo_home->parse($home);
            return $wz->{home} = $mojo_home;
        }
    }

    $wz->{home} ||= Mojo::Home->new->detect;
}

sub mailer
{
    my ($wz, $home) = @_;
    ref $wz or $wz = $wz->instance;
    $wz->{mailer} ||= WZ::Mailer->new(%{ $wz->conf->{mail} || {} });
}

sub _init_db
{
    my ($wz, $model) = @_;
    ref $wz or $wz = $wz->instance;

    if (my $conf_db = $wz->conf->{db})
    {
        $wz->{db} = {};
        WZ::DB::configure(%$conf_db);
    }
}

sub db
{
    my ($wz, $model) = @_;
    ref $wz or $wz = $wz->instance;
    $model //= 'main';
    $wz->_init_db unless $wz->{db};
    $wz->{db}{$model} ||= WZ::DB->get($model);
}

sub db_ids
{
    my ($wz, $model) = @_;
    ref $wz or $wz = $wz->instance;
    $model //= 'main';
    $wz->_init_db unless $wz->{db};
    WZ::DB::get_ids($model);
}

sub cache
{
    my ($wz, $namespace) = @_;
    ref $wz or $wz = $wz->instance;
    my $cache_conf = $wz->conf->{cache} or return;
    WZ::Cache->new(
        namespace => $namespace,
        servers   => $cache_conf->{servers},
        ttl       => $cache_conf->{ttl},
    );
}

1;
__END__