package Fish::Sq;

=head

Author: Allen Haim <allen@netherrealm.net>, © 2015.
Source: github.com/misterfish/fish-lib-perl
Licence: GPL 2.0

Convenient OO interface for sqlite3 databases.

Knows about transactions, can clean up after itself, allows
logging of sql, etc.

RaiseError and PrintError are true by default.

This module will steal Ctl-c and has special exit routines.

=cut

use 5.18.0;

use Moose;

use DBI;
use Data::Dumper 'Dumper';

use Fish::Utility qw, sys sys_ok shell_quote iwar war R G BR BB e8 d8 ,;

# - - - - Static.

my @Status;

# means ctrl-c or similar.
my $Panic = 0;

# - - - - Constants.

my $TRANSACTION_LENGTH = 10000;
my @SPIN = qw( | / - \ );

has dbh => (
    is => 'ro',
    writer => 'set_dbh',
    isa => 'DBI::db',
);

# not counting select
has _num_updates => (
    is  => 'rw',
    isa => 'Int',
    traits      => ['Counter'],
    handles     => {
        _num_updates_inc => 'inc',
        _num_updates_dec => 'dec',
    },
    default => 0,
);

# - - - Constructor:

has file => (
    is => 'ro',
    isa => 'Str',
);

has ro => ( # Complain if it doesn't exist (don't create).
    is  => 'ro',
    isa => 'Bool',
);

has print_error => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
);

has raise_error => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
);

has auto_commit => (
    is  => 'ro',
    isa => 'Bool',
);

has force_cleanup => (
    is  => 'ro',
    isa => 'Bool',
    default => 0,
);

# Print progress msgs, etc., to stderr.
has verbose => (
    is  => 'ro',
    isa => 'Bool',
    default => 0,
);

has verbose_kill_newlines => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has chmod => (
    is  => 'ro',
    isa => 'Str',
);

# - - - - - / Constructor

# - - - Public get, private set.

has status => (
    is => 'ro',
    isa => 'HashRef',
    writer => 'set_status',
);

# internal, for referencing static @Status ary, not currently necessary.
has _idx => (
    is => 'ro',
    isa => 'Int',
    traits      => ['Counter'],
    handles     => {
        _idx_inc => 'inc',
        _idx_dec => 'dec',
    },
    default => -1,
);

has build_error => (
    is => 'ro',
    writer => '_set_build_error',
    isa => 'Bool',
);

has _has_stdout => (
    is  => 'rw',
    isa => 'Bool',
);

sub BUILD {
    my ($self) = @_;
    my $file = $self->file;

    if (not -e $file) {
        my $err;
        if ($self->ro) {
            war "File", BR $file, "doesn't exist and 'ro' flag was given -> sq undefined.";
            $err = 1;
        }
        if (not sys_ok sprintf qq, touch %s ,, shell_quote $file) {
            war "File", BR $file, "doesn't exist and unable to create it.";
            $err = 1;
        }
        if ($err) {
            $self->_set_build_error(1);
            return;
        }
    }

    $self->_has_stdout( -t STDOUT );

    # Turn to 0 to enable transactions -- huge speed increase on writes.
    # Note that begin_work is not necessary.
    # Keep them off to hopefully avoid locking issues if we're only going to
    # read.

    my $auto_commit = $self->auto_commit // $self->ro // 0;

    my $dbh = DBI->connect(
        "dbi:SQLite:dbname=$file",

        # no username and pass with sqlite
        '',
        '',

        {  
            # Perl strings retrieved from DB will contain chars.
            sqlite_unicode => 1,

            AutoCommit  =>  $auto_commit,

            PrintError  =>  $self->print_error,
            RaiseError  =>  $self->raise_error,
        }
    );

    if (my $ch = $self->chmod) {
        sys_ok qq, chmod $ch "$file",, { die => 0 } or
            war sprintf "Couldn't set requested permissions (%s)", BR $ch;
    }

    $self->set_dbh($dbh);

    # Two steps to enhance performance supposedly, but don't see any
    # difference.  
    # $dbh->do('PRAGMA cache_size = 500000');
    # $dbh->do('PRAGMA synchronous=OFF');

    my $status = {
        dbh => $dbh,
        committing => 0,
        dirty => 0,
    };

    # Not bothering with taking them out ever on destruction so push is
    # fine.
    push @Status, $status;
    $self->set_status($status);

    if ($self->force_cleanup) {
        # Force END and DEMOLISH on Ctrl-c
        $SIG{KILL} = $SIG{INT} = sub { 
            $Panic = 1;
            exit 1;
        };
    }
}

