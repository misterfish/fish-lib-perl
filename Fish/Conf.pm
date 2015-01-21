#!/usr/bin/env perl 

package Fish::Conf;

use 5.20.0;

BEGIN {
    use File::Basename;
    push @INC, dirname $0;
}

use Moo;
use MooX::Types::MooseLike::Base ':all';

use Cwd 'realpath';
use File::stat;
use Config::IniFiles;

use Fish::Conf::Listener;

use Fish::Utility;
use Fish::Utility_l 'chompp', 'list', 'def';
use Fish::Class 'o';

use constant DO_CACHE => 0;

has conf_files => (
    is => 'ro',
    isa => ArrayRef,
    required => 1,
);

has required => (
    is => 'ro',
    isa => ArrayRef,
);

has default_block => (
    is => 'rw',
    isa => Str,
);

has quiet => (
    is => 'rw',
    isa => Bool,
);

has _conf_files_ok => (
    is => 'rw',
    isa => ArrayRef,
);

has _conf_files_rejected => (
    is => 'rw',
    isa => ArrayRef,
);

has _config => (
    is => 'rw',
    isa => sub { ierror unless ref $_[0] eq 'Config::IniFiles' },
);

# For c and cr.
has _cache1 => (
    is => 'rw',
    isa => HashRef,
);

# For cr_list. 
has _cache2 => (
    is => 'rw',
    isa => HashRef,
);

has _last_read_mtime => (
    is => 'rw',
    isa => HashRef,
    default => sub {{}},
);

has _listener => (
    is => 'rw',
);

# - -
# syntactic sugar for required keys
has _cr => (
    is => 'rw',
);

has _cr_list => (
    is => 'rw',
);
# - -

my $DEFAULT_BLOCK = '_default';

sub BUILD {
    my ($self) = @_;

    my ($ok, $not_ok) = $self->_check_files;
    my @ok_conf_files = @$ok;
    my @not_ok_conf_files = @$not_ok;

    $self->default_block($DEFAULT_BLOCK) unless $self->default_block;

    $self->_conf_files_ok(\@ok_conf_files);
    $self->_conf_files_rejected(\@not_ok_conf_files);

    $self->_listener(
        Fish::Conf::Listener->new(
            master => $self,
        )
    );

    $self->update_config;

}

sub _init_cfg {
    my ($self, $cf, $opts) = @_;
    $opts //= {};
    my @overlay;
    @overlay = (-import => $opts->{base}) if $opts->{base};

    my $cfg = Config::IniFiles->new( 
        -file => $cf,
        -default => $self->default_block,
        -handle_trailing_comment => 1,
        @overlay,
    ) 
        or error sprintf "Couldn't parse config file (%s), does it have a default block ([%s])?", BR $cf, Y $self->default_block;
    
    $cfg
}

sub _check_files {
    my ($self) = @_;
    my @files = list $self->conf_files;
    my @ok;
    my @not_ok;
    for my $f (@files) {
        if (not -f $f) { 
            war 'File', BR $f, "doesn't exist";
            push @not_ok, $f;
            next;
        }
        if (not -r $f) {
            war 'File', BR $f, "not readable";
            push @not_ok, $f;
            next;
        }
        push @ok, $f;
    }
    @ok or error "Couldn't find usable config.";
    return \@ok, \@not_ok;
}

sub _c {
    my ($self, $k, $required, $opt) = @_;
    $k // ierror;

    $opt //= {};
    my $type = $opt->{type};
    my $v;

    my $cache;
    if (DO_CACHE) {
        $cache = $self->_cache1;
        return $v if def $v = $cache->{$k};
    }
   
    $v = $self->_config->val($self->default_block, $k);

    if ($required and not defined $v) {
        my @ok_cf = list $self->_conf_files_ok;
        my @not_ok_cf = list $self->_conf_files_rejected;
        @ok_cf = map { G $_ } @ok_cf;
        @not_ok_cf = map { BR $_ } @not_ok_cf;
        my @all_cf = (@ok_cf, @not_ok_cf);
        my $s = @all_cf > 1 ? 'conf files were' : "conf file is";
        error sprintf "Config key %s is required (%s %s)", R $k, $s, join ', ', @all_cf;
    }

    return unless $v;

    # value given multiple times should override, not get a \n in the middle.
    $v = (split /\n/, $v)[-1]; 
    strip_s $v;

    # Bool is a coderef provided by MooX. 
    if ($type and $type == Bool) {
        $v = $v eq 'false' ? 0 :
            $v eq 'true' ? 1 :
            $v;
    }

    $cache->{$k} = $v if DO_CACHE;

    $v
}

sub _c_list {
    my ($self, $key, $required) = @_;
    my $method = $required ? 'cr' : 'c';

    if (DO_CACHE) {
        my $cache = $self->_cache2;
        return $cache->{$key} // 
            ($cache->{$key} = [split / \s* , \s* /x, $self->$method($key)]);
    }
    else {
        my $val = $self->$method($key);
        return $val ? [split / \s* , \s* /x, $val] : [];
    }
}

