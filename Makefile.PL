require 5.014;
use strict;
use warnings;


print <<"HERE";
THIS IS ALPHA SOFTWARE. IT MIGHT CHANGE.
HERE

my $github    = 'https://github.com/briandfoy/';
my $main_file = 'lib/WordPress/Grep.pm';

my %WriteMakefile = (
	'NAME'	        => 'WordPress::Grep',
	'ABSTRACT_FROM' => $main_file,
	'VERSION_FROM'  => $main_file,
	'LICENSE'       => 'perl',
	'AUTHOR'        => 'brian d foy <bdfoy@cpan.org>',

	'CONFIGURE_REQUIRES' => {
		'ExtUtils::MakeMaker' => '6.64',
		},

	'BUILD_REQUIRES' => {
		},

	'TEST_REQUIRES' => {
		'Test::More' => '0.95',
		},
	
	'PREREQ_PM'    => { 
		'DBI'        => '0',
		'DBD::mysql' => '0',
		'Carp'       => '0',
		},

	clean  => { FILES    => q|WordPress-Grep-*| },
	);

sub arguments { \%WriteMakefile }

do_it() unless caller;
sub do_it {
	require File::Spec;
	my $MM ='ExtUtils::MakeMaker';
	my $MM_version =
		eval{ "$MM " . $WriteMakefile{'CONFIGURE_REQUIRES'}{'ExtUtils::MakeMaker'} }
			//
		"$MM 6.64";
	eval "use $MM_version" || die "Could not load $MM_version: $@";
	eval "use Test::Manifest 1.21" 
		if -e File::Spec->catfile( qw(t test_manifest) );
	WriteMakefile( %WriteMakefile );
	}


no warnings;
__PACKAGE__;
