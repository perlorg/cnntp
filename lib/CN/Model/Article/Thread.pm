package CN::Model::Article::Thread;
use strict;
use Mail::Thread;
use base qw(Mail::Thread);

sub _get_hdr {
    my ($class, $msg, $hdr) = @_;
    $msg->email->header($hdr) || '';
}

sub _container_class { "CN::Model::Article::Thread::Container" }

package CN::Model::Article::Thread::Container;
use base qw(Mail::Thread::Container);

sub header { eval { $_[0]->message->email->header($_[1]) } }

1;





