package Category::UrlData;

# Any Data that can be associated with the entries in a DMOZ category

use CycleChecker;
use Featurizable;
use GraphSummarizer;
use Memoize;
use Modality::AnchortextModality;
use Modality::PageModality;
use Modality::SummaryModality;
use Modality::TitleModality;
use Modality::UrlModality;
use NGrams;
use Service::NLP::DependencyList;
use Service::NLP::SentenceChunker;
use Service::Web::UrlData;
use StringNormalizer;
use StringVector;
use Web::Anchortext;
use Web::Document::HtmlDocument;
# TODO : does it make sense to have a dependency on Web::Summarizer::* here ?
use Web::Summarizer::Support;
use Web::Summarizer::UrlSignature;

use Clone qw/clone/;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Encode qw(encode_utf8);
use Function::Parameters qw(:strict);
use JSON;
use File::Temp qw/tempfile/;
use MIME::Base64 qw/decode_base64/;
use Switch;
use URI;

use Moose;
use MooseX::Aliases;
use MooseX::Storage;
use namespace::autoclean;

#with CycleChecker;
with( 'Featurizable' );
with( 'Logger' );
with( 'MongoDBAccess' );
with Storage('format' => 'JSON', 'io' => 'File');

# TODO : should be set via a configuration file ?
our $DEFAULT_NAMESPACE = 'web';

# TODO : turn this into a regular Web::Document (would make a lot more sense from a semantic point of view) ?
# TODO : should this belong inside one of the Modality classes ? If so, how do we handle sharing between PageModality and TitleModality ?
has '_html_document' => ( is => 'ro' ,
			  isa => 'Web::Document::HtmlDocument' ,
			  init_arg => undef ,
			  lazy => 1 ,
			  builder => '_html_document_builder' ,
			  handles => [ 'get_links' ]
    );
sub _html_document_builder {
    my $this = shift;

    my $content_field = 'content';

    # CURRENT : maybe separate UrlData (which abstract the modality generation logic) from the access to the raw data ?
    #           => get_field goes through ...
    #           => we could specify a cache right here, so the modality classes become responsible for accessing caches

    my $html_content = new Web::Document::HtmlDocument( url => $this->url );

    return $html_content;
}

has '_mongodb_collection_url_data' => ( is => 'ro' , isa => 'MongoDB::Collection' , init_arg => undef , lazy => 1 , builder => '_mongodb_collection_url_data_builder' );
sub _mongodb_collection_url_data_builder {
    my $this = shift;
    return $this->get_collection( 'web' , 'url_data' );
}

has '_mongodb_collection_url_data_extra' => ( is => 'ro' , isa => 'MongoDB::Collection' , init_arg => undef , lazy => 1 , builder => '_mongodb_collection_url_data_extra_builder' );
sub _mongodb_collection_url_data_extra_builder {
    my $this = shift;
    return $this->get_collection( 'web' , 'url_data_extra' );
}

=pod
# Note : _url_id cannot be undefines => no instance can be created for an unresolvable URL
has '_url_id' => ( is => 'ro' , isa => 'Value' , init_arg => undef , lazy => 1 , builder => '_url_id_builder' );
sub _url_id_builder {

    my $this = shift;

    # 1 - check whether an id exists for the target url in its current form
    my $url_id = $this->_url_2_id( $this->_mongodb_collection_mapping_url_id , $this->url );

    if ( ! defined( $url_id ) ) {

	print STDERR "URL does not exist in Web graph: " . $this->url . "\n";

	# 2 - check whether an id exists for the target url the url-canonical-mapping
	my $url_canonical = $this->_url_2_id( $this->_mongodb_collection_mapping_url_canonical , $this->url );

	if ( ! defined( $url_canonical ) ) {
	    die "Connect to Service::Web::UrlNormalizer ...";
	}

	# TODO : avoid code duplication
	if ( defined( $url_canonical ) ) {
	    $url_id = $this->_url_2_id( $this->_mongodb_collection_mapping_url_id , $url_canonical );
	    if ( ! defined( $url_id ) ) {
		print STDERR "URL does not exist in Web graph: " . $url_canonical . "\n";
		$url_id = $url_canonical;
	    }
	}

    }

    if ( ! defined( $url_id ) ) {
	print STDERR "URL cannot be resolved: " . $this->url . "\n";
    }

    return $url_id;

}
=cut

# url entry
has '_url_entry' => ( is => 'rw' , isa => 'HashRef' , init_arg => undef , lazy => 1 , default => sub { {} } );

