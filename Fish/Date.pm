package Fish::Date;

use 5.14.0;

use strict;
use warnings;

use Date::Calc qw, Day_of_Week Day_of_Week_to_Text ,;

use Fish::Utility_a;
use Fish::Class 'o';

# optional arg: time

sub new { shift if $_[0] eq __PACKAGE__;
    my (@args) = @_;
    my %args = @args;
    my $time = delete($args{time}) // time;
    if (scalar keys %args) {
        war sprintf "%s: ignoring arg %s", __PACKAGE__, BR $_ for keys %args;
    }

    my @time = localtime $time;
    my @fields = qw, sec min hour mday mon year wday yday isdst,;
    my %fields = (
        # theirs -> mine
        sec => ['sec', 'secs'],
        min => ['min', 'minutes'],
        hour => ['hour', 'hr'],
        mday => ['mday', 'day', 'date'],
        mon => ['mon', 'month'],
        year => ['yr', 'year'],
        wday => ['wday'],
        yday => ['yday'],
        isdst => ['isdst'],
    );
    my @more_mine = qw, dow dow_as_text ,;
    my @accessors;
    for my $v (values %fields) {
        push @accessors, $_ for @$v;
    }
    push @accessors, @more_mine;
    my $o = o( map { $_ => undef } @accessors);
    for my $theirs (@fields) {
        my $mine = $fields{$theirs};
        my $val = shift @time;
        if ($theirs eq 'mon') {
            $val++;
        }
        elsif ($theirs eq 'year') {
            $val += 1900;
        }
        $o->$_($val) for @$mine;
    }
    # Note: mon-sun, 1-7
    my $dow = Day_of_Week($o->year, $o->month, $o->day);
    $o->dow($dow);
    # locale-dependent
    $o->dow_as_text(Day_of_Week_to_Text($dow));

    $o
}

1;
