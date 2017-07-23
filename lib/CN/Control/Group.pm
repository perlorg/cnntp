package CN::Control::Group;
use strict;
use base qw(CN::Control);
use Combust::Constant qw(OK NOT_FOUND);
use CN::Model;
use POSIX qw(ceil);
use Digest::MD5 qw(md5_hex);
use URI;
use URI::QueryParam;
use Captcha::reCAPTCHA;
use XML::RSS;
use XML::Atom::Feed;
use XML::Atom::Entry;
$XML::Atom::DefaultVersion = '1.0';
use Combust::Cache;

sub request_setup {
    my $self = shift;
    
    return $self->{setup} if $self->{setup};

    # increment this to invalidate all the pages cached
    my $page_version = 1;

    my ($group_name, $year, $month, $page_type, $number) = 
        ($self->request->uri =~
         m!^/group/([^/]+)
          /([^/]+?)
          /([^/]+?)
          /(msg|page)(\d+)
          \.html$
         !x
       );

    my ($page, $article) = (0, 0);
    if ($page_type and defined $number) {
        $page    = $number if $page_type eq 'page';
        $article = $number if $page_type eq 'msg';
    }

    # redirect /group/perl.beginners to /group/perl.beginners/
    if ($self->request->uri =~ m!^/(group/[^/]+)$!) {
        die { redirect => "/$1/" }
    }

    unless ($group_name) {
        ($group_name, $year, $month) = 
        ($self->request->uri =~
         m!^/group/([^/]+)
          /([^/]+?)
          (?:/([^/]+?))?
          \.html$
         !x
       );
    }

    my ($feed_format, $feed_type);
    unless ($group_name) {
        ($group_name, $feed_format, $feed_type) = 
        ($self->request->uri =~
         m!^/group/([^/]+)
          /(rss|atom)/(threads|posts)
          \.xml$
         !x
       );
    }

    unless ($group_name) {
        ($group_name, $article) = 
            ($self->request->uri =~ m!^/group(?:/([^/]+)
                                              (?:/(\d+)?)?
                                              $)?!x);
    }

    unless ($group_name) {
        ($group_name, $article) = 
            ($self->request->uri =~ m!^/group(?:/([^/]+)
                                              (?:/;(msgid=.*)?)?
                                              $)?!x);
    }

    # redirect /2006/09/ to /2006/09.html 
    if ($self->request->uri =~ m!^/(group/[^/]+)/(\d{4})/(\d{2})/?$!) {
        die { redirect => "/$1/$2/$3.html" }
    }
    

    # fail-safe to catch bad urls that just would give us the group
    # index
    die { status => 404 }
      unless $group_name or $self->request->uri =~ m!^/group/?$!;

    return $self->{setup} = { group_name => $group_name || '',
                              year       => $year    || 0,
                              month      => $month   || 0,
                              article    => $article || 0,
                              page       => $page    || 1,
                              feed_format=> $feed_format || '',
                              feed_type  => $feed_type || '',
                              version    => $page_version,
                            };
}

sub render {
    my $self = shift;

    my $req = eval { $self->request_setup };
    if (my $err = $@) {
        return 500 unless ref $err;
        return $self->redirect($err->{redirect}, 'perm') if $err->{redirect};
        return 404 if $err->{status} and $err->{status} == 404;
        return $self->show_error($err->{message});
    }

    my @x = eval { 
        return $self->render_group_list unless $req->{group_name};
        my $group = CN::Model->group->fetch(name => $req->{group_name});
        return 404 unless $group;
        if ($req->{article}) {
            return $self->redirect_article unless $req->{year}; 
            return $self->render_article;
        }
        return $self->render_feed($group)  if $req->{feed_format};
        return $self->render_group($group);
    };
    if ($@) {
        warn "ERROR: $@";
        return $self->show_error($@)
    }
    return @x;
}


sub cache_info {
    my $self = shift;
    my $setup = eval { $self->request_setup };
    return {} unless $setup;

    #warn Data::Dumper->Dump([\$setup], [qw(setup)]);
    return {} if $self->deployment_mode eq 'devel';

    my $type = 'cn_grp_p'; 

    unless ($setup->{group_name}) {
        return { type    => $type,
                 backend => "memcached",
                 id      => '_group_list_',
                 expire  => 3600 * 2, # cache groups page for 2 hours
             };
    }

    my $expiration = 900;
    $expiration = 86400 if $setup->{group_name} and $setup->{group_name} eq 'perl.cpan.testers';

    return {
            type => $type,
            backend => "memcached",
            id   => md5_hex
                     (join ";",
                      map { "$_=" . (defined $setup->{$_} ? $setup->{$_} : '__undef__') }
                      qw(version group_name year month page article feed_format feed_type)
                     ),
            expire => $expiration,
           }

}

