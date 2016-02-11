package Experiments::NAACL_HLT_2015::ReferenceAdaptation;

use strict;
use warnings;

use File::Temp;
use Significance;

use Moose;
use namespace::autoclean;

extends( 'Experiment::Table' );
with( 'Experiments::EMNLP_2015' );

has 'significance_analyzer' => ( is => 'ro' , isa => 'Significance' , init_arg => undef , lazy => 1 , builder => '_significance_analyzer_builder' );
sub _significance_analyzer_builder {
    my $this = shift;
    return new Significance;
}

sub post_formatting {

    my $this = shift;
    my $cell = shift;
    my $cell_value = shift;

    # 1 - determine if cell_value is max in the current block
    # TODO : to be combined with cell markers
    my $cell_row = $cell->row;
    my $cell_column = $cell->column;

    if ( $cell_column == 0 ) {
	return $cell_value;
    }

    my $cell_block = $this->_system_block( $cell );
    if ( $cell_block eq 'title' ) {
	return $cell_value;
    }

    my $column = $this->get_column( $cell_column );
    my $first = 1;
    my $is_max = 1;
    foreach my $column_cell ( @{ $column } ) {

	if ( $first ) {
	    $first = 0;
	    next;
	}

	if ( $column_cell == $cell ) {
	    next;
	}

	if ( $this->_system_block( $column_cell ) ne $cell_block ) {
	    next;
	}

	if ( ( ( $column_cell->value == $cell_value ) && ( $column_cell->row < $cell_row ) ) || ( $column_cell->value > $cell_value ) ) {
	    $is_max = 0;
	}

    }

    my $post_formatted_value = $cell_value;
    if ( $is_max ) {
	$post_formatted_value = '\textbf{' . $post_formatted_value . '}';
    }

    return $post_formatted_value;
    
}

sub _system_block {

    my $this = shift;
    my $cell = shift;

    my $cell_row = $cell->row;
    my $cell_column = $cell->column;

    my $cell_row_system = $this->_cell_array->[ $cell_row ]->[ 0 ]->value;
    my @cell_row_system_elements = split /:::/ , $cell_row_system;
    my $cell_row_block = $cell_row_system_elements[ 0 ];

    return $cell_row_block;

}

sub cell_markers {

    my $this = shift;
    my $cell = shift;
    my $cell_value = shift;

    my @markers;

    # 1 - determine cell position
    my $cell_row = $cell->row;
    my $cell_column = $cell->column;

    # 2 - is this a cell of interest ?
    # TODO : this should really be specified through configuration
    if ( $cell_row && $cell_column ) { # i.e. we don't do anything for the header cells
	my $cell_row_system = $this->_cell_array->[ $cell_row ]->[ 0 ]->value;
	if ( $cell_row_system ne 'title' && $cell_row_system !~ m/baseline/ && $cell_row_system ne 'adaptation:::graph4-adaptation-extractive-reranked-oracle' ) { # i.e. we don't do anything for baseline systems

	    # significance to closest baseline system
	    my $reference_cell_row = $cell_row - 1;
	    while ( $this->_cell_array->[ $reference_cell_row ]->[ 0 ]->value !~ m/baseline/ ) {
		$reference_cell_row--;
	    }

	    # 3 - determine target cell to compare to
	    my $reference_cell = $this->_cell_array->[ $reference_cell_row ]->[ $cell_column ];

	    # 4 - determine target cell value (should not lead to infinite recursion)
	    my $reference_cell_value = $reference_cell->value;

	    # 5 - compute significance
	    if ( $cell_value > $reference_cell_value ) {
		my $reference_cell_row_system = $this->_cell_array->[ $reference_cell_row ]->[ 0 ]->value;
		my ( $is_significant , $p_value , $significance_test ) = $this->is_difference_significant( $reference_cell , $cell );
		$this->logger->debug( "Testing significance between $cell_row_system ($cell_value) and $reference_cell_row_system ($reference_cell_value) => $is_significant");
		if ( $is_significant ) {
		    push @markers , [ $is_significant , $p_value , $significance_test ];
		}
	    }

	} 
    }

    # 4 - compute marker(s)

    return \@markers;

}

sub is_difference_significant {

    my $this = shift;
    my $reference_cell = shift;
    my $cell = shift;

    my $reference_distribution = $reference_cell->_instances;
    my $target_distribution = $cell->_instances;

    return $this->significance_analyzer->test_significance( $reference_distribution , $target_distribution );

}

# system entries builder
sub _system_entries_builder {

    my $this = shift;

    # CURRENT : namespace ?
    #my @system_namespaces = ( 'graph4-ranking-combined' );
    #foreach my $system_namespace ( @system_namespaces ) {
    #my $core_system_id = join( ':::' , $system_namespace , $core_system->[ 0 ] );

    # CURRENT : generate list of cells from meta-configuration
    my $summarizer_systems_entries = $this->generate_summarizer_systems_entries;
    my @systems = @{ $summarizer_systems_entries };
    
    return \@systems;

}

# TODO : to be share with ReferenceRanking
sub _header_cells_builder {
    my $this = shift;
    my @header_cells = @{ $this->metrics };
    return \@header_cells;
}

sub generate_unit_group_id {

    my $this = shift;
    my $system_label = shift;
    my $system_configuration = shift;

    return $system_label;

}

sub _rows_builder {

    my $this = shift;
    
    my @system_rows;

    my $system_entries = $this->system_entries;
    foreach my $system_entry ( @{ $system_entries } ) {
	push @system_rows , $system_entry;
    }

    return \@system_rows;

}

__PACKAGE__->meta->make_immutable;

1;
