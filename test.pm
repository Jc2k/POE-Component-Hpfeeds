package TestHpfeeds;
use strict;
use warnings;

use POE;
use POE::Component::Hpfeeds;

my $session = POE::Component::Hpfeeds->spawn(
  RemoteAddress => 'hpfeeds',
  RemotePort    => 20000,
  Ident         => 'test',
  Secret        => 'test',
  Connected     => sub {
    my ($kernel, $session) = @_[KERNEL, SESSION];
    $kernel->post($session => subscribe => 'test');
    $kernel->post($session => publish => ('test', 'HELLO'));
  },
  Publish       => sub {
    my ($kernel, $session, $channel, $payload) = @_[KERNEL, SESSION, ARG0, ARG1];
    print STDERR "$channel: $payload\n";
    $kernel->post($session => publish => ($channel, $payload));
  }
);

POE::Kernel->run();
