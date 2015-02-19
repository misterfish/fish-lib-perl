package Fish::Embperl;

use 5.14.0;

use strict;
use warnings;

BEGIN {
    our @ISA = 'Exporter';
    our @EXPORT = qw, mywarn err ,;
}

use Fish::Utility_a 'hash';

sub soft_ref {
    my ($name) = @_;
    no strict 'refs';

    $$name
}

# Archaic code -- get hardcoded 'OUT' filehandle from caller.

sub getOUT {
    my $package;
    {
        my $i = 1;
        while (not $package or $package eq __PACKAGE__) {
            ($package) = caller $i;
            die 'too much recursion' if $i++ == 10;
        }
    }
    my $pack = $package . '::';
    my $ref = soft_ref $pack or warn, return;
    my %sym_table = hash $ref;
    my $glob = $sym_table{OUT} or warn, return; # star thing
    my $fh = *$glob{GLOB} or warn, return; # foo thing

    $fh
}

sub mywarn {
    my (@s) = @_;

    my ($fh) = getOUT or warn, return;

    printf $fh "<pre>Error: %s\n</pre>", join ' ', @s;
}

sub err {
    my (@s) = @_;
    mywarn @s;
    Embperl::exit(1); 
}




1;
