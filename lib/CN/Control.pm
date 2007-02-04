package CN::Control;
use strict;
use base qw(Combust::Control Combust::Control::Bitcard);
use Apache::Constants qw(OK);
use Email::Address;

# use Devel::GC::Helper;

sub init {
    my $self = shift;

    # should maybe just do this every N requests
    Email::Address->purge_cache;

    # $self->r->register_cleanup(
    #                                 sub {
    #                                     warn "getting leaks";
    #                                     my $leaks = eval { Devel::GC::Helper::sweep; } || [];
    #                                     warn $@ if $@;
    #                                     warn "got leaks";
    #                                     for my $leak (@$leaks) {
    #                                         warn "Leaked $leak";
    #                                     }
    #                                     return 1;
    #                                 }
    #                                 );

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
