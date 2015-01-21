package Fish::Class;

# XX allow class inner => { acc => { field1 => {}, field2 => [] } }

=head

Make a class with easy (and fast) accessors like this:

class inner => ['field1', 'field2'],
    sub1 => sub {
    },
    sub2 => sub {
    },
;

or 

class inner => { extends => 'something', acc => ['field1', 'field2'] },
    sub1 => sub {
    },
    sub2 => sub {
    },
;

and optionally:

package inner {
    use ...;
    my $protected1 = ...;
    my @protected2 = ...;
    sub sub3 { }
}

'new' is made automatically.

$self->SUPER::funcname won't work in the 'class' declaration.
$self-> _-> super->('funcname') will work, or put it in the package {} block.

o and om:

my $o = o(
    key => val,
    key2 => undef,
    key3 => [],
    ...,

    method1 => sub {
        my ($self, $arg1, $arg2, ...) = @_;
        ...
    }
);

Methods can not be assigned to after the object is made.

For the rest: 

say $o->key;
$o->key2('something');
say $o->key2;

my $l = $o->key3;
push @$l, 'val1', 'val2';

And, p is reserved.

- - -

We don't want to depend on any Fish::Utility stuff, and keep error messages unfancy (no colors, etc.).

=cut

use 5.18.0;

BEGIN {
    use base 'Exporter';
    our @EXPORT = qw, class ,;
    our @EXPORT_OK = qw, o om od ,;
}

use Fish::Class::Class 'class';
use Fish::Class::Anon 'o', 'om', 'od';

1;