sub render_group_list {
    my $self = shift;
    my $groups = CN::Model->group->get_groups;

    my %groups;
    for my $group (@$groups) {
        my $count = $group->get_recent_articles_count;
        my $avg   = $group->get_daily_average;
	next unless $group->latest_article;
        if ($count == 0 and $group->latest_article->age_seconds > 86400 * 30 * 4) {
            push @{$groups{inactive}}, $group; 
        }
        else {
            if ($avg > .4) {
                push @{$groups{active}}, $group; 
            }
            else {
                push @{$groups{slow}}, $group; 
            }
        }
    }

    $self->tpl_param('groups', \%groups); 
    return OK, $self->evaluate_template('tpl/group_list.html');
}

sub group {
    my $self = shift;
    return $self->{group} if $self->{group};
    $self->{group} = CN::Model->group->fetch(name => $self->request_setup->{group_name});
}

my $captcha = Captcha::reCAPTCHA->new;

sub render_captcha {
    my $self = shift;

    $self->no_cache(1);

    if (my $response = $self->req_param('recaptcha_response_field')) {
        my $result = $captcha->check_answer
          ($self->config->site->{cnntp}->{recaptcha_private},
           $self->request->remote_ip,
           $self->req_param('recaptcha_challenge_field'),
           $response,
          );

        if ($result->{is_valid}) {
            $self->cookie('captcha' => time);
            return $self->redirect($self->request->uri . "?ts=" . time);
        }

    }

    $self->tpl_param(
        'captcha' => $captcha->get_html($self->config->site->{cnntp}->{recaptcha_public}));

    return OK, $self->evaluate_template('tpl/captcha.html');

}

my $bot_cache = Combust::Cache->new(type => 'bot', backend => 'memcached');

sub render_group {
    my $self = shift;

    my $group = $self->group;

    if ($group->name eq 'perl.cpan.testers') {

	my $ip = $self->request->remote_ip;
	my $data = $bot_cache->fetch(id => "1;testers;$ip");
        $data   = $data && $data->{data}; 
	$data ||= { ts => time, count => 0 };

	$data->{count}++;

	if ( $data->{ts} < time - 86400 * 4 ) {
	    $data->{ts}    = time;
	    $data->{count} = 1;
	}

	$bot_cache->store( data => $data );

        my $valid_cookie = $self->cookie('captcha');
        $valid_cookie = 0 unless $valid_cookie && ($valid_cookie > time - 43200);

	if ($data->{count} >= 4 and !$valid_cookie) {
            return $self->render_captcha;
        }

    }

    my $max = $self->req_param('max') || 0;

    my ($year, $month, $page) = ($self->request_setup->{year}, $self->request_setup->{month}, $self->request_setup->{page});

    return $self->render_year_overview if $year and ! $month;

    unless ($year) {
        my $newest_article = $group->latest_article;
        return 404 unless $newest_article;
        ($year, $month) = ($newest_article->received->year, $newest_article->received->month);
    }

    my $month_obj = DateTime->new(year => $year, month => $month, day => 1);

    $self->tpl_param('this_month' => $month_obj);

    my $per_page = 75;

    my $thread_count = $group->get_thread_count($month_obj);
    my $pages = ceil( $thread_count / $per_page);

    $self->tpl_param(page_number => $page);
    $self->tpl_param(pages       => $pages);

    my $articles = CN::Model->article->get_articles
        (  query => [ group_id => $group->id,
                      received => { lt => $month_obj->clone->add(months => 1) },
                      received => { gt => $month_obj },
                      ],
           limit => $per_page,
           offset => ( $page * $per_page - $per_page ),
           group_by => 'thread_id',
           sort_by => 'id desc',
         );

    $Rose::DB::Object::Manager::Debug = 0;

    $self->tpl_param('previous_month' => $group->previous_month($month_obj));
    $self->tpl_param('next_month'     => $group->next_month($month_obj));

    $self->tpl_param(group => $group);
    $self->tpl_param(articles => $articles);

    return OK, $self->evaluate_template('tpl/article_list.html');
}

sub render_year_overview {
    my $self = shift;
    my $year = $self->request_setup->{year};
    my $group = $self->group;
    my @months;
    for my $month (1..12) { 
        my $month_obj = DateTime->new(year => $year, month => $month, day => 1);
        my $count = 
          CN::Model->article->get_articles_count
              (query => [ group_id  => $group->id,
                          received => { lt => $month_obj->clone->add(months => 1) },
                          received => { gt => $month_obj },
                        ],
              );
        push @months, { month => $month_obj, count => $count } if $count;
    }

    $self->tpl_param('previous_year' => $group->previous_month(DateTime->new(year => $year, month => 1)));
    $self->tpl_param('next_year'     => $group->next_month(    DateTime->new(year => $year, month => 12)));

    $self->tpl_param(group  => $self->group);
    $self->tpl_param(months => \@months);
    $self->tpl_param(year   => $year);
    return OK, $self->evaluate_template('tpl/year.html');
}

