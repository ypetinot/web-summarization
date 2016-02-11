package Modality;

use strict;
use warnings;

# base class for all modalities - that is for the abstraction of specific facets of the data available through Category::UrlData
# TODO:
# 2 - all modalities should be mutually exclusive so that they can be considered simulataneously without any form of overlap (unless explicitly requested).
# 3 - each modality then has its own way of producing objects and subobjects, the only requirement (maybe supported through a role) is that the objects/sub-objects be traceable in terms of how they were produced and which modality they originated from.

use MooseX::Role::Parameterized;

parameter fluent => (
    isa => 'Str',
    required => 0,
    default => 0
); 

parameter namespace => (
    isa => 'Str',
    required => 1
);

parameter id => (
    isa => 'Str',
    required => 1
);

role {

    my $p = shift;
    my $fluent = $p->fluent;
    my $namespace = $p->namespace;
    my $id = $p->id;

    # id
    #has 'id' => ( is => 'ro' , isa => 'Str' , required => 1 , default => $id );
    my %id_params;
    if ( defined( $id ) ) {
	$id_params{ id } = $id;
    }
    with('Identifiable' => \%id_params );
    
    # object
    has 'object' => ( is => 'ro' , isa => 'Category::UrlData' , required => 1 );
    
    # fluent
    # TODO : there should probably be a disctinction between fluent and segmented ?
    has 'fluent' => ( is => 'ro' , isa => 'Bool' , required => 1 , default => $fluent );

    # Note : this is only needed if we want to use a standardized method call to generate the segments
    #requires 'data';

    # ArrayRef[text segments] (note this implies a TextModality => create base class)
    ##requires 'segments';

    # ArrayRef[Web::Summarizer::StringSequence]
    # Note : we could just move the utterances generation code here since utterances are generated from segments
    ##requires 'utterances';

    with( 'CachedCollection' => { namespace => $namespace , name => $id } );

};

1;
