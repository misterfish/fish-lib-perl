package Fish::Class;

=head

Author: Allen Haim <allen@netherrealm.net>
Licence: GPL 3.0

--- Requires: perl 5.18, and Class::XSAccessor.
---
--- Motivation: re-introduce some nice concepts from other dynamic languages
--- like javascript, ruby, and lua into perl.
---
--- Accessors created using Class::XSAccessor are fast because they're
--- implemented at the C-level. 
---
--- Still the philosophy behind this is to be kind to the programmer, not
--- necessarily the machine. o() and om() in particular are not meant to be
--- fast.
---
--- The internals below are not that fun to read (they involve manually
--- messing with symbol table entries, etc., and with as few dependencies as
--- possible).
---
--- For anything more complicated than simple usage you should really
--- look into Moo/Moose/Mouse (I recommend Moo). 

--- Class-based usage using class as a 'keyword' (really a function, of
--- course):

Make a class with easy (and fast) accessors like this:

use Fish::Class 'class';

class dog => ['name', 'color', 'species'];

(alternate syntax:)

class dog => [qw, name color species ,];

Or like this:

class dog => ['name', 'color', 'species'],
    bark => sub { 
        my ($self, ...) = @_;
        ... 
    },
    jump => sub { ... };

This is roughly equivalent to the following in javascript:

function Dog(props) {
    this.name = props.name
    this.color = props.color
    ...
}

Dog.prototype.bark = function() bark { 
    ...
}

...

Another possibility is:

class dog => { extends => 'animal', acc => ['name', 'color', 'species'] },
    bark => sub { ... },
    jump => sub { ... };
;

More methods can be 'monkey-patched' in like this:

package dog {
    use ...;
    my $protected1 = ...;
    my @protected2 = ...;
    sub sub3 { }
}

After all 'class' just works by changing the current package to package
'dog', declaring some functions, and getting out.

'new' is made automatically, and is of course reserved.

A private object named _ is also created, and is also reserved.

Then: 

my $dog = $dog->new(name => xxx, color => xxx); # args optional

Get/set properties using perl-style accessors:

my $name = $dog->name;
$dog->name('egbert');

Note:
$self->SUPER::funcname won't work inside subs in the 'class' declaration.

Solution:
$self->_->super->('funcname') will work.

To get a list ref of the keys:
my $keys = $self->_->keysr;

Example:

use Fish::Utility_l 'list';
say for list $self->_->keysr;

A property named 'keys' also exists in the _ object, but it's more annoying
to use, since it's a method:

say for $self->_->keys->();

--- Anonymous objects:
--- 
--- Use o() and om() to create plain old objects, with a slightly different
--- interface than just normal hashes (no curly braces, use perl-style
--- accessors, and referencing a non-existent key is a runtime error).
--- Also om() has a bit more magic built in (see below).

use Fish::Class 'o', 'om';

my $dog = o(
    name => xxx,
    color => yyy,
    tricks => [...],
    ...,

    bark => sub {
        my ($arg1, $arg2, ...) = @_; # note, no $self.
        ...
    }
);

This is like the javascript:

var dog = {
    name: 'mr. dog',
    color: yyy,
    tricks: [...],
    ...

    bark: function bark () {
    },

    ...
}

om() looks almost the same (see below for the difference):

my $cat = om(
    name => 'mr. cat',
    scream => sub {
        my ($self, $arg1, $arg2, ...) = @_; # note, with $self.
        say sprintf "%s sez: awww", $self->name;
        ...
    }
);

To get/set: no curly braces, use perl-style accessors, and accessing
non-existing keys is an error.

my $dog_name = $dog->name;
my $cat_name = $cat->name;
$dog->name('new dog name');
$cat->name('new cat name');

my $tricks = $o->key3;
push @$tricks, 'val1', 'val2';

With o(), methods are called like this:

$dog->bark->($arg1, $arg2, ...);

And you can replace a method whenever you like using a set accessor:

$dog->bark(sub { ... });

And, you can not usefully refer to other properties of the dog at
define-time.

With om(), methods calls are simplified, and, the object itself is passed as
$self. Easier shown than described:

$cat->scream; # $self->name is now available to the 'scream' sub.

But with om(), you can not replace methods any more, because what looks like
a set accessor will just call the method:

$cat->scream(sub { ... }) will call the method and pass it the sub (not what
you want).

Finally, _p is a reserved key, allowing this:

my $keys_ref = $dog->_p->keysr;

And of course you can freely mix 'class' usage with 'o' and 'om' usage. 

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