# Check that required keys are there.
# Also, make the cr-> syntactic sugar on required keys.
# Not sure if the cr-> syntax is even necessary. XX

sub _check_required_and_update_cr {
    my ($self) = @_;
    my $required = $self->required;

    #state $i = 0;

    ### Dynamically generate private classes.
    #my $cr_class = sprintf "Fish::Conf::priv.%d" . $i++;
    #class $cr_class, $required;

    my $cr_obj_normal = o(
        map { $_ => $self->cr($_) } @$required
    );

    my $cr_obj_list = o(
        map { $_ => $self->cr_list($_) } @$required
    );

    #my $cr_obj_normal = $cr_class->new;
    #my $cr_obj_list = $cr_class->new;

    #for my $k (@$required) {
    #$cr_obj_normal->$k($self->cr($k)) ;
    #$cr_obj_list->$k($self->cr_list($k)) ;
    #}

    $self->_cr($cr_obj_normal);
    $self->_cr_list($cr_obj_list);
}

sub _info {
    my ($self, @s) = @_;
    return if $self->quiet;
    # info(@s) won't work because of prototype.
    #shift; &info
    info(shift @s, @s);
}

# - - -  Public

# Check timestamps for changes. 
# If any, clear the whole cache and reload the
# whole config.
# Call any registered listeners when properties are changed.
sub update_config {
    my ($self) = @_;

    my $cf = $self->_conf_files_ok;
    
    my $changed;
    for my $cf (@$cf) {
        # In the instant that it's being saved, file is not there.
        my $stat = stat $cf or 
            next;

        my $stamp = $self->_last_read_mtime->{$cf};
        next if defined $stamp and $stat->mtime <= $stamp;
        $self->_last_read_mtime->{$cf} = $stat->mtime;
        $changed = 1;
    }

    return unless $changed;

    %$_ = () for $self->_cache1, $self->_cache2;

    state $first = 1;
    my $oldcfg;
    if ($first) {
        $first = 0;
    }
    else {
        $oldcfg = $self->_config;
        $self->_info('Updating config.');
    }

    my @c = @$cf;
    my $cfg = $self->_init_cfg(shift @c);
    for (@c) {
        my $cfg_overlay = $self->_init_cfg($_);
        my $cfg_mixed = $self->_init_cfg($_, { base => $cfg });
        $cfg = $cfg_mixed;
    }

    $self->_config($cfg);

    my @changed;

    # compare.
    if ($oldcfg) {
        my $def = $self->default_block;
        for my $key ($oldcfg->Parameters($def)) {
            my $oldexists = $oldcfg->exists($def, $key);
            my $newexists = $cfg->exists($def, $key);
            my $oldval = $oldcfg->val($def, $key);
            my $newval = $cfg->val($def, $key);
            my $changed = 0;
            if ($oldexists == $newexists) {
                if ($oldexists == 1) {
                    $changed = 1 unless $oldval eq $newval;
                }
            }
            else {
                $changed = 1;
            }
            #push @changed, $self->e2i($key) if $changed; 
            push @changed, $key if $changed; 
        }

    }

    $self->_check_required_and_update_cr;

    $self->_listener->fire('changed', @changed) if @changed;
}

# e.g. $conf->c('key')
sub c(_) {
    shift->_c(shift, 0)
}

# same as c, but parse 'true' and 'false'
sub cb(_) {
    shift->_c(shift, 0, { type => Bool })
}

# e.g. $conf->cr('key') or $conf->cr->key
# config, required=1
sub cr(_) {
    my ($self, $key) = @_;
    if (not defined $key) {
        return $self->_cr;
    }

    $self->_c($key, 1)
}

# e.g. list $conf->c_list('key')
# config, required=0, split list value on commas
sub c_list($) {
    shift->_c_list(shift, 0)
}

# synonym for c_list
sub cl($) {
    shift->c_list(shift)
}

# e.g. list $conf->cr_list('key')
# config, required=1, split list value on commas
sub cr_list($) {
    my ($self, $key) = @_;
    if (not defined $key) {
        return $self->_cr_list;
    }

    $self->_c_list($key, 1)
}

# synonym for cr_list
sub crl($) {
    shift->cr_list(shift)
}

# userdata is optional.
sub add_listener {
    my ($self, $type, $properties, $sub, $userdata) = @_;
    ierror 'Need type' unless $type;
    ierror 'Need properties' unless $properties;
    ierror 'Need property' unless $properties->{property};
    ierror 'Need sub' unless $sub;

    if ($type eq 'changed') {
        #$self->e2i_s($properties->{property});
        $self->_listener->add($type, $properties, $sub, $userdata);
    }
    else {
        wartrace "Type", BR $type, "not implemented";
    }
}

# external to internal: config-key -> config_key
# internal to external not provided, probably not useful since not 1 to 1.
sub e2i {
    my ($self, $s) = @_;
    $s =~ s, - ,_,gx;

    $s
}

sub e2i_s {
    my ($self, $s) = @_;
    $s = $self->e2i($s);
    $_[1] = $s;
}

1;