# refresh url entry (currently only if one of the requested fields is not present)
# TODO : add flag to force refresh
# Note : might be able to implement this using around ?
# CURRENT : what would be the implications of storing multi-key entries for a namespace (e.g. dmoz) ? => for the target field(s), store as array refs ?
method refresh_url_entry( $field , :$namespace = $DEFAULT_NAMESPACE ) {
    
    if ( ! defined( $self->_url_entry->{ $namespace }->{ $field } ) ) {

	    # 1 - determine collection associated with target namespace
	    my $namespace_collection = $self->get_collection( $namespace , $field );

	    # 2 - look up entry in collection
	    my $url_entry_updated = $namespace_collection->find_one( { _id => $self->url } );

	    # 3 - update current url entry copy
	    if ( defined( $url_entry_updated ) ) {
		$self->_url_entry->{ $namespace } = $url_entry_updated;
	    }
	    elsif ( ! defined( $self->_url_entry->{ $namespace } ) ) {
		$self->_url_entry->{ $namespace } = {}
	    }
	    else {
		# Nothing - in particular do not overwrite whatever entry is already present
	    }

    }
    
    return $self->_url_entry;

}

# TODO : to be removed since we should now be loading data through the MongoDB datastore
has 'remote_service_client' => ( is => 'ro' , isa => 'Service::Web::UrlData' , init_arg => undef , lazy => 1 ,
				 builder => '_remote_service_client_builder' );
sub _remote_service_client_builder {
    my $this = shift;
    return new Service::Web::UrlData;
}

# (modality) anchortext
has 'anchortext_modality' => ( is => 'ro' , isa => 'Modality' , init_arg => undef , lazy => 1 , builder => '_anchortext_modality_builder' );
sub _anchortext_modality_builder {
    my $this = shift;
    return new Modality::AnchortextModality( object => $this );
}

# (modality) content
has 'content_modality' => ( is => 'ro' , isa => 'Modality' , init_arg => undef , lazy => 1 , builder => '_content_modality_builder' );
sub _content_modality_builder {
    my $this = shift;
    # TODO : PageModality needs to generate an object that is compatible with the Mime-type associated with the target URL
    #        => start with Mime-type identification ?
    return new Modality::PageModality( object => $this );
}

# (modality) title
has 'title_modality' => ( is => 'ro' , does => 'Modality' , init_arg => undef , lazy => 1 , builder => '_title_modality_builder' );
sub _title_modality_builder {
    my $this = shift;
    my $modality = new Modality::TitleModality( id => 'title' , object => $this );
    return $modality;
}

has 'summary_modality' => ( is => 'ro' , does => 'Modality' , init_arg => undef , lazy => 1 , builder => '_summary_modality_builder' );
sub _summary_modality_builder {
    my $this = shift;
    my $summary_modality = new Modality::SummaryModality( object => $this );
    return $summary_modality;
}

has 'signature' => ( is => 'ro' , isa => 'Vector' , init_arg => undef , lazy => 1 , builder => '_signature_builder' );
sub _signature_builder {
    my $this = shift;
    # TODO : create class field for the UrlSignature builder ?
    return new Web::Summarizer::UrlSignature->compute( $this );
}

# TODO : support id via Identifiable role
has 'url' => (is => 'rw', isa => 'Str', alias => 'id' , required => 1);

# TODO : transition to using exclusively this field instead of url then remove url and rename this field
has 'uri' => ( is => 'ro' ,
	       isa => 'URI' ,
	       init_arg => undef ,
	       lazy => 1 ,
	       builder => '_uri_builder' ,
	       handles => [ 'host' ]
);
sub _uri_builder {
    my $this = shift;
    return URI->new( $this->url );
}

# TODO : to be removed once the proper indexing process is in place ?
has 'original_url' => ( is => 'rw' , isa => 'Str' , predicate => 'has_original_url' );
sub url_match {
    my $this = shift;
    my $url = shift;
    return ( URI::eq( $url , $this->url ) || ( $this->has_original_url && ( URI::eq( $url , $this->original_url ) ) ) );
}

has 'url_modality' => ( is => 'ro' , does => 'Modality' , init_arg => undef , lazy => 1 , builder => '_url_modality_builder' );
sub _url_modality_builder {
    my $this = shift;
    my $url_modality = new Modality::UrlModality( object => $this );
    return $url_modality;
}

has 'fields' => (is => 'rw', isa => 'HashRef', default => sub { {} });

# temp data
# TODO: should we create a subclass for this functionality ?
has '_featurized_cache' => (is => 'rw', isa => 'HashRef', default => sub { {} });

