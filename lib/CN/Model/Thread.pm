package CN::Model::Thread;
use strict;
use CN::Model::Article::Thread;

sub new {
    my ($class, $group, $thread_id) = @_;
    # TODO: lookup in cache

    my $self = bless { group => $group, $thread_id => $thread_id }, $class;

    my $articles = CN::Model->article->get_articles
        (  query => [ group_id  => $group->id,
                      thread_id => $thread_id,
                    ],
           order_by => 'parent'
        );


    my $threader = CN::Model::Article::Thread->new(@$articles);
    $threader->thread;

    $self->{threader} = $threader;

    # TODO: save to cache 
    $self;
}

sub threader {
    shift->{threader};
}

sub rootset {
    shift->threader->rootset;
}

sub dump_em {
    my ($self, $level) = @_;
    debug (' \\-> ' x $level);
    if ($self->message) {
        warn $self->message->email->header("Subject") , "\n";
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
