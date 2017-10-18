package Travis::Utilities::Log;

=pod

=head1 NAME

  Travis::Utilities::Log - Log manager based on Moose.

=head1 VERSION

  This documentation refers to Travis::Utilities::Log version 0.02.

=head1 SYNOPSIS

  use Travis::Utilities::Log;

  my $log = Travis::Utilities::Log->new();
  $log->info('Hi, this is a log message.');

=head1 DESCRIPTION

This Moose class is a log manager that can throw typed message in standard
outputs and/or file outputs. It is highly configurable. Settings are attached
to PID at the first instance, hence, each further instances of this class
are automatically set.

=head1 AUTHORS

=over

=item Hugo Devillers - (hugo.devillers@gmail.com)

=item Travis Harrods - (travis.harrods@gmail.com)

=back

=cut

#==============================================================================
# Class TRAVIS::Utilities::Log is a log manager the allow to write logs data.
#
# Authors: Travis Harrods <travis.harrods@gmail.com>
#          Hugo Devillers <hugo.devillers@gmail.com>
# Created: 07-MAI-2015
# Updated: 24-JAN-2017
#==============================================================================

#==============================================================================
# REQUIEREMENTS
#==============================================================================
# OOp manager
use Moose;
# Base
use English;
use File::Basename;
use Term::ANSIColor; # A more readable way to put colors in terms.
use Term::ReadKey;   # Get stats from the term

# Emulate ANSI console on Windows systems
if( $^O eq 'MSWin32' ) {
  # TODO: test availability and disable color if not available.
  require Win32::Console::ANSI;
}


#==============================================================================
# STATIC PRIVATE VARIABLES
#==============================================================================
# Boolean indicating if the current loggin instance is the master
my $is_pid_master = 0;
# HTML color correspondance
my %html_colors = (
   "\e[32m" => 'green'
);


#==============================================================================
# ATTRIBUTS
#==============================================================================
our $VERSION = 0.02;
# PID of the process
has 'pid' => (
  is => 'ro',
  isa => 'Int',
  reader => 'get_pid',
  default => $PID
);
# Write to std
has 'sink_std' => (
  is => 'rw',
  isa => 'Bool',
  default => 1,
  reader => 'get_sink_std',
  writer => 'set_sink_std'
);
# Write to a file
has 'sink_file' => (
  is => 'rw',
  isa => 'Bool',
  default => 0,
  reader => 'get_sink_file',
  writer => 'set_sink_file'
);
# File name for output
has 'output_file' => (
  is => 'rw',
  isa => 'Str',
  default => 'output_log',
  reader => 'get_output_file',
  writer => 'set_output_file'
);
# Split file
has 'split_file' => (
  is => 'rw',
  isa => 'Bool',
  default => 0,
  reader => 'get_split_file',
  writer => 'set_split_file'
);
# Display level
has 'level' => (
  is => 'rw',
  isa => 'Int',
  default => 0,
  reader => 'get_level',
  writer => 'set_level'
);
# Display colours
has 'colours' => (
  is => 'rw',
  isa => 'Bool',
  default => 1,
  reader => 'get_colours',
  writer => 'set_colours',
);
# Colors are displayed in HTML mode
has 'html' => (
   is => 'rw',
   isa => 'Bool',
   default => 0,
   reader => 'get_html',
   writer => 'set_html'
);
# Max chararcter width
has 'width' => (
  is => 'rw',
  isa => 'Int',
  default => 80,
  reader => 'get_width',
  writer => 'set_width'
);

