package RandomVariable;

# Current : make this a Trait instead ?

use strict;
use warnings;

#use Moose::Role;
use MooseX::Role::Parameterized;
with('MooseX::Log::Log4perl');

parameter type => {
    isa => 'Str',
    required => 1
}

role {

    my $p = shift;
    my $type = $p->type;

    # value
    has 'value' => ( is => 'ro' , isa => $type , predicate => 'observed' , required => 0 );

# connected objects
# TODO : might want to move this functionality to a subclass as this is not a generic functionality for all RandomVariable's
    has 'connected_objects' => ( is => 'ro' , isa => 'HashRef[Notifiable]' , default => sub { {} } );

    sub set {
	
	my $this = shift;
	my $value = shift;
	
	# 0 - check whether this value is different than the current one
	# TODO
	
	# 1 - set value in underlying object
	# TODO
	
	# 2 - inform dependent objects that this variable's value has changed
	$this->notify_change_all;
	
    }
    
    sub register_connected_object {
	
	my $this = shift;
	my $object = shift;
	
	my $object_id = $object->id;
	if ( defined( $this->connected_objects->{ $object_id } ) ) {
	    # do nothing
	    $this->debug->warning("Object $object_id is already connected to the current RandomVariable ...");
	}
	else {
	    $this->connected_objects->{ $object_id } = $object;
	}
	
    }
    
    sub notify_change_all {
	
	my $this = shift;
	
	foreach my $connected_object_id ( %{ $this->connected_objects } ) {
	    $this->nofity_change( $connected_object );
	}
	
    }
    
    sub notify_change {
	
	my $this = shift;
	my $connected_object_id = shift;
	
	my $connected_object = $this->connected_objects->{ $connected_object_id };
	$connected_object->set_dirty( $this );
	
    }
    
};

1;
