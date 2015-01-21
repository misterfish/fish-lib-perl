package Fish::Class::Common;

=head

Not intended to be 'use'd directly. Use Fish::Class.

=cut

use 5.18.0;

BEGIN {
    use base 'Exporter';
    our @EXPORT = qw, 
        is_int is_num is_non_neg_even
        symbol_table assign_soft_ref
        contains
        ierror 
    ,;
}

sub contains (+_) {
    my ($ary, $search) = @_; # $ary is indeed a reference
    warn, 
        return unless defined $search;

    grep { defined $_ and $_ eq $search } @$ary
}

use Carp 'cluck', 'confess';

local $SIG{__WARN__} = \&cluck;
local $SIG{__DIE__} = \&confess;

sub is_num(_);
sub is_int(_);
sub is_non_neg_even(_);

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

# For programmer and very internal errors.
sub ierror {
    my (@s) = @_;

    my $s = join ' ', @s;
    $s = "Internal error: " . $s;

    confess $s, "\n";
}

sub assign_soft_ref {
    my ($fullname, $value) = @_;
    ierror "Bad call" unless defined $fullname;

    # perl magic -- assign directly to symbol table. Will die if fullname is
    # nonsense.
    no strict 'refs';
    *$fullname = $value;
}

1;
