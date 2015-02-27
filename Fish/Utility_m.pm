package Fish::Utility_m;

use 5.18.0;

BEGIN {
    #use Exporter 'import';
    use base 'Exporter';

    # Things which look like or be reserved words.
    our @EXPORT_OK = qw,
        global stdin d deg
    ,;

    our @EXPORT = qw,
        debug_level debug_fh debug_stdout datadump
        D D2 D3 D_QUIET 
        DC DC_QUIET

        get_stdin 

        is_multiple randint is_int is_even is_odd is_num round

        mywait yes_no
        bn get_file_no get_tmp
        bench_start bench_end bench_end_pr bench_pr
        escape_double_quotes escape_double_quotes_r
        field pad padl nice_units nice_bytes nice_bytes_join comma abbr
        term_restore term_echo_off
        get_date get_date_2 datestring datestring2 
        get_url find_children
    ,;
}

#use utf8;

use File::Basename 'basename';
use File::Temp;
use IO::Handle; #stdin

use Fish::Utility;
use Fish::Utility_l;

=head Loaded dynamically when needed to improve startup time:

use LWP::UserAgent;
use HTML::TreeBuilder;
use Data::Dumper;
use Term::ReadKey ();
use Math::Trig ':pi'; #deg
use Time::HiRes 'time';

=cut

sub D;
sub D2;
sub D3;
sub D_QUIET;

my $Debug_level = 0;
my $Debug_fh = *STDERR;

# Dump and debug.

sub debug_level { 
    $Debug_level = shift if @_;

    $Debug_level
}

sub debug_fh { 
    $Debug_fh = shift if @_;

    $Debug_fh
}

sub debug_stdout { 
    $Debug_fh = *STDOUT;
}

sub d { 
    runtime_import 'Data::Dumper';

    Data::Dumper::Dumper(@_) 
}

sub datadump { 
    runtime_import 'Data::Dumper';

    Data::Dumper->Dump([shift]) 
}

sub D_QUIET {
    my $opt = ref $_[0] eq 'HASH' ? shift : {};

    my $first_white = $opt->{first_white} // 1;

    my $do_encode_utf8 = $opt->{no_utf8} ? 0 : 1;

    $Debug_level > 0 or return;

    my @c = (\&G, \&BR);

    my $i = 0;
    my $s;
    $s = $c[0]->('[nothing]') unless @_;
    my $first = 1;

    for (@_) {
        local $_ = $_;
        if (not defined) {
            $_ = '[undef]';
        }
        elsif ($_ eq '') {
            $_ = '[empty]';
        }
        $_ = e8 if $do_encode_utf8;
        my $c;
        my $_s;
        if ($first_white and $first) {
            $first = 0;
            $_s = $_;
        }
        else {
            $c = $c[$i++ % 2];
            $_s = $c->($_);
        }

        $s .= sprintf "%s ", $_s;
    }

    $s . "\n"
}

sub DC {
    D {first_white=>0}, @_;
}

sub DC_QUIET {
    D_QUIET {first_white=>0}, @_;
}

sub D  { _D(0, @_) }
sub D2 { _D(1, @_) }
sub D3 { _D(2, @_) }

sub _D {
    my ($dl, @d) = @_;
    return unless $Debug_level > $dl;
    my $save_fh = select;
    select $Debug_fh;
    my $save_flush = $|;
    $| = 1;
    printf $Debug_fh "%s", D_QUIET @d;
    $| = $save_flush;
    select $save_fh;
}

# System.

sub get_stdin {
    &stdin
}

# Looks a lot like a reserved word; get_stdin is exported.
sub stdin {
    my ($opt) = @_;
    $opt //= {};

    # Also possible, but with fewer options:
    # return \*STDIN; 

    my $die = $opt->{die} // 1;
    my $blocking = $opt->{blocking} // 1;

    my $io = IO::Handle->new;
    if (not $io->fdopen(fileno STDIN,"r")) {
        my $e = "Couldn't open " . Y "stdin: " . $!;
        $die ? error $e : war $e;
        return;
    }
    $io->blocking($blocking);

    $io
}

sub get_file_no {
    my ($fh) = @_;
    $fh or war ("fh is undef"), return;
    my $fn = fileno($fh);
    my $ok = $fn && $fn != -1;
    return $ok ? $fn : undef;
}


