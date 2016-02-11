package TargetAdapter::ConfusionNetworkTargetAdapter;

use strict;
use warnings;

use Digest::MD5 qw(md5 md5_hex md5_base64);
use File::Temp;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter' );

# TODO : to be removed unless I can make the claim that this is a generic feature to be supported by UrlData
# CURRENT/Note : moving to a solution where the lm is built dynamically in ConfusionNetworkTargetAdapter => in any case allows to collect all the necessary code in a single Perl module
# lm
# TODO : this should be - configurable - interpolated language model
has 'lm' => ( is => 'ro' , isa => 'File::Temp' , init_arg => undef , lazy => 1 , builder => '_lm_builder' );
sub _lm_builder {

    my $this = shift;

    # TODO : this should probably not be hard-coded
    my $target_content = join ( ' ' , @{ $this->target->get_field( 'content.rendered' ) } );

    # 1 - create temp file to hold the lm
    my $lm_file = File::Temp->new( UNLINK => 1 , SUFFIX => '.lm' );

    # TODO : should we be doing better ?
    my $ngram_order = 5;
    # TODO : is there a more elegant way of generating the command ?
    my $third_party_bindir = Environment->third_party_local_bin;

    my $temp_content_file = File::Temp->new;
    print $temp_content_file $target_content;
    $temp_content_file->close;

    `cat $temp_content_file | ${third_party_bindir}/ngram-count -text - -order ${ngram_order} -sort -no-sos -no-eos -unk -lm ${lm_file} -write-binary-lm`;
    if ( $? ) {
	print STDERR "Unable to generate target language model ...\n";
	$lm_file = undef;
    }

    unlink $temp_content_file;

    return $lm_file;

}

