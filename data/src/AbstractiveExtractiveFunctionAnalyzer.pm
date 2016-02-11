package AbstractiveExtractiveFunctionAnalyzer;

use strict;
use warnings;

use File::Slurp;
use JSON;
use List::MoreUtils qw/uniq/;
use Text::Trim;

use Moose;
use namespace::autoclean;

extends 'Category::GlobalOperator';

sub _token_filter {

    my $this = shift;
    my $token = shift;

    return ( ( ( length( $token ) > 1 ) && ( $token !~ m/^\p{PosixPunct}+$/si ) ) || 0 );

}

# summary vocabulary (file)
has 'summary_vocabulary' => ( is => 'ro' , isa => 'Str' , required => 1 );

# summary vocabulary
has '_summary_vocabulary' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_summary_vocabulary_builder' );
sub _summary_vocabulary_builder {
    my $this = shift;
    my @vocabulary_entries = sort { length( $b ) <=> length( $a ) }
    uniq
	grep { $this->_token_filter( $_ ); }
    map { $this->_summary_token_normalizer( $_ ) }
    grep { $this->_token_filter( $_ ); }
    map { chomp; $_ } read_file( $this->summary_vocabulary );
    return \@vocabulary_entries;
}

# summary vocabulary index
has '_summary_vocabulary_index' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_summary_vocabulary_index_builder' );
sub _summary_vocabulary_index_builder {

    my $this = shift;
    
    my %vocabulary_index;
    map { $vocabulary_index{ $_ } = 1 } @{ $this->_summary_vocabulary };

    return \%vocabulary_index;

}

# summary vocabulary regular expression
#has '_summary_vocabulary_regex' => ( is => 'ro' , isa => 'RegexpRef' , init_arg => undef , lazy => 1 , builder => '_summary_vocabulary_regex_builder' );
has '_summary_vocabulary_regex' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_summary_vocabulary_regex_builder' );
sub _summary_vocabulary_regex_builder {

    my $this = shift;
    
    # TODO : why are the \W necessary to avoid over-fragmentation ?
#    my $summary_vocabulary_regexp_string = join( "|" , ( map { "(?:\W\Q${_}\E\W)" } @vocabulary_entries ) );
#    my $summary_vocabulary_regexp_string = join( "|" , ( map { qr/(?:\Q${_}\E)/ } @vocabulary_entries ) );
    my @vocabulary_regexes = map { qr/(?:(?:^|(?<=\W))\Q${_}\E(?=$|\W))/ } @{ $this->_summary_vocabulary };

###    my $summary_vocabulary_regexp_string = join( "|" , 
###    return qr/${summary_vocabulary_regexp_string}/;

    return \@vocabulary_regexes;

}

# output stats
has 'output_stats' => ( is => 'ro' , isa => 'Str' , predicate => 'has_output_stats' );

# record fields
has 'record_fields' => ( is => 'rw' , isa => 'ArrayRef' , predicate => 'has_record_fields' );

our $MARKER_COMBINABLE = '*';
our $MARKER_COUNTABLE = '+';
our $MARKER_AVERAGE = '/';
our $MARKER_KEY = '@';

# TODO : turn this into a library function (where does it belong ?)
sub _tokenize_url {

    my $url = shift;
    my $reference_tokens_fields;

    my $string = lc( $url );

    my %_url_tokens;
    my @reference_tokens = sort { length( $b ) <=> length( $a ) } keys( %{ $reference_tokens_fields } );
    foreach my $reference_token (@reference_tokens) {
	
	while ( $string =~ s/($reference_token)/ /sgi ) {
	    $_url_tokens{ $1 }++;
	}

	while ( $string =~ s/\s+/ /sgi ) {}
	$string = trim($string);
	
	if ( ! length( $string ) ) {
	    last;
	}

    }

    # finally split on punctuation and spaces to get the remaining tokens
    map { $_url_tokens{ $_ }++; } split /\p{Punct}|\s/ , $string;

    my @url_tokens = keys( %_url_tokens );
    return \@url_tokens;

}

