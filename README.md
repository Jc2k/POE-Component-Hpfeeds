# NAME

POE::Component::Hpfeeds - send and receive messages to/from a hpfeeds broker

# VERSION

version 0.01

# SYNOPSIS

This POE Component provides a Hpfeeds client.

```
use strict;
use warnings;

use POE;
use POE::Component::Hpfeeds;

my $session = POE::Component::Hpfeeds->spawn(
  RemoteAddress => 'localhost',
  RemotePort    => 20000,
  Ident         => 'ident',
  Secret        => 'secret',
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
```


# EXPORT

...

# FUNCTIONS

## spawn

Creates the POE::Session for the Hpfeeds client.

Parameters:
    RemoteAddress           => 'localhost',
    RemotePort              => 20000,
    Ident                   => 'ident',
    Secret                  => 'secret',

## INTERNAL FUNCTIONS

...

# SEE ALSO

- [Python 3 hpfeeds](https://github.com/Jc2k/hpfeeds3)

# AUTHOR

John Carr <john.carr@unrouted.co.uk>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2018 by John Carr.

This is free software, licensed under:

    Apache 2
