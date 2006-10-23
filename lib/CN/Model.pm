package CN::Model;
##
## This file is auto-generated *** DO NOT EDIT ***
##
use CN::DB::Object;
use CN::DB::Manager;

our $SVN = q$Id$;

{ package CN::Model::Article;

use strict;

use base qw(CN::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'articles',

  columns => [
    group_id     => { type => 'integer', not_null => 1 },
    id           => { type => 'integer', not_null => 1 },
    msgid        => { type => 'varchar', default => '', length => 32, not_null => 1 },
    subjhash     => { type => 'varchar', default => '', length => 32, not_null => 1 },
    fromhash     => { type => 'varchar', default => '', length => 32, not_null => 1 },
    thread_id    => { type => 'integer', default => '', not_null => 1 },
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

  primary_key_columns => [ 'group_id', 'id' ],

  foreign_keys => [
    group => {
      class       => 'CN::Model::Group',
      key_columns => { group_id => 'id' },
    },
  ],
);
}

{ package CN::Model::Article::Manager;

use CN::DB::Manager;
our @ISA = qw(CN::DB::Manager);

sub object_class { 'CN::Model::Article' }

__PACKAGE__->make_manager_methods('articles');
}

# Allow user defined methods to be added
eval { require CN::Model::Article }
  or $@ !~ m:^Can't locate CN/Model/Article.pm: and die $@;

{ package CN::Model::Group;

use strict;

use base qw(CN::DB::Object::Cached);

__PACKAGE__->meta->setup(
  table   => 'groups',

  columns => [
    id   => { type => 'integer', not_null => 1 },
    name => { type => 'varchar', default => '', length => 255, not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  unique_key => [ 'name' ],

  relationships => [
    articles => {
      class      => 'CN::Model::Article',
      column_map => { id => 'group_id' },
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

{ package CN::Model;

  sub dbh { shift; CN::DB::Object->init_db(@_)->dbh; }
  sub db  { shift; CN::DB::Object->init_db(@_);      }

  my @classes = qw(
    CN::Model::Article
    CN::Model::Group
    );
  sub flush_caches {
    $_->meta->clear_object_cache for @classes;
  }

  my $article;
  sub article { $article ||= bless [], 'CN::Model::Article::Manager' }
  my $group;
  sub group { $group ||= bless [], 'CN::Model::Group::Manager' }

}
1;
