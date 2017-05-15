package CN::App;
use Moose;
use Plack::Builder;
extends 'Combust::App';
with 'Combust::App::ApacheRouters';
with 'Combust::Redirect';
use CN::Model;
use CN::Control;
use Combust::Cache;

$Combust::Cache::namespace .= '.v2';

1;

