package Fish::Utility;

use 5.18.0;

use base 'Exporter';

BEGIN {
    our @EXPORT = qw,
        runtime_import
        sys sys_system sys_chomp sys_ok sys_code 
        sysl sysll 
        safeopen safeclose 
        info_level verbose_cmds die_cmds
        error ierror errortrace
        war warl warreturn iwar wartrace 
        info ask errortrace
        sayf infof askf 
        e8 d8 remove_quoted_strings
strip_ptr 
        strip strip_s strip_r
        cross check_mark brackl brackr
        shell_escape shell_escape_r shell_escape_s
        shell_quote shell_quote_r shell_quote_s
        ps_running
        rem

        import_export_ok

        disable_colors force_colors strip_colors
        R BR G BG B BB CY BCY Y BY M BM RESET ANSI GREY
    ,;
}

use utf8;

use Term::ANSIColor ();
use Carp 'cluck', 'confess';

#my @BULLETS = qw, ꣐ ⩕ ⨏ ⨎ ٭ ᳅ 𝇚 𝄢 𝄓 𝄋 𝁐 ,;
my @BULLETS = qw, ꣐ ⩕ ٭ ᳅ 𝇚 𝄢 𝄓 𝄋 𝁐 ,;
my $BULLET = $BULLETS[int rand @BULLETS];

our $Cmd_verbose = 0;
our $Cmd_die = 1;
our $Info_level = 1;

our $Disable_colors = 0;
our $Force_colors = 0;

our $CHECK = '✔';
our $CROSS = '✘';

# U+3008 LEFT ANGLE BRACKET
# U+3009 RIGHT ANGLE BRACKET
our $BRACK_L = '〈';
our $BRACK_R = '〉';

my $BRACK_CMD_L = "«";
my $BRACK_CMD_R = "»";

sub d8(_);
sub e8(_);

sub error;
sub war;
sub wartrace;
sub info(_@);
sub safeopen;
sub ps_running(_);

sub _cmd_bracket { $BRACK_CMD_L . shift . $BRACK_CMD_R }

sub verbose_cmds { shift if _class_method(@_);
    $Cmd_verbose = shift if @_;

    $Cmd_verbose
}

sub die_cmds { shift if _class_method(@_);
    $Cmd_die = shift if @_;

    $Cmd_die
}

sub info_level { shift if _class_method(@_);
    $Info_level = shift if @_;

    $Info_level
}

sub cross { $CROSS }
sub check_mark { $CHECK }
sub brackl { $BRACK_L }
sub brackr { $BRACK_R }

sub color { Term::ANSIColor::color(@_) }

# bright is either bold or a bit lighter.
sub R (_)   { _color('red', $_[0])          	}
sub BR (_)  { _color('bright_red', $_[0])   	}
sub G (_)   { _color('green', $_[0])        	}
sub BG (_)  { _color('bright_green', $_[0]) 	}
sub B (_)   { _color('blue', $_[0])         	}
sub BB (_)  { _color('bright_blue', $_[0])  	}
sub CY (_)  { _color('cyan', $_[0])         	}
sub BCY (_) { _color('bright_cyan', $_[0])  	}
sub Y (_)   { _color('yellow', $_[0])       	}
sub BY (_)  { _color('bright_yellow', $_[0])	}
sub M (_)   { _color('magenta', $_[0])      	}

# actually the same as magenta.
sub BM (_)          { return _color('bright_magenta', $_[0]) }

# 0 .. 15
sub ANSI ($$)   { my $a = shift; return _color("ansi$a", $_[0]) }
# 0 .. 23
sub GREY ($$)   { my $a = shift; return _color("grey$a", $_[0]) }

sub RESET           { return color('reset') }

sub disable_colors { 
    $Disable_colors = 1;
    $Force_colors = 0;
}

sub force_colors {
    $Force_colors = 1;
    $Disable_colors = 0;
}

sub strip_colors(_@) { Term::ANSIColor::colorstrip(@_) }

sub sys_chomp(_@) {
    # Pass @_ to sys without prototype checking.
    # Do it like this because otherwise sys will force scalar.
    my ($ret, $code) = &sys;

    # catch more than chomp
    $ret =~ s/ \s* $//x;

    wantarray ? ($ret, $code) : $ret
}

