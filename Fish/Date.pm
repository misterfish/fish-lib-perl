package Fish::Date;

use 5.14.0;

use strict;
use warnings;

use Date::Calc qw, Day_of_Week Day_of_Week_to_Text ,;

use Fish::Utility_a;
use Fish::Class 'o';

# Simpler interface to date functions.
# Accessors are: 
#  sec = secs 
#  min = mins = minutes 
#  hour = hr = hrs 
#  mday = day = date 
#  mo = mon = month 
#  yr = year 
#  wday yday isdst dow dow_as_text 

# optional arg: time

# in the order as returned by localtime
my @FIELDS_LOCALTIME = qw, sec min hour mday mon year wday yday isdst ,;
my @FIELDS_ALIAS = qw, secs mins minutes hr hrs day date mo month yr ,;
my @FIELDS_OTHER = qw, dow dow_as_text ,;

my @fields = (@FIELDS_LOCALTIME, @FIELDS_ALIAS, @FIELDS_OTHER);

sub new { shift if $_[0] eq __PACKAGE__;
    my (@args) = @_;
    my %args = @args;
    my $time = delete($args{time}) // time;
    if (scalar keys %args) {
        war sprintf "%s: ignoring arg %s", __PACKAGE__, BR $_ for keys %args;
    }

    my @time = localtime $time;
    say @time;
    my @fields_localtime = qw, sec min hour mday mon year wday yday isdst ,; # the other as returned by localtime
    my %fields = (
        # theirs -> mine
        sec => ['sec', 'secs'],
        min => ['min', 'mins', 'minutes'],
        hour => ['hour', 'hr', 'hrs'],
        mday => ['mday', 'day', 'date'],
        mon => ['mo', 'mon', 'month'],
        year => ['yr', 'year'],
        wday => ['wday'],
        yday => ['yday'],
        isdst => ['isdst'],
    );
    my $self = o( map { $_ => undef } @fields);
    for my $theirs (@FIELDS_LOCALTIME) {
        my $mine = $fields{$theirs};
        my $val = shift @time;
        if ($theirs eq 'mon') {
            $val++;
        }
        elsif ($theirs eq 'year') {
            $val += 1900;
        }
        $self->$_($val) for @$mine;
    }
    # Note: mon-sun, 1-7
    my $dow = Day_of_Week($self->year, $self->month, $self->day);
    $self->dow($dow);
    # locale-dependent
    $self->dow_as_text(Day_of_Week_to_Text($dow));

    $self
}

1;
