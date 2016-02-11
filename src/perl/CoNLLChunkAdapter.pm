package CoNLLChunkAdapter;

use strict;
use warnings;

use Carp::Assert;
use Text::Trim;

use Moose;
use namespace::autoclean;

sub _segment {
    my $that = shift;
    my $string = shift;
    my @components = grep { length( $_ ); } map { trim( $_ ) } split /(\s+|\(|\))/ , $string;
    return \@components;
}

sub map_2_conll_chunks {

    my $that = shift;
    my $string = shift;

    my $output_buffer_simple = $that->process_construct_simple( $string );
    
    return join( " " , @{ $output_buffer_simple } );

}

sub map_2_tree {

    my $that = shift;
    my $string = shift;
    my $node_builder = shift;
    
    # CURRENT : move to tree construction and use this tree to generate the CoNLL format => make sure both strings are identical
    my $output_buffer_wrapper = $that->process_construct_wrapper( $string , $node_builder );

    return $output_buffer_wrapper;

}

sub process_construct_simple {

    my $that = shift;
    my $raw_string = shift;

    # TODO : possible to avoid code duplication ?
    my $construct_buffer = $that->_segment( $raw_string );

    my $output_buffer = [];

    my $chunk_type = undef;
    my $chunk_type_count = undef;
    for ( my $i=0; $i<scalar( @{ $construct_buffer } ); $i++ ) {

	my $current_token = $construct_buffer->[ $i ];
	my $next_token = $construct_buffer->[ $i + 1 ];
	my $next_next_token = $construct_buffer->[ $i + 2 ];
	
	if (  $current_token eq '(' && $next_token =~ m/^[A-Z]+$/ && $next_next_token eq '(' ) {
	    $chunk_type = $next_token;
	    $chunk_type_count = 0;
	    $i++;
	}
	elsif ( $current_token eq '(' || $current_token eq ')' ) {
	    next;
	}
	else {

	    my $next_token_transliterated = _token_transliterate( $next_token );

	    my $token_sequence_label = ( $chunk_type =~ m/P$/ && $current_token !~ m/^\p{Punct}+$/ && $current_token !~ m/^\-[A-Z]+B\-$/ ) ?
		join( '-' , ( $chunk_type_count++ ? 'I' : 'B' ) , $chunk_type ) : 'O';
	    my $token_base = join( "/" , $next_token_transliterated , $current_token , $token_sequence_label );
	    push @{ $output_buffer } , $token_base;
	    $i++;
	}

    }

    return $output_buffer;

}

# construct tree
sub process_construct_wrapper {

    my $that = shift;
    my $raw_string = shift;
    my $node_builder = shift;

    # TODO : possible to avoid code duplication ?
    my $construct_buffer = $that->_segment( $raw_string );

    my $construct_buffer_from = 0;
    my $construct_buffer_to = $#{ $construct_buffer };

    my @trees;

    # 1 - make sure that both the first and last components are opening and closing brackets respectively
    my $from_is_opening_parenthesis = ( $construct_buffer->[ $construct_buffer_from ] eq '(' );
    my $to_is_opening_parenthesis = ( $construct_buffer->[ $construct_buffer_to ] eq ')' );
    affirm { ! ( ! $from_is_opening_parenthesis || ! $to_is_opening_parenthesis ) } "Must deal with parenthesized string at this point : $from_is_opening_parenthesis / $to_is_opening_parenthesis / $raw_string" if DEBUG;

    my $construct_buffer_cursor = ++$construct_buffer_from;

    # 2 - make sure the the second component is the ROOT marker
    if ( $construct_buffer->[ $construct_buffer_cursor ] ne 'ROOT' ) {
	die "Missing ROOT marker ...";
    }

    # 3 - process buffer
    while ( ++$construct_buffer_cursor < $construct_buffer_to ) {

	# 4 - collect balanced sets of parentheses and process
	my $balanced = 1;
	my $sentence_from = $construct_buffer_cursor;
	my $sentence_to   = $sentence_from;
	do {

	    my $current_token = $construct_buffer->[ $construct_buffer_cursor ];
	    $sentence_to = $construct_buffer_cursor++;
	    
	    if ( $current_token eq ')' ) {
		$balanced--;
	    }
	    elsif ( $current_token eq '(' ) {
		$balanced++;
	    }

	} while ( ( $balanced != 0 ) && ( $construct_buffer_cursor < $construct_buffer_to ) );

	# 5 - generate tree
	push @trees , generate_tree( $node_builder , $construct_buffer , $sentence_from , $sentence_to );


    }

    return \@trees;

}


