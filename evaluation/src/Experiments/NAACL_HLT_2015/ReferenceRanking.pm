package Experiments::NAACL_HLT_2015::ReferenceRanking;

# TODO : paper as full programs ?

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'Experiment::Table' );
with( 'Experiments::EMNLP_2015' );

# system entries builder
sub _system_entries_builder {

    my $this = shift;
    
    # systems (configurations keys)
    # TODO : these could be coming from a top-level configuration file but not necessary at all (again config files are really hidden scripts)

    my $retrieval_mode_prefix = '@reference-collector-params@index-query-field';
    my @retrieval_modes = ( [ 's' , 'description' ] , [ 'c' , 'content-rendered' ] , [ 't' , 'title' ] );

    my $ranking_mode_prefix = '@reference-ranker-class';
    my @ranking_modes = ( [ 'k' , 'WordGraph::ReferenceRanker::ReferenceTargetJointProbability' ] , [ 'f' , 'WordGraph::ReferenceRanker::SymmetricTargetSimilarity' ] );

    my $similarity_mode_prefix = '@reference-ranker-params@similarity-field';
    my @similarity_modes = ( ['c' , 'content' ] , [ 't' , 'title' ] , [ 'a' , 'anchortext' ] , [ 'u' , 'url' ] );
    
    my @core_systems;
    push @core_systems , [ 'wg-baseline-ranking-max'   , 1 , 0 , 0 ];
    push @core_systems , [ 'graph4-baseline-ranking'   , 1 , 1 , 1 ];
    push @core_systems , [ 'wg-baseline-retrieval'     , 1 , 0 , 0 ];
    push @core_systems , [ 'title'                     , 0 , 0 , 0 ];
    push @core_systems , [ 'wg-baseline-ranking-min'   , 1 , 0 , 0 ];
    
    my @systems;
    foreach my $core_system (@core_systems) {
	
	my $core_system_id = $core_system->[ 0 ];
	my $variable_retriever = $core_system->[ 1 ];
	my $variable_ranker = $core_system->[ 2 ];
	my $variable_similarity_field = $core_system->[ 3 ];
	
	if ( $variable_retriever ) {
	    
	    foreach my $retrieval_mode (@retrieval_modes) {
		
		my $retrieval_mode_label = $retrieval_mode->[ 0 ];
		my $retrieval_mode_key = $retrieval_mode->[ 1 ];
		my $retrieval_mode_parameter_key = $this->_generate_parameter_key_value_string( $retrieval_mode_prefix , $retrieval_mode_key );
		
		if ( $variable_ranker ) {
		    
		    foreach my $ranking_mode (@ranking_modes) {
			
			my $ranking_mode_label = $ranking_mode->[ 0 ];
			my $ranking_mode_key = $ranking_mode->[ 1 ];
			my $ranking_mode_parameter_key = $this->_generate_parameter_key_value_string( $ranking_mode_prefix , $ranking_mode_key );
			
			# TODO : can we do better ?
			if ( $variable_similarity_field ) {
			    
			    foreach my $similarity_mode (@similarity_modes) {
				
				my $similarity_mode_label = $similarity_mode->[ 0 ];
				my $similarity_mode_key = $similarity_mode->[ 1 ];
				my $similarity_mode_parameter_key = $this->_generate_parameter_key_value_string( $similarity_mode_prefix , $similarity_mode_key );
				
				my $system_label = "retrieval[$retrieval_mode_label]+ranking[$ranking_mode_label-$similarity_mode_label]";
				push @systems , [ $system_label , $this->_generate_system_id( $core_system_id , $retrieval_mode_parameter_key , $ranking_mode_parameter_key , $similarity_mode_parameter_key ) ];
				
			    }
			    
			}
			else {
			    
			    push @systems , [ "retrieval[$retrieval_mode_label]+$core_system_id\[$ranking_mode_label\]" , $this->_generate_system_id( $core_system_id , $ranking_mode_parameter_key , $retrieval_mode_parameter_key ) ];
			    
			}
			
		    }
		    
		}
		else {
		    
		    # Note : generate-summarizers-list will only include parameters that are being scanned => this seems like the expected behavior
		    push @systems , [ "$core_system_id\[$retrieval_mode_label\]" , $this->_generate_system_id( $core_system_id , $retrieval_mode_parameter_key ) ];
		    
		}
		
	    }
	    
	}
	else {
	    
	    # TODO : can we avoid writing the same variable twice ?
	    push @systems , [ $core_system_id , $core_system_id ];
	    
	}	
	
    }
	
    return \@systems;

}

# build the table - this is necessarily a custom function
sub table_builder {

    my $this = shift;

    # => yes, use the definition to produce the list of cells (some of them being units) => then fill individual units
    # => problem, how do we get the table definition ? => coded
    # => take the table and make it a template

    # Note : store cells in row format
    # TODO : use CPAN module instead ?
    my @cells;

    # CURRENT : assuming I get generate-summarizers-list to produce the unit group key ... what else is needed ?
    # => get experiment driver to produce the list ... => can the table be produced from the meta configuration ?

    foreach my $system (@systems) {
	
	my $system_label = $system->[ 0 ];
	my $system_id = $system->[ 1 ];

	# TODO
	my $system_params = $system->[ 2 ];

=pod
	# 1 - load system configuration
	my $configuration = Config::JSON->new( $system_configuration )->config;
=cut

    }

    return \@cells;
    
}

# TODO : how to mark cells that ask as references ? how to mark cells for which significance is to be computed ?

__PACKAGE__->meta->make_immutable;

1;
