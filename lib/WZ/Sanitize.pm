package WZ::Sanitize;

use strict;
use warnings;
use utf8;
use Regexp::Common qw /whitespace/;
use HTML::Scrubber;

my $SCRUBBER;


sub trim
{
    defined($_[0]) or return;
    $_[0] =~ s/$RE{ws}{crop}//g;
    $_[0];
}

sub xml_escape
{
    defined $_[0] or return;
    for ($_[0])
    {
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
        s/'/&#39;/g;
    };
    $_[0];
}

sub sql_like_escape
{
    defined $_[0] or return;
    for ($_[0])
    {
        s/([%_\\])/\\$1/g;
        s/^\s+//g;
    };
    $_[0];
}

sub html
{
    my $html = $_[0];
    return unless defined $html;

    $html = $SCRUBBER->scrub($html);

    for ($html)
    {
        s/(^|[\'";{])\s*position:\s*\w+\s*;?/$1/sgi;
        s/<[^>]+j\W*?a\W*?v\W*?a\W*?s\W*?c\W*?r\W*?i\W*?p\W*?t/[[JS BLOCKED]]/gsi;
        s/<[^>]+v\W*?b\W*?s\W*?c\W*?r\W*?i\W*?p\W*?t/[[VBS BLOCKED]]/gsi;
        s/<([^>]+)white-space:\s*nowrap/<$1white-space: normal/gsi;
        s/<\s*nobr([^>]+)>//gsi;
        s/<\s*td([^>]+)nowrap/<td $1/gsi;
        s/\n/\<br \/\>/sgi;
    }

    return $_[0] = $html;
}

BEGIN
{
    $SCRUBBER = HTML::Scrubber->new(
        deny    => qw/
            head html body title applet base basefont bgsound blink embed style
            frame iframe frameset ilayer iframe layer link meta object script
        /,
        rules   => [
            img => {
                src => qr{^(?!http://)}i, # only relative image links allowed
                alt => 1,                 # alt attribute allowed
                '*' => 0,                 # deny all other attributes
            },
        ],
        default => [
            1,
            {
                '*'         => 1, # default rule, allow all attributes
                background  => 1,
                cite        => 0,
                language    => 0,
                onblur      => 0,
                onchange    => 0,
                onclick     => 0,
                ondblclick  => 0,
                onerror     => 0,
                onfocus     => 0,
                onkeydown   => 0,
                onkeypress  => 0,
                onkeyup     => 0,
                onload      => 0,
                onerror     => 0,
                onmousedown => 0,
                onmousemove => 0,
                onmouseout  => 0,
                onmouseover => 0,
                onmouseup   => 0,
                onreset     => 0,
                onselect    => 0,
                onsubmit    => 0,
                onunload    => 0,
                id          => 0,
            },
        ],
        style   => 0,
        script  => 0,
        comment => 0,
        process => 0,
    )
        or Carp::croak('Failed to initialize HTML scrubber');
}

1;
__END__