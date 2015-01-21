package Fish::Class::Class;

=head

Not intended to be 'use'd directly. Use Fish::Class.

=cut

use 5.18.0;

BEGIN {
    use base 'Exporter';
    our @EXPORT = qw, class ,;
}

# An alternate to Class::XSAccessor is Object::Tiny; 
# both are fast and easy to use.

# use Object::Tiny;
use Class::XSAccessor;

use Carp 'cluck', 'confess';

use Fish::Class::Common qw, 
    is_int is_num is_non_neg_even 
    symbol_table assign_soft_ref ierror 
,;

local $SIG{__WARN__} = \&cluck;
local $SIG{__DIE__} = \&confess;

sub class {
    my ($class, $spec, @subs) = @_;

    my $e = sprintf "Error making class '%s'", $class;

    my $acc_string = '';
    my $superclass = '';

    if ($spec) {
        my @accessors;
        if (ref $spec eq 'ARRAY') {
            @accessors = @$spec;
        }
        elsif (ref $spec eq 'HASH') {
            my $acc = $spec->{acc} // [];
            ref $acc eq 'ARRAY' or 
                ierror 'need array';
            @accessors = @$acc;

            if ($superclass = $spec->{extends}) {
                ref $superclass and 
                    ierror 'need string';
            }
        }
        else {
            ierror 'bad spec';
        }
        if (@accessors) {
            $acc_string = sprintf 
                "accessors => [qw/ %s /]," ,
                join ' ', @accessors;
        }
    }

    my $ext_string = $superclass ? 
        # -norequire means don't look for a .pm, look in this same source
        # file.
        "use parent -norequire, '$superclass'" : 
        '';

    my $eval = <<ENDEVAL;
        package $class; 
        BEGIN {
            $ext_string;
        }
        use Class::XSAccessor {
            constructor => 'new',
            $acc_string
        };
        1;
ENDEVAL

    eval $eval or 
        ierror $e, "$@";

    if (@subs) {
        ierror "$e", "need even-sized list of subs" unless is_non_neg_even @subs;
        for (my $i = 0; $i < @subs - 1; $i += 2) {
            my ($name, $sub) = @subs[$i, $i+1];
            cluck('sub named "new" is not allowed'), 
                next if $name eq 'new';
            my $fullname = "$class::$name";
            { 
                no strict 'refs';
                *$fullname = $sub;
            }
        }
    }

    # Make this syntax work:
    # $self->_->super('supermethod', arg, arg, ...)
    # Eventually, more things can go in _.
    {
        my $fullname = "$class" . "::_";
        my $sub = sub {
            my ($self) = @_;
            my $anon_object = Fish::Class::Anon->new_obj( 

                # Note, self not passed.
                super => sub { 
                    my ($func_name, @args) = @_;
                    my @isa = do {
                        no strict 'refs';
                        @{$class . "::ISA"}
                    };
                    my $super;
                    for my $is (@isa) {
                        if ($is->can($func_name)) {
                            $super = $is;
                            last;
                        }
                    }
                    ierror "Couldn't resolve supermethod '$func_name' for class $class" unless $super;

                    my $sym_table = symbol_table($super);
                    my %sym_table = %$sym_table;
                    my $glob = $sym_table{$func_name};
                    my $func = *$glob{CODE};
                    $func->($self, @args)
                },
            );

            $anon_object
        };

        # Directly assign to symbol table.
        assign_soft_ref $fullname, $sub;
    }
}

1;
