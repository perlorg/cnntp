package CN::Model::Group;
use strict;

# select count(*) from header where grp = 60 and received > DATE_SUB(NOW(), INTERVAL 56 DAY);

sub uri {
    my $self = shift;
    join "/", '', 'group', $self->name;
}

sub list {
    my $nntp = CN->nntp;
    die "No NNTP server\n" unless $nntp;

    my $groups = $nntp->list;
    #warn Data::Dumper->Dump([\$groups], [qw(groups)]);
    my @g;
    push @g, __PACKAGE__->new($_) for sort keys %$groups;
    @g;
}


1;
