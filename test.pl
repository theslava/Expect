
use strict;
$^W = 1;			# warnings too
use Test;
use Config;

my $Perl = $^X;

BEGIN { plan tests => 16 }

use Expect;
$Expect::Exp_Internal = 0;

{
  my $exp = Expect->spawn("$Perl -v");
  ok(defined $exp);
  $exp->log_user(0);
  ok($exp->expect(10, "krzlbrtz", "Copyright") == 2);
  ok($exp->expect(10, "Larry Wall", "krzlbrtz") == 1);
  ok(not $exp->expect(3, "Copyright"));
}

{
  my $exp = new Expect;
  ok(defined $exp);
  $exp->log_stdout(0);
  $! = 0;
  ok(not defined $exp->spawn("Ignore_This_Error_Its_A_Test__efluna3w6868tn8"));
  ok($!);
  my $res = $exp->expect(20,
			 [ "Cannot exec" => sub{ ok(1); }],
			 [ eof => sub{ ok(0) }],
			 [ timeout => sub{ ok(0) }],
			);
  ok(defined $res and $res == 1);
}

{
  my @Strings =
    (
     "The quick brown fox jumped over the lazy dog.",
     "Ein Neger mit Gazelle zagt im Regen nie",
     "Was ich brauche ist ein Lagertonnennotregal",
    );

  my $exp = new Expect;
#  my $exp = new Expect ("$Perl -MIO::File -ne 'BEGIN {\$|=1; \$in = new IO::File \">reverse.in\" or die; \$in->autoflush(1); \$out = new IO::File \">reverse.out\" or die; \$out->autoflush(1); } chomp; print \$in \"\$_\\n\"; \$_ = scalar reverse; print \"\$_\\n\"; print \$out \"\$_\\n\"; '");


  print "isatty(\$exp): ";
  if (POSIX::isatty($exp)) {
    print "YES\n";
    eval { $exp->stty("raw") or die $!; };
    warn "\$exp->stty('raw'): $@\n" if $@;
  } else {
    print "NO\n";
  }

  print "isatty(\$exp->slave_pty): ";
  if (POSIX::isatty($exp->slave_pty)) {
    print "YES\n";
    eval { $exp->slave_pty->stty("raw") or die $!; };
    warn "\$exp->slave_pty->stty('raw'): $@\n" if $@;
  } else {
    print "NO\n";
  }

  $exp->spawn("$Perl -ne 'chomp; sleep 0; print scalar reverse, \"\\n\"'")
    or die "Cannot spawn $Perl: $!\n";
  my $called = 0;
  $exp->log_file(sub { $called++; });
  foreach my $s (@Strings) {
    my $rev = scalar reverse $s;
    $exp->send("$s\n");
    $exp->expect(10,
		 [ quotemeta($rev) => sub { ok(1); }],
		 [ timeout => sub { ok(0); die "Timeout"; } ],
		 [ eof => sub { ok(0); die "EOF"; } ],
		);
  }
  ok($called >= @Strings);

  my $randstring = 'fakjdf ijj845jtirg8e 4jy8 gfuoyhjgt8h gues9845th guoaeh gt98hae 45t8u ha8rhg ue4ht 8eh tgo8he4 t8 gfj aoingf9a8hgf uain dgkjadshftuehgfusand987vgh afugh 8h 98H 978H 7HG zG 86G (&g (O/g &(GF(/EG F78G F87SG F(/G F(/a sldjkf hajksdhf jkahsd fjkh asdHJKGDSGFKLZSTRJKSGOSJDFKGHSHGDFJGDSFJKHGSDFHJGSDKFJGSDGFSHJDGFljkhf lakjsdh fkjahs djfk hasjkdh fjklahs dfkjhasdjkf hajksdh fkjah sdjfk hasjkdh fkjashd fjkha sdjkfhehurthuerhtuwe htui eruth ZI AHD BIZA Di7GH )/g98 9 97 86tr(& TA&(t 6t &T 75r 5$R%/4r76 5&/% R79 5 )/&';
  my $maxlen;
  $exp->log_stdout(0);
  $exp->log_file("test.log");
  my $exitloop;
  $SIG{ALRM} = sub { die "TIMEOUT on send" };

  foreach my $len (1 .. length($randstring)) {
    my $s = substr($randstring, 0, $len);
    my $rev = scalar reverse $s;
    eval {
      alarm(10);
      $exp->send("$s\n");
      alarm(0);
    };
    if ($@) {
      ok($maxlen > 80);
      print "Warning: your raw pty blocks when sending more than $maxlen bytes!\n";
      $exitloop = 1;
      last;
    }
    $exp->expect(10,
		 [ quotemeta($rev) => sub {$maxlen = $len; }],
		 [ timeout => sub { ok($maxlen > 80);
				    print "Warning: your raw pty can only handle $maxlen bytes at a time!\n" ;
				    $exitloop = 1; } ],
		 [ eof => sub { ok(0); die "EOF"; } ],
		);
    last if $exitloop;
  }
  print "Good, your raw pty can handle at least ".length($randstring)." bytes at a time.\n" if not $exitloop;
  ok($maxlen > 80);
}

