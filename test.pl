
use strict;
use Test;
use Config;

my $Perl = $^X;

BEGIN { plan tests => 11 }

ok(require Expect);
$Expect::Exp_Internal = 0;

{
  my $exp = Expect->spawn("$Perl -v");
  sleep 1;
  $exp->log_user(0);
  ok($exp->expect(10, "krzlbrtz", "Copyright") == 2);
  ok($exp->expect(10, "Larry Wall", "krzlbrtz") == 1);
  ok(not $exp->expect(5, "Copyright"));
}

{
  my $exp = Expect->spawn("efjlewhrerzuna3wc6tb83g6868tn8");
  sleep 1;
  my $has_eof = 0;
  my $res = $exp->expect(2,
			 [ eof => sub{ $has_eof = 1;}],
			);
  ok(not defined $res);
  skip($Config{archname} eq 'aix', $has_eof);
}

{
  my @Strings =
    (
     "The quick brown fox jumped over the lazy dog.",
     "Ein Neger mit Gazelle zagt im Regen nie",
     "Was ich brauche ist ein Lagertonnennotregal",
     " fakjdf ijj845jtirg8e 4jy8 gfuoyhjgt8h gues9845th guoaeh gt98hae 45t8u ha8rhg ue4ht 8eh tgo8he4 t8 gfj aoingf9a8hgf uain dgkjadshftuehgfusand987vgh afugh 8h 98H 978H 7HG zG 86G (&g (O/g &(GF(/EG F78G F87SG F(/G F(/a sldjkf hajksdhf jkahsd fjkh asdljkhf lakjsdh fkjahs djfk hasjkdh fjklahs dfkjhasdjkf hajksdh fkjah sdjfk hasjkdh fkjashd fjkha sdjkfhehurthuerhtuwe htui eruth",
    );

  my $exp = new Expect ("$Perl -ne 'chomp; sleep 0; print scalar reverse, \"\\n\"'");
  sleep 1;
  my $called = 0;
  $exp->log_file(sub { $called++; });
  foreach my $s (@Strings) {
    my $rev = scalar reverse $s;
    $exp->send("$s\n");
    $exp->expect(10,
		 [ quotemeta($rev) => sub { ok(1); }],
		 [ timeout => sub { ok(0); die "Timeout"; } ],
		 [ eof => sub { die "EOF"; } ],
		);
  }
  close $exp;
  ok($called >= 2*@Strings);
}

exit(0);
