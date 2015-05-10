#!/usr/bin/perl

package Fish::Socket::Server::unix;

use base 'Fish::Socket::Server';

use 5.18.0;

our $AUTOLOAD;

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

    my $self = $class->SUPER::new();

    # fh
    $self->{listener} = undef;

    unlink $path or die "Can't unlink $path" if -e $path;

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
    $name =~ s/.*://; 

    die "Can't access `$name' field in class $class" unless exists $self->{$name};

    return @_ ? $self->{$name} = shift : $self->{$name};
}

sub DESTROY {}


1;
