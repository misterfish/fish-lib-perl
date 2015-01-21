#!/usr/bin/perl 

BEGIN {
    use File::Basename;
    push @INC, dirname $0;
}

package Fish::Curses;

use constant MOOSE => 0;

use 5.10.0;

use if MOOSE, 'Moose';
use if ! MOOSE, 'Carp';

use Term::ReadKey;

use Curses qw/ 
    curs_set 
    init_pair
    start_color
    use_default_colors
    init_color
    endwin 
    COLOR_RED COLOR_GREEN COLOR_BLUE COLOR_PAIR COLOR_WHITE
    COLOR_CYAN COLOR_BLACK COLOR_MAGENTA COLOR_YELLOW
    A_BOLD

/;

use Fish::Utility_a qw/ sys safeopen /;

my $a = 0;
use constant RED => ++$a;
use constant GREEN => ++$a;
use constant BLUE => ++$a;
use constant WHITE => ++$a;
use constant CYAN => ++$a;
use constant BLACK => ++$a;
use constant MAGENTA => ++$a;
use constant YELLOW => ++$a;

$SIG{KILL} = $SIG{INT} = sub { exit };

if (! MOOSE) {
    sub has;
    our $AUTOLOAD;
}
else {
    has _c => (
        is => 'rw',
        isa => 'Curses',
    );

    has _fh_tty => (
        is  => 'rw',
    );
}

if (! MOOSE) {
    sub new {
        my $self = {
            _fh_tty => undef,
            _c => undef,
        };
        bless $self, shift;
        return $self->BUILD;
    }
}

sub BUILD {
    my ($self) = @_;

    ReadMode "cbreak";

    $self->_fh_tty(safeopen("/dev/tty"));

    my $c = Curses->new;
    $self->_c($c);

    #hide cursor
    curs_set(0);

    use_default_colors();
    start_color();
    init_pair(RED, COLOR_RED, -1);
    init_pair(GREEN, COLOR_GREEN, -1);
    init_pair(BLUE, COLOR_BLUE, -1);
    init_pair(WHITE, COLOR_WHITE, -1);
    init_pair(CYAN, COLOR_CYAN, -1);
    init_pair(BLACK, COLOR_BLACK, -1);
    init_pair(MAGENTA, COLOR_MAGENTA, -1);
    init_pair(YELLOW, COLOR_YELLOW, -1);

    return $self;
}

sub R { 
    my $c = shift;
    $c->_color(RED) ;
    $c->attroff(A_BOLD);
}
sub BR { 
    my $c = shift;
    $c->_color(RED) ;
    $c->attron(A_BOLD);
}
sub G { 
    my $c = shift;
    $c->_color(GREEN) ;
    $c->attroff(A_BOLD);
}
sub BG { 
    my $c = shift;
    $c->_color(GREEN) ;
    $c->attron(A_BOLD);
}
sub B { 
    my $c = shift;
    $c->_color(BLUE) ;
    $c->attroff(A_BOLD);
}
sub BB {
    my $c = shift;
    $c->_color(BLUE) ;
    $c->attron(A_BOLD);
}
sub Y { 
    my $c = shift;
    $c->_color(YELLOW) ;
    $c->attroff(A_BOLD);
}
sub BY { 
    my $c = shift;
    $c->_color(YELLOW) ;
    $c->attron(A_BOLD);
}
sub M { 
    my $c = shift;
    $c->_color(MAGENTA) ;
    $c->attroff(A_BOLD);
}
sub BM { 
    my $c = shift;
    $c->_color(MAGENTA) ;
    $c->attron(A_BOLD);
}
sub BL { 
    my $c = shift;
    $c->_color(BLACK) ;
    $c->attroff(A_BOLD);
}
sub W { 
    my $c = shift;
    $c->_color(WHITE) ;
    $c->attroff(A_BOLD);
}
sub C { 
    my $c = shift;
    $c->_color(CYAN) ;
    $c->attroff(A_BOLD);
}
sub attroff { shift->_c->attroff(@_) }
sub attron { shift->_c->attron(@_) }

sub event_loop {
    my ($self, $cb) = @_;
    ref $cb eq 'CODE' or die;
    my $tty = $self->_fh_tty;
    while (1) {
        # waits
        if (my $key = ReadKey 0, $tty) {
            $cb->($key);
        }
    }
}

sub _color { shift->_c->attron(COLOR_PAIR(shift)) };

sub put {
    my $c = shift->_c;
    $c->addstr(shift) while @_;
    $c->refresh;
}

sub say {
    shift->put(@_, "\n");
}

sub clear { shift->_c->clear }


if ( ! MOOSE ) {
    sub DESTROY {}
    sub AUTOLOAD {
        my $self = shift;
        my $type = ref($self)
                   or croak "$self is not an object";

        my $name = $AUTOLOAD;
        $name =~ s/.*://;   # strip fully-qualified portion

        #unless (exists $self->{_permitted}->{$name} ) {
        unless (exists $self->{$name} ) {
            croak "Can't access `$name' field in class $type";
        }

        if (@_) {
            return $self->{$name} = shift;
        } else {
            return $self->{$name};
        }
    }
}

1;

END {
    endwin();
    ReadMode 'normal';
}

