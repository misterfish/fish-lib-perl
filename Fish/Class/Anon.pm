package Fish::Class::Anon;

=head

Author: Allen Haim <allen@netherrealm.net>, © 2015.
Source: github.com/misterfish/fish-lib-perl
Licence: GPL 2.0

Not intended to be 'use'd directly. Use Fish::Class.

=cut

use 5.18.0;

BEGIN {
    use base 'Exporter';
    our @EXPORT = qw, o om od ,;
}

use Carp 'cluck', 'confess';

use Fish::Class 'class';
use Fish::Class::Common 'ierror', 'contains';
use Fish::Class::Anon::anon;

local $SIG{__WARN__} = \&cluck;
local $SIG{__DIE__} = \&confess;

# To transparently enable calling equivalent class methods, e.g.
# Fish::Class->o, Fish::Class::Anon->o.

my @CALLABLE_AS = (
    __PACKAGE__,
    'Fish::Class',
);

sub new_obj { 
    ierror 'call as class method' unless &class_method;
    shift;
    my (@spec) = @_;
    Fish::Class::Anon::anon->new(
        spec => \@spec,
    );
}

# Note, even if called as Fish::Class::o(), package is this package
# (which is correct).
# Should not be called as class method.
sub o { 
    my $anon = __PACKAGE__->new_obj(@_);
    $anon->_p->mode_method(0);

    $anon
}

# With subs converted into 'methods'
# Should not be called as class method.
sub om {
    my $anon = &o; # pass context
    $anon->_p->mode_method(1);

    $anon
}

# Returns undef when non-existent field queried.
# Should not be called as class method.
sub od {
    my $anon = &o; # pass context
    $anon->_p->default_undef(1);

    $anon
}

# future maybe: sub og -> generic.

# - - - private.

# Enforce calling of class methods as class_name->method, not class_name::method.
# Overloading tricks to allow both can fail in edge cases.

# The & means we see the caller's @_.
sub class_method {
    my ($pack) = @_;
    return unless defined $pack and not ref $pack;

    contains @CALLABLE_AS, $pack
}

1;
