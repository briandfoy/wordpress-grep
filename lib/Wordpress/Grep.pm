package Wordpress::Grep;
use v5.16;
use strict;
use warnings;

use subs qw();
use vars qw($VERSION);

use Carp qw(croak);
use DBI;

$VERSION = '0.010_001';

=encoding utf8

=head1 NAME

Wordpress::Grep - Search Wordpress titles and content

=head1 SYNOPSIS

	use Wordpress::Grep;

	my $wp_grep = Wordpress::Grep->connect(
		# required
		user =>
		password =>
		database =>

		# has defaults
		host     =>
		port     =>
		);
		
	my @posts = $wp_grep->search(
		sql_like        => '....',
		regex           => qr/ ... /,
		code            => sub { ... },
		type            => [ 'post', 'revision', 'page', 'attachment' ],
		include_columns => [ ],
		exclude_columns => [ ],
		);

=head1 DESCRIPTION


* Assumes UTF-8
* using regex always adds post_content and post_title

=over 4

=item connect

Connect to the WordPress database. You must specify these parameters, 
which should be the same ones in your I<wp_config.php> (although if 
you need this tool frequently, consider setting up a read-only user
for this, or run it against a slave).

	user
	password
	database

These parameters have defaults

	host	defaults to localhost
	port	defaults to 3306

=cut

sub connect {
	my( $class, %args ) = @_;
	
	foreach my $required ( qw(user password database) ) {
		croak "You must set '$required' in connect()" 
			unless defined $args{$required};
		}

	$args{host} //= 'localhost';
	$args{port} //= 3306;
	
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

Return the db connection

=cut

sub db { $_[0]->{db} }

=item search

=cut

sub search {
	my( $self, %args ) = @_;

	$self->_set_args( \%args );
	$self->_check_args;

	my $query = $self->_get_sql;
	
	# filter results by the LIKE, directly in the SQL
	$query .= $self->_like_where_clause if defined $args{sql_like};
	$self->_set_query( $query );
	
	#XXX Can I figure out the number dynamically in a better way?
	my $param_count = () = $query =~ /\?/g;
	$self->_set_bind_params( [ ( $args{sql_like} ) x $param_count ] ) 
		if defined $args{sql_like};

	my $posts = $self->_get_posts;
say "There are " . keys(%$posts) . " posts in the module";
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
	$_[0]->{query} = $_[1];
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
		croak "'regex' value must be a regex reference" 
			unless ref $self->_args->{regex} eq ref qr//;	
		}

	if( exists $self->_args->{code} ) {
		croak "'code' value must be a code reference" 
			unless ref $self->_args->{code} eq ref sub {};
		}

	my @array_keys = qw( type include_columns exclude_columns );
	foreach my $array_arg ( @array_keys ) {
		next unless exists $self->_args->{$array_arg};
		croak "'array_arg' value must be an array reference" 
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
	}

=back

=head1 TO DO


=head1 SEE ALSO


=head1 SOURCE AVAILABILITY

This source is in Github:

	http://github.com/briandfoy/wordpress-grep/

=head1 AUTHOR

brian d foy, C<< <bdfoy@gmail.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2013, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;
