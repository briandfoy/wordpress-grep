use ExtUtils::MakeMaker;

require 5.016;

print <<"HERE";
THIS IS ALPHA SOFTWARE. IT MIGHT CHANGE.
HERE

eval "use Test::Manifest 1.21";

my $main_file = 'lib/WordPress/Grep.pm';
WriteMakefile(
	'NAME'	        => 'WordPress::Grep',
	'ABSTRACT_FROM' => $main_file,
	'VERSION_FROM'  => $main_file,
	'LICENSE'       => 'perl',
	'AUTHOR'        => 'brian d foy <bdfoy@cpan.org>',
	
	'PREREQ_PM'    => { 
		'Test::More' => '0.95',
		'DBI'        => '0',
		'DBD::mysql' => '0',
		'Carp'       => '0',
		},

	clean  => { FILES    => q|WordPress-Grep-*| },
	);
