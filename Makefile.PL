use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
	      'NAME'	     => 'Expect',
	      'VERSION_FROM' => 'Expect.pm',
	      'PREREQ_PM'    => { 'IO::Stty' => '0.02',
                                  'IO::Tty' => '0.02',
                                  'IO::Pty' => '0.01',
				},
	      'dist'         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
	      );
