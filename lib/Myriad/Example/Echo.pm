package Myriad::Example::Echo;
use Myriad::Service ':v1';
async method echo : RPC (%args) {
 return $args{message};
}
1;
