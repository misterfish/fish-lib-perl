package Fish::ShellQuote;

use base 'Exporter';

BEGIN {
    our @EXPORT = qw,
        shell_quote shell_quote_r shell_quote_s
    ,;
}

sub shell_quote(_) {
    my ($s) = @_;
    shell_quote_r(\$s);

    $s
}

sub shell_quote_r(_) {
    my ($r) = @_;

    my $num = $$r =~ s, ' ,'\\'',xg;
    my @chars = qw,
        $
        !
        `
        *
        & ?
        ;
        |
        ( )
        { }
        < >
    ,;
    push @chars, ' ';
    my $chars = join '', @chars;
    my $chars_re = qr,[$chars],;
    my $quote;
    $quote = 1 if $$r =~ $chars_re;
    $$r = qq,'$$r', if $quote;
}

# Alters input.
sub shell_quote_s(_) {
    my ($s) = @_;
    shell_quote_r(\$s);

    $_[0] = $s
}

1;
