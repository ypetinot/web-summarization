package Evaluation::TableBuilder;

use strict;
use warnings;

use Evaluation::Definitions;

use Algorithm::Loops qw(
        Filter
        MapCar MapCarU MapCarE MapCarMin
        NextPermute NextPermuteNum
        NestedLoops
    );

use LaTeX::Table;
#use Table::Data;
use Number::Format qw(:subs);  # use mighty CPAN to format values

use Moose;
use namespace::autoclean;

# systems
has 'systems' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , default => sub { {} } );

my %data_points;
my @raw_data_header;

my @headers_parameters;
my @headers_data;

my $count = 0;
my $n_fields = 0;

my %param2values;

my $separator = $Evaluation::Definitions::SYSTEM_FIELD_SEPARATOR;
my $separator_key_value = $Evaluation::Definitions::KEY_VALUE_SEPARATOR;

my $sort_numeric = sub { my ( $a , $b ) = @_; return ( $a <=> $b ); };
my $sort_alphanumeric = sub { my ( $a , $b ) = @_; return ( $a cmp $b ); };

# 1 - table definition
# TODO: config file ?
# TODO : should we allow for vertical row headers ?
my $requested_headers = {
    'rows' => {
	'system' => {
	    sort => $sort_alphanumeric ,
	    partition => {
		'reference-ranker-class' => { sort => $sort_alphanumeric }
	    }
	} 
    },
    'columns' => {
	'reference-cluster-limit' => {
	    sort => $sort_numeric ,
	    partition => {
		'ngram-jaccard-jaccard-1' => {},
		'ngram-jaccard-jaccard-2' => {},
		'ngram-jaccard-jaccard-3' => {},
		'ngram-prf-fmeasure-1' => {},
		'ngram-prf-fmeasure-2' => {},
		'ngram-prf-fmeasure-3' => {},
		'ngram-prf-precision-1' => {},
		'ngram-prf-precision-2' => {},
		'ngram-prf-precision-3' => {},
		'ngram-prf-recall-1' => {},
		'ngram-prf-recall-2' => {},
		'ngram-prf-recall-3' => {}
	    }
	}
    }
};


sub add_system_point {

    my $this = shift;
    my $coordinates = shift;
    my $system_key = shift;

    $this->systems->{ $system_key } = $coordinates;

}

sub _get_headers {

    my $headers_definition = shift;

    my @headers;

    my $current = $headers_definition;
    while( scalar( keys( %{ $current } ) ) ) {

	foreach my $key ( keys %{ $current } ) {
	    my %properties_copy;
	    map { $properties_copy{ $_ } = $current->{ $key }->{ $_ }; } grep { $_ ne 'partition' } keys( %{ $current->{ $key } } );
	    push @headers , [ $key , \%properties_copy ];
	}

	$current = $current->{ 'partition' };

    }

    return \@headers;

}

# TODO : remove code redundancy
my $row_headers = _get_headers( $requested_headers->{ 'rows' } ); 
my $column_headers = _get_headers( $requested_headers->{ 'columns' } );

my %system_configuration;
map { $param2values{ $_ }{ $system_configuration{ $_ } }++; } keys( %system_configuration );

my %param2cardinality;
map { $param2cardinality{ $_ } = scalar( keys( %{ $param2values{ $_ } } ) ); } keys( %param2values );

# 3 - table generation

# **************************************************************************************************************************************************************************
# 3 - 2 - generate header
# **************************************************************************************************************************************************************************

sub _build_header {

    my $headers = shift;
    my $position = shift || 0;
    my $repetition = shift || 1;

    my $current_header = $headers->[ $position ];
    my $current_header_repetition = $param2cardinality{ $current_header } || 1;

    my $sub_header;

    if ( $position < scalar( @{ $headers } ) - 1 ) {
	$sub_header = _build_header( $headers , $position + 1 , $current_header_repetition );
    }
    else {
	$sub_header = \@raw_data_header;
    }

    my $column_span = scalar( @{ $sub_header } ) / $current_header_repetition;
    
    my @local_header_motif = ( join( ':' , $current_header , $column_span . "c" ) );
    # column fillers
    for (my $j=0; $j<( $column_span - 1 ); $j++) {
	push @local_header_motif , '';
    }

    my @local_header;
    for (my $i=0; $i<$current_header_repetition * $repetition; $i++) {
	push @local_header , @local_header_motif;
    }
    
    return \@local_header;

}

