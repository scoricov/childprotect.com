package WZ::Mailer;

use strict;
use warnings;
use utf8;
require Carp;
use Mojo::Template;
use MIME::Lite;
require WZ;


sub new
{
    my ($class, @args) = @_;
    my $self = bless {
        default => {},
        @args,
    }, ref $class || $class;

    return $self;
}

sub send
{
    my ($self, $template_name, $vars, %mail_args) = @_;
    my $conf_args = $self->{$template_name};

    my %mail = (
        enabled  => 1,
        %{ $self->{default} },
        $conf_args ? %$conf_args : (),
        %mail_args,
        Type     => 'multipart/mixed',
    );

    $mail{enabled} or return 0;
    my $send_args = delete $mail{send};

    defined($mail{$_}) && utf8::encode($mail{$_}) for (qw(
        bcc         cc          from          keywords    organization
        references  reply-to    return-path   sender      subject      to
    ));

    my $msg = MIME::Lite->new(%mail);

    $vars->{mail} = \%mail;
    my $body = Mojo::Template->new->encoding('UTF-8')->render_file(
        $self->get_template_file_name($template_name),
        $vars,
    );
    utf8::encode($body);

    $msg->attach(
        Type => 'text/plain; charset=UTF-8',
        Data => $body,
    );

    ($send_args && @$send_args) ? $msg->send(@$send_args) : $msg->send;
}

sub get_template_file_name
{
    my ($class, $template_name) = @_;
    WZ->home->rel_file('templates/mail/' . $template_name . '.epl')
}

1;
__END__