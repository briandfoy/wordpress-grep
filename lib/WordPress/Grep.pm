package WordPress::Grep;
use v5.14;
use strict;
use warnings;

use utf8;

use Carp qw(croak);
use DBI;

our $VERSION = '0.010_006';

=encoding utf8

=head1 NAME

WordPress::Grep - Search Wordpress titles and content

=head1 SYNOPSIS

	use WordPress::Grep;

	my $wp_grep = WordPress::Grep->connect(
		# required
		user     => $user,
		database => $db,

		# optional
		password => $pass,

		# has defaults
		host     => 'localhost',
		port     => '3306',
		);

	my $posts = $wp_grep->search(
		sql_like        => '....',
		regex           => qr/ ... /,
		code            => sub { ... },
		include_columns => [ ],  # not implemented
		exclude_columns => [ ],  # not implemented
		);

	foreach my $post_id ( keys %$post ) {
		printf "%4d %s\n",
			$posts->{$post_id}{ID}, $posts->{$post_id}{post_title};
		}

=head1 DESCRIPTION

[This is alpha software.]

This module allows you to search through the posts in a WordPress
database by directly examining the C<wp_posts> table. Forget about
these limited APIs. Use the power of Perl directly on the content.

I've long wanted this tool to examine consistency in my posts. I want
to check my use of CSS and HTML across all posts to check what I may
need to change when I change how I do things. This sort of thing is hard
to do with existing tools and the WordPress API (although there is a
L<WordPress::API>).

I want to go through all posts with all the power of Perl, so my
grep:

=over 4

=item 1 Takes an optional LIKE argument that it applies to C<post_title> and C<post_content>.

=item 2 Takes an optional regex argument that it uses to filter the returned rows, keeping only the rows whose titles or content that satisfy the regex.

=item 3 Takes a code argument that it uses to filter the returned rows, keeping only the rows which return true for that subroutine.

=item 4 Returns the matching rows in the same form that C<DBI>'s C<fetchall_hashref> returns. The top-level key is the value in the
C<ID> column.

=back

Right now, there are some limitations based on my particular use:

=over 4

=item * I only select the C<post> types.

=item * I assume UTF-8 everywhere, including in the database.

=item * Applying a regex or code filter always return (at least) the C<post_title> and C<post_content>.

=item * The LIKE and regex filters only work on C<post_title> and C<post_content>. The code filter gets the entire row as a hash reference and can do what it likes.

=back

I've set up a slave of the MySQL server that runs my WordPress
installations. In that slave, I set up a read-only user for this tool.

=head2 Methods

=over 4

=item connect

Connect to the WordPress database. You must specify these parameters,
which should be the same ones in your I<wp_config.php> (although if
you need this tool frequently, consider setting up a read-only user
for this, or run it against a slave).

	user
	database

If you need a password, you'll have to provide that:

	password

These parameters have defaults

	host	defaults to localhost
	port	defaults to 3306
	user    defaults to root

=cut

sub connect {
	my( $class, %args ) = @_;

	foreach my $required ( qw(database) ) {
		croak "You must set '$required' in connect()"
			unless defined $args{$required};
		}

	$args{host} //= 'localhost';
	$args{port} //= 3306;
	$args{user} //= 'root';

	my $dsn = "dbi:mysql:db=$args{database};host=$args{host};port=$args{port}";

	#dbi:DriverName:database_name
	#dbi:DriverName:database_name@hostname:port
	#dbi:DriverName:database=database_name;host=hostname;port=port

	my $db = DBI->connect( $dsn, $args{user}, $args{password} );
	croak "Could not connect to database [$args{host}:$args{port}]\n$DBI::Error"
		unless defined $db;
	my $self = bless {
		db       => $db,
		args     => \%args,
		}, $class;
	$self->_db_init;

	return $self;
	}

sub _db_init {
	my( $self ) = @_;

	$self->_db_utf8;
	}

sub _db_utf8 {
	my( $self ) = @_;

	my $sql = qq{SET NAMES 'utf8';};
	$self->db->do($sql);
	$self->db->{'mysql_enable_utf8'} = 1;
	}

=item db

Return the db connection. This is a vanilla DBI connection to MySQL.
If you subclass this, you can do further setup by overriding C<_db_init>.

=cut

sub db { $_[0]->{db} }

=item search

