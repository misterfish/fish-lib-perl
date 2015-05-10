package Fish::Socket::Server::tcp;

use base 'Fish::Socket::Server';

use 5.18.0;

our $AUTOLOAD;

sub new {
    # host can be undef
    my ($class, $host, $port) = @_;

    my $self = $class->SUPER::new();

    my $proto = getprotobyname 'tcp';

    my $sh;

    # from manpage
    socket $sh, PF_INET, SOCK_STREAM, $proto or die "socket: $!";
    setsockopt $sh, SOL_SOCKET, SO_REUSEADDR, pack("l", 1) or die "setsockopt: $!";
    my $bind = sockaddr_in $port, ($host ? inet_aton $host : INADDR_ANY);
    bind $sh, $bind or die "bind: $!";
    listen $sh, SOMAXCONN or die "listen: $!";

    $self->{sh} = $sh;

    return bless $self, $class;
}


sub listen {
    my ($self) = @_;
    my $ch;

    my $paddr = accept $ch, $self->sh;
    my ($port, $iaddr) = sockaddr_in $paddr;

    select $ch;
    $| = 1;
    select STDOUT;

    $self->ch($ch);

    my $msg = <$ch>;

    return wantarray ? ($msg, $port, $iaddr) : $msg;
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
