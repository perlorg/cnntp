package CN::Model::Thread;
use strict;
use CN::Model::Article::Thread;

sub new {
    my ($class, $group, $thread_id) = @_;
    # TODO: lookup in cache

    my $self = bless { group => $group, thread_id => $thread_id }, $class;

    # TODO: save to cache 
    $self;
}

sub authors {
    my ($self, $how_many) = @_;
    my %authors;
    map { $authors{$_->author_name}++ } @{ $self->articles };
    my @authors = sort { $authors{$b} <=> $authors{$a} } keys %authors;
    @authors > $how_many ? splice(@authors, 0, $how_many) : @authors;
}

sub last_article {
    my ($self, $month) = @_;
    my $articles = $self->articles;
    return $articles->[-1] unless $month;
    my $last_time = $month->clone->set( day => 1 )->add(months => 1)->epoch;
    my $last_article;
    for my $article (@$articles) {
        last if $last_time < $article->received->epoch; 
        $last_article = $article;
    }
    $last_article;
}

sub articles {
    my $self = shift;
    return $self->{articles} if $self->{articles};
    my $articles = CN::Model->article->get_articles
        (  query => [ group_id  => $self->{group}->id,
                      thread_id => $self->{thread_id},
                    ],
           order_by => 'id'
        );
    $self->{articles} = $articles;
}

sub threader {
    my $self = shift;
    return $self->{threader} if $self->{threader};
    my $articles = $self->articles;
    my $threader = CN::Model::Article::Thread->new(@$articles);
    $threader->thread;
    $self->{threader} = $threader;
}

sub rootset {
    shift->threader->rootset;
}

sub dump_em {
    my ($self, $level) = @_;
    debug (' \\-> ' x $level);
    if ($self->message) {
        my $subj = $self->message->email ? $self->message->email->header("Subject") : $self->message->h_subject;
        warn $subj, "\n";
    } else {
        warn "[ Message $self not available ]\n";
    }
    dump_em($self->child, $level+1) if $self->child;
    dump_em($self->next, $level) if $self->next;
}

sub debug {
    warn @_, "\n"; 
}

1;