# given a CN object, performs CN-based decoding
sub _adapt {

    my $this = shift;
    my $original_sentence = shift;
    my $alignment = shift;

    my @original_sequence;
    my @replacement_candidates;
    my $adapted_sequence;

    my $n_tokens = $original_sentence->length;
    my $has_extractive_locations = 0;
    for (my $i=0; $i<$n_tokens; $i++) {
	    
	my $original_sentence_token = $original_sentence->object_sequence->[ $i ];
	my $original_sentence_token_surface = $original_sentence_token->surface;

	# TODO : we should be using regexes instead ?
	my $candidate =  $alignment->{ $original_sentence_token_surface };
	if ( defined( $candidate ) ) {
	    $has_extractive_locations++;
	}

	push @original_sequence, $original_sentence_token;
	push @replacement_candidates , $candidate;

    }

    # 1 - first check aligned sequence to see if it contains extractive locations
    if ( $has_extractive_locations ) {

	print STDERR ">> sentences has extractive locations ==> performing confusion network adaptation ...\n";

	# *****************************************************************************************************************************
	# build confusion network
	# *****************************************************************************************************************************
	
	# TODO : make this a field ?
	my $token_total_occurrences = $this->global_data->global_count( 'summary' , 1 );
	
	my @aligns;
	for (my $i=0; $i<$n_tokens; $i++) {
	    
	    my $token = $original_sequence[ $i ];
	    my $data  = $replacement_candidates[ $i ];

	    my $token_surface_original;
	    my $token_surface_probability_replace;
	    my $token_alternatives;

	    # TODO : can we do better (i.e. avoid declaring the variables of interest separately)
	    if ( $token->is_slot_location ) {
		$token_surface_original = $token->original_sequence_surface;
		$token_surface_probability_replace = $token->extractive_probability;
		$token_alternatives = $data;
	    }
	    else {
		$token_surface_original = $token->surface;
		$token_surface_probability_replace = 0;
		$token_alternatives = {};
	    }

	    my $token_surface_probability_preserve = 1 - $token_surface_probability_replace;	    
	    my $token_surface_normalized = lc( $token_surface_original );
	    
	    push @aligns , [ $token_surface_original , $token_surface_normalized , $token_surface_probability_preserve , $token_surface_probability_replace , $token_alternatives ];

	}
	
	my $num_aligns = scalar( @aligns );
	
	my $confusion_network_fh = File::Temp->new;
	my $confusion_network_filename = $confusion_network_fh->filename;
	# TODO : move this to UrlData ?
	my $original_sentence_object_url = Encode::encode_utf8( $original_sentence->object->url );
	print $confusion_network_fh "name $original_sentence_object_url\n";
	print $confusion_network_fh "numaligns $num_aligns\n";
	# TODO : use the reference/sentence score instead ?
	print $confusion_network_fh "posterior 1\n";
	
	my @unknowns;
	for ( my $i = 0 ; $i <= $#aligns ; $i++ ) {
	    
	    my $align = $aligns[ $i ];
	    my ( $token_surface , $token_surface_normalized , $token_surface_probability_preserve , $token_surface_probability_replace , $token_alternatives ) = @{ $align };
	    
	    my $is_unknown = 0;
	    
	    my @token_alternatives_keys = keys( %{ $token_alternatives } );
	    my $n_alternatives = scalar( @token_alternatives_keys );
	    
	    # token alternatives filtered / normalization factor
	    my %token_alternatives_filtered;

	    # Note : the original sequence cannot possibly (should not) require filtering
	    my @token_alternatives_surface;

	    my $normalization_factor = 0;

	    foreach my $alternative_token (@token_alternatives_keys) {

		my $alternative_score = $token_alternatives->{ $alternative_token };
		
		push @token_alternatives_surface , $alternative_token;	       		

		# store alternative (unnormalized) probability
		$token_alternatives_filtered{ $alternative_token } = $alternative_score;;
		
		# update normalization factor
		$normalization_factor += $alternative_score;
		
	    }

	    # normalize alternative probabilities
	    map { $token_alternatives_filtered{ $_ } *= $token_surface_probability_replace / $normalization_factor } keys( %token_alternatives_filtered );

	    # add original option
	    unshift @token_alternatives_surface , $token_surface_normalized;
	    $token_alternatives_filtered{ $token_surface_normalized } = $token_surface_probability_preserve;
	    
	    # create confusion network entry
	    my $confusion_network_line = "align $i " . join( " " , map {
		( join( "_" , split ( /\s+/ , $_ ) ) , $token_alternatives_filtered{ $_ } ) } @token_alternatives_surface );
	    print $confusion_network_fh "$confusion_network_line\n"; 
	    
	    # Note : not needed since there is no correct word ...
	    # print $confusion_network_fh "reference $i " ...
	    
	}

	$confusion_network_fh->close;
	
	# *****************************************************************************************************************************
	# decode lattice
	
	# TODO : make the odp lm location configurable
	# CURRENT / TODO : how to configure environment dynamically / at run-time ?
	my $lm_file_odp = "/proj/nlp/users/ypetinot/ocelot/svn-research/trunk/data/ngrams/summary/5/-gt1min+++10+++-gt2min+++10+++-gt3min+++10+++-gt4min+++10+++-gt5min+++10+++-unk.model";
#	my $lm_file_odp = join( '/' , Environment->data_base , "ngrams/summary/5/-gt1min+++10+++-gt2min+++10+++-gt3min+++10+++-gt4min+++10+++-gt5min+++10+++-unk.model" );
	my $lm_file_target = $this->lm;
	
	my $third_party_local_bin = Environment->third_party_local_bin;
	my $decoding_mode = "-viterbi-decode";
	#my $decoding_mode = "-posterior-decode";
	my $decoder_command = "${third_party_local_bin}/lattice-tool -read-mesh ${decoding_mode} -in-lattice ${confusion_network_filename} -lm ${lm_file_target} -mix-lm ${lm_file_odp} -no-nulls -split-multiwords -tolower -order 3 -max-time 60 -lambda 0.99 | cut -d ' ' --complement -f1";
###	my $decoder_command = "${third_party_local_bin}/lattice-tool -read-mesh ${decoding_mode} -in-lattice ${confusion_network_filename} -lm ${lm_file_target} -no-nulls -split-multiwords -tolower -order 3 -max-time 60 -lambda 0.8 | cut -d ' ' --complement -f1";
	# TODO : make this "more" optional ? => i.e. create a special flag for this type of logging ?
	if ( $this->has_output_directory ) {
	    my $plot_png_filename = join( '.' , join( "/" , $this->output_directory , __PACKAGE__ , 'lattices' , md5_hex( $original_sentence_object_url ) . md5_hex( $original_sentence->verbalize ) ) , 'png' );
	    `/bin/bash -c 'dot -Tpng <( ${third_party_local_bin}/wlat-to-dot ${confusion_network_filename} ) -o ${plot_png_filename}'`;
	}
	my $decoded_sentence = `$decoder_command`;
#-no-expansion

	# drop first and last tokens (markers)
	# TODO : realign with original sequence ?
	my @decoded_sentence_tokens = map { new Web::Summarizer::Token( surface => $_ ) } split /\s+/ , $decoded_sentence;
	shift @decoded_sentence_tokens;
	pop @decoded_sentence_tokens;
	
	$adapted_sequence = \@decoded_sentence_tokens;

	print STDERR ">> done with confusion network adaptation !\n";
	
    }
    else {
	$adapted_sequence = \@original_sequence;
    }

    # create new sentence object
    my $adapted_sentence = new Web::Summarizer::Sentence( object_sequence => $adapted_sequence , object => $this->target ,
							  source_id => join( '.' , $original_sentence->source_id , 'adaptated' ) );


    return $adapted_sentence;

}

__PACKAGE__->meta->make_immutable;

1;
