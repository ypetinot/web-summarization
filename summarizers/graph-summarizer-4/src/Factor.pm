package Factor;

# Factor instance in a FactorGraph - a Factor is instantiated from / associated with a FactorType

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# id
has 'id' => ( is => 'ro' , isa => 'Str' , required => 1 );

with('Identifiable');

# (factor) type
has 'type' => ( is => 'ro' , does => 'FactorType' , required => 1 );

# TODO : how can we implement this using delegation ?
sub featurize {
    my $this = shift;
    return $this->type->featurize( $this->object1 , $this->object2 );
}

# (factor graph) instance
has 'instance' => ( is => 'ro' , does => 'FactorGraph' , required => 1 );

# object 1
has 'object1' => ( is => 'ro' , required => 1 );

=pod # probably no longer needed
# TODO : trait to avoid having to replicate this piece of code ?
around 'object1' => sub {

    my $orig = shift;
    my $self = shift;
    
    if ( scalar( @_ ) ) {
	return $self->$orig( @_ );
    }

    no strict;
    return $self->instance->{ $self->$orig() };

};
=cut

# object 2
has 'object2' => ( is => 'ro' , required => 1 );

=pod # probably no longer needed
# TODO : trait to avoid having to replicate this piece of code ?
around 'object2' => sub {

    my $orig = shift;
    my $self = shift;
    
    if ( scalar( @_ ) ) {
	return $self->$orig( @_ );
    }

    no strict;
    return $self->instance->{ $self->$orig() };

};
=cut

sub value {

    my $this = shift;

    # the factor value is computed by call the underlying factor type using the current variable attachments
    # TODO : what is left to do to handle unobserved variables ?

    # TODO : generalize ?
    return $this->type->value( $this->object1 , $this->object2 );

}

__PACKAGE__->meta->make_immutable;

1;
