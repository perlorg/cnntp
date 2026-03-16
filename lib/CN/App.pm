package CN::App;
use Moose;
use Plack::Builder;
extends 'Combust::App';
with 'Combust::App::ApacheRouters';
with 'Combust::Redirect';
use CN::Tracing;
use CN::Model;
use CN::NNTP;
use CN::Control;
use Combust::Cache;
use Combust::Logger qw(logconfig);

use OpenTelemetry::Constants qw( SPAN_KIND_SERVER SPAN_STATUS_ERROR SPAN_STATUS_OK );
use OpenTelemetry -all;
use Syntax::Keyword::Dynamically;

$Combust::Cache::namespace .= '.v2';

logconfig(verbose => 5, saywarn => 1);

$SIG{__WARN__} = sub {
    my $message = shift;
    my $span    = OpenTelemetry::Trace->span_from_context(OpenTelemetry::Context->current);
    if ($span) {
        my $trace_id = $span->context->hex_trace_id;
        my $span_id  = $span->context->hex_span_id;
        warn "trace_id=$trace_id span_id=$span_id $message";
    }
    else {
        warn "$message";
    }
};

augment 'reference' => sub {
    my $self = shift;

    my $tracer = CN::Tracing->tracer;

    enable sub {
        my $app = shift;

        sub {
            my $env = shift;
            my $uri = $env->{PATH_INFO};

            if (    ($uri eq "/__health" or $uri eq "/_health")
                and ($env->{REQUEST_METHOD} eq "GET" or $env->{REQUEST_METHOD} eq "HEAD"))
            {

                {
                    my $pspan =
                      OpenTelemetry::Trace->span_from_context(OpenTelemetry::Context->current);
                    $pspan->set_name($env->{REQUEST_METHOD} . " health");

                    # flush tracing data when there's a health check, otherwise
                    # the OpenTelemetry code waits until the "buffer" is full
                    eval {
                        local $SIG{ALRM} = sub { die "otel flush timeout\n" };
                        alarm(1);
                        CN::Tracing->flush(2);
                        alarm(0);
                    };
                    alarm(0);
                    if ($@ =~ /otel flush timeout/) {
                        warn "health: OpenTelemetry flush timed out\n";
                    }

                    my $dbh = CN::Model->dbh();

                    my $ping_ok = eval {
                        local $SIG{ALRM} = sub { die "db ping timeout\n" };
                        alarm(3);
                        my $ok = $dbh->ping;
                        alarm(0);
                        $ok;
                    };
                    alarm(0);
                    if ($@ =~ /db ping timeout/) {
                        warn "health: database ping timed out\n";
                        return [500, ['Content-Type' => 'text/plain'], ["db ping timeout\n"]];
                    }
                    unless ($ping_ok) {
                        warn "Could not ping database...";
                        return [500, ['Content-Type' => 'text/plain'], ["db ping\n"]];
                    }
                }
                return [200, ['Content-Type' => 'text/plain'], ["App says ok\n"]];
            }

            my $res = eval {
                local $SIG{ALRM} = sub { die "request timeout\n" };
                alarm(30);
                my $r = $app->($env);
                alarm(0);
                $r;
            };
            alarm(0);
            if ($@ =~ /request timeout/) {
                warn "CN::App: request timed out: $uri\n";
                CN::NNTP->reset_connection;
                return [504, ['Content-Type' => 'text/plain'], ["Request timed out\n"]];
            } elsif ($@) {
                die $@;
            }
            return $res;
        };
    };
};

1;
