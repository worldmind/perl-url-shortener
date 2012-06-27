#!/usr/bin/perl -w

use Plack::Request;
use Plack::Builder;
use AnyEvent::Redis::RipeRedis;
use Math::BaseCalc;

my $counter_key = 'urls_counter';
my $u = Math::BaseCalc->new( digits => '62' );
my $redis = AnyEvent::Redis::RipeRedis->new( host => 'localhost', port => '6379', password => '' );

my $app = sub {
  my $env = shift;
  my $req = Plack::Request->new($env);
  my $res = $req->new_response(200);
  $res->content_type('text/plain; charset=utf-8');
  my $query = $req->query_parameters();

  if ($req->path eq '/') {
    return sub {
      my $respond = shift;
      my $w = $respond->([200, ['Content-Type' => 'text/plain']]);
      my $url = $query->{url};
      unless ( $url ) {
        $w->write( "Give me url" );
        undef $w;
        return;
      }
      $redis->incr( $counter_key, { on_done => sub {
         my $number = shift;
         my $key = $u->to_base( $number );
         $redis->set( $key, $url, {on_done => sub {
            my $data = shift;
            $w->write( "Short for $url is $key" );
            undef $w;
           },
         } );
      },
      } );
    }
  }
  else {
    return sub {
      my $respond = shift;
      my $w = $respond->([200, ['Content-Type' => 'text/plain']]);
      my $key = ( $req->path =~ m!/(.+)$! )[0];
      $redis->get( $key, { on_done => sub {
        my ( $url ) = @_;
        $w->write( "Got $url" );
        undef $w;
      }
      } );
    }
  }

  [404, ['Content-Type' => 'text/plain'], ['Not found']];
};

