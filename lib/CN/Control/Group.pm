package CN::Control::Group;
use strict;
use base qw(CN::Control);
use Apache::Constants qw(OK);
use CN::Model;

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
        my $group = CN::Model->group->fetch(name => $group_name);
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
    return {};
    return {} if $setup->{msg};
    return {} if $setup->{group_name};

    return { type => 'nntp_group',
             id   => $setup->{group_name} || '_group_list_',
           };
}

sub render_group_list {
    my $self = shift;
    my $groups = CN::Model->group->get_groups;
    $self->tpl_param('groups', $groups); 
    return OK, $self->evaluate_template('tpl/group_list.html');
}

sub render_group {
    my $self = shift;

    my $group = CN::Model->group->fetch(name => $self->request_setup->{group_name});

    my $max = $self->req_param('max') || 0;

    my $articles = CN::Model->header->get_headers
        (  query => [ grp => $group->id, ],
           limit => 40,
           sort_by => 'art desc',
         );

    $self->tpl_param(group => $group);
    $self->tpl_param(articles => $articles);

    return OK, $self->evaluate_template('tpl/article_list.html');
}


sub show_error {
    my ($self, $msg) = @_;
    $self->tpl_param(msg => $msg);
    $self->r->status(500);
    return OK, $self->evaluate_template('tpl/error.html');
}

sub show_nntp_error { shift->show_error('Could not connect to backend NNTP server; please try again later'); }

1;
