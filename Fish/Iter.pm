package Fish::Iter;

=head

Author: Allen Haim <allen@netherrealm.net>, © 2015.
Source: github.com/misterfish/fish-lib-perl
Licence: GPL 2.0

Some new ways to loop in perl. Meant to be fast for the programmer, not the
machine.

iter(r) functions encapsulate calls to 'each', for which each hash and array
in perl maintains an internal state. 

See perldoc -f each.

iter(r)ab functions set $a and $b in the caller. Note that these already
exist in your symbol table (that's why sort works). This is similar to how
List::Util works.

Usage:

iter
----
 while (my $i = iter @a) {
     say sprintf "idx: %s -> val: %s", $i->k, $i->v;
 }
 while (my $i = iter %a) {
     say sprintf "key: %s -> val: %s", $i->k, $i->v;
 }
 my $j;
 say sprintf "idx: %s -> val: %s", $j->k, $j->v while $j = iter @a;
 say sprintf "key: %s -> val: %s", $j->k, $j->v while $j = iter %a;

 while (my $i = iter %hash) {}
 while (my $i = iter @array) {}
 while (my $i = iter @$array_ref) {}
 while (my $i = iter %$hash_ref) {}

iterr
-----
 while (my $i = iterr $array_ref) {}
 while (my $i = iterr $hash_ref) {}

iterab
------
 while (iterab %hash) {
     say sprintf "%s -> %s", $a, $b;
 }
 while (iterab @array) {}
 while (iterab @$array_ref) {}
 while (iterab %$hash_ref) {}

iterrab
-------
 while (iterrab $array_ref) {}
 while (iterrab $hash_ref) {}

it
--
 The following is correct and will not end the iteration early if something
 is undef. The $i object is defined even if one of the elements is undef.

 This also works, using a global object. Very thread-unsafe, and nested
 loops will obviously not work.

 Don't forget to import the function 'it'.

 say sprintf "%s -> %s", it->k, it->v while iter %a;

subfor a.k.a. forgo
------
 example: print even numbers.
 $_ is the implicit variable, the loop is lazy, and you can end an iteration
 early with return, so you can do the return and the warning (which returns
 undef) in one line.

 use Fish::Utility_m 'is_even';

 subfor 1, $n, sub {
     is_even or 
         return war "Not even [close]!";
 
     info;
 }; 

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
    our @EXPORT = qw, 
        iter iterr iterab iterrab 
        subfor forgo
        iter_reset iter_resetr
        it
    ,;
}

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

# See example usage above.

sub subfor {
    my ($start, $stop, $sub) = @_;
    local $_;
    for ($_ = $start; $_ <= $stop; $_++) {
        $sub->();
    }
}

sub forgo { &subfor }

1;




