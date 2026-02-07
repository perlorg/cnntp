package CN::Model::Article::Thread;
use strict;
use Mail::Thread;
use base qw(Mail::Thread);

sub _get_hdr {
    my ($class, $msg, $hdr) = @_;
    if (my $email = $msg->email) {
        return $email->header($hdr) || '';
    }
    # Fall back to database-stored headers when NNTP article is unavailable
    return $msg->h_messageid  if $hdr eq 'Message-ID';
    return $msg->h_references if $hdr eq 'References';
    return $msg->h_subject    if $hdr eq 'Subject';
    return '';
}

sub _container_class { "CN::Model::Article::Thread::Container" }

package CN::Model::Article::Thread::Container;
use base qw(Mail::Thread::Container);

sub header { $_[0]->message && CN::Model::Article::Thread->_get_hdr($_[0]->message, $_[1]) }

1;





