package Fish::Class::Common;

=head

Author: Allen Haim <allen@netherrealm.net>, © 2015.
Source: github.com/misterfish/fish-lib-perl
Licence: GPL 2.0

Not intended to be 'use'd directly. Use Fish::Class.

=cut

use 5.18.0;

BEGIN {
    use base 'Exporter';
    our @EXPORT = qw, 
        is_int is_num is_non_neg_even
        symbol_table assign_soft_ref
        contains list
        ierror iwar
    ,;
}

use Carp 'cluck', 'confess';

local $SIG{__WARN__} = \&cluck;
local $SIG{__DIE__} = \&confess;

sub is_num(_);
sub is_int(_);
sub is_non_neg_even(_);

sub contains (+_) {
    my ($ary, $search) = @_; # $ary is indeed a reference
    return iwar() unless defined $search;

    grep { defined $_ and $_ eq $search } @$ary
}

sub list ($) { 
    my $s = shift;
    ref $s eq 'ARRAY' or ierror("need array ref to list()");
    return @$s;
}

sub symbol_table {
    my ($name) = @_;
    no strict 'refs';
    my %sym_table = %{$name . '::'};

    \%sym_table
}

sub is_num(_) {
    my ($d) = @_;
    defined $d or warn("is_num: missing arg"), 
        return;
    
    return unless $d =~ m, ^ -? \d+ (\.\d+)? $ ,x;

    1
}

sub is_int(_) {
    my ($n) = @_;
    defined $n or warn("is_int: missing arg"),
        return;
    is_num $n or warn("Expected number as arg to is_int"),
        return;

    $n == int $n
}

sub is_non_neg_even (_) { 
    my ($s) = @_;
    defined $s or warn("is_non_neg_even: missing arg"),
        return;

    (is_num $s and is_int $s) or warn("Expected non-negative int to is_non_neg_even"),
        return;

    return unless $s >= 0;

    $s % 2 ? 0 : 1
}

# ierror/iwar: for programmer and very internal errors.  Basically copied
# from an older version of Fish::Utility, in order to avoid a dependence on
# it. 
# Skips the fancier features (colors, more options). 
sub ierror {
    my (@s) = @_;

    my $s = join ' ', @s;
    $s = "Internal error: " . $s;

    confess $s, "\n";
}

sub iwar {
    my ($s) = @_;

    my @string = $s ? ($s) : ();
    $s = join ': ', "Internal warning", @string;

    cluck $s;

    # so caller can do return iwar
    undef
}

sub assign_soft_ref {
    my ($fullname, $value) = @_;
    ierror("Bad call") unless defined $fullname;

    # perl magic -- assign directly to symbol table. 
    # Will die if fullname is nonsense.
    no strict 'refs';
    *$fullname = $value;
}

1;
