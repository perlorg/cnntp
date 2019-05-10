package CN::Control::Health;
use strict;
use base qw(CN::Control);
use Combust::Constant qw(OK);
use CN::Model ();

sub render {
    my $self = shift;

    my $dbh = CN::Model->dbh();

    $self->content_type('text/plain');
    $self->no_cache(1);

    unless ($dbh->ping) {
        warn "Could not ping database...";
        return 500, "db ping\n";
    }

    return OK, "All ok\n";
}

1;
