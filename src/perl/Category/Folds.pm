package Category::Folds;

# Abstracts the collections of folds over raw category data

# A Folds object is typically instantiated only once to create a set of folds for a given dataset. Once this has been
# done, individual Fold instances can be used/serialized independently and there is no need (at least for now) to
# keep/serialize a Folds instance.

use strict;
use warnings;

use Moose;

use Category::Data;
use Category::Fold;

use File::Path;
use POSIX;

# mode: leave-n-out
our $MODE_NAME_LEAVE_N_OUT = "leave-n-out";

# mode: leave-p-out
our $MODE_NAME_LEAVE_P_OUT = "leave-p-out";

# mode: all
our $MODE_NAME_ALL = "all";

# fields

# category data back pointer
has 'category_data' => ( is => 'rw', required => 1 , traits => [ 'DoNotSerialize' ] );
 
# folds
has 'folds' => ( is => 'rw', isa => 'ArrayRef[Category::Fold]', init_arg => undef , builder => '_folds_builder' );
sub _folds_builder {
    my $this = shift;
    return $this->load || $this->create;
}

# folds files
has 'folds_files' => (is => 'ro', isa => 'ArrayRef[Str]', default => sub { [] });

# create folds
sub create {

    my $this = shift;
    my $mode = shift;
    my $param = shift;

    my @folds;

    # load (minimal) category data
    # TODO : improve
    my $urls = $this->category_data->urls;
    if ( ! $urls ) {
	die "Unable to load category data ...";
    }
    
    # all existing entries
    my @all_entries = @{ $urls };

    # number of gists
    my $n_gists = scalar( @all_entries );

    # all available gists indices
    my @all_gists_indices;
    for (my $i=0; $i<$n_gists; $i++) {
	push @all_gists_indices, $i;
    }

    if ( $mode eq $MODE_NAME_LEAVE_N_OUT || $mode eq $MODE_NAME_LEAVE_P_OUT ) {
	
	my $target_splice_out_size = $param || 1;
	if ( $mode eq $MODE_NAME_LEAVE_P_OUT && $param ) {
	    # if the current category is too small (i.e. less than param entries) we hold out at least one entry per fold
	    $target_splice_out_size = floor( ( $param / 100 ) * $n_gists ) || 1;
	}
	    
	# generate folds
	for (my $i=0; $i<$n_gists / $target_splice_out_size; $i++) {
	    
	    my @fold_gists_indices = @all_gists_indices;
	    splice @fold_gists_indices, $i * $target_splice_out_size, $target_splice_out_size;
	    
	    if ( scalar(@fold_gists_indices) - ( $n_gists - $target_splice_out_size ) > $target_splice_out_size ) {
		die "An error occurred while creating fold $i ...";
	    }
	    
	    # create fold instance
	    my $fold = new Category::Fold( id => $i , category_data_base => $this->category_data_base , fold_gists => \@fold_gists_indices );
	    
	    # append new fold to the list of folds
	    push @{ $this->folds }, $fold;
	    
	}
	
    }
    else { # or do we just want to have a separate method to access the complete data fold ?

	# create fold instance
	my $complete_fold = new Category::Fold( category_data => $this->category_data , fold_gists => \@all_gists_indices );

	# append new fold to the list of folds
	push @folds, $complete_fold;

    }

    return \@folds;

}

# get the number of folds maintained by this instance
sub size {
    my $this = shift;
    return scalar( @{ $this->folds } );
}

# get a specific fold
sub get_fold {

    my $this = shift;
    my $index = shift;

    my $fold = $this->folds->[ $index ];

    return $fold;

}

# folds base directory
sub folds_file {
    my $this = shift;
    return $this->category_data->category_file_name( "folds" );
}

# get the base serialization path for folds
sub base_serialization_path {

    my $this = shift;
    my $create_path = shift || 0;
    my $serialization_path = $this->folds_file;

    return $serialization_path;

}

# serialize the folds
sub serialize_folds {

    my $this = shift;

    open FOLDS, ">" . $this->folds_file or die "Unable to create folds file: " . $this->folds_file;
    
    my @folds = @{ $this->folds };
    for (my $i=0; $i<scalar(@folds); $i++) {
	my $fold = $folds[$i];
	print FOLDS join( "\t" , $fold->id , $fold->freeze ) . "\n";
    }

    close FOLDS;

}

# load
sub load {

    my $this = shift;
	
    # Reads folds file content
    if ( open( FOLDS , $this->folds_file ) ) {
	
	my @folds;
	while ( <FOLDS> ) {
	    
	    chomp;
	    my @fields = split /\t/, $_;
	    my $fold_id = shift @fields;
	    my $fold_json = shift @fields;
	    
	    my $fold_object = Category::Fold->restore( $this->category_data , $fold_json );
	    push @folds, $fold_object;
	    
	}
	
	close( FOLDS );

	return \@folds;
	
    }

    return undef;

}

__PACKAGE__->meta->make_immutable;

1;
