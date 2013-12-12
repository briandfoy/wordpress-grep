use ExtUtils::MakeMaker;

require 5.016;

eval "use Test::Manifest 1.21";

my $main_file = 'lib/Wordpress/Grep.pm';
WriteMakefile(
	'NAME'	        => 'Wordpress::Grep',
	'ABSTRACT_FROM' => $main_file,
	'VERSION_FROM'  => $main_file,
	'LICENSE'       => 'perl',
	'AUTHOR'        => 'brian d foy <bdfoy@cpan.org>',
	
	'PREREQ_PM'    => { 
		'Test::More' => '0.95',
		'DBI'        => '0',
		},

	clean  => { FILES    => q|Wordpress-Grep-*| },

	);