sub mywait {
    my ($proc_name, $opts) = @_;
    my $cmd = qq, ps -C "$proc_name" ,;
    $opts //= {};
    my $sleep = $opts->{sleep} // 1;
    my $verbose = $opts->{verbose} // 0;

    my $return;

    while (sys_ok $cmd, { verbose => 0 }) {
        say sprintf qq,Still waiting for %s to hang up.,, Y $proc_name if $verbose;
        sleep $sleep;
    }

}

# Date.

sub get_date {
    my $date = localtime(time);
    $date =~ s/[: ]/_/g;
    return $date;
}

sub get_date_2 {
    my ($time) = @_;
    $time //= time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime $time;

    sprintf "%d-%02d-%02d-%02d.%02d.%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;
}

sub datestring {
    my ($time) = @_;
    $time //= time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime $time; 
    my @months = qw, Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec ,;
    sprintf "%s %02d, %d %02d:%02d:%02d", $months[$mon], $mday, 1900+$year, $hour, $min, $sec;
}

sub datestring2 { get_date_2(@_) }

# Math, trig, random.

# inclusive
sub randint {
    my ($low, $high) = @_;
    return int rand ($high + 1 - $low) + $low;
}

sub is_num(_) {
    my $d = shift;
    def $d or wartrace("is_num: missing arg"), 
        return;
    
    $d =~ m, ^ ( \+ | - ) ? ( \d+ (\.\d+)? | (\.\d+) ) $ ,x 
}

sub is_int(_) {
    my $n = shift;
    def $n or wartrace("is_int: missing arg"),
        return;
    is_num $n or return 0;

    $n == int $n
}

sub is_even(_) {
    my $s = shift;
    def $s or wartrace("is_even: missing arg"),
        return;
    ( is_num $s and $s >= 0 and is_int $s ) or wartrace("Need non-negative int to is_even"),
        return;

    not $s % 2
}

sub is_odd(_) {
    my $s = shift;
    def $s or wartrace("is_odd missing arg"),
        return;
    ( is_num $s and $s >= 0 and is_int $s ) or wartrace("Need non-negative int to is_odd"),
        return;

    $s % 2
}

# Pretty print, strings.

sub pad($$) {
    my ($length, $str) = @_;
    my $l = length $str;
    return $l >= $length ? $str :
        $str . ' ' x ($length - $l);
}

sub padl($$) {
    my ($length, $str) = @_;
    my $l = length $str;
    return $l >= $length ? $str :
        (' ' x ($length - $l)) . $str;
}


# e.g. nice_units(x, 1024, 'b', 'K', 'M', 'G') for sizes
sub nice_units {
    my ($n, $opt) = @_;

    my $ok;
    my $order;
    my $zeroth_integral;
    my @units;
    my $num;
    {
        last unless $opt;

        $order = $opt->{order} or last;
        $zeroth_integral = $opt->{zeroth_integral} // 0;
        my $units = $opt->{units} or last;
        @units = @$units;
        $num = scalar @units or last;

        $ok = 1;
    }

    war("Invalid call to nice_units"), return unless $ok;

    for my $i (0..$num - 1) {
        my $u = shift @units // '?';
        my $thres = $order ** ($i+1);
        my $format;
        if ($i == 0 and $zeroth_integral) {
            $format = "%d" 
        }
        else {
            $format = "%.1f";
        }
        if ( $n < $order ** ($i+1) ) {
            return sprintf($format, $n / ($order ** $i)), $u;
        }
        else {
            # only on last one
            if ($i == $num - 1) {
                return sprintf($format, $n / ($order ** $num)), $u;
            }
        }
    }
}

sub nice_bytes ($) {
    my ($n) = @_;

    nice_units($n, {
        order => 1024,
        zeroth_integral => 1,
        units => ['b', 'k', 'M', 'G'],
    })
}

sub nice_bytes_join ($) {
    return join '', nice_bytes shift;
}

# 12345 -> 12,345
sub comma($) {
    my $n = shift;
    my @n = reverse split //, $n;
    my @ret;
    while (@n > 3) {
        my @m = splice @n, 0, 3;
        push @ret, @m, ',';
    }
    push @ret, @n;

    join '', reverse @ret
}


sub field {
    my ($width, $string, $len) = @_;
    $len //= length $string;
    my $num_spaces = $width - $len;
    if ($num_spaces < 0) {
        warn sprintf "Field length (%s) bigger than desired width (%s)", $len, $width;
        return $string;
    }
    return $string . ' ' x ($width - $len);
}


