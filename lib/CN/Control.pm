package CN::Control;
use strict;
use base qw(Combust::Control);
use Combust::Constant qw(OK);
use CN::Tracing;
use Email::Address;
use OpenTelemetry::Constants qw( SPAN_KIND_SERVER SPAN_STATUS_ERROR SPAN_STATUS_OK );
use OpenTelemetry -all;
use OpenTelemetry::Trace;
use Syntax::Keyword::Dynamically;

# use Devel::GC::Helper;

sub init {
    my $self = shift;

    my $span       = OpenTelemetry::Trace->span_from_context(OpenTelemetry::Context->current);
    my $class_name = ref $self;
    $span->set_attribute("class", $class_name);

    # set better name for the outer span
    $class_name =~ s/^CN::Control:://;
    $self->set_span_name($class_name);

    for my $h (
        qw(
            X-Forwarded-For
            X-Original-Forwarded-For
            X-Real-IP
            CF-Connecting-IP CF-RAY
            Fastly-Client-IP
        )
      )
    {
        my $d = $self->request->header_in($h);
        $span->set_attribute(lc("http.request.header.$h"), $d) if $d;
    }

    my $tracer = CN::Tracing->tracer;
    my $span   = $tracer->create_span(
        name => "init",

        # kind => SPAN_KIND_SERVER,
        # attributes => {url => $uri,},
    );
    dynamically otel_current_context = otel_context_with_span($span);

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

    my $trace_id = $span->context->hex_trace_id;
    $self->request->header_out('Traceparent', $trace_id);

    $span->end();

    return OK;
}

sub post_process {
    my $self = shift;

    my $req    = $self->request;
    my $status = $req->response->status || 200;

    if ($self->no_cache || $status >= 400) {
        $req->header_out('Cache-Control', 'no-cache,max-age=0,private');
        $req->header_out('Pragma',        'no-cache');
    }
    else {
        $req->header_out('Cache-Control', 'max-age=43200');
    }

    return OK;
}

sub set_span_name {
    my $self = shift;
    my $name = shift or return;
    my $span = OpenTelemetry::Trace->span_from_context(OpenTelemetry::Context->current);
    $span->recording or return;

    if (!$span->can('snapshot')) {
        warn "span does not have snapshot method, can't change name";
        return;
    }

    # set better name for the outer span
    my $span_name = $span->snapshot->name;
    $span_name =~ s/^(\S+).*/$1 ${name}/;    # preserve the http method
    $span->set_name($span_name);

}

1;
