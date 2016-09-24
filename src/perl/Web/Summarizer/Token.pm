package Web::Summarizer::Token;

use strict;
use warnings;

use WordNetLoader;

use Carp::Assert;
use Function::Parameters qw(:strict);
use List::Util qw/min/;
use Memoize;

use Moose;
use MooseX::Aliases;
use namespace::autoclean;

# TODO : move to a base class ?
with( 'Logger' );
# TODO : remove ?
###with( 'Dictionary' );
with( 'DMOZ' );
with( 'Freebase' );
with( 'WordNetLoader' );

# surface form
has 'surface' => ( is => 'rw' , isa => 'Str' , required => 1 , builder => '_surface_builder' );

# TODO : could we do better ?
sub surface_normalized {
    my $this = shift;
    my $surface_original = $this->surface;
    if ( $surface_original =~ m/^(.*)s$/ && length( $surface_original ) > 2 ) {
	return $1;
    }
    return $surface_original;
}

sub surface_capitalized {
    my $this = shift;
    my $surface_capitalized = $this->surface;
    if ( $surface_capitalized =~ m/^([a-z])(.*)/ ) {
	$surface_capitalized = uc( $1 ) . $2;
    }
    return $surface_capitalized;
}

sub surface_regular {
    my $this = shift;
    return lc( $this->surface );
}

sub surface_grouped {
    my $this = shift;
    # TODO : should strip out all punctuation instead ? => only if necessary, my concern is that surface form of tokens (including embedded punctuation) is used the statistical POS/Dependency parser.
    my $is_multi_word = ( $this->word_length > 1 ) ? 1 : 0;
    my @surface_components = grep { ( ! $is_multi_word ) || ( $_ !~ m/^\p{PosixPunct}$/si ) } split /\s+/ , $this->surface;
    return join( '_' , @surface_components );
}

# POS
has 'pos' => ( is => 'ro' , isa => 'Str' , default => '' , required => 0 );

# Sequence info
# How do we reconcile incompatible sequence ? ==> should we reconcile ?
has 'sequence' => ( is => 'ro' , isa => 'Str' , default => '' , required => 0 );

# Abstract type
has 'abstract_type' => ( is => 'ro' , isa => 'Str' , default => '' , required => 0 );

# TODO : come up with something better
# TODO : implement as role ?
# is this a special token (e.g. marker, etc) ?
has 'is_special' => ( is => 'ro' , isa => 'Bool' , init_arg => undef , lazy => 1 , builder => '_is_special_builder' );
sub _is_special_builder {
    my $this = shift;
    return ( $this->surface =~ m/^\<.+\>$/ );
}

# Synset(s)
has 'synsets' => ( is => 'ro' , isa => 'ArrayRef[Str]' , init_arg => undef , lazy => 1 , builder => '_synsets_builder' );
sub _synsets_builder {
    my $this = shift;

    # 1 - determine type/pos => based on initial parsing (this makes things easier)
    my $type = undef;
    my $pos = $this->pos;
    if ( $this->is_noun ) {
	$type = 'n';
    }
    elsif ( $this->is_adjective ) {
	$type = 'a';
    }
    elsif ( $this->is_adverb ) {
	$type = '?';
    }
    else {
	# nothing we can do ?
    }
    
    # 2 - based on pos, request list of synsets
    if ( defined( $type ) ) {
	my $sense_key = join( '#' , $this->surface , $type , 1 );
	my @synsets = $this->_wordnet_loader->wordnet_query_data->querySense( $sense_key , 'syns' );
	return \@synsets;
    }

}

