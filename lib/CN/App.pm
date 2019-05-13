package CN::App;
use Moose;
use Plack::Builder;
extends 'Combust::App';
with 'Combust::App::ApacheRouters';
with 'Combust::Redirect';
use CN::Model;
use CN::Control;
use Combust::Cache;
use Combust::Logger qw(logconfig);

$Combust::Cache::namespace .= '.v2';

logconfig(verbose => 5, saywarn => 1);

1;

