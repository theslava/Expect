#!/usr/local/bin/perl

use Expect;

# Turn off viewability.
$Expect::Log_Stdout=0;
#$Expect::Debug=1;
#$Expect::Exp_Internal=1;

unless ($ARGV[0] && $ARGV[0] ne '--help')
{
  print "Usage: $0 hostname\r\n";
  exit;
}

# Spawn an ftp process. point it at the host listed on the command line.
$ftp = Expect->spawn('ftp',$ARGV[0]);

# Build an 'email address' for anonymous login.
$user = $ENV{'USER'};
$hostname = `hostname`;
chomp $hostname;
# This is pretty twisted, but should work.
$domain_name = `grep -i domain /etc/resolv.conf`;
chop $domain_name;
$domain_name =~ s/domain\s*//i;
$hostname .= '.'.$domain_name if $domain_name; # For use in email address.


$ftp->expect(30,'Name\s.*:\s')|| die "Never got 'Name' prompt"; 
#die "Never got 'Name' prompt" unless defined($matched);# 0 indicates a match.

print $ftp "anonymous\r";

$ftp->expect(30,"word:") || die "Never got 'Password' prompt";

print $ftp "$user\@$hostname\r";

#230 = guest login ok.
$ftp->expect(30,"230")|| die "Couldn't log in to $ARGV[0]";

$ftp->expect(30,'\>\s') || die "Never got prompt after logging in to $ARGV[0]";

print $ftp "cd pub\r";

#250 CWD command successful
$ftp->expect(30,"250") || die "Couldn't change to dir. pub"; 

$ftp->expect(3,'\>\s') ||  die "Never got prompt after changing to dir. pub";

print "Successfully logged in to $ARGV[0] at dir. pub.\r\n";

# Print a new prompt since we goofed up the old one with the last print
# statement.
print "ftp> ";

$ftp->interact(); # Notice no escape character.

$ftp->close(); #Clean up after ourselves. Completely optional in
# this case.
exit;