sub render_feed {
    my $self  = shift;
    my $group = $self->group;
    my $setup = $self->request_setup;

    return 404 if $group->name eq 'perl.cpan.testers';

    my $feed_format = $setup->{feed_format};
    my $feed_type   = $setup->{feed_type};

    my $articles = CN::Model->article->get_articles
        (  query => [ group_id => $group->id,
                    ],
           limit => 40,
           ($feed_type eq 'threads' ? (group_by => 'thread_id') : ()),
           sort_by => 'id desc',
        );

    my $base_url = $self->config->base_url('cnntp');

    my @entries = map {
        my $msg_count;
        if ($feed_type eq 'threads') {
            $msg_count = $_->thread_count;
        }
        +{ link   => $base_url . $_->uri,
           title  => $_->h_subject_parsed 
                        . ($feed_type eq 'posts'
                            ? " by " . $_->author_name 
                            : " ($msg_count message" . ($msg_count > 1 ? "s" : "") . ")" ),
           body   => $_->body_html,
           author => ($feed_type eq 'posts' ? $_->author_name : join(", ", $_->thread->authors(4))),
           date   => $_->received,
        } 
    } @$articles;

    my $feed_title     = $group->name;
    my $feed_link      = $base_url . $group->uri;
    my $feed_copyright = 'Copyright 1998-' . DateTime->now->year . ' perl.org';

    if ($feed_format eq 'rss') {
        my $rss = XML::RSS->new(version => '2.0');
        $rss->channel(title       => $feed_title,
                      link        => $feed_link,
                      description => '...',
                      pubDate     => DateTime->now->strftime("%a, %d %b %Y %H:%M:%S %z"),
                      webMaster   => 'ask@perl.org',
                      copyright   => $feed_copyright,
                     );
        for my $entry (@entries) {
            $rss->add_item(title       => $entry->{title},
                           permaLink   => $entry->{link},
                           description => $entry->{body},
                           pubDate     => $entry->{date}->strftime("%a, %d %b %Y %H:%M:%S %z"),
                          );
        }
        return OK, $rss->as_string, 'application/rss+xml';

    }
    elsif ($feed_format eq 'atom') {
        my $feed = XML::Atom::Feed->new;
        $feed->title($feed_title);
        $feed->id($feed_link);
        for my $entry (@entries) {
            my $e = XML::Atom::Entry->new;
            $e->title($entry->{title});
            $e->content("<p>From: " . $entry->{author} . "\n\n" . $entry->{body} . '</p>');
            $e->issued($entry->{date}->iso8601 . 'Z');
            my $link = XML::Atom::Link->new;
            $link->type('text/html');
            $link->rel('alternate');
            $link->href($entry->{link});
            $e->add_link($link);
            $feed->add_entry($e);
        }
        return OK, $feed->as_xml, 'application/atom+xml'
    }

    return NOT_FOUND;
}

sub render_article {
    my $self = shift;

    my $req = $self->request_setup;

    my $article = CN::Model->article->fetch(group_id => $self->group->id,
                                            id       => $req->{article}
                                            );

    return 404 unless $article;

    # should we just return 404? 
    return $self->redirect_article
        unless $article->received->year == $req->{year}
               and $article->received->month == $req->{month};

    # $article->email; # die here if we can't get the article from cache or nntp

    $self->tpl_param('article' => $article);
    $self->tpl_param('group'   => $self->group);

    return OK, $self->evaluate_template('tpl/article.html');

}

sub redirect_article {
    my $self = shift;
    my $req = $self->request_setup;

    my $article;

    if ($req->{article} =~ m/^msgid=(.*)/) {
        my $msg_id = $1;
        $msg_id =~ s/\[at\]/@/;
        my $md5 = md5_hex($msg_id);

        # local $Rose::DB::Object::Debug = $Rose::DB::Object::Manager::Debug = 1;

        $article = CN::Model->article->get_articles
          (query => [ msgid    => $md5,
                      group_id => $self->group->id,
                    ]);
        $article = $article && $article->[0];
    }

    $article ||= CN::Model->article->fetch(group_id => $self->group->id,
                                           id       => $req->{article}
                                          );
    
    return 404 unless $article;

    return $self->redirect($article->uri, 'perm');
}

sub show_error {
    my ($self, $msg) = @_;
    $self->tpl_param(msg => $msg);
    return 500, $self->evaluate_template('tpl/error.html');
}

1;
