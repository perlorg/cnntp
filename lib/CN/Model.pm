package CN::Model;
##
## This file is auto-generated *** DO NOT EDIT ***
##
use CN::DB::Object;
use CN::DB::Manager;

our $SVN = q$Id$;

{ package CN::Model::Group;

use strict;

use base qw(CN::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'groups',

  columns => [
    id   => { type => 'integer', not_null => 1 },
    name => { type => 'varchar', default => '', length => 255, not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  unique_key => [ 'name' ],

  relationships => [
    header => {
      class      => 'CN::Model::Header',
      column_map => { id => 'grp' },
      type       => 'one to many',
    },
  ],
);
}

{ package CN::Model::Group::Manager;

use CN::DB::Manager;
our @ISA = qw(CN::DB::Manager);

sub object_class { 'CN::Model::Group' }

__PACKAGE__->make_manager_methods('groups');
}

# Allow user defined methods to be added
eval { require CN::Model::Group }
  or $@ !~ m:^Can't locate CN/Model/Group.pm: and die $@;

{ package CN::Model::Header;

use strict;

use base qw(CN::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'header',

  columns => [
    grp          => { type => 'integer', not_null => 1 },
    art          => { type => 'integer', not_null => 1 },
    msgid        => { type => 'varchar', default => '', length => 32, not_null => 1 },
    subjhash     => { type => 'varchar', default => '', length => 32, not_null => 1 },
    fromhash     => { type => 'varchar', default => '', length => 32, not_null => 1 },
    thread       => { type => 'integer', default => '0', not_null => 1 },
    parent       => { type => 'integer', default => '0', not_null => 1 },
    received     => { type => 'datetime', default => '0000-00-00 00:00:00', not_null => 1 },
    h_date       => { type => 'varchar', default => '', length => 255, not_null => 1 },
    h_messageid  => { type => 'varchar', default => '', length => 255, not_null => 1 },
    h_from       => { type => 'varchar', default => '', length => 255, not_null => 1 },
    h_subject    => { type => 'varchar', default => '', length => 255, not_null => 1 },
    h_references => { type => 'varchar', default => '', length => 255, not_null => 1 },
    h_lines      => { type => 'scalar', default => '0', length => 8, not_null => 1 },
    h_bytes      => { type => 'integer', default => '0', not_null => 1 },
  ],

  primary_key_columns => [ 'grp', 'art' ],

  foreign_keys => [
    group => {
      class       => 'CN::Model::Group',
      key_columns => { grp => 'id' },
    },
  ],
);
}

{ package CN::Model::Header::Manager;

use CN::DB::Manager;
our @ISA = qw(CN::DB::Manager);

sub object_class { 'CN::Model::Header' }

__PACKAGE__->make_manager_methods('headers');
}

# Allow user defined methods to be added
eval { require CN::Model::Header }
  or $@ !~ m:^Can't locate CN/Model/Header.pm: and die $@;

{ package CN::Model;

  sub dbh { shift; CN::DB::Object->init_db(@_)->dbh; }
  sub db  { shift; CN::DB::Object->init_db(@_);      }

  my @classes = qw(
    CN::Model::Group
    CN::Model::Header
    );
  sub flush_caches {
    $_->meta->clear_object_cache for @classes;
  }

  my $group;
  sub group { $group ||= bless [], 'CN::Model::Group::Manager' }
  my $header;
  sub header { $header ||= bless [], 'CN::Model::Header::Manager' }

}
1;