# Two ways to call: 
# ($command, $die, $verbose)
# ($command, { die => , verbose =>, list => }

# returns $out in list ctxt (if die is 0)
# returns ($out, $code) in list ctxt (if die is 0)

sub sys(_@) {
    my ($command, $arg2, $arg3) = @_;

    my ($die, $verbose);

    my $opt;

    strip_r(\$command);

    if ( $arg2 and ref $arg2 eq 'HASH' ) {
        $opt = $arg2;
        $die = $opt->{die};
        $verbose = $opt->{verbose};
    }
    else {
        $die = $arg2;
        $verbose = $arg3;
        $opt = {};
    }

    $die //= $Cmd_die;
    $verbose //= $Cmd_verbose;

    $die = 0 if wantarray; # they want a code back

    my $wants_list = $opt->{list} // 0;
    my $kill_err = $opt->{killerr} // 0;
    my $utf8 = $opt->{utf8} || $opt->{UTF8} || $opt->{'utf-8'} || $opt->{'UTF-8'} // 0;
    my $quiet = $opt->{quiet} // 0;
    my $no_chomp = do {
        my $c = $opt->{chomp} // 1;
        not $c
    };

    my @out;
    my $out;
    my $ret;

    my $ctxt_list = wantarray;

    my $c = remove_quoted_strings($command); # for & check

    $kill_err and $command = "$command 2>/dev/null";

    # & -> system
    if ( 
        ($c =~ / ^ (.+) \s+ \& \s+ (.*) $ /x) || 
        ($c =~ / ^ (.+) \s+ \& $/x)
    )
    {
        say sprintf "%s [fork] %s", G e8 $BULLET, $command if $verbose;
        system("$command");
        $out = "[cmd immediately bg'ed, output not available]";
    } 
    # backquotes
    else {
        say sprintf "%s %s", G e8 $BULLET, $command if $verbose;
        if ($wants_list) {
            @out = map { 
                chomp unless $no_chomp; 
                $utf8 ? d8 $_ : $_
            } `$command`;
        } else {
            $out = `$command`;
            utf8::encode $out if $utf8;
        }
        $ret = $?;

        # Don't use $!, which is for system errors -- most programs don't
        # have any idea how to set this.
        # Just let stderr go to terminal. Same for sys_system.
    }

    if ($ret) {
        my $e = sprintf "Couldn't execute cmd %s.", _cmd_bracket BR $command;
        if ($die) {
            error $e;
        }
        elsif (! $quiet) {
            war $e;
        }
    }

    # posix thing
    $ret >>= 8 if defined $ret and $ret > 0;

    if ($wants_list) {
        return $ctxt_list ? (\@out, $ret ) : \@out;
    } else {
        return $ctxt_list ? ( $out, $ret ) : $out;
    }
}

sub sys_system {
    my ($command, $opt) = @_;
    $opt //= {};
    my $die = $opt->{die} // $Cmd_die;
    my $quiet = $opt->{quiet} // 0;

    strip_r(\$command);

    my $verbose = $opt->{verbose} // $Cmd_verbose // 1;
    say sprintf "%s %s", G e8 $BULLET, $command if $verbose;
    
    system $command;
    if ($?) {
        my $e = sprintf "Couldn't execute cmd %s.", BR $command;
        if ($die) {
            error $e;
        }
        else {
            war $e unless $quiet;
            return $?;
        }
    }
    
    0
}

sub sysl {
    my ($command, $arg1, $arg2) = @_;
    return ref $arg1 eq 'HASH' ? 
        sys $command, { list => 1, %$arg1 } : 
        sys($command, {
            die => $arg1,
            verbose => $arg2,
            list => 1,
        })
    ;
}

sub sysll {
    my $ret = scalar sysl @_;

    @$ret
}

sub sys_code {
    my ($command, @args) = @_;
    # don't die, don't yack
    if (@args) {
        if (ref $args[0] eq 'HASH') {
            $args[0]->{die} = 0;
            $args[0]->{quiet} = 1;
        }
        else {
            wartrace "Old calling of sys_code deprecated";
        }
    }
    my (undef, $ret) = sys $command, @args;

    $ret
}

