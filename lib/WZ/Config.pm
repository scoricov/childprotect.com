package WZ::Config;

use strict;
use warnings;
require Carp;
require WZ;


my $DEFAULT_NAME   = 'webzilla';
my $FILE_EXTENTION = '.conf';

sub new
{
    my ($class, @args) = @_;
    my $self = bless {
        conf => {},
        name => $DEFAULT_NAME,
        @args,
    }, ref $class || $class;

    $self->load;

    return $self;
}

sub conf { $_[0]->{conf} }

sub load
{
    my $self = shift;
    my $filename = $self->{file} // (($self->{name} // $DEFAULT_NAME) . $FILE_EXTENTION);
    my $file = WZ->home->rel_file('conf/' . $filename);

    # Slurp UTF-8 file
    open my $handle, "<:encoding(UTF-8)", $file
        or Carp::croak(qq/Couldn't open config file "$file": $!/);
    my $content = do { local $/; <$handle> };

    # Process
    $self->{conf} = $self->parse($content, $file);
}

sub parse
{
    my ($self, $content, $file) = @_;

    # Run Perl code
    no warnings;
    Carp::croak(qq/Couldn't parse config file "$file": $@/)
        unless my $config = eval "$content";
    Carp::croak(qq/Config file "$file" did not return a hashref.\n/)
        unless ref $config && ref $config eq 'HASH';

    $config;
}

1;
__END__