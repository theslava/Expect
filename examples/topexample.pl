#!/usr/local/perl/bin/perl

require Expect;

#$Expect::Debug=1;
$Expect::Exp_Internal=0;
$Expect::Log_User=1;

$me = $ENV{'USER'};

# Initialize stdin for use.
$stdin=Expect->exp_init(\*STDIN);

$host = $ARGV[0];

unless ($ARGV[0] && ($ARGV[0] ne '--help'))
{
  print "Usage: $0 host\r\n";
  exit;
}

$telnet=Expect->spawn('telnet',$host);


$telnet->log_stdout(0);

# The quick and dirty test. Good if you don't care why an error occurs.
$telnet->expect(30,"gin: ") || die "Never got login prompt on $host";

print $telnet $me."\r";

# This is a little better. If you found errors occurring you'd probably want
# to turn debugging on and watch it.
($match,$error) =$telnet->expect(30,"ord: ");
die "Never got password prompt on $host, $error" if $error;

# Get password from user.
# Turn off echoing. We are getting a password after all.
$old_tty_setting =$stdin->exp_stty('-g');
$stdin->exp_stty('-echo');

# Print a password prompt if we're not echoing for the user.
print "Password for $me\@$host: " unless $telnet->log_stdout();
# Go until we get a return from STDIN.
($_,$error,$match,$before)=$stdin->expect(undef,"[\r\n]");
# print a newline to make output consistent.
print "\r\n";
$password = $before;
chomp($password);
print $telnet $password."\r";

# Okay, we can turn it back on again. Still don't need to log_stdout STDIN.
$stdin->exp_stty($old_tty_setting );

($_,$error)=$telnet->expect(30,"[\$\%\>\#]\s?","incorrect");

die "Never got shell prompt on $host, $error" if $error;

die "Try using a different password. Stopping " if /2/;

# Open logfile for writing. Pass through terminal filter.

$telnet->log_stdout(1);

open (LOGFILE,"|./term-filter.pl \> logfile.tmp");
$logfile=Expect->exp_init(\*LOGFILE);

print $telnet "exec top\r"; # Exec prevents return to shell after top exits.

$stdin->set_group($telnet); # Connect STDIN to telnet session
$telnet->set_group($logfile); # Connect telnet to logfile.
# Note that it isn't necessary to connect $telnet_obj to STDOUT.
# STDOUT is automatically connected unless you set $log_stdout(0)

# Let's make an escape sequence for ourselves.
$stdin->set_seq("\027","main::escape"); # \027 is Ctrl-W
# Alternately we could have said:
#$stdin->set_seq("\027",\&escape);

# Normally you would simply use interact.. this is just to show how one uses
# interconnect.
Expect::interconnect($stdin, $telnet); # Only files we read from.

exit;

sub escape {
  print "Got escape sequence.\r\n";
# return 1; # Don't exit, continue interconnection.
  return 0; # Exit, don't continue interaction.
}
