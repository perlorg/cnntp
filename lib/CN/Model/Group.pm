package CN::Model::Group;
use strict;
use Combust::Cache;

# select count(*) from header where grp = 60 and received > DATE_SUB(NOW(), INTERVAL 56 DAY);

my $cache = Combust::Cache->new(type => 'group_info', backend => 'memcached');

sub uri {
    my $self = shift;
    my $file = shift;
    my $args = {};
    if (ref $file eq 'HASH') {
        $args = $file;
        $file = undef;
    }
    if (ref $file and $file->isa('DateTime')) {
	$args->{month} = $file;
	$file = undef;
    }
    my $url = join "/", '', 'group', $self->name, "";

    my $feed_format = $args->{feed_format};
    my $feed_type   = $args->{feed_type};
    if ($feed_format and $feed_type) {
        return sprintf("%s%s/%s.xml", $url, $feed_format, $feed_type);
    }

    if ($args->{year}) {
        return sprintf("%s%04d.html",
                       $url,  
                       $args->{year}->year
                       );
    }

    if (my $month = $args->{month}) {
        if ($args->{page} and $args->{page} > 1) {
            $url .= sprintf "%s/page%i.html", $month->strftime("%Y/%m"), $args->{page};
        }
        else {
            $url .= sprintf "%s.html", $month->strftime("%Y/%m");
        }
    }

    # TODO: convert $file parameters to $args

    return $url unless $file;
    if ($file->isa('CN::Model::Article')) {
        return sprintf("%s%04d/%02d/msg%d.html",
                       $url,  
                       $file->received->year, 
                       $file->received->month, 
                       $file->id
                       );
    }

    $url
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

sub previous_month {
    my ($group, $month_obj) = @_;

    if (my $data = $cache->fetch(id => join(":", "previous_month", $group->id, $month_obj->ymd))) {
      return $data->{data};
    }

    my $article = CN::Model->article->get_articles
        (  query => [ group_id => $group->id,
                      received => { lt => $month_obj },
                      ],
           limit => 1,
           sort_by => 'id desc',
	);
    $article = $article && $article->[0];
    my $rv = $article ? $article->received : undef;
    $cache->store(data => $rv, expire => 86400 * 60);

    return $rv;
}

sub next_month {
    my ($group, $month_obj) = @_;

    my $article = CN::Model->article->get_articles
        (  query => [ group_id => $group->id,
                      received => { gt => $month_obj->clone->add(months => 1) },
                      ],
           limit => 1,
           sort_by => 'id',
           );
    $article = $article && $article->[0];
    $article ? $article->received : undef;
}

sub get_recent_articles_count {
    my $self = shift;
    return $self->{_recent_count} if defined $self->{_recent_count};

    my $date = DateTime->now->subtract(months => 3);

    if (my $data = $cache->fetch(id => join(":", 'recent_count', $self->id, $date->ymd))) {
	return $data->{data};
    }

    my $count = CN::Model->article->get_articles_count
        (query => [ group_id  => $self->id,
                    received  => { gt => $date }
                    ],
         );
    $cache->store(data => $count, expire => 86400 * 5 );
    $self->{_recent_count} = $count;
}

sub get_daily_average {
    my $self = shift;
    my $count = $self->get_recent_articles_count;
    $count / 90;
}

sub latest_article {
    my $self = shift;
    return $self->{_latest_article} if $self->{_latest_article}; 
    my $article = CN::Model->article->get_articles
            (  query => [ group_id => $self->id, ],
               limit => 1,
               sort_by => 'id desc',
               );
    $self->{_latest_article} = $article && $article->[0];
}

sub get_thread_count {
    my ($self, $month) = @_;
    return 0 unless $month and $month->isa('DateTime');

    my $dbh = $self->dbh;
    my ($sql, $bind) = CN::Model->article->get_objects_sql
        (class => 'CN::Model::Article',
          query => [ group_id => $self->id,
                      received => { lt => $month->clone->add(months => 1) },
                      received => { gt => $month },
                      ],
           );
    $sql =~ s/SELECT.*FROM/SELECT COUNT(distinct thread_id) FROM/sm;
    #warn " [ $sql ] ";

    my ($count) = 
    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute(@$bind);
        $sth->fetchrow_array;
    };

    $count;
}
 
#package CN::Model::Group::Manager;




1;
