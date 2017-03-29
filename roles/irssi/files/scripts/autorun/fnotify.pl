use strict;
use warnings;
use vars qw($VERSION %IRSSI);
use Irssi;

$VERSION = '0.0.6';
%IRSSI = (
  name => 'fnotify',
  authors => 'Tyler Abair, Thorsten Leemhuis, James Shubin' .
  ', Serge van Ginderachter',
  contact => 'fedora@leemhuis.info, serge@vanginderachter.be',
  description => 'Write notifications to a file in a consistent format.',
  license => 'GNU General Public License',
  url => 'http://www.leemhuis.info/files/fnotify/fnotify https://ttboj.wordpress.com/',
);

#
# README
#
# To use:
# $ cp fnotify.pl ~/.irssi/scripts/fnotify.pl
# irssi> /load perl
# irssi> /script load fnotify
# irssi> /set fnotify_ignore_hilight 0 # ignore hilights of priority 0
#

#
# AUTHORS
#
# Ignore hilighted messages with priority = fnotify_ignore_hilight
# version: 0.0.6
# Tyler Abair <tyler.abair@gmail.com>
#
# Strip non-parsed left over codes (Bitlbee otr messages)
# version: 0.0.5
# Serge van Ginderachter <serge@vanginderachter.be>
#
# Consistent output formatting by James Shubin:
# version: 0.0.4
# https://ttboj.wordpress.com/
# note: changed license back to original GPL from Thorsten Leemhuis (svg)
#
# Modified from the Thorsten Leemhuis <fedora@leemhuis.info>
# version: 0.0.3
# http://www.leemhuis.info/files/fnotify/fnotify
#
# In parts based on knotify.pl 0.1.1 by Hugo Haas:
# http://larve.net/people/hugo/2005/01/knotify.pl
#
# Which is based on osd.pl 0.3.3 by Jeroen Coekaerts, Koenraad Heijlen:
# http://www.irssi.org/scripts/scripts/osd.pl
#
# Other parts based on notify.pl from Luke Macken:
# http://fedora.feedjack.org/user/918/
#

my %config;

Irssi::settings_add_int('fnotify', 'fnotify_ignore_hilight' => -1);
$config{'ignore_hilight'} = Irssi::settings_get_int('fnotify_ignore_hilight');

Irssi::signal_add(
    'setup changed' => sub {
        $config{'ignore_hilight'} = Irssi::settings_get_int('fnotify_ignore_hilight');
    }
);

#
# catch private messages
#
sub priv_msg {
  my ($server, $msg, $nick, $address, $target) = @_;
  my $msg_stripped = Irssi::strip_codes($msg);
  my $network = $server->{tag};
  filewrite('priv_hilight.txt', '' . $network . ' ' . $nick . ' ' . $msg_stripped);
}

#
# catch public messages
#
sub pub_msg {
  my ($server, $msg, $nick, $address, $target) = @_;
  my $msg_stripped = Irssi::strip_codes($msg);
  my $network = $server->{tag};
  filewrite('pub_channels.txt', '' . $network . ' ' . $nick . ' ' . $msg_stripped);
}

#
# catch 'hilight's
#
sub hilight {
  my ($dest, $text, $stripped) = @_;
  my $ihl = $config{'ignore_hilight'};
  if ($dest->{level} & MSGLEVEL_HILIGHT && $dest->{hilight_priority} != $ihl) {
    my $server = $dest->{server};
    my $network = $server->{tag};
    filewrite('priv_hilight.txt', $network . ' ' . $dest->{target} . ' ' . $stripped);
  }
}

#
# write to file
#
sub filewrite {
  my ($destination, $text) = @_;
  my $fnfile = Irssi::get_irssi_dir() . "/" . $destination;
  if (!open(FILE, ">>", $fnfile)) {
    print CLIENTCRAP "Error: cannot open $fnfile: $!";
  } else {
    print FILE $text . "\n";
    if (!close(FILE)) {
      print CLIENTCRAP "Error: cannot close $fnfile: $!";
    }
  }
}

#
# Truncate the contents of the log files
#
sub truncate_log_files {
  my $priv_file = Irssi::get_irssi_dir() . "/priv_hilight.txt";
  my $pub_file = Irssi::get_irssi_dir() . "/pub_channels.txt";

  # Truncate both the files
  open(FILE, ">" . $priv_file) or print CLIENTCRAP "Error: cannot truncate file $priv_file: $!";
  open(FILE, ">" . $pub_file) or print CLIENTCRAP "Error: cannot truncate file $pub_file: $!";
}

sub cleanup_log_files {
  my $priv_file = Irssi::get_irssi_dir() . "/priv_hilight.txt";
  my $pub_file = Irssi::get_irssi_dir() . "/pub_channels.txt";

  # Truncate both the files
  unlink $priv_file;
  unlink $pub_file;
}

#
# irssi signals
#
Irssi::signal_add_last("message private", "priv_msg");
Irssi::signal_add_last("message public", "pub_msg");
Irssi::signal_add_last("print text", "hilight");
Irssi::signal_add_last("window changed", "truncate_log_files");
Irssi::signal_add_last("gui exit", "cleanup_log_files");