# Benchmark.

#sub bench_start(_) { _bench(0, @_) }
#sub bench_end(_) { _bench(1, @_) }
#sub bench_pr(_) { _bench(2, @_) }
#sub bench_end_pr(_) {
sub bench_start { _bench(0, @_) }
sub bench_end { _bench(1, @_) }
sub bench_pr { _bench(2, @_) }
sub bench_end_pr {
    bench_end(@_);
    bench_pr(@_);
}

sub _bench {
    my ($a, $id) = @_;

    runtime_import 'Time::HiRes';

    state %start;
    state %total;
    state %idx;

    # start
    if ($a == 0) {
        $start{$id} = Time::HiRes::time();
        $total{$id} //= 0;
        $idx{$id}++;
    }
    # end
    elsif ($a == 1) {
        $total{$id} += Time::HiRes::time() - $start{$id};
        delete $start{$id};
    }
    # print
    elsif ($a == 2) {
        say '';
        my $time = $total{$id} or war("Unknown id:", R $id),
            return;
        $time = sprintf "%.2f", $time;
        info sprintf 'Bench: id %s counts %s time %s', CY $id, Y $idx{$id}, G $time;
    }
    else { wartrace '_bench called incorrectly' }
}

sub is_multiple {
    my ($a, $b) = @_;
    return not $a % $b;
}

# deg(180) -> pi
# in the spirit of hex().
sub deg {
    runtime_import 'Math::Trig';

    my $deg = shift;
    state %cache;
    my $rad;
    if ($rad = $cache{$deg}) {
        return $rad;
    }
    else {
        $rad = Math::Trig::pi() / 180 * $deg;
        return $cache{$deg} = $rad;
    }
}

sub escape_double_quotes(_) {
    wartrace 'deprecated -- use shell_escape';

    my ($s) = @_;
    escape_double_quotes_r(\$s);
    $s;
}

sub escape_double_quotes_r(_) {
    wartrace 'deprecated -- use shell_escape_r';

    my ($r) = @_;
    $$r =~ s/ " /\\"/xg;
}

sub term_echo_off {
    runtime_import 'Term::ReadKey';
    Term::ReadKey::ReadMode('noecho');
}

sub term_restore {
    runtime_import 'Term::ReadKey';
    Term::ReadKey::ReadMode('restore');
}

sub bn(_) { basename shift }

# First: global $x
# Then: global 'key', 'value' means $g->$key($value)
# global 'key' means $g->$key
#
# Can die. 
sub global {
    my ($k, $v) = @_;
    state $g;
    if (my $r = ref $k) {
        errortrace "global called incorrectly" unless $r eq 'Fish::Class';
        $g = $k;
    }
    else {
        errortrace "No \$g" unless $g;
        if (! defined $v) {
            return $g->$k;
        }
        else {
            return $g->$k($v);
        }
    }
}

# security risk
sub get_tmp {
    my ($opt) = @_;
    $opt //= {};
    my $dir = $opt->{dir} // 0;

    # Quite useless if it gets unlinked no? XX
    my $unlink = $opt->{unlink} // $opt->{cleanup} // 1;

    my $base_prefix = $opt->{base_prefix} // '';

    #http://listofrandomwords.com/index.cfm?blist
    state $TOKENS = [qw,
        interpervading cyclic breathalyzer preestimating clipboard supernaturalize strophe excrescence unputridity 
        sternward sanative loony effervesce gluing pseudomiraculous australia underlapped schiz erina ochered
        unupbraiding determinated nonpurification lazier notoriously accelerant podiatrist unstern sedimentologic
        nonburdensome revitalized enola ungiddy cloddishness uncontained unparasitical fearfulness detonator justine
        dopester hairbrained granitizing graphitize stoichiometrically decollate nonsatiric unscathed semilyrical
        crepuscle unfeted arcadia hypnosporangium collegiately recondemnation unaccomplishable spirit prejudiceless
        liftable unbroken gynomonoeciously withing horrebow literally piecer preexecuting bangs unconfutative lamellirostrate
        holomorphic schizogenously multicarinate judaea parasynthesis groete twine orological unadministrative dysesthesia
        bemba leucippides nonpreparation measurably preachier coppice kornberg featheredged cusco louden viperish 
        markos stingray zealot postmalarial asa dinnerless tetanize gratinate pitchometer gigot cumberment egression
        pipiest bellows corbina spell farrago zoea radioautography determinedly uncaptioned rambla skikda
        premonarchical chinee homoerotic unrebuked waggle anthropographic ceroma spiritualist psychographically monostichic 
        decimation ciliately gate cryptanalytic wingspan gidjee choleric pycnidial kenneled calyculus photochromy nonrescissory
        unintellectuality renegade benthonic odontology droplet flippancy slipperlike unpinned arecibo unassertive
        syssarcosis unmutative boater franglais transformer nidificating

    ,];
    state $DIR = '/tmp';

    my $template = sprintf "%s%sXXXX", $base_prefix, $TOKENS->[int rand @$TOKENS];

    my $tmp;
    if ($dir) {
        $tmp = File::Temp->newdir( $template, DIR => $DIR, CLEANUP => $unlink );
    }
    else {
        $tmp = File::Temp->new( TEMPLATE => $template, DIR => $DIR, UNLINK => $unlink );
    }

    $tmp

}