# Default message types
has 'default_message_types' => (
  traits => ['Hash'],
  is     => 'rw',
  isa    => 'HashRef',
  default => sub{ {
    info => {
      color     => 'white on_green',
      do_caller => 0,
      stderr    => 0,
      die       => 0
    },
    warning => {
      color     => 'white on_yellow',
      do_caller => 1,
      stderr    => 1,
      die       => 0
    },
    error   => {
      color     => 'white on_red',
      do_caller => 1,
      stderr    => 1,
      die       => 0
    },
    fatal   => {
      color     => 'white on_red',
      do_caller => 1,
      stderr    => 1,
      die       => 1
    },
    debug   => {
      color     => 'white on_cyan',
      do_caller => 1,
      stderr    => 0,
      die       => 0
    },
    trace   => {
      color     => 'white on_magenta',
      do_caller => 0,
      stderr    => 0,
      die       => 0
    }
  }},
  handles => {
    listMessageTypes => 'kv'
  }
);

has 'default_values' => (
  traits  => ['Hash'],
  is      => 'ro',
  isa     => 'HashRef',
  default => sub { {
    text      => 'hello, world',
    color     => 'white on_green',
    type      => 'LOG',
    do_caller => 0,
    stderr    => 0,
    die       => 0
  }},
  handles => {
    getDefault => 'get'
  }
);

# Default date color
has 'date_color' => (
  is      => 'rw',
  isa     => 'Str',
  default => 'bold bright_black'
);

# Maximal type length
has 'max_type_length' => (
  is      => 'rw',
  isa     => 'Int',
  default => 10
);

#==============================================================================
# BUILDER
#==============================================================================
sub BUILD
{
  my $self = shift;
  # The instance will be considered as PID master is no PID file is set.
  my $pid_file = '.'.$self->get_pid;
  if(-e $pid_file)
  {
    # The current instance is not a PID master
    # Load configuration from the master PID file
    open(PID, '<'.$pid_file);
    my $conf = <PID>;
    close(PID);
    my @tab = split(/;/, $conf);
    $self->set_level($tab[0]);
    $self->set_sink_std($tab[1]);
    $self->set_sink_file($tab[2]);
    $self->set_split_file($tab[3]);
    $self->set_output_file($tab[4]);
  }
  else
  {
    # Create the PID file that contains logging parameters
    open(PID, '>'.$pid_file);
    $is_pid_master = 1;
    print PID $self->get_level.';'.$self->get_sink_std.';'.$self->get_sink_file.
      ';'.$self->get_split_file.';'.$self->get_output_file;
    close(PID);
  }

  # Get terminal size
  my ($wchar, $hchar, $wpixel, $hpixel) = GetTerminalSize();
  $self->set_width($wchar);

  # Create the methods to display messages
  foreach my $kv ( $self->listMessageTypes() ) {
    $self->_add_message_type($kv->[0], $kv->[1]);
  }
}

#==============================================================================
# DESTRUCTOR
#==============================================================================
sub DEMOLISH
{
  my $self = shift;
  # If the current instance is the PID master, delete the PID file.
  if($is_pid_master == 1)
  {
    my $pid_file = '.'.$self->get_pid;
    if(-e $pid_file)
    {
      unlink $pid_file;
    }
  }
}

#==============================================================================
# PRIVATE METHODS
#==============================================================================
sub _add_message_type {
  my $self = shift;
  my $type = shift;
  my $args = shift;

  $self->meta->add_method( $type => sub {
    my $self = shift;
    my $text = shift;

    $args->{'text'} = $text;
    $args->{'type'} = uc $type;

    $self->message($args);
  });

}

sub _format_caller {
  my $self = shift;
  my $span = shift;

  my $call = "\n";
  my $depth = 2;
  my @info = caller($depth);
  while (@info) {
    $call .= $span.$info[0].': line '.$info[2].' ('.(basename($info[1])).")\n";
    $depth++;
    @info  = caller($depth);
  }
  return($call);
}

