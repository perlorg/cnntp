package CN::Control::Group;
use strict;
use base qw(CN::Control);
use Apache::Constants qw(OK);
use CN::Group;

sub request_setup {
    my $self = shift;
    
    return $self->{setup} if $self->{setup};

    my ($group_name, $msg) = 
      ($self->request->uri =~ m!^/group(?:/([^/]+)
                                        (?:/(\d+))?
                                       )?!x);

    return $self->{setup} = { group_name => $group_name || '',
                              msg        => $msg || 0,
                            };
}

sub render {
    my $self = shift;

    my $setup = $self->request_setup;
    my ($group_name, $msg) = ($setup->{group_name}, $setup->{msg});

    my @x = eval { 
        return $self->render_group_list unless $group_name;
        my $group = CN::Group->new($group_name);
        return $self->render_group($group) unless $msg;
        return $self->render_msg($group, $msg);
    };
    if ($@) {
        return $self->show_error($@)
    }
    return @x;
}


sub cache_info {
    my $self = shift;
    my $setup = $self->request_setup;
    return {} if $setup->{msg};
    return {} if $setup->{group_name};

    return { type => 'nntp_group',
             id   => $setup->{group_name} || '_group_list_',
           };
}

sub render_group_list {
    my $self = shift;
    my @groups = CN::Group->list;
    $self->tpl_param('groups', \@groups); 
    return OK, $self->evaluate_template('tpl/group_list.html');
}

sub render_group {
    return OK, 
}


sub show_error {
    my ($self, $msg) = @_;
    $self->tpl_param(msg => $msg);
    return OK, $self->evaluate_template('tpl/error.html');

}

sub show_nntp_error { shift->show_error('Could not connect to backend NNTP server; please try again later'); }

1;
