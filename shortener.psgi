#!/usr/bin/perl -w

use Plack::Request;
use Plack::Builder;
use AnyEvent::Redis::RipeRedis;
use Digest::Tiger;
use Math::BaseCalc;

# settings
my $server = 'http://localhost:8080/';
my $counter_key = 'urls_counter';
my %redis_conf = (
  host    => 'localhost',
  port     => '6379',
  password => '',
);
my $base = 62;
my $index = q{
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <title>URL shotener</title>
 </head>
 <body>
  <form action="/">
   <fieldset>
    <label for="url">Enter URL:</label>
    <input type="text" name="url" id="url" />
    <input type="submit" value="Get short link" />
   </fieldset>
  </form>
 </body>
</html>
};

my $u = Math::BaseCalc->new( digits => $base );
my $redis = AnyEvent::Redis::RipeRedis->new( %redis_conf );

my $app = sub {
  my $env = shift;
  my $req = Plack::Request->new($env);
  my $query = $req->query_parameters();

  if ($req->path eq '/') {
    return sub {
      my $respond = shift;
      my $url = $query->{url};
      my $url_hash = Digest::Tiger::hexhash( $url );
      unless ( $url ) {
        my $w = $respond->([200, ['Content-Type' => 'text/html; charset=utf-8']]);
        $w->write( $index );
        undef $w;
        return;
      }
      $redis->get( $url_hash, { on_done => sub {
        my ( $short_url ) = @_;
        if ( $short_url ) {
          my $w = $respond->([200, ['Content-Type' => 'text/html; charset=utf-8']]);
          $w->write( "Short for $url is $server$short_url" );
          undef $w;
          return;
        }
        $redis->incr( $counter_key, { on_done => sub {
           my $number = shift;
           my $w = $respond->([200, ['Content-Type' => 'text/html; charset=utf-8']]);
           my $short_url = $u->to_base( $number );
           $redis->set( $url_hash, $short_url, {on_done => sub {
             $redis->set( $short_url, $url, {on_done => sub {
                my $data = shift;
                $w->write( "Short for $url is $server$short_url" );
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
      my $key = ( $req->path =~ m!/(.+)$! )[0];
      $redis->get( $key, { on_done => sub {
        my ( $url ) = @_;
        my $w = $respond->([301, ['Location' => $url]]);
        $w->write( "Go to $url" );
        undef $w;
      }
      } );
    }
  }

  [404, ['Content-Type' => 'text/plain'], ['Not found']];
};