# builds tree for the specified range
sub generate_tree {
    
    my $node_builder = shift;
    my $construct_buffer = shift;
    my $construct_buffer_from = shift;
    my $construct_buffer_to = shift;
    my $check_first_token = shift;
    my $_parent = shift;

    #p join( " " , map { $construct_buffer->[ $_ ] } ( $construct_buffer_from .. $construct_buffer_to) )

    # 1 - make sure that both the first and last components are opening and closing brackets respectively
    my $from_is_opening_parenthesis = ( $construct_buffer->[ $construct_buffer_from ] eq '(' );
    my $to_is_closing_parenthesis = ( $construct_buffer->[ $construct_buffer_to ] eq ')' );
    
    my $is_leaf = ! $from_is_opening_parenthesis && ! $to_is_closing_parenthesis;
    #if ( ! $from_is_opening_parenthesis || ! $to_is_opening_parenthesis ) {
    #	die "We have a structural problem : $from_is_opening_parenthesis / $to_is_opening_parenthesis";
    #}
    
    my $construct_buffer_cursor = $construct_buffer_from;
    my $construct_buffer_token = $construct_buffer->[ ++$construct_buffer_cursor ] ;

    my $root_token = $node_builder->( $is_leaf ,
				      ( $is_leaf ? _token_transliterate( join( " " , map { $construct_buffer->[ $_ ] } ( $construct_buffer_from .. $construct_buffer_to ) ) ) :
					$construct_buffer_token )
				      , $_parent ) || $construct_buffer_token;
    
    # b 148 ( ! ( $root_token ne '(' && $root_token ne ')' ) )
    affirm { $root_token ne '(' && $root_token ne ')' } "parentheses - as punctuation characters - cannot occur as tokens";
    
    # TODO : should this become an assertion as well ?
    if ( defined( $check_first_token ) && ( $root_token ne $check_first_token ) ) {
	die "Missing $check_first_token marker ...";
    }
    
    # create root node
    # TODO : make sure we do not duplicate code for node creation
    my $tree = Tree->new( $root_token );
    
    # CURRENT : if leaf, just return token object ?

    # Note : this sounds like a reasonable condition to end the recursion (is there a formal name for this concept ?)
    if ( ! $is_leaf ) {
	
	while ( ++$construct_buffer_cursor < $construct_buffer_to ) {
	    
	    my $sentence_from = $construct_buffer_cursor;
	    
	    # determine position of the end of the sentence then process
	    my $sentence_level = 0;
	    do {
		my $current_token = $construct_buffer->[ $construct_buffer_cursor++ ];
		if ( $current_token eq ')' ) {
		    $sentence_level--;
		}
		elsif ( $current_token eq '(' ) {
		    $sentence_level++;
		}
	    }
	    while ( $sentence_level != 0 );
	    
	    # TODO : should we excluding parentheses outside parentheses ?
	    # p join( " " , map { $construct_buffer->[ $_ ] } ( $construct_buffer_from .. $construct_buffer_to) )
	    my $sub_tree = generate_tree( $node_builder , $construct_buffer , $sentence_from , --$construct_buffer_cursor , undef , $tree );
	    
	    $tree->add_child( $sub_tree );
	    
	}

    }
    
    return $tree;
   
}

sub _token_transliterate {

    my $original_token = shift;

    my %mapping = ( '-LRB-' => '(' , '-RRB-' => ')' , '-LSB-' => '[' , '-RSB-' => ']' );
    my $mapped = $mapping{ $original_token };
    if ( defined( $mapped ) ) {
	return $mapped;
    }
    
    return $original_token;

}

__PACKAGE__->meta->make_immutable;

1;