# semantic representation cache
has '_semantic_representation_cache' => ( is => 'rw' , isa => 'HashRef', default => sub { {} } );

# TODO : attempt to fix original support-based implementation
sub most_likely_surface_form {

    my $this = shift;
    my $string = shift;

    my %forms;

    my $string_token = ref( $string ) ? $string : new Web::Summarizer::Token( surface => $string );
    my $string_token_regex = $string_token->create_regex( capture => 1 );
    my @utterance_sources = values( %{ $this->modalities } );
    my $has_form = 0;
    foreach my $utterance_source (@utterance_sources) {
	my $segments = $utterance_source->segments;
	foreach my $segment (@{ $segments }) {
	    if ( $segment =~ $string_token_regex ) {
		$forms{ $1 }++;
		$has_form = 1;
	    }
	}
    }

    if ( $has_form ) {
	my @sorted_forms = sort {
	    my $count_a = $forms{ $a };
	    my $count_b = $forms{ $b };
	    if ( $count_a != $count_b ) {
		$forms{ $b } <=> $forms{ $a }
	    }
	    else {
		# Note : this is a cheap trick so that versions that are less capitalized come out first in case of a tie
		# Ewhurst <=> EWHURST
		$b cmp $a
	    }
	} keys( %forms );
	return $sorted_forms[ 0 ];
    }

    return undef;

}

=pod
# TODO : does this really belong here ?
sub most_likely_surface_form {

    my $this = shift;
    my $string = shift;

    my $string_token = ref( $string ) ? $string : new Web::Summarizer::Token( surface => $string );
    my $matches = $this->supports( $string_token->create_regex( capture => 1 ) ,
				   regex_match => 1 , matches => 1 , per_modality => 1 );

    if ( defined( $matches ) ) {

	my %forms;

	# TODO : could implement as a heap to save some time
	foreach my $source ( keys( %{ $matches } ) ) {
	    map { $forms{ $_->[ 0 ] }++; } @{ $matches->{ $source }->[ 3 ] }
	}

	my @sorted_forms = sort { $forms{ $b } <=> $forms{ $a } } keys( %forms );
	return $sorted_forms[ 0 ];

    }

    return undef;

}
=cut

# TODO : serialize named entities => easier if moved to Modality classes ?
# TODO : do this really belong here ? => move implementation to modality class (i.e. allows special handling for URLs)
# named entities
has 'named_entities' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_named_entities_builder' );
sub _named_entities_builder {

    my $this = shift;

    if ( ! $this->has_field( 'named_entities' , namespace => 'nlp' ) ) {

	my %named_entities;
	
	# TODO : make available via a role ?
	my $parsing_service = Service::NLP::SentenceChunker->new;

	# TODO : confirm that this is working as expected
	my @utterance_sources = values( %{ $this->modalities } );
	my %segment2seen;
	foreach my $utterance_source (@utterance_sources) {
	    my $utterance_source_named_entities = $utterance_source->named_entities;
	    foreach my $entity_tag (keys( %{ $utterance_source_named_entities } )) {
		map {
		    if ( ! defined( $named_entities{ $entity_tag } ) ) {
			$named_entities{ $entity_tag } = {};
		    }
		    $named_entities{ $entity_tag }->{ $_ }++;
		}
		keys( %{ $utterance_source_named_entities->{ $entity_tag } } );
	    }
	}

	$this->set_field( 'named_entities' , encode_json( \%named_entities ) , namespace => 'nlp' );

    }

    return decode_json( $this->get_field( 'named_entities' , namespace => 'nlp' ) );
    
}

# CURRENT :
# 2 - given a slot, determine set of *matching* dependencies
# 3 - generate list of candidates from target dependencies
# 4 - expand list of candidates using identified named entities => minimum one word match with a candidate + internal dependencies