# TODO : confirm that we go exactly one level up 
has hypernyms => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_hypernyms_builder' );
sub _hypernyms_builder {

    my $this = shift;
    my $level = shift;
    my $depth = shift;

    if ( ! defined( $level ) ) {
	$level = 1;
    }

    if ( ! defined( $depth ) ) {
	$depth = 0;
    }

    my @hypernyms;

    my $current_senses = $this->_wordnet_senses;
    my @current_level_hypernyms;
    foreach my $current_sense (@{ $current_senses }) {
	my @current_hypes = $this->wordnet_querySense( $current_sense , 'hypes' );
	push @current_level_hypernyms , map { $this->_wordnet_sense_to_token( $_ ); } @current_hypes;
    }

    if ( $depth ) {
	push @hypernyms , @current_level_hypernyms;
    }

    if ( $level ) {
	foreach my $entry (@current_level_hypernyms) {
	    my $entry_hypernyms = $entry->_hypernyms_builder( $level - 1 , $depth + 1 );
	    push @hypernyms , @{ $entry_hypernyms };
	}
    }

    return \@hypernyms;

}

has 'hyponyms' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_hyponyms_builder' );
sub _hyponyms_builder {

    my $this = shift;
    my $depth = shift;

    if ( ! defined( $depth ) ) {
	$depth = 0;
    }

    my @hyponyms;

    my $current_senses = $this->_wordnet_senses;
    my @current_level_hyponyms;
    foreach my $current_sense (@{ $current_senses }) {
	my @current_hypos = $this->wordnet_querySense( $current_sense , 'hypos' );
	push @current_level_hyponyms , map { $this->_wordnet_sense_to_token( $_ ); } @current_hypos;
    }    
    
    # TODO : what if the original token does not have an abstract type ?
    push @hyponyms , @current_level_hyponyms;

# TODO : reintroduce ? currently this goes what too far in general
=pod
    if ( scalar( @current_level_hyponyms ) ) {
	foreach my $entry (@current_level_hyponyms) {
	    my $entry_hyponyms = $entry->_hyponyms_builder( $depth + 1 );
	    push @hyponyms , @{ $entry_hyponyms };
	}
    }
=cut

    return \@hyponyms;

}

sub get_related_wordnet_senses {

    my $this = shift;
    my $relationship = shift;

    # 2 - list senses for the current token
    my $wordnet_senses = $this->_wordnet_senses;

    # 2 - filter out senses ?
    # TODO

    # 3 - for each wordnet sense generate a new Token object
    my @related_tokens = map {
	$this->_wordnet_sense_to_token( $_ );
    } @{ $wordnet_senses };

    return \@related_tokens;

}

sub _wordnet_sense_to_token {
    my $this = shift;
    my $token_type = shift;
    my $token_surface = $token_type;
    $token_surface =~ s/\#.*$//sgi;
    return new Web::Summarizer::Token( surface => $token_surface , abstract_type => $token_type );
}

sub _wordnet_senses {
    my $this = shift;

    my @senses;
    my $abstract_type = $this->abstract_type;
   
    if ( $abstract_type && $abstract_type =~ m/\#/ ) {

	push @senses , $abstract_type;

    }
    else {

	my $string = $this->id;
	
	# TODO : currently we cannot handle tokens like C#, how can we fix this in a generic fashion ?
	if ( length( $string ) && $string !~ m/\#/ ) {
	    @senses = grep {
		$this->_wordnet_sense_compatible( $_ );
	    } $this->wordnet_querySense( $string );
	}
	
    }

    return \@senses;
}

sub _wordnet_sense_compatible {

    my $this = shift;
    my $sense = shift;

    if ( $sense =~ m/\#([a-z])(\#\d+)?$/ ) {
	if ( $1 eq 'a' && ! $this->is_adjective ) {
	    return 0;
	}
	elsif ( $1 eq 'n' && ! $this->is_noun ) {
	    return 0;
	}
	elsif ( $1 eq 'v' && ! $this->is_verb ) {
	    return 0;
	}
    }
    
    return 1;

}

sub word_length {
    my $this = shift;
    my $token_length = scalar( split /\W+/ , $this->surface );
    return $token_length;
}

sub length {
    my $this = shift;
    return length( $this->surface );
}

