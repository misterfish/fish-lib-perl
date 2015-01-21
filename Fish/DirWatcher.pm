#!/usr/bin/perl

=head

Dirty way to see if dirs change.

=cut

package Fish::DirWatcher;

BEGIN {
    use File::Basename;
    push @INC, dirname $0;
}

use 5.10.0;

use strict;
use warnings;

use Fish::Utility_a;

use Data::Dumper 'Dumper';

use Moose;
use File::Slurp 'write_file', 'read_file';
use File::stat;
use Storable qw/ freeze /;

has path => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

# filename for storing data, given in constructor
has state_file => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

# only look at file entries, not dirs.
has only_files => (
    is          => 'ro',
    isa         => 'Bool',
    default     => 0,
);

# make a temporary cache of mtimes but don't store it in the file.
has make_mtimes_cache => (
    is          => 'ro',
    isa         => 'Bool',
    default     => 0,
);

has _stored_data        => (
    is          => 'rw',
    isa         => 'Str',
    default     => sub {""},
);

has _cur_data        => (
    is          => 'rw',
    isa         => 'Str',
);

has _mtimes_cache => (
    is          => 'rw',
    isa         => 'HashRef',
    default     => sub {{}},
);

$Storable::canonical = 1;

# don't use store and retrieve. just freeze and store it as binary in the
# file.

sub BUILD {
    my ($self, @args) = @_;
    $self->_update;
}

sub _update {
    my ($self) = @_;

    if (-e (my $c = $self->state_file)) {
        my $data = read_file $c, binmode => ':raw';
        $self->_stored_data($data);
    }

    my $cur_data = $self->_get_data;
    $self->_cur_data(freeze $cur_data);

    D2 'cur_data', Dumper($cur_data);
}

# ret -1 if no stored data.
sub changed {
    my ($self) = @_;
    my $data = $self->_stored_data;
    $self->_update;

    return 0 if $self->_cur_data eq $self->_stored_data;
    $self->sync;
    return 1;
}

sub sync {
    my ($self) = @_;
    write_file $self->state_file, { binmode => ':raw' },  $self->_cur_data;
}

sub _get_data {
    my ($self) = @_;
    my %data;

    my $a = $data{mtimes} = [];
    my $of = $self->only_files;
    my $dh = safeopen $self->path, {dir => 1};

    # is readdir order always guaranteed? XX
    for (readdir $dh) {
        next if /^\./;
        my $f = sprintf "%s/%s", $self->path, $_;
        next if $of and -d $f;
        my $mt = $self->_mtime($f) or next;
        $self->_store_mtime($_, $mt) if $self->make_mtimes_cache;
        push @$a, $mt;
    }
    return \%data;
}

sub _mtime {
    my ($self, $f) = @_;
    # broken links for example
    return -e $f ? (stat $f)->mtime : undef;
}

sub _store_mtime {
    my ($self, $file, $mtime) = @_;
    my $f = $self->path . "/$file";
    $self->_mtimes_cache->{$f} = $mtime;
}

sub get_mtimes {
    my ($self) = @_;
    $self->make_mtimes_cache or 
        error "Can't call", BR 'get_mtimes', "unless", Y 'make_mtimes_cache', "is true.\n";

    return $self->_mtimes_cache;
}


1;
