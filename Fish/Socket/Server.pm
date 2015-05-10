#!/usr/bin/perl

package Fish::Socket::Server;

BEGIN {
    use File::Basename;
    push @INC, dirname $0;
}

use 5.18.0;

use Socket;

our $AUTOLOAD;

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
    my $ch = $self->ch or warn("No client"), 
        return;
    print $ch $msg, "\n";
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