The possible arguments:

	sql_like - a string
	regex    - a regular expression reference (qr//)
	code     - a subroutine reference

    categories - an array reference of category names
    tags       - an array reference of tags names

This method first builds a query to search through the C<wp_posts>
table.

If you specify C<sql_like>, it limits the returned rows to those whose
C<post_title> or C<post_content> match that argument.

If you specify C<categories> or C<tags>, another query annotates the
return rows with term information. If the C<categories> or C<tags> have
values, the return rows are reduced to those that have those categories
or tags. If you don't want to reduce the rows just yet, you can use C<code>
to examine the row yourself.

If you specify C<regex>, it filters the returned rows to those whose
C<post_title> or C<post_content> satisfy the regular expression.

If you specify C<code>, it filters the returned rows to those for
which the subroutine reference returns true. The coderef gets a hash
reference of the current row. It's up to you to decide what to do with
it.

These filters are consecutive. You can specify any combination of them
but they always happen in that order. The C<regex> only gets the rows
that satisfied the C<sql_like>, and the C<code> only gets the rows
that satisfied C<sql_like> and C<regex>.

=cut

sub search {
	my( $self, %args ) = @_;

	$self->_set_args( \%args );
	$self->_check_args;

	my $query = $self->_get_sql;

	# filter results by the LIKE, directly in the SQL
	$query .= $self->_like_where_clause if defined $args{sql_like};
	$self->_set_query( $query );

	my $posts = $self->_get_posts;

	# filter posts by the regex
	if( defined $self->_args->{regex} ) {
		my $re = $self->_args->{regex};
		foreach my $post_id ( keys %$posts ) {
			delete $posts->{$post_id} unless
				(
				$posts->{$post_id}{post_title} =~ m/$re/
					or
				$posts->{$post_id}{post_content} =~ m/$re/
				);
			}
		}

	# filter posts by the sub
	if( defined $args{code} ) {
		foreach my $post_id ( keys %$posts ) {
			delete $posts->{$post_id}
				unless $args{code}->( $posts->{$post_id} );
			}
		}

	$self->_clear_search;

	return $posts;
	}

sub _query { exists $_[0]->{query} ? $_[0]->{query} : '' }
sub _set_query {
	my( $self, $query ) = @_;

	#XXX Can I figure out the number dynamically in a better way?
	my $param_count = () = $query =~ /\?/g;
	$self->_set_bind_params( [ ( $self->_args->{sql_like} ) x $param_count ] )
		if defined $self->_args->{sql_like};

	$self->{query} = $query;
	}

sub _bind_params { exists $_[0]->{bind_params} ? @{$_[0]->{bind_params}} : () }
sub _set_bind_params {
	croak "_set_bind_params must be an array reference" unless
		ref $_[1] eq ref [];
	$_[0]->{bind_params} = $_[1];
	}

sub _args { exists $_[0]->{args} ? $_[0]->{args} : {} }
sub _set_args {
	croak "_set_args must be a hash reference" unless
		ref $_[1] eq ref {};
	$_[0]->{args} = $_[1];
	}


sub _clear_search {
	my @clear_keys = qw( args sql bind_params );
	delete @{ $_[0] }{ @clear_keys };
	}

sub _check_args {
	my( $self ) = @_;

	if( exists $self->_args->{regex} ) {
		croak "'regex' value must be a regex reference [@{[$self->_args->{regex}]}]"
			unless ref $self->_args->{regex} eq ref qr//;
		}

	if( exists $self->_args->{code} ) {
		croak "'code' value must be a code reference"
			unless ref $self->_args->{code} eq ref sub {};
		}

	my @array_keys = qw( type categories tags include_columns exclude_columns );
	foreach my $array_arg ( @array_keys ) {
		next unless exists $self->_args->{$array_arg};
		croak "'$array_arg' value must be an array reference"
			unless ref $self->_args->{$array_arg} eq ref [];
		}

	return 1;
	}

sub _get_sql {
	'SELECT * FROM wp_posts WHERE post_type = "post"'
	}

sub _like_where_clause {
	' AND (post_title LIKE ? OR post_content LIKE ?)'
	}

sub _get_posts {
	my( $self ) = @_;
	my $sth = $self->db->prepare( $self->_query );
	croak
		"Could not create statement handle\n\n" .
		"DBI Error: $DBI::Error\n\n" .
		"Statement-----\n@{[$self->_query]}\n-----\n"
		unless defined $sth;
	$sth->execute( $self->_bind_params );

	my $posts = $sth->fetchall_hashref( 'ID' );

	if( $self->_include_terms ) {
		my @post_ids = keys %$posts;
		my $terms = $self->_get_terms;

		my %categories = map { $_, 1 } @{ $self->_args->{categories} };
		my %tags       = map { $_, 1 } @{ $self->_args->{tags} };

		# reduce the posts in
		foreach my $post_key ( @post_ids ) {
			my $this = $terms->{$post_key};

			my $found = 0;

			# if none are specified, include all
			$found = 1 if( 0 == keys %tags && 0 == keys %categories );

			my %this_tags =
				map  { $this->{$_}{name}, $this->{$_}{term_taxonomy_id} }
				grep { $this->{$_}{taxonomy} eq 'post_tag' }
				keys %$this;

			my %Seen_tags;
			my @found_tags = grep { ++$Seen_tags{$_} > 1 }
				keys %this_tags, keys %tags;
			$found += do {
				if( $self->_args->{tags_and} ) { @found_tags == keys %tags }
				else { scalar @found_tags }
				};

			my %this_categories =
				map  { $this->{$_}{name}, $this->{$_}{term_taxonomy_id} }
				grep { $this->{$_}{taxonomy} eq 'category' }
				keys %$this;
			my %Seen_categories;
			my @found_categories = grep { ++$Seen_categories{$_} > 1 }
				keys %this_categories, keys %categories;
			$found += do {
				if( $self->_args->{categories_and} ) { @found_categories == keys %categories }
				else { scalar @found_categories }
				};

			if( $found ) {
				$posts->{$post_key}{terms}      = $terms->{$post_key};
				$posts->{$post_key}{tags}       = [ keys %this_tags ];
				$posts->{$post_key}{categories} = [ keys %this_categories ];
				}
			else {
				delete $posts->{$post_key};
				}

			}
		}

	return $posts;
	}

sub _include_terms {
	$_[0]->_args->{categories} or $_[0]->_args->{tags};
	}

sub _get_terms {
	my( $self, $post_ids ) = @_;

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

	my $terms = $sth->fetchall_hashref( [ qw( ID term_id) ] );
	}

=back

=head1 TO DO


=head1 SEE ALSO

L<WordPress::API>

=head1 SOURCE AVAILABILITY

This source is in Github:

	http://github.com/briandfoy/wordpress-grep/

=head1 AUTHOR

brian d foy, C<< <briandfoy@pobox.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013-2025, brian d foy <briandfoy@pobox.com>. All rights reserved.

You may redistribute this under the Artistic License 2.0.

=cut

1;
