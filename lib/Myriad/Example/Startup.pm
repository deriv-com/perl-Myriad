package Myriad::Example::Startup;
# VERSION
# To try this out, run:
#  myriad.pl service Myriad::Example::Startup
use Myriad::Service ':v1';
async method startup (%args) {
 $log->infof('This is our example service, running code in the startup method');
}
1;
