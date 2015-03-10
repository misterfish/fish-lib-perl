use 5.18.0;

=head

my $opt = opt {
    v   => 'f',         # flag, e.g. -v
    H   => 's',         # string, e.g. -H <hostname>
    percentage => 'r',  # real num, e.g. --percentage 3.2
    count   => 'i',     # int, e.g. -i 3
};

Second arg is optional config hash.
Value of 'flags' is list of flags to be passed to Getopt::Long. 
Default flags are: no_auto_abbrev bundling no_ignore_case
Pass empty array ref for no flags.

Afterwards, @ARGV is only what's left.

my $opt = opt {...}, 
    { 
        flags => [qw, auto_abbrev no_bundling ... ,],
    }
);

=cut

use Fish::Utility 'war', 'iwar', 'strip_s', 'BR';
use Fish::Class 'od';
use Fish::Iter;

my @FLAGS_DEFAULT = qw,
    no_auto_abbrev bundling no_ignore_case
,;

sub opt {
    my ($opt_spec, $config) = @_;
    $config //= {};
    $opt_spec or iwar("Need opt spec"),
        return;
    ref $opt_spec eq 'HASH' or iwar("Need hash as opt spec"),
        return;

    my %spec_getopt;
    my %spec_return;

    our %opts;

    while (my $i = iter %$opt_spec) {
        my ($spec_k, $spec_v);
        my $k = $i->k;
        my $v = $i->v;
        defined $v or iwar("Undef in opt spec"),
            return;
        # opts{k} = undef for scalar, [] for list
        ($spec_k, $opts{$k}) = 
            $v eq 'f'       ? ("$k", undef) :
            $v eq 'i'       ? ("$k=i", undef) :
            $v eq 'r'       ? ("$k=f", undef) : # 'float'
            $v eq 's'       ? ("$k=s", undef) : 
            $v eq 'ms'       ? ("$k=s@", []) :  # multiple strings (e.g. -X 1 -X 2)
            (iwar("Bad spec:", BR $v), 
                return
            );
        
        $spec_v = \$opts{$k};
        $spec_getopt{$spec_k} = $spec_v;
    }

    keys %spec_getopt or iwar("Nothing to do"),
        return;

    my @flags; 
    if (my $f = $config->{flags}) {
        @flags = @$f;
    }
    else {
        @flags = @FLAGS_DEFAULT;
    }

    # use Getopt::Long with @flags
    eval sprintf "use Getopt::Long ':config', %s; 1", join ', ', map { qq,"$_", } @flags or
       iwar("Couldn't load Getopt::Long:", BR $@),
       return;

    my $ok;
    {
        local $SIG{__WARN__} = \&mywarn; # passes context 

        $ok = GetOptions(
            %spec_getopt
        );
    }

    return unless $ok; # no need to warn again, messages already printed.

    $spec_return{$_} = $opts{$_} for keys %$opt_spec;

    my $o = od(
        %spec_return
    );

    $o
}

sub mywarn {
    my (@s) = @_;
    my $w = join ' ', @s;
    $w ||= '(unknown)';
    strip_s $w;
    war "Error parsing options:", $w;
}

1;
