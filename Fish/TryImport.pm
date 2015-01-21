package Fish::TryImport;

use 5.10.0;

BEGIN {
    @ISA = 'Exporter';
    @EXPORT = qw, try_use try_use_no_import ,;
}

use strict;
use warnings;

use Fish::Utility_a;

sub _req {
    my ($mod, $caller, $opts, @symbols) = @_;
    my $eval_use = "package $caller; use $mod (); 1";

    #D 'eval', $eval;
    
    eval $eval_use or do { 
        war "Couldn't use module:", R $mod;
        my @s;
        my $t = 'Try';
        if (my $d = $opts->{debian}) {
            push @s, "debian package " . Y $d;
        }
        push @s, "the command " . M "sudo cpan $mod";
        war $t, join ' or ', @s;
        warn "\n";
    }, return;
    
    if (@symbols) {
        my $imp = sprintf "qw(%s)", join ' ', @symbols;
        my $eval_import = "package $caller; use $mod $imp; 1";
        eval $eval_import or do {
            my $s = join ', ', map { M $_ } @symbols;
            war sprintf "Couldn't import symbols %s from module %s", $s, Y $mod;
            warn "\n";
        }, return;
    }

    1;
}

sub _try_use_import_these {
    my ($caller, $mod, $opts, @symbols) = @_;
    #@symbols or error "Need symbols for try_use_import_these";
    return _req $mod, $caller, $opts, @symbols;
}

sub _try_use_import_all {
    my ($caller, $mod, $opts) = @_;
    $opts //= {};
    return _req $mod, $caller, $opts;
}

=head
# import all:

try_use 'List::Util::WeightedChoice'; 
try_use 'Math::Bezier', { debian => 'libmath-bezier-perl' };

# import some:
try_use 'List::Util::WeightedChoice', {}, 'choose_weighted', 'func1', 'func2', ...

# import some and give install hint:
try_use 'Math::Bezier', { debian => 'libmath-bezier-perl' }, 'func1', 'func2', ...

# import none:
try_use_no_import 'List::Util';

# import none and give install hint:
try_use_no_import 'List::Util', { debian => 'xxx' }; 

=cut

# imports all 
sub try_use {
    shift if ref $_[0] eq '__PACKAGE__'; # allow -> call

    # scalar is unary op

    if (@_ > 2) {
        return _try_use_import_these scalar caller, @_;
    }
    elsif (@_ == 2 or @_ == 1) {
        return _try_use_import_all scalar caller, @_;
    }
    else {
        war "Invalid call to try_use.";
    }
}

sub try_use_no_import {
    shift if ref $_[0] eq '__PACKAGE__'; # allow -> call

    @_ and war("Invalid call to try_use_no_import"), 
        return;

    return _try_use_import_these scalar caller, {}, ();
}


1;