sub is_noun {
    my $this = shift;
    # Note : is this an accurate generalization ?
    return ( $this->pos =~ m/^N/ );
}

sub is_adjective {
    my $this = shift;
    return ( $this->pos =~ m/^JJ/ || $this->pos =~ m/^ADJ/ );
}

sub is_adverb {
    my $this = shift;
    return ( $this->pos =~ m/^ADV/ );
}

sub is_numeric {
    my $this = shift;
    return ( $this->surface =~ m/^\d(?:.*\d)?$/ );
}

sub is_verb {
    my $this = shift;
    return ( $this->pos =~ m/^V/ );
}

# Shared key (allow to identify matching candidates)
sub shared_key {
    my $this = shift;
    return join( "::", $this->pos, lc( ( $this->abstract_type ? $this->abstract_type : $this->surface ) ) );
}

# TODO : make this method a requirement (Role ? "KeyableObject")
sub key {
    my $this = shift;
    return $this->shared_key;
}

# TODO : what should the id of a token really be ?
has 'id' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_id_builder' );
sub _id_builder {
    my $this = shift;
    return lc( $this->surface );
}

# is slot location ?
sub is_slot_location {
    my $this = shift;
    return ( $this->abstract_type =~ m/SLOT/ );
}

# is punctuation ?
sub is_punctuation {
    my $this = shift;
    return ( $this->surface =~ m/^\p{PosixPunct}+$/ );
}

# is quote ?
sub is_quote {
    my $this = shift;
    return ( $this->surface eq "'" ) || ( $this->surface =~ m/^\\p{IsPi}|p{IsPf}$/ ) || ( $this->surface eq '`' );
}

has 'as_regex_anywhere' => ( is => 'ro' , init_arg => undef , lazy => 1 , builder => '_as_regex_anywhere_builder' );
sub _as_regex_anywhere_builder {
    
    my $this = shift;
    
    my $regex = $this->create_regex( anywhere => 1 );

    return $regex;

}

has 'as_regex' => ( is => 'ro' , init_arg => undef , lazy => 1 , builder => '_as_regex_builder' );
sub _as_regex_builder {
    
    my $this = shift;
    
    my $regex = $this->create_regex;

    return $regex;

}

# TODO : ideally anywhere should be automatically activated depending on whether the target string is fluent/segmented or not
# TODO : shouldn't the first parameter be implicit ?
method create_regex( :$anywhere = 0 , :$capture = 0 , :$plurals = 0 ) {
    
    my $token_surface = $self->surface;
    
    affirm { CORE::length( $token_surface ) != 0 } "Regex should only be generated for non-empty tokens" if DEBUG;

    my @token_components = split /(?:\s|\p{PosixPunct})+/ , $token_surface;

    affirm { scalar( @token_components ) } 'Token components cannot be empty' if DEBUG;

    my $regex_string = join(
	'(?:\s|\p{PosixPunct})*?'
	, map {
	my $component = $_;

	# TODO : check plural handling is compatible with POS when available
	# TODO : handle ies => y cases (e.g. deliveries)
	if ( $plurals && $component =~ m/s$/si ) {
	    my $without_plural = substr $component , 0 , -1;
##	    qr/${without_plural}s?/
	    "${without_plural}s?"
#	    qr/\Q$without_plural\Es?/
	}
	elsif ( $plurals ) {
##	    qr/${component}s?/
	    "${component}s?"
#	    qr/\Q$component\Es?/
	}
	else {
##	    qr/$component/
	    "$component"
#	    qr/\Q$component\E/
	}
			     } @token_components );
    
    if ( $capture ) {
	$regex_string = '(' . $regex_string . ')';
    }

    # TODO : remove slight redundancy
    # http://perldoc.perl.org/perlre.html#Character-set-modifiers
    my $regex = $anywhere ? qr/$regex_string/sia : qr/(?:^|\W)$regex_string(?:\W|$)/sia;

    return $regex;

}

