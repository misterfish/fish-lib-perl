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

    my $num_single_quote = $$r =~ s, ' ,'\\'',xg;
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
    my $should_quote;
    $should_quote = 1 if $num_single_quote or $$r =~ $chars_re;
    $$r = qq,'$$r', if $should_quote;
}

# Alters input.
sub shell_quote_s(_) {
    my ($s) = @_;
    shell_quote_r(\$s);

    $_[0] = $s
}

1;
