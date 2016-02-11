package DMOZ::GlobalData;

use strict;
use warnings;

use Memoize;

use DMOZ::CategoryRepository;
use Environment;
use Service::Web::UrlData;

use Text::Trim;

use Moose;
use namespace::autoclean;

with( 'Logger' );

# CURRENT
###use Service::Corpus::UrlDataService;
###with( 'Service::ThriftBased' => { port => 8990 , client_class => 'Service::Corpus::UrlDataServiceClient' } );
use Service::NLP::LMService;
with( 'Service::ThriftBased' => { port => 9595 , client_class => 'Service::NLP::LMServiceClient' } );

# access data through remote service ? ( should we create a Role for this kind of behavior ? e.g. Remoteable ? )
has 'remote' => ( is => 'ro' , isa => 'Bool' , default => 1 );

=pod
# TODO : to be removed since we should now be loading data through the MongoDB datastore
has 'remote_service_client' => ( is => 'ro' , isa => 'Service::Web::UrlData' , init_arg => undef , lazy => 1 ,
				 builder => '_remote_service_client_builder' );
sub _remote_service_client_builder {
    my $this = shift;
    return new Service::Web::UrlData;
}
=cut

# fold id
# TODO: should really be required
has 'fold_id' => ( is => 'ro' , isa => 'Num' , required => 0 );

# data directory
has 'data_directory' => ( is => 'ro' , isa => 'Str' , default => sub { return Environment->data_base; } );

# global count
has 'global_counts' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } , required => 0 );

# ngram count threshold
has 'ngram_count_threshold' => ( is => 'ro' , 'isa' => 'Num' , default => 0 );

=pod
has 'global_counts' => ( is => 'ro' , isa => 'Ref' , builder => '_global_counts_builder' , lazy => 1 );
sub _global_counts_builder {

    my $this = shift;

#    my %hash;
#    tie %hash , "TokyoCabinet::HDB" , $hash_file , TokyoCabinet::HDB::OWRITER | TokyoCabinet::HDB::OCREAT , 4000000;

#    return \%hash;

###    my $hdb = TokyoCabinet::HDB->new();
###    my $hash_file = join("/", $this->output_directory(), "global_counts.hdb");
###    $hdb->open( $hash_file , TokyoCabinet::HDB::OWRITER | TokyoCabinet::HDB::OCREAT );
    
###    return $hdb;

    my $fdb = TokyoCabinet::FDB->new();
    my $hash_file = join("/", $this->output_directory(), "global_counts.fdb");
    $fdb->open( $hash_file , TokyoCabinet::FDB::OWRITER | TokyoCabinet::FDB::OCREAT );

    return $fdb;

}
=cut

# global count meta
has 'global_counts_meta' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

sub total_instances {

    # TODO

}

#memoize("total_occurrences");
sub _total_occurrences {

    my $this = shift;
    my $field = shift;
    my $ngram_order = shift;

    # trigger data loading, just in case
    return $this->field_count_data( $field , $ngram_order )->[ 1 ]->{ 'total_occurrences' };

}

sub global_distribution {

    my $this = shift;
    my $field = shift;
    my $ngram_order = shift;
    
    my $field_distribution = $this->field_count_data( $field , $ngram_order )->[ 0 ];

    return $field_distribution;

}

# Note : If no data_feature is specified, return the total number of occurrences ? (i.e. total_occurrences)
# TODO : is memoizing the best option ?
memoize( 'global_count' );
sub global_count {

    my $this = shift;
    my $field = shift;
    my $ngram_order = shift;
    my $data_feature = shift;

    # Note : for now we drop the order => is there any reason to bring it back ? speed maybe ?
    return $this->_client->global_count( $field , $data_feature );
    
=pod
    if ( $this->remote ) {
	#return $this->remote_service_client->global_count( $field , $ngram_order , $data_feature );
    }

    my $field_distribution = $this->global_distribution( $field , $ngram_order );

    if ( defined( $data_feature ) ) {
	return $field_distribution->{ $data_feature } || 0;
    }
    
    return $this->_total_occurrences( $field , $ngram_order );
=cut

}

=pod
sub global_rank {

    my $this = shift;
    my $field = shift;
    my $ngram_order = shift;
    my $data_feature = shift;

    return $this->field_rank_data

}
=cut

sub get_ngram_counts_file {

    my $this = shift;
    my $field = shift;
    my $ngram_order = shift;
    my $options = shift;

    # TODO : this needs to be generated from a list of options / the list of options could be provided by this class
    my $field_count_file_base = '-gt1min+++10+++-gt2min+++10+++-gt3min+++10+++-gt4min+++10+++-gt5min+++10+++-unk.model';
    my $ngram_order_upper_bound = 5;
    my $global_ngram_counts_file = join( "/" , $this->data_directory , 'ngrams' , $field , $ngram_order_upper_bound , join( "." , $field_count_file_base , 'counts' , $ngram_order ) );
	
    return $global_ngram_counts_file;

}

sub field_count_data {
    
    my $this = shift;
    my $field = shift;
    my $ngram_order = shift;
    
    my $field_key = $this->get_key( $field , $ngram_order );
    
    if ( ! defined( $this->global_counts->{ $field_key } ) ) {
	
	$this->logger->info( ">> [$this] loading $field / $field_key / $ngram_order" );
	
	my $global_ngram_counts_file = $this->get_ngram_counts_file( $field , $ngram_order );
	my $specific_field_total_count = 0;
	
	# open counts file for the target field / ngram order
	open GLOBAL_NGRAM_COUNTS, $global_ngram_counts_file or die "Unable to open global ngram counts file ($global_ngram_counts_file): $!";
	
	while ( <GLOBAL_NGRAM_COUNTS> ) {
	    
	    chomp;
	    
	    my @ngram_fields = split /\t/, $_;
	    my $ngram_surface = shift @ngram_fields;
	    my $ngram_count = shift @ngram_fields;
	    
	    if ( $ngram_count < $this->ngram_count_threshold ) {
		next;
	    }
	    
	    # We only count one occurrence per instance (avoid any kind of spamming)
	    $specific_field_total_count += $ngram_count;
	    
	    # TODO : i should not have to normalize here, must improve data generation
	    my $normalized_ngram = _normalize( $ngram_surface );
	    if ( length( $normalized_ngram ) ) {
		$this->global_counts->{ $field_key }->{ $normalized_ngram } += $ngram_count ;
	    }
	    
	}
	
	# close counts file
	close GLOBAL_NGRAM_COUNTS;
	
	$this->global_counts_meta->{ $field_key }->{ 'total_occurrences' } = $specific_field_total_count;
	
    }
    
    return [ $this->global_counts->{ $field_key } , $this->global_counts_meta->{ $field_key } ];
    
}

# generic key generation
sub get_key {

    my $this = shift;

    return join( "::" , @_ );

}

# TODO : this has to go away ultimately
sub _normalize {
    my $string = shift;
    my $normalized_string = trim( $string );
    $normalized_string =~ s/\p{Punct}$//;
    return lc( $normalized_string );
}

__PACKAGE__->meta->make_immutable;

1;
