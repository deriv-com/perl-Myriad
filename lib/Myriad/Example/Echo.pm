package Myriad::Example::Echo;
# VERSION
# To try this out, run:
#  myriad.pl service Myriad::Example::RPC rpc myriad.example.echo/message='{"message":"example message"}'
use Myriad::Service ':v1';
async method echo : RPC (%args) {
 return $args{message};
}
1;
