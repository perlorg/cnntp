package CN::Model::Article;
use strict;
use Encode qw/decode/;
use Email::Address;
use CN::NNTP;
use Email::MIME;

sub h_subject_parsed {
    my $self = shift;
    my $subject = $self->h_subject;
    decode('MIME-Header', $subject);
}

sub thread_count {
    my $self = shift;
    CN::Model->article->get_articles_count
        (query => [ group_id => $self->group->id,
                    thread   => $self->thread,
                  ],
         );
}

sub h_from_parsed {
    my $self = shift;
    return $self->{_h_from_parsed} if $self->{_h_from_parsed};
    $self->{_h_from_parsed} = (Email::Address->parse($self->h_from))[0];
}

sub author_email {
    my $self = shift;
    $self->h_from_parsed && $self->h_from_parsed->address;
}

sub author_name {
    my $self = shift;
    my $name = $self->h_from_parsed && $self->h_from_parsed->name;
    $name && $name =~ s/^"(.*)"$/$1/;
    $name;
}

sub email {
    my $self = shift;
    return $self->{_article_parsed} if $self->{_article_parsed};
    my $nntp = CN::NNTP->nntp;
    $nntp->group($self->group->name);
    my $article = $nntp->article($self->id);
    $self->{_article_parsed} = Email::MIME->new(join "", @$article);
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

1;
