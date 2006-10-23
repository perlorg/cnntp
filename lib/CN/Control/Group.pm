package CN::Control::Group;
use strict;
use base qw(CN::Control);
use Apache::Constants qw(OK);
use CN::Model;

sub request_setup {
    my $self = shift;
    
    return $self->{setup} if $self->{setup};

    my ($group_name, $year, $month, $article) = 
      ($self->request->uri =~ m!^/group(?:/([^/]+)
                                        /([^/]+)
                                        /([^/]+)
                                        (?:/(\d+))?
                                       )?!x);


    unless ($group_name) {
        ($group_name, $article) = 
            ($self->request->uri =~ m!^/group(?:/([^/]+)
                                              (?:/(\d+))?
                                              )?!x);
    }
    
    return $self->{setup} = { group_name => $group_name || '',
                              year       => $year || 0,
                              month      => $month || 0,
                              article    => $article || 0,
                            };
}

sub render {
    my $self = shift;

    my $req = $self->request_setup;

    my @x = eval { 
        return $self->render_group_list unless $req->{group_name};
        my $group = CN::Model->group->fetch(name => $req->{group_name});
        return 404 unless $group;
        return $self->render_group($group) unless $req->{article};
        return $self->redirect_article($group, $req->{article}) unless $req->{year}; 
        return $self->render_article;
    };
    if ($@) {
        return $self->show_error($@)
    }
    return @x;
}


sub cache_info {
    my $self = shift;
    my $setup = $self->request_setup;
    warn Data::Dumper->Dump([\$setup], [qw(setup)]);
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

sub group {
    my $self = shift;
    return $self->{group} if $self->{group};
    $self->{group} = CN::Model->group->fetch(name => $self->request_setup->{group_name});
}

sub render_group {
    my $self = shift;

    my $group = $self->group;

    my $max = $self->req_param('max') || 0;

    my ($year, $month) = ($self->request_setup->{year}, $self->request_setup->{month});
    warn "YEAR: $year / $month: $month";

    unless ($year) {
        my $newest_article = CN::Model->article->get_articles
            (  query => [ group_id => $group->id, ],
               limit => 1,
               sort_by => 'id desc',
               );
        return 404 unless $newest_article;
        $newest_article = $newest_article->[0];
        ($year, $month) = ($newest_article->received->year, $newest_article->received->month);
    }

    my $month_obj = DateTime->new(year => $year, month => $month, day => 1);
    #$Rose::DB::Object::Manager::Debug = 1;
    my $articles = CN::Model->article->get_articles
        (  query => [ group_id => $group->id,
                      received => { lt => $month_obj->clone->add(months => 1) },
                      received => { gt => $month_obj },
                      ],
           limit => 40,
           group_by => 'thread_id',
           sort_by => 'id desc',
         );

    $self->tpl_param(group => $group);
    $self->tpl_param(articles => $articles);

    return OK, $self->evaluate_template('tpl/article_list.html');
}

sub render_article {
    my $self = shift;

    my $req = $self->request_setup;

    my $article = CN::Model->article->fetch(group_id => $self->group->id,
                                            id       => $req->{article}
                                            );

    # should we just return 404? 
    return $self->redirect_article
        unless $article->received->year == $req->{year}
               and $article->received->month == $req->{month};

    $self->tpl_param('article' => $article);
    $self->tpl_param('group'   => $self->group);

    return OK, $self->evaluate_template('tpl/article.html');

}

sub redirect_article {
    my $self = shift;
    my $req = $self->request_setup;

    my $article = CN::Model->article->fetch(group_id => $self->group->id,
                                            id       => $req->{article}
                                            );
    
    return 404 unless $article;

    return $self->redirect($article->uri);

}

sub show_error {
    my ($self, $msg) = @_;
    $self->tpl_param(msg => $msg);
    $self->r->status(500);
    return OK, $self->evaluate_template('tpl/error.html');
}

sub show_nntp_error { shift->show_error('Could not connect to backend NNTP server; please try again later'); }

1;
