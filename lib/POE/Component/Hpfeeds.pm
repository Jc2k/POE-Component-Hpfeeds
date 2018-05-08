package POE::Component::Hpfeeds;
use strict;
use warnings;

use Data::Dumper;

use Carp 'carp', 'croak';
use Digest::SHA;
use POE::Session;
use POE::Filter::Hpfeeds;
use POE::Component::Client::TCP;

$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Useqq = 1;

our $VERSION = 0.1;


sub spawn {
	my $class = shift;
  my $self = {};
	my $param  =  {@_};

  bless($self, $class);

	croak "$self requires an even number of parameters" if @_ & 1;

  $self->{ident} = 'test';
  $self->{secret} = 'test';

	$self->{session_id} = POE::Component::Client::TCP->new(
    'RemoteAddress' => 'hpfeeds',
    'RemotePort' => '20000',
    #'BindAddress' => '127.0.0.1',
    #'BindPort' => '8080',

		'Filter'        => 'POE::Filter::Hpfeeds',

		'Connected'     => sub {},

		'ServerInput'   => sub {
      my ($kernel, $msg) = @_[KERNEL, ARG0];

      if ($msg->{op} == 1) {
        my $length = unpack("C", $msg->{payload});
        my $name = substr($msg->{payload}, 1, $length);
        my $rand = substr($msg->{payload}, $length + 1);

        $kernel->post($_[SESSION] => authenticate => $rand);

        local $_[ARG0] = \$name;
        ref $param->{'Connected'} eq 'CODE' && $param->{'Connected'}->(@_);
      }
      elsif ($msg->{op} == 3) {
        my $length = unpack("C", $msg->{payload});
        my $ident = substr($msg->{payload}, 1, $length);
        my $rest = substr($msg->{payload}, $length + 1);

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

        my $ident = $self->{ident};
        my $sig = Digest::SHA::sha1($rand . $self->{secret});

        my $msg = {
          op => 2,
          payload => pack("C", length($ident)) . $ident . $sig,
        };

        $heap->{server}->put($msg);
      },
      'subscribe' => sub {
        my ($heap, $channel) = @_[HEAP, ARG0];
        my $ident = $self->{ident};

        my $payload = pack("C", length($ident)) . $ident;
        $payload .= $channel;

        my $msg = {
          op => 4,
          payload => $payload,
        };

        $heap->{server}->put($msg);
      },
      'unsubscribe' => sub {
        my ($heap, $channel) = @_[HEAP, ARG0];
        my $ident = $self->{ident};

        my $payload = pack("C", length($ident)) . $ident;
        $payload .= $channel;

        my $msg = {
          op => 5,
          payload => $payload,
        };

        $heap->{server}->put($msg);
      },
      'publish' => sub {
        my ($heap, $channel, $data) = @_[HEAP, ARG0, ARG1];
        my $ident = $self->{ident};

        my $payload = pack("C", length($ident)) . $ident;
        $payload .= pack("C", length($channel)) . $channel;
        $payload .= $data;

        my $msg = {
          op => 3,
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