# Abbreviate a string and maybe pad with ellipsis.
sub abbr {
    my ($l, $s) = @_;
    if (!$s) {
        $s = $l;
        $l = 100;
    }
    my $s_orig = $s;
    $s = substr($s, 0, $l);
    $s .= ' ...' unless $s eq $s_orig;
    return $s;
}

sub _class_method {
    my ($pack) = @_;

    return unless $pack;

    # more elegant way? XX
    $pack eq __PACKAGE__ or $pack eq 'Fish::Utility_a'
}

sub yes_no {
    if (! -t STDOUT) {
        info "\nyes_no: STDOUT not connected to tty, assuming no.";
        return 0;
    }
    if (! -t STDIN) {
        info "\nyes_no: STDIN not connected to tty, assuming no.";
        return 0;
    }
    my $opt = shift || {};
    if (ref $opt eq '') {
        $opt = 
            $opt eq 'yes' ? { default_yes => 1 } :
            $opt eq 'no'  ? { default_no  => 1 } :
            (warn, return);
    }
    my $infinite = $opt->{infinite} // 1;

    my $default_yes = $opt->{default_yes} // 0;
    my $default_no = $opt->{default_no} // 0;

    if (my $d = $opt->{default}) {
        $d eq 'no' ?  $default_no = 1 :
        $d eq 'yes' ? $default_yes = 1 :
        war ("Unknown 'default' opt given to yes_no()");
    }
    my $question = $opt->{question} // $opt->{ask} // '';
    $default_no and $default_yes and warn, return;
    my $y = $default_yes ? 'Y' : 'y';
    my $n = $default_no ? 'N' : 'n';
    ask "$question" if $question;
    my $print = "($y/$n) ";
    local $\ = undef;
    while (1) {
        printf "$print";
        my $in = <STDIN>;
        strip_r(\$in);
        if (!$in) {
            if ($default_yes) {
                return 1;
            } 
            elsif ($default_no) {
                return 0;
            }
        }
        elsif ($in =~ /^y$/i) {
            return 1;
        }
        elsif ($in =~ /^n$/i) {
            return 0;
        }

        if ( ! $infinite) {
            return 0;
        }
    }
}

sub round {
    my $s = shift;
    my ($s_int, $s_frac) = ( int ($s), $s - int ($s) );
    if ($s_frac >= .5) {
        return $s_int + 1;
    } else {
        return $s_int;
    }
}

sub get_url(_@) {
    runtime_import 'LWP::UserAgent';
    my ($url, $opt) = @_;
    $opt //= {};
    my $timeout = $opt->{timeout} // 5;
    my $agent = $opt->{agent} // 'Mozilla/5.0 (X11; Linux i686; rv:10.0.5) Gecko/20100101 Firefox/10.0.5 Iceweasel/10.0.5';

    # opt cache XX
    #my $do_cache = 1;

    state $ua;
    if (!$ua) {
        $ua = LWP::UserAgent->new(
            timeout => $timeout,
            agent   => $agent,
        );
    }

    my $res = $ua->get($url);
    if ($res->is_success) {
        return $res->decoded_content;
    }
    else {
        my $e = $res->status_line;
        war sprintf "Error getting url %s (%s)", BR $url, $e;
        return;
    }
}

