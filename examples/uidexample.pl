#!/usr/local/bin/perl

use Expect;
# What's my uid?
$my_uid = $<; # Use ruid, in case of su.

# Initialize stdin for use.
$stdin=Expect->exp_init(\*STDIN);
$stdin->log_stdout(0); # Avoid double-echoing.

unless ($ARGV[0] && ($ARGV[0] ne '--help'))
{
  print "Usage: $0 host1 host2... hostn\r\n"; 
  exit;
}
HOST:
foreach $host (@ARGV)
{
  # ssh- more politically correct. You could use rsh.
  $rlogin=Expect->spawn('ssh -l '.$ENV{'USER'}." $host");
# Do we want the user to see what's going on?
  $rlogin->log_stdout(0);
  TOP:
  ($_,$error)=$rlogin->expect(30,"ssword: ","[\$\%\>\#]\s?");
  {
    $error && do
    {
      print "Didn't receive shell or password prompt, $error\r\n";
      next HOST;
    }; # The semicolon is necessary here for do.
    /1/ && do
    {
      # The password prompt will have been printed to the screen b/c
      # log_stdout hasn't been unset. We can therefore grab the
      # password from the user.
    # Save the old tty settings. We could have just assumed it was 'sane'.
    $old_tty_setting=$stdin->exp_stty('-g');
    # Turn off echoing. We are getting a password after all.
    $stdin->exp_stty('-echo');
    # Print a password prompt if we're not echoing for the user.
    print "Password for $host: " unless $rlogin->log_stdout();
    # Go until we get a return from STDIN.
    ($_,$error,$match,$before)=$stdin->expect(undef,"[\r\n]");
    # print a newline to make output consistent.
    print "\r\n";
    $password = $before;
    chomp($password);
    $stdin->exp_stty($old_tty_setting);
    # We are done with stdin. Don't close it, just remove the object.
    undef($stdin);
    print $rlogin $password."\r";
    goto TOP;
    }
  }
  # If we reach this point we've successfully logged in to a server.
  print $rlogin "id\r";
  ($_,$error,$match,$before)=$rlogin->expect(30,'[\$\%\>\#]\s?');
  $server_id=$before;
  $server_id=~/uid\s*\=\s*([0-9]+)/;
  $server_id=$1;
  if ($server_id == $my_uid)
  {
    # Caps are used here so the output would be easy to grep through.
    # We can log output by using tee.
    print "UID $my_uid on $host MATCHES that of ".$ENV{'USER'}." on the local host.\r\n";
  }
  else
  {
    print "UID $server_id on $host does NOT match UID $my_uid for ".$ENV{'USER'}." on the local host.\r\n";
  }
  # Close handle, remove object.
  $rlogin->close();
  undef($rlogin);
}
