# $Id: Makefile.PL,v 1.4 2004/07/04 17:04:17 comdog Exp $
use ExtUtils::MakeMaker;

require 5.006;

eval "use Test::Manifest 1.14";

WriteMakefile(
	'NAME'	       => '[% module %]',
	'ABSTRACT'     => 'This is what the module does',
	'VERSION_FROM' => 'lib/[% module_file %]',
	'LICENSE'      => 'perl',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',
	
	'PREREQ_PM'    => { 
		'Test::More' => '0',
		},

	'PM'           => {
		'lib/[% module_file %]'         => '$(INST_LIBDIR)/[% module_file %]',
		},

	'MAN3PODS'     => {
		'lib/[% module_file %]' => '$(INST_MAN3DIR)/[% module %].3',
		},

	clean  => { FILES    => q|[% module_dist %]-*| },

	);