=pod
# Note : having this here makes more sense than in Category::UrlData ... so keeping this here for now
# TODO : implement using prefix tree instead of regex ?
method object_support( $object , :$allow_partial_match = 0 , :$raw = 1 ) {

    my @sources = ( $object->content_modality , $object->title_modality , $object->url_modality );

    # Note : this is fairly conservative (can/should we make this softer ? i.e. return a probability of support based on all the modalities ? (per-modality weight might be learnable)
    my $token_surface = $self->surface;

    # CURRENT : token synonyms
    # TODO : can we cache this ? maybe as regex ?
    #my $synonyms = $self->synsets;

    # CURRENT : each source should handle its own matching / decision as to whether the token is supported by it (e.g. UrlModality can achieve this using a regex match, Anchortext may use a more statistical approach, etc.)
    my @matches;
    foreach my $source ( @sources ) {

	# TODO : the semantics for raw are different here, really need to clean this up
	if ( ! ( $source->fluent ? $source->supports( $self ) : $source->supports( $self , raw => 1 ) ) ) {
	    next;
	}

	my $source_id = $source->id;
	my $token_occurrences = $source->supports_token( $self );

	# TODO : clean this up
	if ( scalar( @{ $token_occurrences->[ 2 ] } ) ) {

	    push @matches , map { [ $_ , $source_id , 1 ]; } @{ $token_occurrences->[ 2 ] };

	}
	else {

	    # TODO : optimize by splitting token and matching pre-identified tokens for current modality => reduce the number of utterances that need to be inspected ?
	    next;

	    my @source_utterances = @{ $source->utterances };
	    foreach my $source_utterance (@source_utterances) {
		
		my $source_utterance_content = $source_utterance->verbalize;
		
		# 1 - attempt a simple match
		my $appearance_regex = $self->as_regex;
		print STDERR "[" . __PACKAGE__ . "] Testing appearance of [$appearance_regex] in [$source_utterance_content]\n"; 
		my $appears_in_source_utterance = ( $source_utterance_content =~ $appearance_regex );
		
		# 2 - advanced matching if necessary enabled
		if ( !$appears_in_source_utterance && $allow_partial_match ) {
		    
		    my $partial_match = 0;
		    my @token_surface_components = split /\s+/ , $token_surface;
		    my $token_surface_components_count = scalar( @token_surface_components );
		    if ( $token_surface_components_count ) {
			foreach my $token_surface_component (@token_surface_components) {
			    $partial_match += ( $source_utterance_content =~ m/\Q$token_surface_component\E/si );
			}
			$appears_in_source_utterance = $partial_match / $token_surface_components_count;
		    }
		  else {
		      print STDERR ">> found spurious token : $token_surface\n";
		  }
		    
		}
		
		# 3 - keep track of matches
		if ( $appears_in_source_utterance ) {
		    push @matches , [ $source_utterance , $source_id , $appears_in_source_utterance ];
		}
		
	    }
	    
        }

    }

    my $appears_in_object = scalar( @matches );
    $self->trace( "Checked object support for (" . $self->id . ") in (" . $object->url . ") => $appears_in_object" );

    return $raw ? ( $appears_in_object || 0 ) : \@matches;
    
}
=cut

# TODO : should we promote this to Token/UrlData ?
method _appearance_vector ( $object , :$regex_match = 0 ) {

    # check object support
    my $object_occurrences = $object->supports( $self , regex_match => $regex_match , per_modality => 1 );

    # generate appearance vector
    my %coordinates;
    if ( defined( $object_occurrences ) ) {
	map { $coordinates{ $_ } += $object_occurrences->{ $_ }; } keys( %{ $object_occurrences } );
    }
    my $appearance_vector = new Vector( coordinates => \%coordinates );

    return $appearance_vector;

}

