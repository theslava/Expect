
use strict;
use Test;
use Config;

my $Perl = $^X;

BEGIN { plan tests => 7 }

use Expect;

ok(1);

{
  my $exp = Expect->spawn("$Perl -v");
  $exp->log_user(0);
  ok($exp->expect(10, "krzlbrtz", "Copyright") == 2);
  ok($exp->expect(10, "Larry Wall", "krzlbrtz") == 1);
  ok(not $exp->expect(10, "Copyright"));
}

{
  my $exp = Expect->spawn("$Perl -v");
  $exp->log_user(0);
  my $by_larry;
  my $ver_from_v;
  my $ver_from_config = $Config{version};
  my $got_eof;
  expect(20, -i => $exp, 
	 [ 'version\s*(\S+)',
	   sub {
	     my $self = shift;
	     $ver_from_v = ($self->exp_matchlist)[0];
	     $ver_from_v =~ s/[^\d.]//g;
	     exp_continue;
	   }
	 ],
	 [ 'Copyright[^\r\n]*Larry Wall',
	   sub {
	     $by_larry = 1;
	     exp_continue;
	   }
	 ],
	 [ 'eof',
	   sub {
	     $got_eof = 1;
	   }
	 ],
	);
  ok($got_eof);
  ok($by_larry);
  ok($ver_from_v == $ver_from_config);
}