my $fields_definition = {
    'summary' => { actual_field => 'summary.chunked.refined' , is_key => 1 },
    'content' => { actual_field => 'content.rendered' },
    'title'   => { actual_field => 'title' },
    'url'     => { actual_field => 'url.words' },
    'anchortext.extended' => { actual_field => 'anchortext.sentence' }
};

sub _process {

    my $this = shift;
    my $instance_id = shift;
    my $instance = shift;

    my $instance_record = {};

    my $instance_url = $instance->url;
    my $instance_category = $instance->get_category_id;
    my $instance_data_path = $instance->category_data->category_data_base;
    my $instance_has_anchortext = $instance->has_field( 'anchortext' ) || 0;

    my $regex = $this->_summary_vocabulary_regex;

    # data might be corrupted for a few categories - this is not unexpected but should be fixed in the long run
    eval {

	# 1 - get summary tokens
	# CURRENT : use summary.*.refined

	my %instance_summary_tokens;

	my %field2appearance;
 	foreach my $field (keys( %{ $fields_definition })) {

	    my $field_definition = $fields_definition->{ $field };
	    my $field_actual = $field_definition->{ 'actual_field' };
	    my $field_is_key = $field_definition->{ 'is_key' } || 0;

	    if ( ! $instance->has_field( $field_actual ) ) {
		next;
	    }
	    my $field_content = $instance->get_field( $field_actual );

	    # TODO : specific tokenization/chunking behavior via anonymous sub
	    my @field_tokens;

	    if ( $field_is_key ) {
		# TODO : how can we avoid duplicating the normalization for this specific set of tokens ?
		@field_tokens = grep { $this->_token_filter( $_ ); } map { my @_token_fields = split /\//, $_; $this->_summary_token_normalizer( $_token_fields[ 0 ] ); } split /\t/ , $field_content;
		for (my $i=0; $i<=$#field_tokens; $i++) {
		    my $summary_token = $field_tokens[ $i ];
		    $instance_summary_tokens{ $summary_token } = $i;
		}
	    }
	    # Note : this implies that url.words should be processed last (or at least after the necessary sources of reference tokens)
	    elsif ( $field_actual eq 'url.words' ) {
		@field_tokens = @{ _tokenize_url( $instance_url , \%field2appearance ) };
	    }
	    elsif ( ( $field_actual eq 'anchortext.sentence' ) && $instance_has_anchortext ) {
		my $modality_anchortext_sentence = $instance->get_modality( $field_actual );
		my $ngram_order = 1;
		my ( $modality_order_ngrams , $mapping , $mapping_surface ) = $instance->get_modality_data( $modality_anchortext_sentence , $ngram_order , 1 , 1 );
		@field_tokens = map { $mapping_surface->{ $_ }; } keys( %{ $modality_order_ngrams } );
	    }
	    else {
###		@field_tokens = split /\s+/ , $field_content;
		@field_tokens = ( $field_content );
	    }
	    
	    my @field_tokens_normalized = map { $this->_summary_token_normalizer( $_ ) } grep { length( $_ ) && ( $_ !~ m/^\p{Punct}+$/si ) } uniq @field_tokens;
###	    map { $field2appearance{ $_ }{ $field } = 1; } @field_tokens_normalized;

	    # TODO : how can I clean this up ?
	    if ( $field_is_key ) {
		map { $field2appearance{ $_ }{ $field } = 1; } @field_tokens_normalized;
	    }
	    else {
=pod
		while ( $field_content =~ m/($regex)/sgio ) {
		    $field2appearance{ $1 }{ $field } = 1;
		}
=cut

# NOTE : might not be necessary
my $field_content_copy = $field_content;
foreach my $_regex (@{ $regex }) {
    while ( $field_content_copy =~ s/($_regex)/ [[_]] /sgi ) {
	my $match = $1;
	if ( ! defined( $this->_summary_vocabulary_index->{ $match } ) ) {
	    die "Unknown vocabulary word : $match";
	}
	$field2appearance{ $match }{ $field } = 1;
    }
}

=pod
# Split version
my $field_content_copy = $field_content;
my @regex_chunks = ( $field_content_copy );
foreach my $_regex (@{ $regex }) {

    my @regex_chunks_new;
    while ( $#regex_chunks >= 0 ) {

	my $current_chunk = shift @regex_chunks;
	my @_chunks = split /$_regex/si , $current_chunk;

	if ( $#_chunks > 0 ) {
	    my $match = '';
	    $field2appearance{ $match }{ $field } = 1;
	}

	push @regex_chunks_new , @_chunks;

    }

    @regex_chunks = @regex_chunks_new;

}
=cut

	    }
   
	}
	
	# 2 - refine spans using other entries in the same category ?
	# TODO
	
	# TODO : remove title portion from content (create the notion of 'body')

=pod
    # 2 - iterate over summary tokens
    for (my $i=0; $i<=$#instance_summary_tokens; $i++) {
	
	my $instance_summary_token = $instance_summary_tokens[ $i ];
	my $relative_position = $i ? ( $i / $#instance_summary_tokens ) : 0;
	
	$this->_update_record( $instance_record , 'summary_token' , lc( $instance_summary_token ) , $MARKER_KEY );
	$this->_update_record( $instance_record , 'url' , $instance_url );
	$this->_update_record( $instance_record , 'category' , $instance_category );
	$this->_update_record( $instance_record , 'relative_position' , $relative_position , $MARKER_AVERAGE );
	
	my $appears_in_content = ( ( $instance_content =~ m/$instance_summary_token/si ) || 0 );
	$this->_update_record( $instance_record , 'appears_in_content' , $appears_in_content , $MARKER_COUNTABLE );
	
	my $appears_in_title = ( ( $instance_title =~ m/$instance_summary_token/si ) || 0 );
	$this->_update_record( $instance_record , 'appears_in_title' , $appears_in_title , $MARKER_COUNTABLE );
	
	$this->_update_record( $instance_record , 'has_anchortext' , $instance_has_anchortext , $MARKER_COUNTABLE );
	
	my $appears_in_anchortext_sentence = ( ( $instance_anchortext_sentence =~ m/$instance_summary_token/si ) || 0 );
	$this->_update_record( $instance_record , 'appears_in_anchortext_sentence' , $appears_in_anchortext_sentence , $MARKER_COUNTABLE );
	
	my $appears_in_url = ( ( $instance_url =~ m/$instance_summary_token/si ) || 0 );
	$this->_update_record( $instance_record , 'appears_in_url' , $appears_in_url , $MARKER_COUNTABLE );
	
	my $appears_in_anchortext = $appears_in_anchortext_sentence;
	my $appears_in_modalities = $appears_in_content || $appears_in_title || $appears_in_anchortext || $appears_in_url;
	$this->_update_record( $instance_record , 'appears_in_modalities' , $appears_in_modalities , $MARKER_COUNTABLE );
	
	    $this->_compile_record( $instance_record );
	
}
=cut

	my $instance_summary_tokens_count = scalar( keys( %instance_summary_tokens ) );

	# 2 - iterate over tokens
	foreach my $token (keys( %field2appearance )) {
	    
	    $this->_update_record( $instance_record , 'summary_token' , $token , $MARKER_KEY );
	    $this->_update_record( $instance_record , 'instance_id' , $instance_id );
	    $this->_update_record( $instance_record , 'has_anchortext' , $instance_has_anchortext , $MARKER_COUNTABLE );
	    
	    my $key_appearance;
	    my %modalities_appearance;
	    
	    my $appears_in_modalities = 0;
	    foreach my $field (keys( %{ $fields_definition })) {
		my $field_definition  = $fields_definition->{ $field };
		my $appears_in_field = defined( $field2appearance{ $token }{ $field } ) || 0;
		$this->_update_record( $instance_record , "appears_in_${field}" , $appears_in_field , $MARKER_COUNTABLE );
		if ( ! $field_definition->{ 'is_key' } ) {
		    $appears_in_modalities ||= $appears_in_field;
		    $modalities_appearance{ $field } = $appears_in_field;
		    # TODO : try to optimize this update ?
		    $modalities_appearance{ 'modalities' } = $appears_in_modalities;
		}
		else {
		    my $relative_position = $appears_in_field ? ( ( $instance_summary_tokens{ $token } / $instance_summary_tokens_count ) || 0 ) : 'N/A';
		    $this->_update_record( $instance_record , 'relative_position' , $relative_position , $MARKER_AVERAGE );
		    $key_appearance = $appears_in_field;
		}
	    }
	    $this->_update_record( $instance_record , 'appears_in_modalities' , $appears_in_modalities , $MARKER_COUNTABLE );
	    
	    foreach my $field (keys( %modalities_appearance )) {
		my $appears_in_field = $modalities_appearance{ $field };
		my $appears_in_key_and_field = $key_appearance * $appears_in_field;
		$this->_update_record( $instance_record , "appears_in_summary_and_${field}" , $appears_in_key_and_field , $MARKER_COUNTABLE );
	    }
	    
	    $this->_compile_record( $instance_record );
	    
	}
	
    };
    
    if ( $@ ) {
	my $instance_url = $instance->url();
	print STDERR ">> An error occurred while processing instance $instance_url: $@\n";
    }
    
}

sub _summary_token_normalizer {
    
    my $this = shift;
    my $token = shift;
    
    # we remove trailing periods and commas
    my $token_normalized = lc( $token );
    # TODO : generate regular expressions automatically
    $token_normalized =~ s/^(\.|\,|\"|\'|\;|\:)+//si;
    $token_normalized =~ s/(\.|\,|\"|\'|\;|\:)+$//si;
    trim( $token_normalized );

    return $token_normalized;

}

sub _update_record {

    my $this = shift;
    my $instance_record = shift;
    my $key = shift;
    my $value = shift;
    my $marker = shift || '';

    $instance_record->{ $marker . $key } = $value;

}

sub _compile_record {
    
    my $this = shift;
    my $instance_record = shift;

    if ( ! $this->has_record_fields ) {
	# Note : fields without marker should go first ==> use priorities
	my @record_fields = sort {
	    my $_a_key_test= ( $a =~ m/^${MARKER_KEY}/ ) || 0;
	    my $_b_key_test = ( $b =~ m/^${MARKER_KEY}/ ) || 0;
	    if ( $_a_key_test && $_b_key_test ) {
		die "Currently we do not support multi-field keys ...";
	    }
	    elsif ( $_a_key_test ) {
		-1;
	    }
	    elsif ( $_b_key_test ) {
		1;
	    }
	    else {
		$a cmp $b;
	    }
	} keys( %{ $instance_record } );
	$this->record_fields( \@record_fields );
	if ( $this->job_id == 1 ) {
	    print join( "\t" , @record_fields ) . "\n";
	}
    }

    print join( "\t" , map { $instance_record->{ $_ } } @{ $this->record_fields } ) . "\n";
    
}

sub _finalize {

    my $this = shift;

    if ( $this->has_output_stats ) {

	my %stats;
	$stats{ 'instance_count' } = $this->instance_count;

	open OUTPUT_STATS , sprintf( ">%s" , $this->output_stats ) or die sprintf( "Unable to create stats output file (%s): $!" , $this->output_stats );
	print OUTPUT_STATS encode_json( \%stats );
	close OUTPUT_STATS;

    }

}

__PACKAGE__->meta->make_immutable;

1;
