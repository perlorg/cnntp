package CN::Model;
##
## This file is auto-generated *** DO NOT EDIT ***
##
use Combust::RoseDB;
use Combust::RoseDB::Manager;

our @table_classes;

BEGIN {
  package CN::Model::_Meta;
  use base qw(Combust::RoseDB::Metadata);
  use Combust::RoseDB::ConventionManager;
  our $VERSION = 0;

  sub registry_key { __PACKAGE__ }
  sub init_convention_manager { Combust::RoseDB::ConventionManager->new }

  # Always quote table names to handle MySQL 8 reserved words (e.g. "groups")
  sub fq_table_sql {
    my($self, $db) = @_;
    return $self->{'fq_table_sql'}{$db->{'id'}} ||=
      join('.', grep { defined } ($self->select_catalog($db),
                                  $self->select_schema($db),
                                  $db->quote_table_name($self->table)));
  }
}
BEGIN {
  package CN::Model::_Base;
  use base qw(Combust::RoseDB::Object Combust::RoseDB::Object::toJson);
  our $VERSION = 0;

  sub init_db       { shift; Combust::RoseDB->new_or_cached(@_, type => 'cnntp', combust_model => "CN::Model") }
  sub meta_class    {'CN::Model::_Meta'}
  sub combust_model { our $model ||= bless [], 'CN::Model'}
}
BEGIN {
  package CN::Model::_Object;
  use base qw(CN::Model::_Base Rose::DB::Object);
  our $VERSION = 0;
}
BEGIN {
  package CN::Model::_Object::Cached;
  use base qw(CN::Model::_Base Rose::DB::Object::Cached);
  our $VERSION = 0;
}

{ package CN::Model::Article;

use strict;

use base qw(CN::Model::_Object);

__PACKAGE__->meta->setup(
  table   => 'articles',

  columns => [
    group_id     => { type => 'integer', not_null => 1 },
    id           => { type => 'integer', not_null => 1 },
    msgid        => { type => 'varchar', default => '', length => 32, not_null => 1 },
    subjhash     => { type => 'varchar', default => '', length => 32, not_null => 1 },
    fromhash     => { type => 'varchar', default => '', length => 32, not_null => 1 },
    thread_id    => { type => 'integer', default => '0', not_null => 1 },
    parent       => { type => 'integer', default => '0', not_null => 1 },
    received     => { type => 'datetime', not_null => 1 },
    h_date       => { type => 'varchar', default => '', length => 255, not_null => 1 },
    h_messageid  => { type => 'varchar', default => '', length => 255, not_null => 1 },
    h_from       => { type => 'varchar', default => '', length => 255, not_null => 1 },
    h_subject    => { type => 'varchar', default => '', length => 255, not_null => 1 },
    h_references => { type => 'varchar', default => '', length => 2048, not_null => 1 },
    h_lines      => { type => 'integer', default => '0', not_null => 1 },
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

push @table_classes, __PACKAGE__;
}

{ package CN::Model::Article::Manager;

use strict;

our @ISA = qw(Combust::RoseDB::Manager);

sub object_class { 'CN::Model::Article' }

__PACKAGE__->make_manager_methods('articles');
}

# Allow user defined methods to be added
eval { require CN::Model::Article }
  or $@ !~ m:^Can't locate CN/Model/Article.pm: and die $@;

{ package CN::Model::Group;

use strict;

use base qw(CN::Model::_Object);

__PACKAGE__->meta->setup(
  table   => 'groups',

  columns => [
    id          => { type => 'integer', not_null => 1 },
    name        => { type => 'varchar', length => 255, not_null => 1 },
    description => { type => 'varchar', length => 255, not_null => 1 },
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

push @table_classes, __PACKAGE__;
}

{ package CN::Model::Group::Manager;

use strict;

our @ISA = qw(Combust::RoseDB::Manager);

sub object_class { 'CN::Model::Group' }

__PACKAGE__->make_manager_methods('groups');
}

# Allow user defined methods to be added
eval { require CN::Model::Group }
  or $@ !~ m:^Can't locate CN/Model/Group.pm: and die $@;

{ package CN::Model::SchemaRevision;

use strict;

use base qw(CN::Model::_Object);

__PACKAGE__->meta->setup(
  table   => 'schema_revision',

  columns => [
    revision    => { type => 'integer', default => '0', not_null => 1 },
    schema_name => { type => 'varchar', length => 30, not_null => 1 },
  ],

  primary_key_columns => [ 'schema_name' ],
);

push @table_classes, __PACKAGE__;
}

{ package CN::Model::SchemaRevision::Manager;

use strict;

our @ISA = qw(Combust::RoseDB::Manager);

sub object_class { 'CN::Model::SchemaRevision' }

__PACKAGE__->make_manager_methods('schema_revisions');
}

# Allow user defined methods to be added
eval { require CN::Model::SchemaRevision }
  or $@ !~ m:^Can't locate CN/Model/SchemaRevision.pm: and die $@;
{ package CN::Model;

  sub db  { shift; CN::Model::_Object->init_db(@_);      }
  sub dbh { shift->db->dbh; }

  my @cache_classes = grep { $_->can('clear_object_cache') } @table_classes;
  sub flush_caches {
    $_->clear_object_cache for @cache_classes;
  }

  sub article { our $article ||= bless [], 'CN::Model::Article::Manager' }
  sub group { our $group ||= bless [], 'CN::Model::Group::Manager' }
  sub schema_revision { our $schema_revision ||= bless [], 'CN::Model::SchemaRevision::Manager' }

}
1;
