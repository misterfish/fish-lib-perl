package Fish::Conf::Listener;

#
=head

Author: Allen Haim <allen@netherrealm.net>, © 2015.
Source: github.com/misterfish/fish-lib-perl
Licence: GPL 2.0

=cut

use 5.18.0;

BEGIN {
    use File::Basename;
    push @INC, dirname $0;
}

use Moo;
use MooX::Types::MooseLike::Base ':all';

use Fish::Utility;
use Fish::Class 'class', 'o';

# ->event_type, indexed by idx
has _li => (
    is => 'rw',
);
# ->event_type, indexed by property
has _lp => (
    is => 'rw',
);

has _required => (
    is => 'rw',
    isa => HashRef,
);

has _want_list => (
    is => 'rw',
    isa => HashRef,
);

has master => (
    is => 'ro',
    required => 1,
    isa => sub { errortrace 'Need Fish::Conf' unless ref $_[0] eq 'Fish::Conf' },
);

my @EVENTS = qw, changed ,;
class dispatcher => [ @EVENTS ];

# the pattern is $self->_li->changed->{$idx} 
# and $self->_lp->changed->{$property}->{$idx} 

sub BUILD {
    my ($self) = @_;
    my $d1 = dispatcher->new;
    my $d2 = dispatcher->new;
    for my $e (@EVENTS) {
        my $hash = {};
        $_->$e($hash) for $d1, $d2;
    }
    $self->_li($d1);
    $self->_lp($d2);
    $self->_required( {} );
    $self->_want_list( {} );
}

sub add {
    my ($self, $event_type, $property, $sub, $userdata) = @_;
    ierror 'Need event_type' unless $event_type;
    ierror 'Need property' unless $property;
    ierror 'Need sub' unless $sub;

    # If the same property is added multiple times then required and want_list will
    # override from the latest one.
    my $prop;
    if (ref $property eq 'HASH') {
        $prop = $property->{property} or ierror;
        $self->_required->{$prop} = $property->{required} // 0;
        $self->_want_list->{$prop} = $property->{want_list} // 0;
    }
    else {
        $prop = $property;
    }

    state $idx = 0;
    $idx++;

    #if ($event_type eq 'changed') {
    #else {
    #    wartrace "Type", BR $event_type, "not implemented";
    #}

    my $i = $self->_li;
    my $p = $self->_lp;

    my $listener = o(
        property => $prop,
        # will be a 'method' -- listener is first arg.
        sub => $sub,
        userdata => $userdata, # can be undef
        idx => $idx,
    );
    iwar ("Unknown event", BR $event_type),
        return unless $i->can($event_type) and $p->can($event_type);

    my $il = $i->$event_type;
    my $ip = $p->$event_type;
    $il->{$idx} = $listener;
    $ip->{$prop} //= {};
    $ip->{$prop}->{$idx} = $listener;

    $idx
}

sub remove {
    my ($self, $idx) = @_;
    my $i = $self->_li;
    my $p = $self->_lp;
    my $l = delete $i->{$idx} or war("No such listener:", $idx),
        return;
    my $prop = $l->{property} or war, 
        return;
    exists $p->{$prop} or war,
        return;
    delete $p->{$prop}->{$idx} or war,
        return;

    1
}

sub fire {
    my ($self, $type, @props) = @_;
    $type or ierror;
    @props or ierror;
    my $p = $self->_lp;
    iwar ("Unknown event", BR $type),
        return unless $p->can($type);
    my $ip = $p->$type;
    my $cfg = $self->master;

    for my $prop (@props) {
        my $ipp = $ip->{$prop} or 
            next;
        for my $idx (keys %$ipp) {
            my $l = $ipp->{$idx};
            my $property = $l->property or war,
                return;
            my $sub = $l->sub or war,
                return;
            my $userdata = $l->userdata; # can be undef

            my $required = $self->_required->{$property};
            my $want_list = $self->_want_list->{$property};
            my $getter = $required && $want_list ? 'cr_list' :
                $required ? 'cr' :
                $want_list ? 'c_list' :
                'c';

            # val can be undef
            $sub->($cfg->$getter($property), $userdata);
        }
    }

}

1;