has 'dependencies' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_dependencies_builder' );
sub _dependencies_builder {

    my $this = shift;

    # TODO : turn into field
    my $json = JSON->new->convert_blessed;

    if ( ! $this->has_field( 'dependencies' , namespace => 'nlp' ) ) {
   
	my %_dependencies;
	
	# TODO : make available via a role ?
	# Note : we use the cheaper (lower quality it seems) parser to get dependencies for the entire object (since it may contain really long segments)
	my $dependency_parsing_service = Service::NLP::SentenceDependencyAnalyzer->new( use_shift_reduce_parser => 1 );
	
	my @utterance_sources = values( %{ $this->modalities } );
	my %segment2seen;
	foreach my $utterance_source (@utterance_sources) {
	    my $segments = $utterance_source->segments;
	    foreach my $segment (@{ $segments }) {
		if ( $segment2seen{ $segment }++ ) {
		    next;
		}
		if ( ! $segment =~ m/\s/ ) {
		    next;
		}
		my $segment_dependencies = $dependency_parsing_service->get_dependencies( $segment , parse_dependencies => 1 );
		 map {
		     my $from_normalized = lc( $_->from );
		     my $to_normalized = lc( $_->to );

		     # TODO : is scalar absolutely necessary ?
		     if ( scalar( grep { $_ =~ m/^\p{PosixPunct}+$/ } ( $from_normalized , $to_normalized ) ) ) {
			 # ignore dependencies involving punctuation characters
		     }
		     else {
			 my $key = join( '-' , $from_normalized , $to_normalized );
			 my $type = $_->type;		
			 if ( ! defined( $_dependencies{ $key } ) ) {
			     $_dependencies{ $key } = [ $from_normalized , $to_normalized , 0 , [] ];
			 }
			 $_dependencies{ $key }->[ 2 ]++;
			 push @{ $_dependencies{ $key }->[ 3 ] } , $_;
		     }
		 } grep { $_->from ne 'ROOT' } @{ $segment_dependencies };
	     }
	 }

	 my @dependencies = values( %_dependencies );
	 $this->set_field( 'dependencies' , $json->encode( \@dependencies ), namespace => 'nlp' );

	 #my $dependencies = new Service::NLP::DependencyList( dependency_data => \%_dependencies );
	 #$this->set_field( 'dependencies' , $dependencies->to_json_compatible , namespace => 'nlp' );

     }

    # TODO : can we do better ? currently having issues directly serializing DependencyList to json
    return Service::NLP::DependencyList->from_json_compatible( $json->decode( $this->get_field( 'dependencies' , namespace => 'nlp' ) ) );
    #return $json->decode( $this->get_field( 'dependencies' , namespace => 'nlp' ) );

}

memoize( 'is_named_entity' );
sub is_named_entity {
    my $this = shift;
    my $string = shift;
    my $named_entities = $this->named_entities;
    foreach my $named_entities_type (keys( %{ $named_entities } )) {
	foreach my $named_entity (keys( %{ $named_entities->{ $named_entities_type } } )) {
	    if ( lc( $named_entity ) eq lc( $string ) ) {
		return 1;
	    }
	}
    }
    return 0;
}

memoize( 'string_to_types' );
sub string_to_types {
    my $this = shift;
    my $string = shift;
    my $named_entities = $this->named_entities;
    my %types;
    foreach my $named_entities_type (keys( %{ $named_entities } )) {
	foreach my $named_entity (keys( %{ $named_entities->{ $named_entities_type } } )) {
	    if ( lc( $named_entity ) eq lc( $string ) ) {
		$types{ $named_entities_type }++;
	    }
	}
    }
    return new Vector( coordinates => \%types );
}

# tokens
has 'tokens' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_tokens_builder' );
sub _tokens_builder {

    my $this = shift;
    
    my %tokens;
    my @utterance_sources = values( %{ $this->modalities } );

    # TODO : what kind of information do we need to return for each token ?
    map {
	my $source_id = $_->id;	
	my $source_tokens = $_->tokens;

	foreach my $token_id (keys( %{ $source_tokens } )) {
	    
	    my $token_entry = $source_tokens->{ $token_id };

	    if ( ! defined( $tokens{ $token_id } ) ) {
		$tokens{ $token_id } = [ $token_entry->[ 0 ] , 0 , [] ];
	    }
	    
	    $tokens{ $token_id }->[ 1 ] += $token_entry->[ 1 ];
	    push @{ $tokens{ $token_id }->[ 2 ] } , @{ $token_entry->[ 2 ] };

	}

    } @utterance_sources;

    return \%tokens;

}

# TODO : move to Web::Summarizer::Token ?
memoize( 'vectorized_context' );
sub vectorized_context {

    my $this = shift;
    my $token = shift;
    
    my $vectorized_context = new Vector;

    # TODO : might be better to specify this functionality as a class name ?
    my $contextualization_function = shift;

    # 1 - get list of utterances for $token
    # TODO : should we handle token in a more transparent way ? coerce the parameter into a Web::Summarizer::Token ?
    my $token_entry = $this->tokens->{ ref( $token ) ? $token->id : $token };
    my $token_utterances = defined( $token_entry ) ? $token_entry->[ 2 ] : [];
    foreach my $token_utterance (@{ $token_utterances }) {

	my $token_utterance_vector = $token_utterance->vectorize;
	$vectorized_context->add( $token_utterance_vector );

    }
    
    return $vectorized_context->normalize;

}

