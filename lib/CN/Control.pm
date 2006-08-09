package CN::Control;
use strict;
use base qw(Combust::Control Combust::Control::Bitcard);
use Apache::Constants qw(OK);
#use CN::User;

sub init {
    my $self = shift;
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
