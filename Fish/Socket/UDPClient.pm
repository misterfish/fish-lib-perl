#!/usr/bin/perl

package Fish::Socket::UDPClient;

BEGIN {
    use File::Basename;
    push @INC, (dirname $0) . '/../..';
}

warn __PACKAGE__, ' not tested.';

use 5.10.0;

our $AUTOLOAD;

use strict;
use warnings;

use IO::Socket::INET;

use Class::XSAccessor {
    constructor => 'new',
    accessors => [qw/
        _socket addr
    /],
};

#use Fish::Utility_a;

sub connect {
    my ($self) = @_;
    $self->addr or die "Need addr.";
    my $socket = IO::Socket::INET->new(
        PeerAddr        => $self->addr,
        Proto           => 'udp'
    ) or die "Couldn't create socket, $!";
    $self->_socket($socket);
}

sub send {
    my ($self, $data) = @_;
    # return??
    $self->_socket->send($data);
}

sub read {
    my ($self) = @_;
    my $fh = $self->_socket;
    local $/ = "\n";
    <$fh>;
}

# - - -

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
