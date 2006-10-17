package CN::Control;
use strict;
use base qw(Combust::Control Combust::Control::Bitcard);
use Apache::Constants qw(OK);
use Email::Address;

sub init {
    my $self = shift;

    # should maybe just do this every N requests
    Email::Address->purge_cache;

    return OK;
}

sub bc_user_class {
  'CN::User';
}

sub bc_info_required {
    'username,email';
}



package CN::Control::Basic;
use base qw(CN::Control Combust::Control::Basic);

package CN::Control::Error;
use base qw(CN::Control Combust::Control::Error);

1;
