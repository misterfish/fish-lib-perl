#!/usr/bin/perl

package Fish::Socket::Server::unix;
use parent 'Fish::Socket::Server';

use 5.10.0;

our $AUTOLOAD;

use strict;
use warnings;

sub D2;

use IO::Socket::UNIX qw( SOCK_STREAM SOMAXCONN );

sub new {
    my ($class, @args) = @_;
    my %args;
    my $path;
    if (@args == 1) {
        $path = shift @args;
    }
    else {
        %args = @args;
        $path = $args{path};
    }
    $path or die;

    # should always be 1 actually
    my $unlink = 1;

    my $self = $class->SUPER::new();

    # fh
    $self->{listener} = undef;

    if (-e $path) {
        if ($unlink) {
            unlink $path or die "Can't unlink $path";
        }
        else {
            warn sprintf "Path '%s' exists, not unlinking.\n", $path;
        }
    }
    -e $path and ();

    my $listener = IO::Socket::UNIX->new(
       Type   => SOCK_STREAM,
       Local  => $path,
       Listen => SOMAXCONN,
    ) or die "Can't create server socket: $!\n";

    $self->{listener} = $listener;

    return bless $self, $class;
}

sub listen {
    my ($self) = @_;

    my $ch = $self->listener->accept or die "Can't accept connection: $!\n";
    $self->ch($ch);

    my $line = <$ch>;
    return $line;
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