#==============================================================================
# METHODS
#==============================================================================
# Generic function to display a message
sub message {
  my $self = shift;
  my $args = shift;

  my @parameters = qw/type text color do_coller stderr die/;
  foreach my $p (@parameters) {
    if( !exists($args->{$p}) ) {
      $args->{$p} = $self->getDefault($p);
    }
  }

  # Prepare the date info
  my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  my $date = '['.sprintf("%02d %s %02d:%02d:%02d",
    $mday, $months[$mon], $hour, $min, $sec).']';

  # Prepare text message
  my $spacer = length($date) + $self->max_type_length() + 2;
  my $width = $self->get_width() - $spacer;
  my $span = " "x$spacer;
  $args->{'text'} =~ s/(.{$width})/$1\n$span/g;

  if( $args->{'do_caller'} ) {
    $args->{'text'} .= $self->_format_caller($span);
  }

  # Prepare type tag
  my $char_type = $self->format_type( $args->{'type'} );

  # Prepare text
  my $text_raw = $date.$char_type.': '.$args->{'text'}."\n";
  my $text_ansi = color($self->date_color()).$date.color('reset').
    color($args->{'color'}).$char_type.color('reset').': '.
    $args->{'text'}."\n";

  # Print message
  if( $self->get_sink_std() ) {
    if( $args->{'stderr'} ) {
      print STDERR $text_ansi;
    } else {
      print $text_ansi;
    }
  }

  # Print into file
  if( $self->get_sink_file() )
  {
    my $output = $self->get_output_file;
    if($self->get_split_file == 1)
    {
      $output .= '.'.$args->{'type'};
    }
    open(LOG, '>>'.$output);
    print LOG $text_raw;
    close(LOG);
  }

  # Need to die
  if( $args->{'die'} ) {
    exit(1);
  }

}

# Format type info
sub format_type {
  my $self = shift;
  my $type = shift;

  my $max_length = $self->max_type_length();
  my $type_length = length($type);
  my $left_spacer = int( ($max_length - $type_length)/2 );
  my $right_spacer = $max_length - $left_spacer - $type_length;

  my $char_type = (' 'x$left_spacer).$type.(' 'x$right_spacer);
  return($char_type);
}

# Generic function for printing messages
sub print_msg
{
  # Get arguments
  my $self = shift;
  my $type = shift;
  my $colour = shift;
  my $msg = shift;
  my $stderr = shift;
  my $call_id = shift;
  if(!defined($call_id))
  {
    $call_id = 0;
  }
  if(!defined($stderr))
  {
  	$stderr = 0;
  }

  # Retrieve call data
  if($type ne 'INFO')
  {
     my ($p, $f, $l) = caller($call_id);
     $f = basename($f);
     $msg.=' (in '.$f.', line '.$l.')';
  }

  # Format the message
  my $spacer = 13+length($type);
  my $width = $self->get_width - $spacer;
  my $span = " "x$spacer;
  $msg =~ s/(.{$width})/$1\n$span/g;

  # Prepare the date info
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  my $date = '['.sprintf("%02d:%02d:%02d", $hour, $min, $sec).']';

  # Prepare the message
  my $out_msg_nc = $date.' '.$type.': '.$msg."\n";
  my $out_msg_c = '';
  if($self->get_colours == 1)
  {
    if($self->get_html == 1)
    {
      $out_msg_c = '<B><span style="color:grey">'.$date.'</span>'.
         '<span style="color:'.$html_colors{$colour}.'">'.$type.'</span></B>'.$msg."\n";
    }
    else
    {
      $out_msg_c = "\e[90m\e[1m".$date."\e[0m ".$colour.$type."\e[39m: ".$msg."\n";
    }

  }
  else
  {
    $out_msg_c = $out_msg_nc;
  }

  # Print into stdout
  if($self->get_sink_std == 1)
  {
  	if($stderr == 1)
  	{
  		print STDERR $out_msg_c;
  	}
  	elsif($stderr == 2)
  	{
  		die $out_msg_c;
  	}
    else
    {
    	print STDOUT $out_msg_c;
    }
  }

  # Print into file
  if($self->get_sink_file == 1)
  {
    my $output = $self->get_output_file;
    if($self->get_split_file == 1)
    {
      $output .= '.'.$type;
    }
    open(LOG, '>>'.$output);
    print LOG $out_msg_nc;
    close(LOG);
  }
}

no Moose;

return(1);
