package Fish::Utility_l;

=head

Author: Allen Haim <allen@netherrealm.net>, © 2015.
Source: github.com/misterfish/fish-lib-perl
Licence: GPL 2.0

=cut

use 5.18.0;

BEGIN {
    use base 'Exporter';

    # Things which look like or be reserved words.
    our @EXPORT_OK = qw,
    ,;

    our @EXPORT = qw,
        slurp slurp8 slurpn slurpn8 slurp_stdin slurp8_stdin slurp_try
        cat catn 
        statt
        is_defined def is_defined_and_false false
        unshiftr pushr shiftr popr scalarr keysr eachr
        contains containsr firstn pairwiser
        chompp rl list hash binary
        lazy mapp
        chd forkk
        iter iterab
    ,;
}

use File::stat;

use Fish::Utility;

=head Loaded dynamically when needed to improve startup time:

use Fish::Iter 'iter', 'iterab';
use List::Util 'first';

=cut

# For firstn, pairwiser.
# Doesn't import List::Util.
use List::MoreUtils 'before', 'pairwise'; 

# runtime_import was causing a segfault with List::MoreUtils as some point.

# Prototype must match Fish::Iter.
sub iter (+) {
    runtime_import 'Fish::Iter';

    &Fish::Iter::iter
}

# Prototype must match Fish::Iter.
sub iterab(+) {
    runtime_import 'Fish::Iter';

    &Fish::Iter::iterab
}

sub list ($) { 
    my $s = shift;
    ref $s eq 'ARRAY' or ierror "need array ref to list()";
    return @$s;
}

sub hash {
    my $s = shift;
    ref $s eq 'HASH' or ierror "need hash ref to hash()";
    return %$s;
}

# string -> binary
sub binary(_) { oct "0b" . $_[0] }

# Usage: 
#  while (is_defined my $a = pop @b) { }
#  if (def my $pid = forkk) { }
#  if (false my $pid = forkk) { child_stuff() }
#
# Note, no prototype; that's why it works.
sub is_defined { defined shift }
sub def { &is_defined }
sub is_defined_and_false { my $s = shift; 1 if (defined $s and not $s) }
sub false { &is_defined_and_false }

sub rl {
    my ($fh) = @_;
    my $in = <$fh> // return;
    chomp $in;
    $in;
}

sub unshiftr($_) { 
    eval { unshift @{shift @_}, @_ }
        or ierror($@);
}
sub pushr($_) { 
    eval { push @{shift @_}, @_ } 
        or ierror($@);
}
sub shiftr(_) { 
    my $return;
    eval { $return = shift @{shift @_}; 1 }
        or ierror($@);

    $return
}
sub popr(_) { 
    my $return;
    eval { $return = pop @{shift @_}; 1 }
        or ierror($@);

    $return
}
sub scalarr(_) { 
    my $return;
    eval { $return = scalar @{shift @_}; 1 }
        or ierror($@);

    $return
}
sub keysr(_) { 
    my @return;
    eval { @return = keys %{shift @_}; 1 }
        or ierror($@);

    @return
}

sub eachr(_) { 
    my ($r) = @_;
    return ref $r eq 'ARRAY' ? 
        each @$r :
        ref $r eq 'HASH' ?
        each %$r : 
        (warn, undef);
}

# Check XX
sub first(&@) {
    runtime_import 'List::Util';

    &List::Util::first
}

# Check XX
sub before(&@) {
    #runtime_import 'List::MoreUtils';

    &List::MoreUtils::before
}

# Called as:
# contains $arrayref, $search
sub containsr($_) {
    my ($ary, $search) = @_;
    # Actually, 'eq' can transparently handle undef.
    defined $search ? 
        first { $_ eq $search } @$ary :
        first { not defined } @$ary
}

# Called as:
# contains @array, $search
sub contains (+_) {
    my ($ary, $search) = @_; # $ary is indeed a reference

    containsr $ary, $search
}

# No limit.
sub slurp(_;$) {
    my ($arg, $opt) = @_;
    $opt //= {};
    local $/ = wantarray ? "\n" : undef;
    my $handle;
    if (ref $arg eq 'GLOB' or ref $arg eq 'IO::Handle') {
        $handle = $arg;
    }
    else {
        # caller can set no_die in opt
        $handle = safeopen $arg, $opt or 
            return $opt->{quiet} ? 
                undef :
                war sprintf "Couldn't slurp %s.", BR $arg; # safeopen prints msg too
    }

    <$handle>
}

sub slurp8(_;$) {
    my ($arg, $opt) = @_;
    $opt //= {};
    $opt->{utf8} = 1;

    slurp($arg, $opt)
}

sub slurpn(_;$) {
    my ($size, $arg) = @_;
    _slurpn($size, $arg, 0);
}
sub slurpn8(_;$) {
    my ($size, $arg) = @_;
    _slurpn($size, $arg, 1);
}