{
  my $exp = new Expect ("$Perl -ne 'chomp; sleep 0; print scalar reverse, \"\\n\"'")
    or die "Cannot spawn $Perl: $!\n";

  $exp->log_stdout(0);
  my $randstring = 'Fakjdf ijj845jtirg8e 4jy8 gfuoyhjgt8h gues9845th guoaeh gt98hae 45t8u ha8rhg ue4ht 8eh tgo8he4 t8 gfj aoingf9a8hgf uain dgkjadshftuehgfusand987vgh afugh 8h 98H 97BH 7HG zG 86G (&g (O/g &(GF(/EG F78G F87SG F(/G F(/a sldjkf hajksdhf jkahsd fjkh asdljkhASDJHARZF2345fegzhuLASDLKASHDJAHADjkahsdaSAHKHASKDHAKSHDAJKSHDf lakjsdh fkjahs djfk hasjkdh fjklahs dfkjhasdjkf hajksdh fkjah sdjfk hasjkdh fkjashd fjkha sdjkfhehurthuerhtuwe htui eruth ZI AHD BIZA Di7GH )/g98 9 97 86tr(& TA&(t 6t &T 75r 5$R%/4r76 5&/% R79 5 )/8';
  my $maxlen;
  my $exitloop;
  foreach my $len (1 .. length($randstring)) {
    my $s = substr($randstring, 0, $len);
    my $rev = scalar reverse $s;
    eval {
      alarm(10);
      $exp->send("$s\n");
      alarm(0);
    };
    if ($@) {
      ok($maxlen > 80);
      print "Warning: your default pty blocks when sending more than $maxlen bytes!\n";
      $exitloop = 1;
      last;
    }
    $exp->expect(10,
		 [ quotemeta($rev) => sub {$maxlen = $len; }],
		 [ timeout => sub { print "Warning: your default pty can only handle $maxlen bytes at a time!\n" ;
				    $exitloop = 1; } ],
		 [ eof => sub { ok(0); die "EOF"; } ],
		);
  }
  print "Good, your default pty can handle at least ".length($randstring)." bytes at a time.\n" if not $exitloop;
  ok($maxlen > 80);
}

{
  my $exp = new Expect($Perl . q{ -MIO::Handle -e 'open(TTY, "+>/dev/tty") or die "no controlling terminal"; autoflush TTY 1; print TTY "prompt: "; $s = <TTY>; chomp $s; print "got: $s\n"; close TTY; exit 0;'});

  my $pwd = "pAsswOrd";
  $exp->expect(10,
	       [ qr/^prompt:/, sub {
		   my $self = shift;
		   $self->send("$pwd\n");
		   exp_continue;
		 } ],
	       [ qr/^got:\s*(\w+)/, sub {
		   my $self = shift;
		   my ($s) = $self->matchlist;
		   chomp $s;
		   print "match: $s\n";
		   ok($s eq $pwd);
		 } ],
	       [ eof => sub {
		   ok(0); die "EOF";
		 } ],
	       [ timeout => sub {
		   ok(0); die "Timeout";
		 } ],
	      );
}
exit(0);