sub sys_ok {
    my ($command, @args) = @_;
    my $opt = ref $args[0] eq 'HASH' ? shift @args : {};

    not sys_code $command, $opt, @args
}



# If used for opening commands, can be tricky (impossible?) to get error
# messages when the command exists but fails (e.g. find /non/existent/path)
# To catch that, read from it once (<$fh>) and check the return value of
# close($fh) (or use safeclose).

sub safeopen {
    (scalar @_ < 3) || error("safeopen() called incorrectly");

    my $file = shift;

    my $die;
    my $is_dir;

    my $arg2 = shift;

    my $utf8;
    my $quiet;
    if (ref $arg2 eq 'HASH') {
        # require an arg to open dirs, to avoid mistakes.
        $die = $arg2->{die};
        $is_dir = $arg2->{dir};
        $utf8 = $arg2->{utf8} || $arg2->{UTF8} || $arg2->{'utf-8'} || $arg2->{'UTF-8'};
        $quiet = $arg2->{quiet} // 0;
    }
    # old form
    else {
        $die = $arg2;
    }

    $die //= 1;

    if ( -d $file ) {
        if (! $is_dir) {
            war "Deprecated -- need opt 'dir => 1' to use safeopen with a dir.";
            exit 1;
        }
        if ( opendir my $fh, $file ) {
            return $fh;
        }
        else {
            $die and error "Couldn't open directory", R $file, "--", $!;
            return undef;
        }
    }

    my $op = 
        $file =~ />/ ? 'writing' :
        $file =~ />>/ ? 'appending' :
        $file =~ /\|\s*$/ ? 'pipe reading' :
        $file =~ /^\s*\|/ ? 'pipe writing' :
        'reading';

    if ( open my $fh, $file ) {
        binmode $fh, ':utf8' if $utf8;

        # In the case of a command, could still be an error.
        return $fh;
    } 
    else {
        my $e = join ' ', "Couldn't open filehandle to", R $file, "for", Y $op, "--", $!;
        $die and error $e;
        war $e unless $quiet;
    }

    return # error
}

# Read from filehandle at least once or there may be a false error reported.
sub safeclose {
    my ($fh, $opt) = @_;
    $opt //= {};
    my $cmd = $opt->{cmd} // '';
    my $die = $opt->{die} // 1;
    my $ok = close $fh;
    if (!$ok) {
        my $cmd_str = $cmd ? "cmd %s" : "last cmd%s"; # dummy in second
        my $e = sprintf "Error (on close) with $cmd_str%s", BR $cmd, $! ? " ($!)" : '';
        $die ? error $e : war $e;
    }
        
    $ok
}

# Generally for user errors or things like file not found.
sub error {
    my ($opts, $string) = _process_info_opts(@_);

    my $stack = $string ? 0 : 1; #stacktrace
    $string = "Something's wrong, dying" unless $string;
    _disable_colors_temp(1) if $opts->{disable_colors};

    my $msg = join '', R e8 "$BULLET ", e8 $string, "\n";

    $stack ? confess $msg : die $msg;
}

# For programmer and very internal errors.
sub ierror {
    my ($opts, $string) = _process_info_opts(@_);

    my @string = $string ? ($string) : ();
    $string = join ': ', "Internal error", @string;
    _disable_colors_temp(1) if $opts->{disable_colors};

    confess R e8 "$BULLET ", e8 $string, "\n";
}

# User warnings or programmer warnings. Programmer warnings can also warn.
# war { opts => }, str1, str2, ...
# or war str1, str2, ...
# same for info.
sub war {
    my ($opts, $string) = _process_info_opts(@_);

    my $show_line_num = $opts->{show_line_num} // 0;
    if (not $string) {
        $string = "Something's wrong";
        $show_line_num = 1;
    }

    if ($show_line_num) {
        my $backtrace = $opts->{backtrace} // 1;
        my ($package, $filename, $line) = caller $backtrace;
        $string .= sprintf " (%s:%s)", Y $filename, BR $line;
    }
    _disable_colors_temp(1) if $opts->{disable_colors};

    utf8::encode $string;
    warn BR e8 "$BULLET ", $string, "\n";

    _disable_colors_temp(0) if $opts->{disable_colors};
}

