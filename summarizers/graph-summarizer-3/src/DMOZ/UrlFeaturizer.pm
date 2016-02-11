package DMOZ::UrlFeaturizer;

use Moose;

# repository base path
has 'repository_base' => (is => 'ro', isa => 'Str', required => 1);

# repository
has '_repository' => (is => 'ro', isa => 'DMOZ::CategoryRepository', lazy => 1 , builder => '_build_repository', init_arg => undef);

# feature keys
has 'feature_keys' => (is => 'ro', isa => 'ArrayRef[Str]', required => 1);

use DMOZ::CategoryRepository;

use JSON;

sub _build_repository {

    my $this = shift;

    return DMOZ::CategoryRepository->new( $this->repository_base() );

}

# Collect features for the target object (URL)
sub collect_features {

    my $this = shift;
    my $url = shift;

    my $url_data = $this->_repository()->get_url_data( $url );
    #print STDERR ">> Found url record: " . $url_data->url() . "\n";

    my $collected_features = {};

    foreach my $feature_key (@{ $this->feature_keys() }) {
	# TODO: simply pass the process argument ?
	my $field_data = $url_data->get_field( $feature_key );
	if ( $field_data ) {
	    $field_data = decode_json( $field_data );
	}
	map { $collected_features->{ $_ }++; } keys( %{ $field_data } );
    }

    return $collected_features;
    
}

no Moose;

1;
