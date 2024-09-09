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

            if (    ($uri eq "/__health" or $uri eq "/_health")
                and ($env->{REQUEST_METHOD} eq "GET" or $env->{REQUEST_METHOD} eq "HEAD"))
            {

                # flush tracing data when there's a health check, otherwise
                # the OpenTelemetry code waits until the "buffer" is full
                CN::Tracing->flush(2);

                {
                    my $pspan =
                      OpenTelemetry::Trace->span_from_context(OpenTelemetry::Context->current);
                    $pspan->set_name($env->{REQUEST_METHOD} . " health");

                    my $dbh = CN::Model->dbh();

                    unless ($dbh->ping) {
                        warn "Could not ping database...";
                        return [500, ['Content-Type' => 'text/plain'], ["db ping\n"]];
                    }
                }
                return [200, ['Content-Type' => 'text/plain'], ["App says ok\n"]];
            }

            my $res = $app->($env);
            return $res;
        };
    };
};

1;
