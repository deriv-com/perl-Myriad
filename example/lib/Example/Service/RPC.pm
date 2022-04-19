package Example::Service::RPC;
use Myriad::Service ':v1';
async method message : RPC {
 return 'Welcome to Myriad';
}
1;
