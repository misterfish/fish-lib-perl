package Fish::Print;

=head

Author: Allen Haim <allen@netherrealm.net>, © 2015.
Source: github.com/misterfish/fish-lib-perl
Licence: GPL 2.0

=cut

BEGIN {
    use File::Basename;
    push @INC, dirname $0;
}

use 5.18.0;

use constant MOOSE => 0;

use if MOOSE, 'Moose';
use if ! MOOSE, 'Carp';

#use Fish::Utility_a;

$| = 1;

if (! MOOSE) {
    sub has;
    our $AUTOLOAD;
}
else {
    has _prog_idx => (
        is          => 'rw',
        isa         => 'Int',
        default     => -1,
    );

    has _printed_length => (
        is          => 'rw',
        isa         => 'Int',
        default     => 0,
    );
}

if (! MOOSE) {
    sub new {
        my $self = {
            _prog_idx => undef,
            _printed_length => undef,
        };
        bless $self, shift;
        #return $self->BUILD;
    }
}
my @PROG = qw, / - \ | ,;

sub cr {
    my ($self, $arg) = @_;
    # instance
    if (ref $self) {
        print "\r", ' ' x $self->_printed_length, "\r";
        $self->_printed_length(0);
    }
    # static
    else {
        my $num = $arg // 0;
        print "\r";
        $num and print ' ' x $num, "\r";
    }
}

sub nl {
    my ($self) = @_;
    $self->_printed_length(0);
    say '';
}

sub print {
    my ($self, @s) = @_;
    
    my $p = join '', @s;
    print $p;
    my $l = length $p;
    my $pl = $self->_printed_length;
    $self->_printed_length($pl + $l);
    return $l;
}

sub prog {
    my ($self) = @_;
    my $i = $self->_prog_idx;
    $i = ++$i % @PROG;
    $self->_prog_idx($i);
    return $PROG[$i];
}

sub prog_pr {
    my ($self) = @_;
    $self->cr;
    $self->print($self->prog, ' ');
}

if ( ! MOOSE ) {
    sub DESTROY {}
    sub AUTOLOAD {
        my $self = shift;
        my $type = ref $self or croak "$self is not an object";

        my $name = $AUTOLOAD;
        $name =~ s/.*://;

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