sub find_children(_@) {
    my ($s, @rest) = @_;

    find_children_r(\$s, @rest)
}

# $r is a reference to a scalar or to a HTML::Element.
# $arg1 can be an array: e.g. ['html']
# $arg1 can be a hash: e.g. { as => 'html' } or { as_html => 1 }
# Types are 'html', 'inner_html', 'text' (default), 'elem', and 'attr'.
# 'attr' has to be given as { as_attr => <attr-name> }.
# The others can use the { as_xxx => 1 } form or the array form.
# @rest gives criteria to look_down. 
# _tag is special.
#  id => 'inner-div', class => 'article', _tag => 'div'
#
# Can also be a sub (doesn't need to be part of a pair then):
#  
# example param:
#         sub {
#             my $c = $_[0]->attr('class') or return;
#             $c =~ /leg-time/
#         }
#

sub find_children_r {
    my ($r, $arg1, @rest) = @_;

    my $ref = ref $r;
    my $build_tree;
    if ($ref eq 'SCALAR') {
        $build_tree = 1;
        runtime_import 'HTML::TreeBuilder', { die => 0 } or iwar("Couldn't import", BR 'HTML::TreeBuilder'),
            return ();

    }
    elsif ($ref eq 'HTML::Element') {
        $build_tree = 0;
    }
    else {
        war "Unexpected:", BR $ref;
        return ();
    }

    $arg1 or iwar("Need arg1"),
        return ();

    my $opt;
    my @spec;
    if (ref $arg1 eq 'HASH') {
        $opt = $arg1;
        @spec = @rest;
    }
    elsif (ref $arg1 eq 'ARRAY') {
        @$arg1 == 1 or iwar("Need exactly one elem in array"), 
            return ();
        $opt = { as => shift @$arg1 };
        @spec = @rest;
    }
    else {
        @spec = ($arg1, @rest);
    }
    $opt //= {};
    $opt->{as} //= '';
    my ($as_text, $as_html, $as_attr, $as_elem, $as_inner_html) = (0) x 
        5;
    if ($opt->{as_text} || $opt->{as} eq 'text' ) {
        $as_text = 1;
    }
    if ($opt->{as_html} || $opt->{as} eq 'html') {
        $as_html = 1;
    }
    if ($opt->{as_inner_html} || $opt->{as} eq 'inner_html') {
        $as_inner_html = 1;
    }
    if (my $a = $opt->{as_attr}) {
        $as_attr = $a;
    }
    if ($opt->{as_elem} || $opt->{as} eq 'elem') {
        $as_elem = 1;
    }

    {
        my $as = 0;
        $_ && $as++ for $as_text, $as_html, $as_attr, $as_elem, $as_inner_html;
        if ($as == 0) {
            $as_text = 1;
            $as = 1;
        }

        if ($as != 1) {
            $as == 1 or wartrace("Confusing 'as' spec, using text");
            $as_text = 1;
        }
    }

    my $root;
    # Inherits methods of both HTML::Parser and HTML::Element.
    if ($build_tree) {
        $root = HTML::TreeBuilder->new;
        # HTML::Parser
        $root->parse($$r) or iwar("Couldn't parse."),
            return ();
    }
    else {
        $root = $r;
    }

    if (my @children = $root->look_down(@spec)) { #HTML::Element
        my @new_children;
        if ($as_text) {
            @new_children = map { $_->as_text } @children;
        }
        elsif ($as_html) {
            @new_children = map { $_->as_HTML } @children;
        }
        elsif ($as_inner_html) {
            for my $child (@children) {
                # Returns HTML::Element or plain text.
                # Note that the outer loop (look_down) never returns plain
                # text (not sure what spec would even look like to produce
                # that).
                my @_children = $child->content_list;
                my $child_string = join '', map { 
                    # no ref => text
                    ref $_ ? $_->as_HTML : $_
                } @_children;
                push @new_children, $child_string;
            }
        }
        elsif ($as_attr) {
            @new_children = map { $_->attr($as_attr) // () } @children;
        }
        elsif ($as_elem) {
            @new_children = @children;
        }
        return @new_children;
    }
    else {
        return ();
    }
} 

1;

# bi-dir-pipe:

#use IPC::Open2;
#my $pid = open2(my $fh_r, my $fh_w, $cmd);
#print $fh_w $q;
#close $fh_w;
#say while <$fh_r>;

