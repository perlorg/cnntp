package CN::App;
use Moose;
use Plack::Builder;
extends 'Combust::App';
with 'Combust::App::ApacheRouters';
with 'Combust::Redirect';
use CN::Tracing;
use CN::Model;
use CN::Control;
use Combust::Cache;
use Combust::Logger qw(logconfig);

use OpenTelemetry::Constants qw( SPAN_KIND_SERVER SPAN_STATUS_ERROR SPAN_STATUS_OK );
use OpenTelemetry -all;
use Syntax::Keyword::Dynamically;

$Combust::Cache::namespace .= '.v2';

logconfig(verbose => 5, saywarn => 1);

augment 'reference' => sub {
    my $self = shift;

    my $tracer = CN::Tracing->tracer;

    enable sub {
        my $app = shift;

        sub {
            my $env = shift;
            my $uri = $env->{PATH_INFO};

            if ($uri eq "/__health"
                and ($env->{REQUEST_METHOD} eq "GET" or $env->{REQUEST_METHOD} eq "HEAD"))
            {
                {
                    my $pspan =
                      OpenTelemetry::Trace->span_from_context(OpenTelemetry::Context->current);
                    $pspan->set_name($env->{REQUEST_METHOD} . " __health");

                    my $span = CN::Tracing->tracer->create_span(
                        name => "flush_otel",
                        kind => SPAN_KIND_SERVER,
                    );
                    dynamically otel_current_context = otel_context_with_span($span);

                    $span->end();
                }
                CN::Tracing->flush(2);
                return [200, ['Content-Type' => 'text/plain'], ["App says ok\n"]];
            }

            my $res = $app->($env);
            return $res;
        };
    };
};

1;