method featurize ( $instance , :$context = 0 , :$corpus = 0 , :$syntax = 0 , :$binary = 0 ) {

    my %features;

    if ( $context ) {

	# TODO : features as registrable objects ?

	# 1 - appearance features (rought context)
	my $appearance_vector = $self->_appearance_vector( $instance )->coordinates;
	map { 
	    my $feature_value = $appearance_vector->{ $_ };
	    $features{ $_ } = $binary ? ( $feature_value ? 1 : 0 ) : $feature_value;
	} keys( %{ $appearance_vector } );

	# 2 - capitalization
	# TODO : avoid recomputing object occurrences
	my $object_occurrences = $instance->supports( $self , matches => 1 , regex_match => $1 , return_utterances => 1 );
	if ( $object_occurrences ) {

	    my $token_regex = $self->create_regex( capture => 1 );
	    my $token_regex_anywhere = $self->create_regex( anywhere => 1 );

	    foreach my $source ( keys( %{ $object_occurrences } ) ) {

		my $feature_key_modality_appearance = join( "-" , 'modality-appears' , $source );

		if ( $source eq 'url' ) {
		    
		    # appears in URL host
		    my $url_host = $instance->host;
		    if ( $url_host =~ m/$token_regex_anywhere/ ) {
			$features{ join( '-' , $feature_key_modality_appearance , 'host' ) } = 1;
		    }
		    
		    # TODO : appears in URL path (first) , appears in URL path (second) , etc.

		}

		my $source_occurrences = $object_occurrences->{ $source }->[ 2 ];
		foreach my $source_occurrence ( @{ $source_occurrences } ) {
		    
		    my $source_occurrence_matches = $source_occurrence->supports_regex( $token_regex );

		    foreach my $source_occurrence_match ( @{ $source_occurrence_matches } ) {
			
			# modality appearance feature
			$features{ $feature_key_modality_appearance }++;

			if ( $source_occurrence_match =~ m/^[A-Z][a-z]?/ ) {
			    $features{ 'capitalized-initials' }++;
			}
			elsif ( $source_occurrence_match =~/^[A-Z]+$/ ) {
			    $features{ 'capitalized-all' }++;
			}

			# TODO : add proportion capitablized ( 10% / 20% / 30% ... )
			# TODO : add position in utterances
			# TODO : add length features !

		    }

		}

	    }
	    
	}

    }

    if ( $syntax ) {

	# Note : the part of speech should be predicted based on all available data for the object
	
	# default to WordNet POS
	#my $pos_dict = $self->dict_pos( $self->surface );	
	map {
	    
	    my $wn_sense = $_;
	    if ( $wn_sense =~ m/\#(\w+)/ ) {
		$features{ join( '-' , 'wn-pos' , $1 ) } = 1; 
	    }

	} $self->wordnet_query_data->queryWord( $self->surface );

    }

=pod
    if ( $semantics ) {

# submodular functions for learning ?
	foreach $pos () {
	    $synset = $self->wordnet_data->querySynset( $pos );
	}

    }
# wikifier as a source of disambiguation ? 
=cut

    if ( $corpus ) {

	my $n_components = split /\s+/ , $self->surface;
	my $summary_corpus_existence = $self->global_data->global_count( 'summary' , min( $n_components , 3 ) , $self->surface );
	$features{ 'corpus-summary-exists' } = $summary_corpus_existence;

	if ( $summary_corpus_existence ) {

	    # TODO : add relative position in summary corpus
	    
	}

    }

    # CURRENT : binarize all features here

    return \%features;

}

# Note : HashRef so we define a distribution over entity_ids ?
has '_entity_ids' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_entity_ids_builder' );
sub _entity_ids_builder {
    my $this = shift;
    
    # look up table of string => ids mapping
    #my $ids = $this->get_types( $this->id );
    # TODO : reinstate surface normalization when loading data in mongodb ?
    my $ids = $this->map_string_to_entities( $this->surface );

    return $ids || [];

}

__PACKAGE__->meta->make_immutable;

1;
