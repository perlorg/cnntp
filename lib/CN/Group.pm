package CN::Group;
use strict;
use CN;

sub new {
    my ($class, $group) = @_;
    return bless { name => $group }, $class;
}

# select count(*) from header where grp = 60 and received > DATE_SUB(NOW(), INTERVAL 56 DAY);

sub name {
    my $self = shift;
    $self->{name};
}

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
