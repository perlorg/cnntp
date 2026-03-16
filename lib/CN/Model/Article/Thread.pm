package CN::Model::Article::Thread;
use strict;
use Mail::Thread;
use base qw(Mail::Thread);

sub _get_hdr {
    my ($class, $msg, $hdr) = @_;
    # Prefer DB-stored headers to avoid NNTP fetches during thread building
    if ($hdr eq 'Message-ID') {
        my $val = $msg->h_messageid;
        return $val if defined $val && $val ne '';
    } elsif ($hdr eq 'References') {
        my $val = $msg->h_references;
        return $val if defined $val && $val ne '';
    } elsif ($hdr eq 'Subject') {
        my $val = $msg->h_subject;
        return $val if defined $val && $val ne '';
    }
    # Fall back to NNTP article only if DB headers are missing
    if (my $email = $msg->email) {
        return $email->header($hdr) || '';
    }
    return '';
}

sub _container_class { "CN::Model::Article::Thread::Container" }

package CN::Model::Article::Thread::Container;
use base qw(Mail::Thread::Container);

sub header { $_[0]->message && CN::Model::Article::Thread->_get_hdr($_[0]->message, $_[1]) }

1;





