package LPSolver::Problem;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# maximize ?
has 'maximize' => ( is => 'ro' , isa => 'Bool' , default => 1 );

# id
has 'id' => ( is => 'ro' , isa => 'Str' , required => 1 );

# objective key
has 'objective_key' => ( is => 'ro' , isa => 'Str' , required => 1);

# variables
has 'variables' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

# objective
has 'objective' => ( is => 'rw' , isa => 'ArrayRef' , predicate => 'has_objective' );

# constraints
has 'constraints' => ( is => 'ro' , isa => 'ArrayRef' , default => sub { [] } );

sub objective_string {
    my $this = shift;
    return $this->_weighted_variables_sum_string( $this->objective );
}

sub _weighted_variables_sum_string {
    my $this = shift;
    my $weighted_variables_sum_definition = shift;
    my $weighted_variables_sum_string = join ( " + " ,
					       (
						map {
						    my $variable_id = $_->[ 0 ];
						    my $variable_weight = $_->[ 1 ];
						    $this->_register_variable( $variable_id );
						    join( ' * ' , $variable_weight , $variable_id );
						}  
						grep { $_->[ 1 ] }
						@{ $weighted_variables_sum_definition } )
	);
    return $weighted_variables_sum_string;
}

sub _register_variable {
    my $this = shift;
    my $variable_id = shift;
    $this->variables->{ $variable_id }++;
}

sub add_constraint {
    my $this = shift;
    my $constraint_definition = shift;
    push @{ $this->constraints } , [
	$this->_weighted_variables_sum_string( $constraint_definition->[ 0 ] ),
	$constraint_definition->[ 1 ],
	$constraint_definition->[ 2 ] ];
}

sub sorted_variables {
    my $this = shift;
    my @sorted_variables = sort { $a cmp $b } keys( %{ $this->variables } );
    return \@sorted_variables;
}

# problem file
# TODO : we should avoid creating a temp file for this, what other options do we have ?
has '_problem_file' => ( is => 'ro' , isa => 'File::Temp' , init_arg => undef , lazy => 1 , builder => '_write_problem' );

# write lp problem to file
sub _write_problem {

    my $this = shift;

    my $id = $this->id;

    # 1 - generate LP problem
    my $lp_problem_fh = File::Temp->new;
    my $lp_problem_filename = $lp_problem_fh->filename;

    open LP_PROBLEM , ">$lp_problem_filename" or die "Unable to create lp problem file ($lp_problem_filename): $!";

    # TODO : there is actually no need to sort the variables
    my @sorted_variables = @{ $this->sorted_variables };

    # 1 - variable definitions
    foreach my $variable ( @sorted_variables ) {
	print LP_PROBLEM "var $variable;\n";
    }
    
    # 2 - objective
    my $mode_string = $this->maximize ? "maximize" : "minimize";
    my $objective_key = $this->objective_key;
    print LP_PROBLEM "$mode_string $objective_key: " . $this->objective_string . ";\n";
    
    # 3 - constraints
    my $constraint_id = 0;
    foreach my $constraint ( @{ $this->constraints } ) {
	$constraint_id++;
	my $constraint_expression = $constraint->[ 0 ];
	my $constraint_operator = $constraint->[ 1 ];
	my $constraint_bound = $constraint->[ 2 ];
	print LP_PROBLEM "s.t. c$constraint_id: " . join( ' ' , $constraint_expression , $constraint_operator , $constraint_bound ) . ";\n";
    }    

    print LP_PROBLEM "\n\n";
    print LP_PROBLEM "solve;\n";
    print LP_PROBLEM "display " . join( ',' , $objective_key , @sorted_variables ) . " ;\n";
    print LP_PROBLEM "end;\n";

    close LP_PROBLEM;
    
    return $lp_problem_fh;

}

__PACKAGE__->meta->make_immutable;

1;

package LPSolver;

use strict;
use warnings;

use Environment;

use Moose::Role;

# path to LP solver
# TODO: we could have a top level module provide this service (akin to FindBin but specific to my distribution)
has '_lp_solver_path' => ( is => 'ro' , isa => 'Str' , builder => '_lp_solver_path_builder' , lazy => 1 );
sub _lp_solver_path_builder {
    my $this = shift;
    return join( "/" , Environment->third_party_local_bin , 'glpsol' );
}

# solve
sub solve {

    my $this = shift;
    my $lp_problem = shift;

    my $objective_value;
    my %lp_solution;

    if ( $lp_problem->has_objective ) {

	my $lp_problem_filename = $lp_problem->_problem_file->filename;
	my $lp_solver_path = $this->_lp_solver_path;
	
	open LP_SOLVER, "$lp_solver_path --math $lp_problem_filename | grep '.val' | sed 's/.val / /' | cut -d' ' -f1,3 |" || die "Unable to launch LP solver ($lp_problem_filename): $!";
	
	# read from LP_SOLVER
	while ( <LP_SOLVER> ) {
	    chomp;
	    my ( $key , $value ) = split /\s+/ , $_;
	    $lp_solution{ $key } = $value;
	}
	
	close LP_SOLVER || die "Did not reach end of LP solver output stream: $! $?";
	
	# TODO : this is more efficient than testing every single time for the objective key, but not very elegant
	# TODO : can I clean this up somehow ?
	my $objective_key = $lp_problem->objective_key;
	$objective_value = $lp_solution{ $objective_key };
	delete $lp_solution{ $objective_key };

    }
    
    return ( \%lp_solution , $objective_value ) ;

}

1;
