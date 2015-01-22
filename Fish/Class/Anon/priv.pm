package Fish::Class::Anon::priv;

use 5.18.0;

=head

Not intended to be 'use'd directly. 
Is used internally by ::anon for the '_p' member.

Currently the _p member has these methods:

keys
keysr
mode_method
default_undef

e.g:

my $a = o(
   a => 1,
   b => 2,
);

say $a->_p->keys;

# order not guaranteed
> b a

say list $a->_p->keysr;

# order not guaranteed
> b a

my $b = om(
    a => 5,
    b => sub { shift->a },
);

say $b->_p->keys;

# order not guaranteed
> a b

say $b->_p->mode_method;

> 1

=cut

use Fish::Class 'class';
class 'Fish::Class::Anon::priv', 
    [qw, keysr mode_method default_undef ,];

sub keys { 
    my $r = shift->keysr;
    @$r
}

1;