my @table_header = _build_header( $column_headers );
my $header_length = scalar( @{ $table_header[ 0 ] } );

# **************************************************************************************************************************************************************************
# 3 - 3 - generate data
# **************************************************************************************************************************************************************************

# TODO ?
# TODO : use Data::Table for the table definition and population ?
=pod
my @table_data;
my @row_filler_model = map { '' } 1..$header_length;
foreach my $system_key (keys( %data_points )) {
    my @temp_row_filler = @row_filler_model;
    push @table_data, \@temp_row_filler;
}
=cut

# populate multi-dimensional array using nested infinite loops
# TODO : remove code redundancy
my $row_configurations = _generate_configurations( $row_headers );
my $column_configurations = _generate_configurations( $column_headers );

sub _generate_configurations {
    
    my $headers_group = shift;

    my @domains = map { [ sort { $requested_headers->{ $_ }->{ 'sort' }->( $a , $b ); } keys( %{ $param2values{ $_ } } ) ] } @{ $headers_group };
    my @configurations= NestedLoops(
	\@domains,
	sub { \@_; },
	);

    return \@configurations;

}

my @table_data;
foreach my $row_configuration (@{ $row_configurations }) {
    
    my %row_config;
    my @row = @{ $row_configuration };

    map { $row_config{ $row_headers->[ $_ ] } = $row_configuration->[ $_ ]; } 0..$#{ $row_headers };

    foreach my $column_configuration (@{ $column_configurations }) {

	map { $row_config{ $column_headers->[ $_ ] } = $column_configuration->[ $_ ]; } 0..$#{ $column_headers };

	foreach my $field (@raw_data_header) {
	    
	    my $system_field_key = _generate_system_field_key( \%row_config , $field );
	    my $cell_value = $data_points{ $system_field_key };

	    push @row , $cell_value;
	    
	}
	
    }

    push \@table_data , \@row;

}

# **************************************************************************************************************************************************************************
# 3 - 4 - generate latex table
# **************************************************************************************************************************************************************************

my $table_latex = LaTeX::Table->new(
    {
#        filename    => 'prices.tex',
#        maincaption => 'Price List',
#        caption     => 'Try our special offer today!',
#        label       => 'table:prices',
#        position    => 'tbp',
        header      => \@table_header,
        data        => \@table_data,
    }
    );


$table_latex->set_callback(sub { 
    my ($row, $col, $value, $is_header ) = @_;

    if ( $value eq '_root' ) {
	$value = '';
    }
    elsif ( ! $is_header ) {
	$value = '';
	    #$data_points{ $raw_system_id }{ $raw_data_header[ $i ] };
    }
    
    return $value;
			   });

# https://rtcpan.develooper.com/Public/Bug/Display.html?id=29641
print $table_latex->generate_string();

# Supporting functions

sub _parse_system_configuration {

    my $encoded_id = shift;

    my @fields = split /\Q$separator\E/ , $encoded_id;
    
    my $system_id = shift @fields;

    my %system_configuration;

    # TODO : this should not be necessary !
    $system_configuration{ 'system' } = $system_id;

    map {
	
	my $param_entry = $_;
	my ( $param_key , $param_value ) = split /$separator_key_value/ , $param_entry;

	$system_configuration{ $param_key } = $param_value;

    } @fields;
    
    return \%system_configuration;

}

sub _generate_system_field_key {

    my $system_configuration = shift;
    my $field_key = shift;

    my @elements = map { join( $separator_key_value , $_ , $system_configuration->{ $_ } ) } sort { $a cmp $b } keys( %{ $system_configuration } );

    return join( $separator , @elements , $field_key);

}

__PACKAGE__->meta->make_immutable;

1;
