package CN::DB::Scaffold;
use strict;
use base qw(Combust::RoseDB::Scaffold);

sub db_model_class {
  my ($self, $db) = @_;
  die "unknown database [$db]" unless $db eq 'cnntp';
  "CN::Model";
}

1;