has 'modalities' => ( is => 'ro' , isa => 'HashRef[Modality]' , init_arg => undef , lazy => 1 , builder => '_modalities_builder' );
sub _modalities_builder {
    my $this = shift;
    my %utterance_sources;
    map { $utterance_sources{ $_->id } = $_; } ( $this->url_modality , $this->content_modality , $this->title_modality , $this->anchortext_modality );
    return \%utterance_sources;
}

# (natural language) utterances
# CURRENT : given a unique id, should utterances be serialized ? if so how ?
# CURRENT : how to use utterances to constrain segmentation ? (i.e. the generation of tokens)
#           => pass / request token segmentation during Modality construction ?
has '_utterances' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_utterances_builder' );
sub _utterances_builder {

    my $this = shift;

    $this->logger->info( "Building utterances for " . $this->url . " ..." );
    
    my %utterances;

    # TODO : should this set be shared through a common definition ?

    # TODO : are these simply processing definitions that are applied to the current UrlData instance ?
    # Note : by default the anchortext_modality provides the extended (sentence) anchortext
    my @utterance_sources = values( %{ $this->modalities } );
    foreach my $utterance_source (@utterance_sources) {
	$utterances{ $utterance_source->id } = $utterance_source->utterances;
    }

    $this->logger->info( "Done building utterances for " . $this->url . " !" );

    return \%utterances;

}

# tokenizer - shared by all modalities (in fact all modalities should be used as input to defined the set of tokens for this object)
has 'tokenizer' => ( is => 'ro' , isa => 'String::Tokenizer' , init_arg => undef , lazy => 1 , builder => '_tokenizer_builder' );
sub _tokenizer_builder {
    my $this = shift;
    #return new Web::Summarizer::Tokenizer( object => $this );
    return new String::Tokenizer;
}

has '_supports_cache' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );

