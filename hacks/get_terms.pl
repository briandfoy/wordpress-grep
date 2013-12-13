#!/usr/local/perls/perl-5.18.1/bin/perl
use v5.16;
use strict;
use warnings;

use WordPress::Grep;

binmode STDOUT, ':utf8';



my $wpgrep = WordPress::Grep->connect(
	database => 'running_wordpress',
	password => 'cat2meow',
	);

my $terms = $wpgrep->_get_terms();

say Dumper( $terms ); use Data::Dumper;

sub WordPress::Grep::_get_terms {
	my( $self, $post_ids ) = @_;
	use Carp qw(croak);
	say "Using my _get_terms";

	my $query =<<'SQL';
SELECT 
	wp_posts.ID, 
	wp_posts.post_title, 
	wp_terms.term_id, 
	wp_terms.name, 
	wp_term_taxonomy.term_taxonomy_id,  
	wp_term_taxonomy.parent, 
	wp_term_taxonomy.taxonomy
FROM 
	wp_posts
LEFT JOIN 
	wp_term_relationships ON wp_term_relationships.object_id = wp_posts.ID
LEFT JOIN 
	wp_term_taxonomy ON wp_term_taxonomy.term_taxonomy_id = wp_term_relationships.term_taxonomy_id
LEFT JOIN 
	wp_terms ON wp_terms.term_id = wp_term_taxonomy.term_id
WHERE
	wp_term_taxonomy.taxonomy IS NOT NULL
SQL

	my $sth = $self->db->prepare( $query );
	croak
		"Could not create statement handle\n\n" .
		"DBI Error: $DBI::Error\n\n" .
		"Statement-----\n$query\n-----\n"
		unless defined $sth;
	$sth->execute;

	my $terms = $sth->fetchall_hashref( [ qw(ID term_id) ] );
	}
