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
    CN::Model->article->get_articles_count
        (query => [ group_id  => $self->group->id,
                    thread_id => $self->thread_id,
                  ],
         );
}

sub thread {
    my $self = shift;
    CN::Model::Thread->new($self->group, $self->thread_id);
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

my $cache = Combust::Cache->new(type => 'article_email');

sub email {
    my $self = shift;
    return $self->{_article_parsed} if $self->{_article_parsed};
    if (my $data = $cache->fetch(id => join(";", 1, $self->group->id, $self->id))) {
        return $data->{data};
    }
    my $nntp = CN::NNTP->nntp;
    $nntp = CN::NNTP->nntp unless $nntp;
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

sub short_date {
    my $self = shift;
    my $date = $self->received;
    my $age = time - $date->epoch;

    return $date->strftime("%e %b %Y") if $age > 86400 * 30 * 6;
    return $date->strftime("%e %b") if $age > 86400 / 2;
    return $date->strftime("%H:%M");
}

1;