# For programmer and very internal warnings.
sub iwar {
    my ($opts, $string) = _process_info_opts(@_);

    my @string = $string ? ($string) : ();
    $string = join ': ', "Internal warning", @string;
    _disable_colors_temp(1) if $opts->{disable_colors};

    war { show_line_num => 1, backtrace => 2 }, $string;
}


# A version of war which is guaranteed to return an empty list.
sub warl {
    war(@_);

    ()
}

# A version of war which returns the first arg. 
sub warreturn {
    my ($arg, @warning) = @_;
    war(@warning);

    $arg
}

# Warn with stack trace.
# Doesn't pipe through war().

sub wartrace {
    my $s = join ' ', @_;
    $s ||= "something's wrong";
    my $w = join ' ', BR $BULLET, $s;
    cluck(e8 $w);
}

# Error with stack trace.
# Doesn't pipe through error().

sub errortrace {
    my (@s) = @_;
    @s = ("Something's wrong, dying") unless @s;
    my $e = join ' ', R $BULLET, @s;
    confess(e8 $e);
}

# Expects char string.
sub info(_@) {
    return unless $Info_level;
    my ($opts, $string) = _process_info_opts(@_);

    _disable_colors_temp(1) if $opts->{disable_colors};

    my $nl = $opts->{no_nl} ? '' : "\n";

    printf "%s %s$nl", BB e8 "$BULLET", e8 $string;

    _disable_colors_temp(0) if $opts->{disable_colors};
}

# Expects char string.
sub ask {
    return unless $Info_level;
    printf "%s %s? ", M e8 "$BULLET", join ' ', map { e8 } @_;
}

# Common opt processing for info, war, etc.
# If the first arg is a hash, it is interpreted as options.
# To really dump a hash, put some scalar as the first opt.
sub _process_info_opts {
    my ($string, $opts);
    $opts = ref $_[0] eq 'HASH' ? shift : {};
    my @s;
    for (@_) {
        my $hash = ref eq 'HASH' ? $_ : undef;

        #wartrace("Undefined var passed to an info func"),
        #    return $opts, '[undefined]' unless defined;

        push @s, 
            (not defined) ? '[undef]' :
            ref eq 'ARRAY' ? 
            ( @$_ ? join '|', @$_ : '[empty]' ) :
            defined($hash) ?
            ( %$hash ? "\n" . join "\n", map { sprintf "%s => %s", Y $_, BB $hash->{$_} } keys %$hash : '[empty]' ) :
            $_;
    }
    return $opts, join ' ', @s;
}

# 1 -> disable colors, storing value of state
# 0 -> restore
sub _disable_colors_temp {
    my ($s) = @_;
    state $dc;
    if ($s) {
        $dc = $Disable_colors;
        disable_colors(1);
    }
    else {
        disable_colors($dc);
        $dc = undef;
    }
}

sub strip_ptr {
    wartrace("Deprecated: use strip_r");
    &strip_r;
}

sub strip(_) {
    #no warnings;
    
    my ($s) = @_;
    strip_r(\$s);

    $s
}

sub strip_r {
    my ($a) = @_;
    $$a =~ s/^\s+//;
    $$a =~ s/\s+$//;
}

# Alters input.
sub strip_s(_) {
    my ($s) = @_;
    strip_r(\$s);
    $_[0] = $s;
}

sub askf {
    # idiosyncrasy with sprintf; doesn't like sprintf(@_)
    ask sprintf shift, @_;
}

sub infof {
    # idiosyncrasy with sprintf; doesn't like sprintf(@_)
    info sprintf shift, @_;
}

sub sayf {
    # idiosyncrasy with sprintf; doesn't like sprintf(@_)
    say sprintf shift, @_;
}
        
sub _color {
    my ($col, $s) = @_;
    if (-t STDOUT or $Force_colors) {
        if (not defined $s) {
            wartrace "Undef passed to _color";
            return '';
        }

        $Disable_colors and return $s;
        return color($col) . $s . color('reset');
    }
    else {
        return $s;
    }
}
   
sub e8(_) {
    my $s = shift;
    utf8::encode $s;
    $s;
}

sub d8(_) {
    my $s = shift;
    utf8::decode $s;
    $s;
}

