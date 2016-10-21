package Fish::Class::Anon::anon;

=head

Author: Allen Haim <allen@netherrealm.net>, © 2015.
Source: github.com/misterfish/fish-lib-perl
Licence: GPL 2.0

Not intended to be 'use'd directly.

=cut

use 5.18.0;

use Carp 'cluck', 'confess';

use Fish::Class::Common 'ierror', 'contains';
use Fish::Class::Anon::priv;

local $SIG{__WARN__} = \&cluck;
local $SIG{__DIE__} = \&confess;

our $AUTOLOAD; # resolve arbitrary method names.

# Disallow the following words as accessor names.
# Note that o is actually ok.
my @RESERVED = qw,
    _p

    new
    AUTOLOAD
    DESTROY
,;

sub new {
    # Args are transformed into methods using autoload.
    my ($pack, @args) = @_;
    my %args = @args;
    my $spec = $args{spec} or 
        ierror "Need spec";
    ref $spec eq 'ARRAY' or
        ierror "Need array ref as spec";
    my @spec = @$spec;
    my %spec = @spec;
    my $self = {};
    my @keys;
    for my $k (keys %spec) {
        $self->{$k} = $spec{$k};
        push @keys, $k;
    }
    $self->{$_} and 
        ierror "$_ is an invalid (reserved) key for anonymous object" for @RESERVED;

    $self->{_p} = Fish::Class::Anon::priv->new(
        keysr => \@keys,
        _anon => $self,
    )->init;
    bless $self, $pack;
}

sub AUTOLOAD {
    my $self = shift;
    ref $self or 
        ierror "self not a hash";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;

    if (not exists $self->{$name}) {
        if ($self->_p->default_undef) {
            return undef;
        }
        if ($name eq 'DESTROY') {
            return undef;
        }
        ierror "Invalid property in anonymous class:", $name, "\n";
    }

    my $thing = $self->{$name};

    # om() (call it is a method, and pass the object explicitly as self. 
    # See documentation in Fish::Class.

    if (ref $thing eq 'CODE' and $self->_p->mode_method) {
        return $thing->($self, @_);
    }

    # o():
    else {
        return @_ ? $self->{$name} = shift : $self->{$name}
    }
}


1;
