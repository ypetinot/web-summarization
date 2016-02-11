package Category::GlobalOperator;

use strict;
use warnings;

use Getopt::Long;
use Text::Trim;

use Moose;
use namespace::autoclean;

extends 'Category::Operator';

binmode(STDERR,':utf8');
binmode(STDOUT,':utf8');

# fields on which the operator operates
has 'fields' => ( is => 'ro' , isa => 'ArrayRef' , default => sub { [] } );

# output directory
has 'output_directory' => ( is => 'ro' , isa => 'Str' );

# output file
has 'output_file' => ( is => 'ro' , isa => 'Str' );

# output files
has '_output_files' => ( is => 'ro' , isa => 'HashRef[FileHandle]' , default => sub { {} } );

# batch (to be used by sub-classes, if needed)
has 'batch_data' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

# instance count
has 'instance_count' => ( is => 'ro' , isa => 'Num' , default => 0 , traits => ['Counter'] ,
			  handles => {
			      inc_instance_counter   => 'inc',
			      dec_instance_counter   => 'dec',
			      reset_instance_counter => 'reset',
			  }
    );

sub BUILDARGS {

    my $class = shift;

    my $p = Getopt::Long::Parser->new;
    $p->configure("pass_through");

    my %args;

    my $arg_accumulator = sub {

	my $accumulation_type = shift;

	return sub {
	    my $arg_key = shift;
	    my $arg_val = shift;
	    
	    if ( $accumulation_type eq 'ArrayRef' ) {
		if ( ! defined( $args{ $arg_key } ) ) {
		    $args{ $arg_key } = [];
		}
		push @{ $args{ $arg_key } } , $arg_val;
	    }
	    else {
		$args{ $arg_key } = $arg_val;
	    }
	};

    };

    my $meta = $class->meta;
    my %options;
    for my $attr ( $meta->get_all_attributes ) {

	my $attribute_name = $attr->name;
	#my $attribute_type = $attr->isa;
	my $attribute_type_constraint = $attr->type_constraint;

	my $attribute_type = "s";
	if ( $attribute_type_constraint eq 'ArrayRef' ) {
	    $attribute_type .= "{1,}";
	}

	my $option_definition = join("=",$attribute_name,$attribute_type);
	$options{ $option_definition } = $arg_accumulator->( $attribute_type_constraint );

    }

    my $count_threshold = undef;
    $p->getoptionsfromarray( \@_, %options );

    return ($class, \%args);

}

# top level process method
sub process {

    my $this = shift;
    my $instance_id = shift;
    my $instance = shift;

    my $instance_url = $instance->url;
    my $instance_category = $instance->get_category_id;

    # TODO : should we only increment if the instance is fully processed ?
    $this->inc_instance_counter;

    if ( scalar( @{ $this->fields } ) ) {
	foreach my $field ( @{ $this->fields } ) {
	    if ( $instance->has_field( $field ) ) {
		$this->_process( $instance_id , $instance , $field );
	    }
	}
    }
    else {
	$this->_process( $instance_id , $instance );
    }

    # TODO : can we move this up to global-category-processor
    my $category_data_base = $instance->category_data->category_data_base;
    print STDERR join( "\t" , "#instance#" , $instance_id , $instance_url , $instance_category , $category_data_base ) . "\n";

}

# default _process (can be used to test with a no-op operator)
sub _process {

    # do nothing

}

sub get_output_file {

    my $this = shift;
    my $field = shift;

    my $output_filename = $this->output_file();
    if ( ! defined( $output_filename ) ) {
	$output_filename = join( "/" , $this->output_directory() , join( "." , $field , @_ ) );
    }

    if ( ! defined( $this->_output_files()->{ $output_filename } ) ) {

	my $output_filehandle = FileHandle->new("> $output_filename");

	if ( ! defined $output_filehandle ) {
	    die "Unable to create joint counts output file ($output_filename) ...";
	}

	binmode( $output_filehandle , ':utf8' );
	$this->_output_files()->{ $output_filename } = $output_filehandle;
	
    }

    return $this->_output_files()->{ $output_filename };

}

# flush batch
sub flush_batch {

    my $this = shift;

    print STDERR ">> Flushing batch data ...\n";

    # let sub-class take care of the flushing
    $this->_flush_batch();

    # clear batch data
    foreach my $batch_data_key (keys( %{ $this->batch_data() } )) {
	delete $this->batch_data()->{ $batch_data_key };
    }
    $this->batch_data( {} );

}

# override finalize method
sub finalize {

    my $this = shift;

    if ( scalar( @{ $this->fields } ) ) {
	foreach my $field ( @{ $this->fields() } ) {
	    $this->_finalize( $field );
	}
    }
    else {
	$this->_finalize;
    }
    
}

# default _finalize
sub _finalize {

    # do nothing

}

__PACKAGE__->meta->make_immutable;

1;
