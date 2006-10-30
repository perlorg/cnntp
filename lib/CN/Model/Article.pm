package CN::Model::Article;
use strict;
use Encode qw/decode/;
use Email::Address;
use CN::NNTP;
use Email::MIME;
use CN::Model::Thread;

sub uri {
    my $self = shift;
    $self->group->uri($self)
}

sub h_subject_parsed {
    my $self = shift;
    my $subject = $self->h_subject;
    decode('MIME-Header', $subject);
}

sub thread_count {
    my $self = shift;
    return $self->{_thread_count} if $self->{_thread_count};
    $self->{_thread_count} =
      CN::Model->article->get_articles_count
        (query => [ group_id  => $self->group->id,
                    thread_id => $self->thread_id,
                  ],
         );
}

sub thread {
    my $self = shift;
    return $self->{_thread} if $self->{_thread};
    $self->{_thread} = CN::Model::Thread->new($self->group, $self->thread_id);
}

sub previous_in_thread {
    my $self = shift;
    $self->_navigation->{previous}
}

sub next_in_thread {
    my $self = shift;
    $self->_navigation->{next}
}


sub _navigation {
    my $self = shift;
    return $self->{_navigation} if $self->{_navigation};

    $self->{_navigation} = {};

    $self->{_last_candidate} = undef;

    $self->_search_thread($self->thread->rootset);

    delete $self->{_seen_me};
    delete $self->{_last};

    $self->{_navigation};
}

sub _search_thread {
    my ($self, $mail, $last) = @_;

    return if $mail && $mail->message
       and $self->_check_navigation($mail, $last);

    if ($mail->child) {
        $self->_search_thread($mail->child, $mail);
    }
    if ($mail->next) {
        $self->_search_thread($mail->next, $mail);
    }
}

sub _check_navigation {
    my ($self, $mail, $last) = @_;
    return 1 if $self->_navigation->{next};

    #warn "$$ MID: ", $mail->message->id,
    #  " SID: ", $self->id,
    #  " LID: ", $last ? $last->message->id : "n/a", "\n";

    if ($self->id == $mail->message->id) {
        #warn "$$ seen me!\n";
        $self->{_seen_me} = 1;
        $self->_navigation->{previous} = $last->message if $last;
    }

    if ($self->{_seen_me}) {
        if ($mail->message->id != $self->id) {
            $self->_navigation->{next} = $mail->message;
        }
    }

    return 1 if $self->_navigation->{next};
    return 0;
}

sub h_from_parsed {
    my $self = shift;
    return $self->{_h_from_parsed} if $self->{_h_from_parsed};
    my $from = decode('MIME-Header', $self->h_from);
    $self->{_h_from_parsed} = (Email::Address->parse($from))[0];
}

sub author_email {
    my $self = shift;
    $self->h_from_parsed && $self->h_from_parsed->address;
}

sub author_name {
    my $self = shift;
    my $name = $self->h_from_parsed && $self->h_from_parsed->name;
    $name && $name =~ s/^"(.*)"$/$1/;
    unless ($name and $name =~ m/\S/) {
        $name = $self->author_email || '';
        $name =~ s/\@.*//;
    }
    $name;
}

my $cache = Combust::Cache->new(type => 'nntp_article_email');

sub email {
    my $self = shift;
    return $self->{_article_parsed} if $self->{_article_parsed};
    if (my $data = $cache->fetch(id => join(";", 1, $self->group->id, $self->id))) {
        return $data->{data};
    }
    my $nntp = CN::NNTP->nntp;
    $nntp = CN::NNTP->nntp unless $nntp;
    die "Could not connect to backend NNTP server; please try again later\n" unless $nntp;
    $nntp->group($self->group->name);
    my $article = $nntp->article($self->id);
    my $email = Email::MIME->new(join "", @$article);
    $cache->store(data => $email, expires => 86400*3);
    $self->{_article_parsed} = $email;
}

sub body {
    my $self = shift;
    my $email = $self->email;

    my @parts = $email->parts;

    my $body;
    for my $part (@parts) {
        # TODO: do all this in the email method and flag/mark attachments?
        next if $part->content_type and $part->content_type =~ m!application/!;

        $body = $part->body; 
        # warn Data::Dumper->Dump([\$part], [qw(part)]);

        if ($part->content_type and $part->content_type =~ m!text/!) {
            if (my ($charset) = ($part->content_type =~ m/charset="?(.*)"?/)) {
                $charset =~ s/;.*$//;
                eval { $body = decode($charset, $body) } if $charset;
            }
            last if $part->content_type =~ m!text/plain!
        }
        
    }
    $body;
}

sub age_seconds {
    my $self = shift;
    my $date = $self->received;
    time - $date->epoch;
}

sub short_date {
    my $self = shift;
    my $age = $self->age_seconds;

    my $date = $self->received;

    return $date->strftime("%e %b %Y") if $age > 86400 * 30 * 6;
    return $date->strftime("%e %b") if $age > 86400 / 2;
    return $date->strftime("%H:%M");
}

1;
