package POE::Component::Hpfeeds;
use strict;
use warnings;

# ABSTRACT: A POE TCP Client for publishing/subscribing to a hpfeeds broker.

use Data::Dumper;

use Carp 'carp', 'croak';
use Digest::SHA;
use POE::Session;
use POE::Filter::Hpfeeds;
use POE::Component::Client::TCP;
use Socket qw(SOL_SOCKET SO_KEEPALIVE IPPROTO_TCP TCP_NODELAY TCP_KEEPIDLE TCP_KEEPINTVL TCP_KEEPCNT);

use constant {
  OPCODE_ERROR => 0,
	OPCODE_INFO => 1,
	OPCODE_AUTH => 2,
	OPCODE_PUBLISH => 3,
	OPCODE_SUBSCRIBE => 4,
	OPCODE_UNSUBSCRIBE => 5,
	OPCODE_MAX => 6,
};

our $VERSION = 0.1;


sub spawn {
	my $class = shift;
  my $self = {};
	my $param  =  {@_};

  bless($self, $class);

	croak "$self requires an even number of parameters" if @_ & 1;

	$self->{session_id} = POE::Component::Client::TCP->new(
    'RemoteAddress' => $param->{RemoteAddress},
    'RemotePort' => $param->{RemotePort},
    #'BindAddress' => '127.0.0.1',
    #'BindPort' => '8080',

		'Filter'        => 'POE::Filter::Hpfeeds',

		'Connected'     => sub {
      my ($socket, $peer_addr, $peer_port) = @_[ARG0, ARG1, ARG2];

      setsockopt($socket, SOL_SOCKET, SO_KEEPALIVE, 1);
      setsockopt($socket, IPPROTO_TCP, TCP_NODELAY, 1);
      setsockopt($socket, IPPROTO_TCP, TCP_KEEPIDLE, 10);
      setsockopt($socket, IPPROTO_TCP, TCP_KEEPINTVL, 5);
      setsockopt($socket, IPPROTO_TCP, TCP_KEEPCNT, 3);
    },

		'ServerInput'   => sub {
      my ($kernel, $heap, $msg) = @_[KERNEL, HEAP, ARG0];

			return unless $heap->{connected};
			return if $heap->{shutdown};

			my $payload = $msg->{payload};

      if ($msg->{op} == OPCODE_ERROR) {
				warn "ProtocolError: $payload";
	      $_[KERNEL]->delay(reconnect => 1);
			}
      elsif ($msg->{op} == OPCODE_INFO) {
        my $length = unpack("C", $payload);
        my $name = substr($payload, 1, $length);
        my $rand = substr($payload, $length + 1);

        $kernel->post($_[SESSION] => authenticate => $rand);

        local $_[ARG0] = \$name;
        ref $param->{'Connected'} eq 'CODE' && $param->{'Connected'}->(@_);
      }
      elsif ($msg->{op} == OPCODE_PUBLISH) {
        my $length = unpack("C", $payload);
        my $ident = substr($payload, 1, $length);
        my $rest = substr($payload, $length + 1);

        $length = unpack("C", $rest);
        my $channel = substr($rest, 1, $length);
        my $payload = substr($rest, $length + 1);

        local $_[ARG0] = $channel;
        local $_[ARG1] = $payload;
        ref $param->{'Publish'} eq 'CODE' && $param->{'Publish'}->(@_);
      }
      else {
        warn 'Unexpected op ' . ${msg}->{op};
        $kernel->delay(reconnect => 1);
      }
		},
		'ServerError'   => sub {
      my ($operation, $error_number, $error_string) = @_[ARG0..ARG2];
      warn "ServerError: $operation error $error_number occurred: $error_string";
      $_[KERNEL]->delay(reconnect => 1);
    },
		'ConnectError'  => sub {
      my ($operation, $error_number, $error_string) = @_[ARG0..ARG2];
      warn "ConnectError: $operation error $error_number occurred: $error_string";
      $_[KERNEL]->delay(reconnect => 1);
    },
		'SessionParams'  => [
      'options' => { 'trace' => 0 }
    ],
    'InlineStates' => {
      'authenticate' => sub {
        my ($heap, $rand) = @_[HEAP, ARG0];

				return unless $heap->{connected};
			  return if $heap->{shutdown};

        my $ident = $param->{Ident};
        my $secret = $param->{Secret};
        my $sig = Digest::SHA::sha1($rand . $secret);

        my $msg = {
          op => OPCODE_AUTH,
          payload => pack("C", length($ident)) . $ident . $sig,
        };

        $heap->{server}->put($msg);
      },
      'subscribe' => sub {
        my ($heap, $channel) = @_[HEAP, ARG0];

			  return unless $heap->{connected};
			  return if $heap->{shutdown};

        my $ident = $param->{Ident};
        my $payload = pack("C", length($ident)) . $ident;
        $payload .= $channel;

        my $msg = {
          op => OPCODE_SUBSCRIBE,
          payload => $payload,
        };

        $heap->{server}->put($msg);
      },
      'unsubscribe' => sub {
        my ($heap, $channel) = @_[HEAP, ARG0];

				return unless $heap->{connected};
			  return if $heap->{shutdown};

        my $ident = $param->{Ident};
        my $payload = pack("C", length($ident)) . $ident;
        $payload .= $channel;

        my $msg = {
          op => OPCODE_UNSUBSCRIBE,
          payload => $payload,
        };

        $heap->{server}->put($msg);
      },
      'publish' => sub {
        my ($heap, $channel, $data) = @_[HEAP, ARG0, ARG1];

				return unless $heap->{connected};
			  return if $heap->{shutdown};

        my $ident = $param->{Ident};
        my $payload = pack("C", length($ident)) . $ident;
        $payload .= pack("C", length($channel)) . $channel;
        $payload .= $data;

        my $msg = {
          op => OPCODE_PUBLISH,
          payload => $payload,
        };

        $heap->{server}->put($msg);
      }
    }
	) or croak "$self has error: $!";

  return $self;
}

1;

__END__
