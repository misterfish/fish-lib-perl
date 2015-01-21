#!/usr/bin/perl

package Fish::Socket::Server;

our $DEBUG;
BEGIN {
    use File::Basename;
    push @INC, dirname $0;
    # doesn't work
    use constant DEBUG => 0;
    use if DEBUG, 'Utility' => 'D2';
}

use 5.10.0;

our $AUTOLOAD;

use strict;
use warnings;

sub D2;

use Socket;

sub new {
    my ($class) = @_;
    return {
        ch => undef,
    };
}

#subclass
sub listen {
}

sub listen_chomp {
    my ($self) = @_;
    my $s = $self->listen;
    chomp $s;
    return $s;
}

sub say {
    my ($self, $msg) = @_;
    my $ch = $self->ch or warn("No client"), return;
    print $ch $msg, "\n";
}

sub AUTOLOAD {
    my $self = shift;
    my $class = ref $self or die "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    die "Can't access `$name' field in class $class" unless exists $self->{$name};

    return @_ ? $self->{$name} = shift : $self->{$name};
}

sub DESTROY {}

1;