sub remove_quoted_strings {
    my $s = shift or return '';
    my @s = split //, $s;
    my @new;
    my $in = 0;
    my $qc = '';
    my $prev = '';
    for (@s) {
        if (! $in) {
            if ( $_ eq "'" or $_ eq '"' ) {
                $in = 1;
                $qc = $_;
            }
            else {
                push @new, $_;
            }
        }
        else {
            if ( $qc eq "'" ) {
                if ($_ eq "'" and $prev ne '\\') {
                    $in = 0;
                    $qc = '';
                }
            }
            elsif ( $qc eq '"' ) {
                if ($_ eq '"' and $prev ne '\\') {
                    $in = 0;
                    $qc = '';
                }
            }
            else {
                # ignore
            }
        }
        $prev = $_;
    }
    return join '', @new;
}
 
sub _class_method {
    my ($pack) = @_;

    return unless $pack;

    # more elegant way? XX
    $pack eq __PACKAGE__ or $pack eq 'Fish::Utility_a'
}

sub rem(_) {
    my ($comment) = @_;
}

sub shell_quote(_) {
    my ($s) = @_;
    shell_quote_r(\$s);

    $s
}

sub shell_quote_r {
    my ($r) = @_;
    $$r =~ s/ " /\\"/xg;
    $$r =~ s/ ` /\\`/xg;
    $$r =~ s/ ! /\\!/xg;
    $$r =~ s/ \$ /\\\$/xg;

    $$r = qq,"$$r",
}

# Alters input.
sub shell_quote_s(_) {
    my ($s) = @_;
    shell_quote_r(\$s);

    $_[0] = $s;
}

# Not intended to take an entire shell command and make it safe. Probably
# shell_quote is the one to use.
sub shell_escape(_) {
    my ($s) = @_;
    shell_escape_r(\$s);

    $s
}

sub shell_escape_r {
    my ($r) = @_;
    $$r =~ s/ " /\\"/xg;
    $$r =~ s/ ` /\\`/xg;
    $$r =~ s/ ! /\\!/xg;
    $$r =~ s/ \$ /\\\$/xg;

    #$$r =~ s/ ' /\\'/xg; # right?
}

# Alters input.
sub shell_escape_s(_) {
    my ($s) = @_;
    shell_escape_r(\$s);

    $_[0] = $s;
}

# Dies.
sub ps_running(_) {
    my ($ps) = @_;
    my $cmd = sprintf qq, ps -C %s ,, shell_quote $ps;
    sys_ok $cmd, { verbose => 0 }
}

sub runtime_import {
    my ($pack, $opt) = @_;
    $opt //= {};
    my $die = $opt->{die} // 1;

    eval "use $pack; 1" or do {
        my $msg = sprintf 'Could not import package %s at runtime: %s', BR $pack, BR $@;
        $die ? ierror $msg : iwar $msg;
    };
}

# Move out XX
sub symbol_table_entry {
    my ($fqn, $what) = @_;
    no strict 'refs';

    $what = uc $what;

    # e.g. *{A::B::var_name}{ARRAY}
    *{$fqn}{$what}
}

sub symbol_table_entry_set {
    my ($fqn, $set) = @_;
    no strict 'refs';
    # e.g. *{A::B::var_name} = $array_ref
    *{$fqn} = $set;
}

sub symbol_table_alias {
    my ($fqn_src, $fqn_dest, $what) = @_;
    no strict 'refs';
    $what = uc $what;
    # e.g. *{A::B::var_name} = *{A::B::var_name}{ARRAY}
    *{$fqn_dest} = *{$fqn_src}{$what};
}

# Import the EXPORT_OK of the given package into the caller.
sub import_export_ok(_) {
    my ($package) = @_;
    my $fqn = $package . '::EXPORT_OK';
    my $exok = symbol_table_entry $fqn, 'array';

    my ($caller_package, $caller_filename, $caller_line) = caller;
    for my $func_name (@$exok) {
        my $fn_fqn = $package . '::' . $func_name;
        my $caller_fn_fqn = $caller_package . '::' . $func_name;
        symbol_table_alias $fn_fqn, $caller_fn_fqn, 'code';
    }
}

1;