sub slurp_stdin {
    local $/ = undef;

    <STDIN> 
}

sub slurp8_stdin {
    my @ret;
    local $/ = "\n";
    push @ret, d8 while <STDIN>;

    join '', @ret
}

# Silently fail and return undef if e.g. file doesn't exist.

sub slurp_try(_;$) {
    my ($arg, $opt) = @_;
    $opt //= {};
    $opt->{die} = 0;
    $opt->{quiet} = 1;
    $opt->{killerr} = 1;

    slurp($arg, $opt)
}

sub _slurpn {
    my ($size, $arg, $utf8) = @_;
    my $bytes;
    if ($size =~ /\D/) {
        if ($size =~ / ^ (\d+) ([bkmg]) $/ix) {
            my $mult = { b => 1, k => 1e3, m => 1e6, g => 1e9, }->{lc $2};
            $bytes = $1 * $mult;
        }
        else {
            error "Invalid size for slurpn:", BR $size;
        }
    }
    else {
        $bytes = $size;
    }
    if (ref $arg eq 'GLOB' or ref $arg eq 'IO::Handle') { 
        # Can't get file size -- just read the given amount of bytes.
        my $in;
        sysread $arg, $in, $bytes or war("Couldn't read from fh"),
            return;

        my $is_stdin = do {
            # STDIN could be duped, in which case it gets a new fileno: open my $fh, ">&STDIN"
            # STDIN could be copied, in which case fileno is the same: open my $fh, "<&=STDIN"
            # And File::stat doesn't work with STDIN.
            my $stdin = safeopen "<&=STDIN", {die => 0} or last;
            fileno($arg) == fileno STDIN                ? 1 :
            ((stat $stdin)->ino == (stat $arg)->ino)    ? 1 :
            0;
        };

        war "Filehandle not completely slurped." if not $is_stdin and not eof $arg;

        return $utf8 ? d8 $in : $in;
    }
    else {
        my $file_size = -s $arg;
        defined $file_size or war (sprintf "Can't get size of file %s: %s", R $arg, $!),
            return;
        $file_size <= $bytes or war (sprintf "File too big (%s), not slurping.", $file_size), 
            return;
        return $utf8 ? slurp8 $arg : slurp $arg;
    }
}

sub catn {
    my ($size, $file) = @_;
    say slurpn $size, $file;
}

sub cat {
    my ($file) = @_;
    catn '10k', $file;
}

sub chompp(_) {
    my ($s) = @_;
    chomp $s;
    $s;
}

# Return first n elements of array.

sub firstn(+$) {
    my ($ary_r, $n) = @_;

    # Normal way: $n = min $n, scalar @$ary_r; @$ary_r[0..$n-1];

    # Should be slightly faster: (only loop once):
    my $i = -1; # before doesn't include the guilty one
    before { ++$i == $n ? 1 : 0 } @$ary_r;
}

sub pairwiser(&$$) {
    my ($sub, $a1, $a2) = @_;

    my ($package, $filename, $line) = caller;

    # Causes segfault.
    # runtime_import 'List::MoreUtils';

    no strict 'refs';
    List::MoreUtils::pairwise( sub { 
        ${"${package}::a"} = $a;
        ${"${package}::b"} = $b;
        $sub->(@_) 
    }, @$a1, @$a2);
}

sub chd(_@) {
    my ($dir, $opt) = @_;
    $opt //= {};
    my $die = $opt->{die} // 1;
    my $verbose = $opt->{verbose} // verbose_cmds;
    if (chdir $dir) {
        info "Chdir", G $dir if $verbose;
        return 1;
    }
    else {
        my @e = ("Can't chdir to", R $dir, "- $!.");
        $die ? error @e : war @e;
        return 0;
    }
}

# Usage:
# while (def my $i = lazy 1, 9) { ... }
#
# Won't work if interrupted.
# Very thread-unsafe.
# Experimental (relies on stacktrace to know when to start over).

sub lazy {
    my ($a, $b) = @_;
    state ($n, $pack, $fn, $line);
    my ($cpack, $cfn, $cline) = caller;
    # init
    if ($pack ne $cpack or $fn ne $cfn or $line ne $cline) {
        $n = $a - 1;
        $pack = $cpack;
        $fn = $cfn;
        $line = $cline;
    }

    ++$n > $b ? undef : $n
}

sub statt(_) {
    stat shift
}

# Like map { } @list but allows return statement within the block.

sub mapp(&@) {
    my ($sub, @list) = @_;

    map { $sub->($_) } @list
}

# Encapsulate the error check (and warning print) of a failed fork.
# Empty prototype to allow: my $pid = forkk // error;
sub forkk() {
    my $pid = fork;
    if (not defined $pid) {
        war "Couldn't fork:", BR $!;
        return;
    }

    $pid
}

1;
