package POE::Filter::Hpfeeds;

use warnings;
use strict;

# ABSTRACT: A POE Filter for encoding and decoding the Hpfeeds protocol.

use Data::Dumper;

use Carp qw(carp croak);


sub new {
    my $class = shift;

    my $self = bless {
        buffer => '',
    }, $class;

    return $self;
}


sub get_one_start {
  my $self = shift;
  my $incoming = shift;

  $self->{buffer} .= join '', @$incoming;

  return;
}


sub get_one {
  my $self = shift;

  # Buffer must have at least enough in for a size and an opcode to return anything
  return [ ] unless (length $self->{buffer} > 5);

  my ($length, $op) = unpack("NC", $self->{buffer});

  # Buffer must have at least enough in for requested record to return anything
  return [ ] unless (length $self->{buffer} >= $length);

  my $payload = substr($self->{buffer}, 5, $length - 5);
  $self->{buffer} = substr($self->{buffer}, $length);

  my $result = {
    op => $op,
    payload => $payload,
  };

  return [ $result ];
}

sub put {
  my ($self, $records) = @_;

  my @raw = ();
  foreach my $rec (@$records) {
    my $length = 5 + length($rec->{payload});
    push @raw, pack("NC", $length, $rec->{op}) . $rec->{payload};
  }

  return \@raw;
}

1;