sub add_column {
    my ($self, $table, $column_def) = @_;
    $self->do("alter table $table add column $column_def");
    return iwar if $self->error;

    1
}

sub add_index {
    # index name doesn't matter actually -- but it can't be the same as the
    # table.
    my ($self, $table, $index_name, $indexed_column, $opt) = @_;
    $opt //= {};
    my $i = $opt->{unique} ? 'unique index' : 'index';
    $self->do(sprintf "create $i%s$index_name on $table($indexed_column)", $opt->{if_not_exists} ? ' if not exists ' : '');
    return iwar if $self->error;

    1
}

sub add_table {
    my ($self, $table, $def, $opt) = @_;
    $opt //= {};
    $def = join ', ', @$def if ref $def eq 'ARRAY';
    $self->do(sprintf "create table%s $table (%s)", $opt->{if_not_exists} ? ' if not exists' : '', $def);
    return iwar if $self->error;

    1
}

sub drop_table {
    my ($self, $table) = @_;
    $self->do("drop table $table");
    return iwar if $self->error;

    1
}

# For inserting etc., use execute.
sub do {
    my $self = shift;
    my $s = shift or 
        return iwar("Bad args to do() (Sq)");

    $self->status->{dirty} = 1 if ! $self->auto_commit;

    my $msg = '';
    if ($self->verbose) {
        $msg = $self->sql_msg($s);
    }
    $self->prog($msg);

    $self->dbh->do($s);
    return iwar if $self->error;

    1
}

# Show progress (if verbose), AND commit if enough statements have come through.
sub prog {
    my ($self, $prog_msg) = @_;

    return unless $self->_has_stdout;

    $self->_num_updates_inc;

    my $n = $self->_num_updates;

    if ($self->verbose) {
        my $s = $SPIN[$n % @SPIN];
        print "\r";
        printf "%s [ %s ] ", $s, BB $n;
        say e8 $prog_msg if $prog_msg;
    }

    $self->commit if not $n % $TRANSACTION_LENGTH;
}

# Not intended for select statements.
sub execute {
    my ($self, $sql, @bind) = @_;
    my $sth = $self->dbh->prepare($sql);

    war(sprintf "Refusing to execute -- ro is set (sql: %s)", BR $sql), 
        return if $self->ro;

    my $dbh = $self->dbh;

    $self->status->{dirty} = 1 if ! $self->auto_commit;
    $sth->execute(@bind);
    return iwar if $self->error;

    my $msg = '';
    $msg = $self->sql_msg($sql) . ' / ' . join '|', @bind if $self->verbose;
    $self->prog($msg);

    1
}

sub get {
    my ($self, $sql, @bind) = @_;
    if ($self->verbose) {
        my $sql_print = $sql;
        $sql_print =~ s/\n/ /g if $self->verbose_kill_newlines;
        war 'sql', $sql_print, 'bind', join '|', @bind;
    }
    my $sth = $self->dbh->prepare($sql);
    return iwar if $self->error;
    $sth->execute(@bind);
    return iwar if $self->error;

    my $res = $sth->fetchall_arrayref;
    return iwar if $self->error;

    war '# results', scalar @$res if $self->verbose;

    $res
}

sub commit {
    my ($self) = @_;

    return if $self->auto_commit;

    my $dbh = $self->dbh;
    
    $self->status->{committing} = 1;

    my $ok = 1;

    eval { $self->dbh->commit } or do {
        iwar "Couldn't commit";
        iwar $self->dbh->errstr;
        iwar $@ if $@;
        $self->rollback;

        $ok = 0;
    };

    $self->status->{committing} = 0;
    $self->status->{dirty} = 0;

    $ok
}

