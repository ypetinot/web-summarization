package Modalities;

use strict;
use warnings;

use Modality::NgrammableModality;

use JSON;

use Moose;
use namespace::autoclean;

# TODO
#has 'configuration_file' => ( is => 'ro' , isa => 'Str' , required => 1 );

has 'modality_definitions' => ( is => 'ro' , isa => 'ArrayRef[Modality]' , builder => '_build_modality_definitions' );
sub _build_modality_definitions {

    # CURRENT : each modality should be associated with a class that describes how it is generated from the raw object (?).
    # CURRENT : this class then defines the facet according to wich the modality can be seen ...
    
    # CURRENT : core = { url } # input
    # CURRENT : level_0 = { url , page , anchortext } # provided by UrlData

    # page.title
    # page.content
    # page.content.rendered
    # page.content.rendered.segmented
    # page.content.rendered.segmented.lm[1]
    # CURRENT : maybe not facets but really processing of what comes before ... => calculus ?
    # CURRENT : can (modality) facets be mutually exclusive ? If yes, then content and title could be two facets of page. If no, then they must treated as distinct modalities early on.

    # Content modality:
    # Roles: Renderable: takes raw content and produce array of text strings    

    # CURRENT : level_1 = { url , content , title , anchortext }
    # CURRENT : level_2 = { url:[blob|words] , content:[blob|rendered|segmented] , title:[blob|words] , anchortext:[basic|sentence] }
    # CURRENT : level_3 = { ... }

    # configuration ==> [ modality_name , is_fluent , [ can_be_ngram_ed , ngram_min_order , ngram_max_order , ngram_decoding_function , ngram_count_filter ] ]
    my $configuration = [
	[ 'content.rendered' , 1 , [ 1 , 1 , 3 , \&JSON::decode_json , 2 ] ],
#	[ 'content' , 1 , [ 1 , 1 , 3 , \&JSON::decode_json , 2 ] ],
	[ 'anchortext.sentence' , 1 , [ 1 , 1 , 3 , \&JSON::decode_json , 2 ] ],
	[ 'anchortext.basic' , 1 , [ 1 , 1 , 3 , \&JSON::decode_json , 2 ] ],
	[ 'title' , 1 , [ 1 , 1 , 3 , \&JSON::decode_json , 2 ] ],
	[ 'url.words' , 0 , [ 1 , 1 , 3 , \&JSON::decode_json , 2 ] ]
	];

    my @definitions = map {

	my $modality_configuration_parameters;
	
	$modality_configuration_parameters->{ id } = $_->[ 0 ];
	$modality_configuration_parameters->{ fluent } = $_->[ 1 ];
	
        # for now all modalities can be ngram-med $_->[ 2 ]->[ 0 ]
	$modality_configuration_parameters->{ ngram_min_order } = $_->[ 2 ]->[ 1 ];
	$modality_configuration_parameters->{ ngram_max_order } = $_->[ 2 ]->[ 2 ];
	$modality_configuration_parameters->{ ngram_data_loader } = $_->[ 2 ]->[ 3 ] unless ( ! $_->[ 2 ]->[ 3 ] );
	$modality_configuration_parameters->{ ngram_count_threshold } = $_->[ 2 ]->[ 4 ];

	new Modality::NgrammableModality( $modality_configuration_parameters );

    } @{ $configuration };

    return \@definitions;

}

# fluent modalities (?)
has 'modalities' => ( is => 'ro' , isa => 'ArrayRef[Modality]' , lazy => 1 , builder => '_build_modalities_list' );
sub _build_modalities_list {

    my $this = shift;

    my @modalities = grep { $_->fluent } @{ $this->modality_definitions };

    return \@modalities;
    
}

# modality index
has '_modality_index' => ( is => 'ro' , isa => 'HashRef[Modality]' , lazy => 1 , builder => '_modality_index_builder' );
sub _modality_index_builder {
    
    my $this = shift;
    
    my %modality_index;
    map { $modality_index{ $_->id } = $_; } @{ $this->modalities };

    return \%modality_index;

}

has 'modalities_ngrams' => ( is => 'ro' , isa => 'ArrayRef[Modality::NgrammableModality]' , lazy => 1 , builder => '_build_modalities_ngrams_list' );
sub _build_modalities_ngrams_list {

    my $this = shift;

    my @modalities_ngrammable = grep { ref( $_ ) eq 'Modality::NgrammableModality' } @{ $this->modality_definitions() };

    return \@modalities_ngrammable;

=pod
    foreach my $modality_definition (@modality_definitions) {

	my $modality_id = $modality_definition->id;
	my $modality_ngram_count_threshold = $modality_definition->ngram_count_threshold;

 	for ( my $ngram_order = $modality_definition->ngram_min_order; $ngram_order <= $modality_definition->ngram_max_order; $ngram_order++ ) {
	    push @modalities_ngram, [ join( "." , $modality_id , "ngrams" , $ngram_order ) , "binary" , "decode_json" ,
					  join( "::" , "count_filter" , $modality_ngram_count_threshold ) ];

	}

    }
=cut

=pod
    return [ 'content.rendered.ngrams.1/binary/decode_json/count_filter::2',
	     'content.rendered.ngrams.2/binary/decode_json/count_filter::2',
	     'content.rendered.ngrams.3/binary/decode_json/count_filter::2',
	     'anchortext.sentence.ngrams.1/binary/decode_json/count_filter::2',
	     'anchortext.sentence.ngrams.2/binary/decode_json/count_filter::2',
	     'anchortext.sentence.ngrams.3/binary/decode_json/count_filter::2',
	     'anchortext.basic.ngrams.1/binary/decode_json/count_filter::2',
	     'anchortext.basic.ngrams.2/binary/decode_json/count_filter::2',
	     'anchortext.basic.ngrams.3/binary/decode_json/count_filter::2',
	     'title.ngrams.1/binary/decode_json/count_filter::2',
	     'title.ngrams.2/binary/decode_json/count_filter::2',
	     'title.ngrams.3/binary/decode_json/count_filter::2',
	     'url.words.ngrams.1/binary/decode_json/count_filter::2',
	     'url.words.ngrams.2/binary/decode_json/count_filter::2',
	     'url.words.ngrams.3/binary/decode_json/count_filter::2'
	];
=cut

}

sub get_modality {

    my $this = shift;
    my $modality_id = shift;

    return $this->_modality_index->{ $modality_id };

}


has 'url_modality' => ( is => 'ro' , isa => 'Modality' , init_arg => undef , lazy => 1 , builder => '_url_modality_builder' );
sub _url_modality_builder {
    my $this = shift;
    return new Modality::UrlModality;
}

__PACKAGE__->meta->make_immutable;

1;