# TODO : memoization is buggy here => write my own module/functionality ?
#memoize( 'supports' );
method supports ( $token , :$regex_match = 0 , :$matches = 0 , :$return_utterances = 0 , :$per_modality = 0 ,
		  :$hypernyms_only = 0 , :$hyponyms_only = 0 ) {

=pod
    # CURRENT
    my $cache_key = join( ':::' , @_ );
    if ( ! defined( $this->_supports_cache->{ $cache_key } ) ) {

    my $return_value = ...;
    return $return_value;
=cut

	my @utterance_sources = values( %{ $self->modalities } );
	my @utterances;
	
	my $support_data = new Web::Summarizer::Support( token => $token );
	
	# TODO : would we ever need per-modality count distribution ?
	my $count = 0;
	my %_matches;
	foreach my $utterance_source (@utterance_sources) {
	    my $utterance_support = $utterance_source->supports( $token ,
								 regex_match => $regex_match ,
								 matches => $matches ,
								 return_utterances => $return_utterances ,
								 hypernyms_only => $hypernyms_only ,
								 hyponyms_only => $hyponyms_only
		);
	    # TODO : instead of doing this, should we be providing a more flexible interface for the call to supports above ?
	    # CURRENT : when matches is on, expect an array of utterances
	    ###my $utterance_source_count = $matches ? scalar( @{ $utterance_support || [] } ) : $utterance_support ;
	    # Note : currently ModalityBase::supports never returns the support structure
	    my $utterance_source_count = $matches ? scalar( @{ $utterance_support || [] } ) : ( $return_utterances ? $utterance_support->[ 1 ] : $utterance_support );
	    
	    if ( $utterance_source_count ) {
		$count += $utterance_source_count;
		if ( $matches || $return_utterances ) {
		    $_matches{ $utterance_source->id } = $utterance_support;
		    $support_data->add_modality_matches( $utterance_source->id , $utterance_support );
		}
		else {
		    $support_data->add_modality_matches_count( $utterance_source->id , $utterance_source_count );
		}
		if ( $return_utterances ) {
		    push @utterances , @{ $utterance_support };
		}
	    }
	    
	}
	
	if ( $return_utterances ) {
	    return scalar( @utterances ) ? \@utterances : undef;
	}
	
	if ( $per_modality ) {
	    if ( $count ) {
		return $support_data;
	    }
	    return undef;
	}
	
	return $count;

}

my $FIELD_MARKER_NGRAMS='ngrams';

# TODO : add meta-information support to Modality class so it can be used in two ways ?
# get modality data (replacement for get_field)
sub get_modality_data {

    my $this = shift;
    my $modality = shift;
    my $ngram_order = shift || 0;
    my $load_mapping = shift;
    my $return_mapping_surface = shift;

    # TODO : can we improve this ? would require changing the way the n-gram data is generated/serialized ~
    my $field_id = $modality->id;

    # TODO : is there a need for a data loader for non-grammed modalities ?
    my $data_loader = undef;

    if ( $ngram_order ) {
	# TODO : can we avoid the variable reuse ?
	$field_id = join( "." , $field_id , $FIELD_MARKER_NGRAMS , $ngram_order );
	$data_loader = $modality->ngram_data_loader;
    }

    return $this->get_field( $field_id , $data_loader , $load_mapping , $return_mapping_surface );

}

sub field_key {

    my $that = shift;
    my $field_name = shift;
    my $process = shift;
    
    my $field_key = $field_name . ( $process ? "/$process" : '' );

    return $field_key;

}

# get field ( optionally for a particular facet )
# Note : this method should abstract the potential organizational division between offline and online processing. Some fields may be generated in an "offline" manner, i.e. prior to being submitted to the system, while other fields may be generated in an "online" manner (i.e. dynamically) by the client algorithms as they become necessary. This method should thus make offline fields available while also triggering the generation of online fields as needed (note that triggering might just mean calling the current object's method that handle the generation of this field) => offline fields are provided at construction time (in a more or less lazy manner), while online fields are real methods
method get_field( $field_name , :$process = undef , :$load_mapping = 0 , :$return_mapping_surface = 0 , :$store = 1 , :$namespace = $DEFAULT_NAMESPACE ) {

    my $field_key = $self->field_key( $field_name , $process );
    # TODO : integrate this in field_key
    my $field_key_transformed = join( '/' , split ( /\./ , $field_key ) );

    my $field_value = undef;

    # Note : first check MongoDB "cache", then remote store, then attempt to generate locally/remotely
    my $url_entry = $self->refresh_url_entry( $field_key_transformed , namespace => $namespace );
    my $url_entry_field = defined( $url_entry ) ? $url_entry->{ $namespace }->{ $field_key_transformed } : undef; 

    if ( defined ( $url_entry_field ) ) {
	$field_value = $url_entry_field;
    }
# TODO : to be removed
    elsif ( $field_name eq 'summary' ) {
	my $url = $self->url;
	die "Remote store unavailable - unable to load field (${url}::${field_name}) ...";
    }
    else {
	
	# generate the requested field
	switch (  $field_name ) {
	    
	    # Note : adding field support here should only be a last resort solution
	    # TODO : these field should become attributes of the class whose serialization behavior should be specified by a trait
	    
	    case 'content' {
		$field_value = $self->_html_document->raw_data;
	    }

	    case 'content.rendered' {
		$field_value = $self->_html_document->render;
	    }
	    
	    else {
		die "Field not supported: $field_name";
	    }
	    
	}
	
	# store field value in (mongodb) cache
	if ( $store && defined( $field_value ) ) {
	    $self->set_field( $field_key_transformed , $field_value );
	}

    }
    
    return $field_value;
    
}

# has field ?
# CURRENT: UrlData should allow you to access all fields in the data store, though some of the fields maybe managed/serialized by other classes
#          namespace => db name
#          fieldname => collection name
#          beyond that, sub-records
method has_field ( $field_name , :$namespace = $DEFAULT_NAMESPACE ) {
    return defined( $self->refresh_url_entry( $field_name , namespace => $namespace )->{ $namespace }->{ $field_name } );
}

method set_field( $key , $value , :$namespace = $DEFAULT_NAMESPACE , :$store = 1
		  #, %namespace_specific
    ) {
    
    # TODO : abstract the reliance on _url_entry_meta through an update method ? Alternatively we could promote the collection and key fields to full fledged fields.
    if ( $store ) {

	$self->get_collection( $namespace , $key )->update( { _id => $self->url } ,
							    { '$set' => { $key => $value } } ,
							    { upsert => 1 } );

    }

    $self->_url_entry->{ $namespace }->{ $key } = $value;

}

# prepare data
# TODO: the exact fields that are getting prepared should be those that will effectively be used down the line (i.e. as specified in the model configuration ?)
sub prepare_data {
    
    my $this = shift;
    my $nodes = shift || [];
    
    if ( ! $this->_prepared ) {

	print STDERR "[" . __PACKAGE__ . "] Preparing data (" . $this->url . ") ...\n";

	my @fields_to_prepare = ( 'content' , 'anchortext_basic' , 'url_words' );
	
	foreach my $field_to_prepare (@fields_to_prepare) {
	    
	    # chunkify field content and mark known chunks
	    # map chunks to the set that has been previously identified
	    my ($chunk_mapped_field, $context_data, $appearance_map, $appearance_context_map) = GraphSummarizer::_chunkify_content( $this->fields->{ $field_to_prepare } , $nodes );
	    
	    # fine grain tokenization now that chunks have been abstracted out
	    my $chunk_tokenized_field = GraphSummarizer::_chunk_tokenize_content( $chunk_mapped_field );
	    
	    # store prepared data
	    $this->fields->{ join("::", $field_to_prepare, 'prepared') } = $chunk_tokenized_field;
	    $this->fields->{ join("::", $field_to_prepare, 'appearance') } = $appearance_map;
	    $this->fields->{ join("::", $field_to_prepare, 'appearance_context') } = $appearance_context_map;
	    
	}

	print STDERR "[" . __PACKAGE__ . "] Done preparing data ...\n";

    }

    # successfully prepared
    $this->_prepared( 1 );

    return $this;
    
}

sub _generate_feature_name {
    return join("::" , @_);
}

# semantic representation
sub semantic_representation {

    my $this = shift;
    my $modality = shift;

    if ( ! defined( $this->_semantic_representation_cache->{ $modality } ) ) {

	# 1 - get field content
	my $modality_content = $this->get_modality_data( $modality );
	
	# 2 - map content to semantic representation
	# TODO: seemless integration for HTML modalities ?
	my $semantic_representation = new StringVector( $modality_content );

	# 3 - set cache
	$this->_semantic_representation_cache()->{ $modality } = $semantic_representation;

    }

    return $this->_semantic_representation_cache()->{ $modality };

}	

# Note : should be removed eventually ?
sub release {

    my $this = shift;

# Note : can cause problems
    $this->category_data( undef );

    foreach my $key (keys( %{ $this->_featurized_cache } )) {
	delete $this->_featurized_cache->{ $key };
    }

}

# TODO : to be removed ?
sub get_all_modalities_ngrams {

    my $this = shift;
    my $min_ngram_order = shift;
    my $max_ngram_order = shift || $min_ngram_order;

    my %ngrams;

    foreach my $ngrammable_modality (@{ $this->modalities_ngrams }) {
	for (my $ngram_order=$min_ngram_order; $ngram_order<=$max_ngram_order; $ngram_order++) {
	    
	    # get ngrams for the current modality/order
	    my ( $modality_order_ngrams , $mapping , $mapping_surface ) = $this->get_modality_data( $ngrammable_modality , $ngram_order , 1 , 1 );
	    
	    map {
		
		# TODO : move normalization somewhere else ?
		my $mapped_ngram = lc( $mapping_surface->{ $_ } );

		if ( ! defined( $ngrams{ $mapped_ngram } ) ) {
		    # maintain individual ngram counts for each modality
		    # TODO : is this generic enough ?
		    $ngrams{ $mapped_ngram } = {};
		}
		
		$ngrams{ $mapped_ngram }{ $ngrammable_modality->id }++;

	    } keys( %{ $modality_order_ngrams } );

	}
    }

    return \%ngrams;

}

sub get_all_modalities_unigrams {

    my $this = shift;

    # 1 - get all available utterances
    my $utterances = $this->_utterances;

    my %unigrams;

    foreach my $modality (keys %{ $utterances }) {
	my $modality_utterances = $utterances->{ $modality };
	foreach my $modality_utterance (@{ $modality_utterances }) {
	    map { $unigrams{ $_ }{ $modality }++ } grep { length( $_ ); } map { StringNormalizer::_normalize( $_ ); } split /\s+/ , $modality_utterance;
	}
    }

    return \%unigrams;

}

# return all available utterances in this instances, possibly filtered
memoize( 'utterances' );
method utterances( :$source = undef , :$pattern = undef ) {

    # TODO : should we add an option to preserve the source modality information ?

    # get all utterances
    my $utterances = $self->_utterances;

    my @target_sources = defined( $source ) ? ( $source ) : keys( %{ $utterances } );

    my %filtered_utterances;
    foreach my $source_id ( @target_sources ) {
	my @source_selection = grep { ( ! defined( $pattern ) ) || ( $_->verbalize =~ $pattern ) } @{ $utterances->{ $source_id } };
	if ( scalar( @source_selection ) ) {
	    $filtered_utterances{ $source_id } = \@source_selection;
	}
    }

    # TODO : return unique utterances only and add some notion of weight ?
    if ( defined( $source ) ) {
	return $filtered_utterances{ $source };
    }
    
    return \%filtered_utterances;

}

method load_url_data ( $args , :$load_content = 1 , :$load_anchortext = 0 ) {

    my $ref_args = ref( $args );

    if ( ( ! $ref_args ) ) {
	$args = { url => $args };
    }
    elsif ( $ref_args =~ m/^URI/ ) {
	$args = { url => $args->as_string };
    }

    # TODO : perform basic URL normalization using URI
    # TODO : perform advanced URL normalization using Service::Web::UrlNormalizer ?

    my $url_data = __PACKAGE__->new( %{ $args } );
    
    # TODO : could we do better ?
    my $url_ok = 1;
    eval {

	# Why is this necessary ?
	my $url_data_id = $url_data->url;

	# 0 - filter out non-text URLs
	if ( $url_data_id =~ m/(?:\.xml|\.jpg)$/si ) {
	    $url_ok = 0;
	}
	else {

	    # 1 - we need to have a valid, even if empty, content modality
	    if ( $load_content ) {
		my $content = $url_data->content_modality->content;
		if ( ! length( $content ) ) {
		    $url_data->logger->warn( "Empty content for : " . $url_data->url );
		    $url_ok = 0;
		}
	    }
	    
	    if ( $load_anchortext ) {
		my $anchortext = $url_data->anchortext_modality->content;
	    }
	    
	}
	
    };
    if ( $@ || ! $url_ok ) {
	my $url = $url_data->url;
	print STDERR "[" . __PACKAGE__ . "] Unable to create UrlData object for $url: $@\n";
	$url_data = undef;
    }
    else {
	$url_data->logger->info( "Successfully loaded data for : " . $url_data->url );
    }    

    return $url_data;

}

# TODO : to be removed, we are now using the URL Signature as a vectorized representation of an instance
=pod
# collect instance "descriptive" content
# content evidenced in more than one modality of the target
###memoize('collect_instance_descriptive_content');
# TODO : enable functionality via a "FeatureExtractor" role that can be applied to the UrlData class as needed ?
sub collect_instance_descriptive_content {

    my $this = shift;
    my $threshold = shift || 0;

    my %descriptive_content;
    
    my @modalities_ngrammable = @{ $this->modalities->modalities_ngrams };
    foreach my $modality_ngrammable (@modalities_ngrammable) {

	my $field = $modality_ngrammable->id;

	if ( ! $this->has_field( $field ) ) {
	    my $url = $this->url;
	    print STDERR ">> Missing field data for url ($url): $field ...\n";
	    next;
	}

	my $ngram_min_order = $modality_ngrammable->ngram_min_order;
	my $ngram_max_order = $modality_ngrammable->ngram_max_order;
	
	for (my $ngram_order = $ngram_min_order; $ngram_order <= $ngram_max_order; $ngram_order++) {

	    # CURRENT
	    # load ngram data, including mapping !
	    my ( $modality_data , $modality_data_mapping , $modality_data_mapping_surface ) = $this->get_modality_data( $modality_ngrammable , $ngram_order , 1 , 1 );
	    if ( ! $modality_data ) {
		print STDERR ">> Missing modality data: $field ...\n";
	    }

	    my %field_content;
	
	    map { 
		
		my $feature_key = $_;
		my $feature_surface = $modality_data_mapping_surface->{ $feature_key };
		my $feature_modality_count = $modality_data->{ $feature_key };
		
		# normalize surface
		my $feature_surface_normalized = $feature_surface;
		while ( $feature_surface =~ s/\[\[NULL\]\]//sig ) {}
		while ( $feature_surface =~ s/\<EOD\>//sig ) {}
		while ( $feature_surface =~ s/NUM//sg ) {}
		while ( $feature_surface =~ s/http:\/\/[^\s]+//sig ) {}
		$feature_surface =~ s/^\p{Punct}+//sg;
		$feature_surface =~ s/\p{Punct}+$//sg;
		$feature_surface = trim( $feature_surface );
		
		if ( length( $feature_surface ) ) {
		    $field_content{ $feature_surface }++;
		}
		
	    } keys( %{ $modality_data } );

	    # update instance stats
	    map { $descriptive_content{ $_ }{ $field } = $field_content{ $_ }; } keys( %field_content );
	    
	}

    }
    
    # at least 1 occurrence in two distinct modalities ?
    map { if ( scalar( keys( %{ $descriptive_content{ $_ } } ) ) < $threshold ) { delete $descriptive_content{ $_ }; } } keys( %descriptive_content );

    return \%descriptive_content;

}
=cut

__PACKAGE__->meta->make_immutable;

1;
