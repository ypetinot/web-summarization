package DMOZ::Mapper::SingleNodeMapper;

use strict;
use warnings;

# computes perplexity of a set of DMOZ entries wrt specified model

use DMOZ::Mapper;
use base qw(DMOZ::Mapper);

# constructor
sub new {

    my $that = shift;
    my $target_path = shift;
    my $wanted_fields = shift;
    my $func = shift;
    
    # instantiate super class
    my $ref = $that->SUPER::new();

    my @path_components = split /\//, $target_path;
    
    $ref->{_target_path } = \@path_components;
    $ref->{_path_cursor} = 0;
    
    $ref->{_wanted_fields} = $wanted_fields;
    $ref->{_func} = $func;
    
    return $ref;

}

# begin method
sub begin {

    my $this = shift;
    my $hierarchy = shift;

    $this->{_hierarchy} = $hierarchy;
    $this->{_evaluated_function} = 0;

}

# pre process method
sub pre_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;

    if ( $this->{_path_cursor} >= scalar(@{$this->{_target_path}}) ) {

	# evaluate the target function
	if ( ! $this->{_evaluated_function} ) {
	    $this->{_func}->($path,$data);
	    $this->{_evaluated_function} = 1;
	}

	return undef;

    } 


    my @expected_name_components;
    for (my $i=0; $i<=$this->{_path_cursor}; $i++) {
	push @expected_name_components, $this->{_target_path}->[$i];
    }
    my $expected_name = join('/',@expected_name_components);

    if ( $node->name() ne $expected_name ) {
	return undef;
    }

    my @wanted_data;

    foreach my $field (@{ $this->{_wanted_fields}}) {
	push @wanted_data, $node->get($field);
    }
    
    $this->{_path_cursor}++;

    return \@wanted_data;
    
}

# post process method
sub post_process {

    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;
    my $recursion_outputs = shift;

    # nothing

}

# end method
sub end {

    my $this = shift;
    my $hierarchy = shift;

}

1;

