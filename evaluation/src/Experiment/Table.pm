package Experiment::Table;

use strict;
use warnings;

use Experiment::Table::HeaderCell;
use Experiment::Table::StringCell;
use Experiment::Table::AverageCell;

use Moose;
use Moose::Util qw/does_role/;
#use Moose::Role;
use namespace::autoclean;

extends( 'Experiment' );

# TODO : should be parameterized on a cell type ?

# tables cells
# TODO : add sanity check to make sure we don't have two cells with the same row/column values
has '_cell_array' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => 'table_builder' );
sub table_builder {

    my $this = shift;

    my @cells;

    # 1 - get header
    # TODO : find an appropriate solution for LaTeX formatting
    my $n_header_cells = 0;
    my @header_cells = map { Experiment::Table::HeaderCell->new( table => $this , row => 0 , column => $n_header_cells++ , 'value' => $_ ); } ( 'Summarizer' , map { $_->[ 0 ] } @{ $this->_header_cells } );
    push @cells , \@header_cells;

    # 2 - get body
    my $rows = $this->_rows;
    for ( my $row_index = 0 ; $row_index < scalar( @{ $rows } ) ; $row_index++ ) {

	my $row = $rows->[ $row_index ];

	my $system_binary = $row->[ 0 ];
	my $system_label = $row->[ 1 ];
	my $system_configuration = $row->[ 2 ];
	my $system_params = $row->[ 3 ];

	# TODO : should the metrics acquired/provided in a different way ?
	my $metrics = $this->metrics;

	# generate system id from system_label and system_configuration
	my $system_id = $this->generate_unit_group_id( $system_label , $system_configuration );

	$this->logger->trace( "Generating table row for $system_label / $system_id ...\n" );

	# CURRENT : do I create an actual summarizer object here ? or a summarizer configuration ?
	my $process = new Experiment::Process( type => $system_label , id => $system_id , params => $system_params );

	# TODO : the AverageCells should be inferred contextually based on the surrounding headers (?)
	my @row_cells = ( Experiment::Table::StringCell->new( table => $this , row => $row_index + 1 , column => 0 , value => $system_label ) );
	for ( my $metric_index = 0 ; $metric_index < scalar( @{ $metrics } ) ; $metric_index++ ) {
	    
	    my $metric_entry = $metrics->[ $metric_index ];

	    # TODO : row/column should be generated automatically
	    my $cell = Experiment::Table::AverageCell->new( table => $this , row => $row_index + 1 , column => $metric_index + 1 , group => $system_id , process => $process , metric => $metric_entry->[ 1 ] , precision => $this->precision );

	    push @row_cells , $cell;

	}

	# TODO : add support for significance tests / references
	# => in particular add check to make sure the list of instances are identical (at least output a warning if they aren't)

	push @cells , \@row_cells;

    }

    return \@cells;

}

# TODO : is this the best way to pass the precision configuration ? should it be required ? should Table become a role ?
# float precision
has 'precision' => ( is => 'ro' , isa => 'Num' , init_arg => undef , lazy => 1 , builder => '_precision_builder' );
sub _precision_builder {
    return 4;
}

# header cells => provided by sub-class
has '_header_cells' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_header_cells_builder' );

# rows
has '_rows' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_rows_builder' );

sub get_column {

    my $this = shift;
    my $column_index = shift;

    my @column_cells;
    foreach my $row ( @{ $this->_cell_array } ) {
	push @column_cells , $row->[ $column_index ];
    }

    return \@column_cells;

}

# TODO : is this really necessary ?
sub _units_builder {

    my $this = shift;    

    my %units;
    map {

	my $unit_group = $_->group;

	if ( ! defined( $units{ $unit_group } ) ) {
	    $units{ $unit_group } = [];
	}

	push @{ $units{ $_->group } } , $_;

    } grep { does_role( $_ , 'Experiment::Unit' ) } map { @{ $_ } } @{ $this->_cell_array };

    return \%units;

}


sub list_jobs {

    my $this = shift;
    my $instances = shift;

    my %jobs;

    # 1 - iterate over 2-dimensional array
    my $cell_array = $this->_cell_array;
    my $n_rows = scalar( @{ $cell_array } );
    for ( my $i=0; $i<$n_rows; $i++ ) {
	
	my $row = $cell_array->[ $i ];
	my $n_cols = scalar( @{ $row } );
	for ( my $j=0; $j<$n_cols; $j++ ) {
	    
	    my $cell = $row->[ $j ];
	    
	    # list jobs for the current cell
	    # TODO : role ?
	    my $cell_jobs = $cell->list_jobs( $instances );

	    # update global list
	    # TODO : shouldn't the unicity of the job list entries be guaranteed at a higher level ?
	    map { $jobs{ $_->uid } = $_ } @{ $cell_jobs };

	}

    }

    my @jobs_list = values( %jobs );
    return \@jobs_list;

}

sub generate_output {

    my $this = shift;

    # simply loop over cell array and print
    my $is_header = 1;
    foreach my $cell_row ( @{ $this->_cell_array } ) {

	my @row_values;

	foreach my $cell (@{ $cell_row }) {
	    push @row_values , $cell->value_post;
	}

	print join( ' & ' , @row_values ) . ' \\\\' . "\n";

	if ( $is_header ) {
	    print '\\hline \\hline' . "\n";
	    $is_header = 0;
	}

    }

=pod

    # TODO : how to allow for nested tables (i.e. complex tables)
    # iterate over column element
    for ( my $i=0 ; $i<=$#columns ; $i++ ) {

	my $column_element = $columns[ $i ];

	# iterate over row element
	for ( my $j=0 ; $j<=$#rows ; $j++ ) {

	    my $row_element = $rows[ $j ];

	    # Note : no particular ordering, the elements collectively define the meaning of this cell
	    # CURRENT : nested elements should themselves be Experiments
	    my $cell = new Experiment::( $row_element , $column_element );

	    # register requirements (should this be moved to a higher level ?)
	    $cell->register_requirement;

	    $array[ $i ][ $j ] = $cell;

	}

    }
=cut

}

1;
