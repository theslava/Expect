use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $Is_Beta = 1;

WriteMakefile(
	      'NAME'	     => 'Expect',
	      'VERSION_FROM' => 'Expect.pm',
	      'PREREQ_PM'    => { 'IO::Stty' => '0.02',
                                  'IO::Tty' => '0.95',
                                  'IO::Pty' => '0.95',
				},
	      'dist'         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
	      );

print <<'__EOT__' if $Is_Beta;
**********************************************************************
WARNING: this is a BETA version.  If it works, good for you, if not,
tell me, <RGiersig@cpan.org> about it and I'll see what I can do.
**********************************************************************
__EOT__