sub rollback {
    my ($self) = @_;
    war "Rolling back and quitting.";
    $self->dbh->rollback;
    return iwar "Couldn't roll back:", $self->dbh->errstr if $self->error;

    1
    ### quits everything
    ##exit 1;
}

sub has_column {
    my ($self, $table, $column) = @_;
    return $self->_has_thing($table, $column, 'column');
}

sub has_index {
    my ($self, $table, $index) = @_;
    return $self->_has_thing($table, $index, 'index');
}

sub has_table {
    my ($self, $table) = @_;
    return $self->_has_thing($table, undef, 'table');
}

sub last_id {
    my ($self) = @_;
    my $id = $self->dbh->func('last_insert_rowid') or war "Couldn't get last insert row id";
    $id;
}

sub sql_msg {
    my ($self, $sql) = @_;
    $sql =~ s/\n/ /g if $self->verbose_kill_newlines;
    return G ("*sql ") . $sql;
}

# undef means error
# otherwise 0 or 1
sub _has_thing {
    # what = index / column
    my ($self, $table, $thing_name, $what) = @_;

    $what eq 'index' or $what eq 'column' or $what eq 'table' or 
        return iwar;

    # catalog, schema, table, type
    # schema is main ??
    my $sth = $self->dbh->table_info('', 'main', $table);
    return iwar if $self->error;
    my $res = $self->dbh->selectall_arrayref($sth);
    return iwar if $self->error or not $res;

    for (@$res) {
        my (undef, $schema, $_table, $_thing, undef, $create) = @$_;
        if ($table eq $_table) {
            if ($what eq 'index' and $_thing eq 'INDEX') {
                return 1 if $create =~ m,^create (unique )?index $thing_name on $table,i;
            }
            elsif ($what eq 'column' and $_thing eq 'TABLE') {
                $create =~ m,^create table $table \((.+)\),i or 
                    return iwar;
                my @s = split ',', $1;
                m, ^ \s* $thing_name ,x and 
                    return 1 for @s;
            }
            elsif ($what eq 'table') {
                return 1;
            }
        }
    }

    0
}

# Check for error. 
# err is set to undef by DBI before almost every call.
# undefined means ok.
# false means warning, or 'success with information'.
# true means error.
sub error {
    my ($self) = @_;

    defined $self->dbh->err
}


# - - - - Cleanup

# END happens before objects are demolished, so we can do cleanup here.
# But then there's no $self context any more so we have to use static
# globals.

END {

    say '';

    if ($Panic) {
        war 'Interrupted -- trying to clean up.';

        my $ok = 1;

        my $dirty = 0;

        for my $s (@Status) {

            my $c = $s->{committing};
            my $d = $s->{dirty};
            my $dbh = $s->{dbh};

            $d and $dirty++;
 
            if ($c) {
                war 'Interrupted while committing, rolling back.';
                $dbh->rollback and war "Rollback ok." or war("Couldn't roll back"), $ok = 0;
            }

            $dbh->disconnect;
        }

        $dirty and war 'Interrupted with unsaved operations in', R $dirty, 'handle', ($dirty == 1 ? '' : 's');

        $ok = 0 if $dirty;

        $ok and war 'Ok.';

    }

    # Normal ending, commit last transactions.
    else {
        for my $s (@Status) {

            my $c = $s->{committing};
            my $d = $s->{dirty};
            my $dbh = $s->{dbh};

            # Shouldn't happen.
            if ($c) {
                war "Something's wrong -- object destroyed while committing, trying to roll back.";
                $dbh->rollback and war "Rollback ok." or war "Couldn't do rollback.";
                exit 1;
            }

            # This is normal -- save last things.
            $dbh->commit if $d;

            $dbh->disconnect;
        }
    }
}

# Can't do cleanup here -- handles might have already been destroyed. See END.
sub DEMOLISH {
    my ($self) = @_;
}

1;
