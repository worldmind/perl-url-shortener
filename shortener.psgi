#!/usr/bin/perl -w

use Plack::Request;
use Plack::Builder;
use AnyEvent::Redis::RipeRedis;
use Digest::Tiger;
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
      my $w = $respond->([200, ['Content-Type' => 'text/plain; charset=utf-8']]);
      my $url = $query->{url};
      my $url_hash = Digest::Tiger::hexhash( $url );
      unless ( $url ) {
        $w->write( "Give me url" );
        undef $w;
        return;
      }
      $redis->get( $url_hash, { on_done => sub {
        my ( $short_url ) = @_;
        if ( $short_url ) {
          $w->write( "Short for $url is $short_url" );
          undef $w;
          return;
        }
        $redis->incr( $counter_key, { on_done => sub {
           my $number = shift;
           my $key = $u->to_base( $number ); # FIXME rename $key
           $redis->set( $url_hash, $key, {on_done => sub {
             $redis->set( $key, $url, {on_done => sub {
                my $data = shift;
                $w->write( "Short for $url is $key" );
                undef $w;
               },
             } );
           },
           } );
        },
        } );
      },
      } );
    }
  }
  else {
    return sub {
      my $respond = shift;
      my $w = $respond->([200, ['Content-Type' => 'text/plain; charset=utf-8']]);
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

