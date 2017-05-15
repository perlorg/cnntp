package CN::Control;
use strict;
use base qw(Combust::Control Combust::Control::Bitcard);
use Combust::Constant qw(OK);
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

sub post_process {
    my $self = shift;

    my $req = $self->request;

    if ($self->no_cache) {
        $req->header_out('Cache-Control', 'no-cache,max-age=0,private');
        $req->header_out('Pragma',        'no-cache');
    }
    else {
        $req->header_out('Cache-Control', 'max-age=43200');
    }

    return OK;
}

1;
