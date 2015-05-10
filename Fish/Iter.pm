package Fish::Iter;

=head

Author: Allen Haim <allen@netherrealm.net>, © 2015.
Source: github.com/misterfish/fish-lib-perl
Licence: GPL 2.0

=cut


This is correct and will not end the iteration early if something is undef.
The $i object is defined even if one of the elements is undef.

while (my $i = iter @a) {
    say sprintf "%s -> %s", $i->k, $i->v;
}

say sprintf "%s -> %s", it->k, it->v while iter %a;

=cut

package _Iter {
    use Class::XSAccessor 
        constructor => 'new',
        accessors => {
            k => 'a',
            i => 'a',
            v => 'b',
        },
        ;
1
}

package Fish::Iter;

use 5.18.0;

BEGIN {
    use base 'Exporter';
    our @EXPORT = qw, iter iterr iterab iterrab 
    iter_reset iter_resetr
    it
    ,;
}

# Old way:
# Usage: while (my $i = iter each %hash)
#        while (my $i = iter each @array)
#        while (my $i = iter eachr $array_ref)
#        while (my $i = iter eachr $hash_ref)
#        while (my $i = iter eachr @$array_ref)
#        while (my $i = iter eachr %$hash_ref)

sub iter_old (@) {
    my ($k, $v) = @_;
    return unless defined $k;
    my $i = _Iter->new(
        a => $k,
        b => $v,
    );

    $i
}

# New way:
# Usage: while (my $i = iter %hash)
#        while (my $i = iter @array)
#        while (my $i = iterr $array_ref)
#        while (my $i = iterr $hash_ref)
#        while (my $i = iter @$array_ref)
#        while (my $i = iter %$hash_ref)

# Allow this:
# say sprintf "%s -> %s", it->k, it->v while iter %a;
# Very thread-unsafe and anything nested will obviously not work.

my $Last;

sub it {
    $Last
}

sub iter (+) {
    my ($ref) = @_;
    my $r = ref $ref;

    my ($k, $v) = 
        $r eq 'ARRAY' ? each @$ref : 
        $r eq 'HASH' ? each %$ref :
        die "Need @ or % to iter.";

    return unless defined $k;

    my $i = _Iter->new(
        a => $k,
        b => $v,
    );

    $Last = $i
}

sub iterr($) {
    my ($ref) = @_;
    my $r = ref $ref;

    return 
        $r eq 'ARRAY' ? iter(@$ref) :
        $r eq 'HASH' ? iter(%$ref) :
        die "Need arrayref or hashref to iterr.";
}

sub iterab_old(@) {
    my ($package, $filename, $line) = caller;
    my $eval = qq| (\$${package}::a, \$${package}::b ) = \@_ |;

    eval $eval
}

sub iterab (+) {
    my ($ref) = @_;
    my $r = ref $ref;
    my ($k, $v) = 
        $r eq 'ARRAY' ? each @$ref : 
        $r eq 'HASH' ? each %$ref :
        die "Need @ or % to iterab.";
    return unless defined $k;
    my ($package, $filename, $line) = caller;
    # security? XX
    my $eval = qq| (\$${package}::a, \$${package}::b ) = (\$k, \$v) |;
    eval $eval;

    1
}

sub iterrab ($) {
    my ($ref) = @_;
    my $r = ref $ref;
    my ($k, $v) = 
        $r eq 'ARRAY' ? each @$ref :
        $r eq 'HASH' ? each %$ref :
        die "Need arrayref or hashref to iterrab.";
    return unless defined $k;
    my ($package, $filename, $line) = caller;
    # security? XX
    my $eval = qq| (\$${package}::a, \$${package}::b ) = (\$k, \$v) |;
    eval $eval;

    1
}

sub iter_resetr(_) {
    my ($ref) = @_;
    # call to keys resets the internal iterator (perldoc -f each)
    ref $ref eq 'ARRAY' ? keys @$ref :
    ref $ref eq 'HASH' ? keys %$ref : 
    (warn, return 0);

    1
}

sub iter_reset(+) {
    iter_resetr shift;
}

1;




