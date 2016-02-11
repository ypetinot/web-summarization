package AdaptationLattice;

use strict;
use warnings;

use Environment;

use Digest::MD5 qw(md5 md5_hex md5_base64);
use File::Slurp qw/read_file/;
use Graph::Directed;

use Moose;
use namespace::autoclean;

# TODO : extends ?
has '_lattice' => ( is => 'ro' , isa => 'Graph::Directed' , init_arg => undef , lazy => 1 , builder => '_lattice_builder' );
sub _lattice_builder {
    return new Graph::Directed;
}

has '_key_2_surface' => ( is => 'ro' , isa => 'hashRef' , init_arg => undef , lazy => 1 , default => sub { {} } );
has '_master_key_2_surfaces' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , default => sub { {} } );

# Extractive tokens
has 'extractive_tokens' => ( is => 'ro' , isa => 'ArrayRef' , required => 1 );

# Abstractive tokens
has 'abstractive_tokens' => ( is => 'ro' , isa => 'ArrayRef' , required => 1 );

# Reference tokens
has 'reference_tokens' => ( is => 'ro' , isa => 'HashRef' , required => 1 );

=pod
sub add_vertex {

    my $this = shift;
    my $vertex_surface = shift;
    
    my $vertex_master_key = scalar( keys( %{ $this->_master_key_2_surfaces } ) ) + 1;

    my $is_slot = ( $vertex_surface =~ m/^\[\[/ ) || 0;

    # TODO : split on whitespace
    # ==> -multi-words !
    
    my @surfaces = map { [ md5_hex( $vertex_master_key . $_ ) , $_ ] } ( $is_slot ? @{ $this->target_tokens } : ( $vertex_surface ) );

    $this->_master_key_2_surfaces->{ $vertex_master_key } = \@surfaces;
    map {
	my ( $entry_key , $entry_surface ) = @{ $_ };
	$this->_lattice->add_vertex( $entry_key );
	$this->_lattice->set_vertex_attribute( $entry_key , 'WORD' , $entry_surface );
    } @surfaces;

    return $vertex_master_key;

}
=cut

sub adapt {

    my $this = shift;
    my $sentence = shift;

    my @tokens = split /\s+/ , $sentence;
    
    # replace first and last tokens
    $tokens[ 0 ] = '<s>';
    $tokens[ $#tokens ] = '</s>';

    # *****************************************************************************************************************************
    # build adaptation lattice
    # *****************************************************************************************************************************

    my $current_token_key = undef;
    for (my $i=0; $i<( $#tokens - 2 ); $i++) {

	my $current_token_surface = $tokens[ $i ];
	my $next_token_surface = $tokens[ $i + 1 ];

	my $next_token_key = $this->add_vertex( $next_token_surface );
	
	if ( $current_token_key ) {
	    
	    my @from_nodes = @{ $this->_master_key_2_surfaces->{ $current_token_key } };
	    my @to_nodes = @{ $this->_master_key_2_surfaces->{ $next_token_key } };
	    
	    foreach my $from_node_entry (@from_nodes) {
		foreach my $to_node_entry (@to_nodes) {
		    $this->_lattice->add_edge( $from_node_entry->[ 0 ] , $to_node_entry->[ 0 ] );
		}
	    }
	    
	}

	$current_token_key = $next_token_key;
	
    }
    
    # *****************************************************************************************************************************
    # decode lattice

    # write out graph as htk lattice
    my $adaptation_fh = File::Temp->new();
    my $adaptation_filename = $adaptation_fh->filename;
    # TODO : make the odp lm location configurable
    my $lm_file_odp = "/proj/nlp/users/ypetinot/ocelot/svn-research/trunk/data/ngrams/summary/3/-gt1min+++10+++-gt2min+++10+++-gt3min+++10.model";
    my $lm_file_target = $this->target->lm;

    my $htk_writer = Graph::Writer::HTK->new();
    $htk_writer->write_graph( $this->_lattice , $adaptation_filename );
    
    my $third_party_local_bin = Environment->third_party_local_bin;
    #my $decoding_mode = "-viterbi-decode";
    my $decoding_mode = "-posterior-decode";
    my $decoded_sentence = `${third_party_local_bin}/lattice-tool -read-htk $decoding_mode -in-lattice ${adaptation_filename} -out-lattice myout -lm ${lm_file_target} -mix-lm ${lm_file_odp} | cut -d ' ' --complement -f1`;
#-no-expansion

    # drop first and last tokens (markers)
    my @decoded_sentence_tokens = split /\s+/ , $decoded_sentence;
    shift @decoded_sentence_tokens;
    pop @decoded_sentence_tokens;
    my $adapted_sentence = join ( " " , @decoded_sentence_tokens );

    return $adapted_sentence;

}

__PACKAGE__->meta->make_immutable;

1;
