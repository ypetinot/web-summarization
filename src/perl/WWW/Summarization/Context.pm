# API to manipulate Contextual Information

package WWW::Summarization::Context;

use strict;
use warnings;

use Carp;
use URI;
use XML::TreePP;
use WWW::Summarization::Context::ContextElement;

my $TARGET_ENTITY_NAME = '[@@TARGET_ENTITY@@]';

# constructor
sub new {

    my $data_structure = shift;
    if ( ! $data_structure ) {
	return undef;
    }

    my $this = { _data => $data_structure };
    bless $this;

    return $this;

}

# serialize
sub serialize {

    my $this = shift;

    # TODO: goes somewhere else
    # normalize all context elements
    foreach my $context_element (@{$this->getContextElements()}) {

	foreach my $facet ($context_element->facets()) {
	    
	    my $current = $context_element->text($facet);
	    $context_element->text($facet, WWW::String::normalize($current));
	    
	}

    }

    my $tpp = XML::TreePP->new();
    $tpp->set( indent => 2 );
    
    return $tpp->write($this->{_data});

}

# deserialize
sub deserialize {

    my $string = shift;

    my $tpp = XML::TreePP->new();
    $tpp->set( force_array => [ 'ContextElement', 'representation' ] );

    # parse context data
    my $tree = undef;
    if ( $string !~ m/\n/s && -f $string ) {
	$tree = $tpp->parsefile($string);
    }
    else {
	$tree = $tpp->parse($string);
    }

    # test
    if ( !$tree || !defined($tree->{Context}->{'-target'}) ) {
	croak("[$0] invalid context data ...");
	return undef;
    }

    return new($tree);

}

# get target
sub getTarget {

    my $this = shift;

    return new URI($this->{_data}->{Context}->{'-target'});

}


# get context elements
sub getContextElements {

    my $this = shift;

    my $tree = $this->{_data};

    my @context_elements;
    push @context_elements, map { WWW::Summarization::Context::ContextElement->new($_); } @{$tree->{Context}->{ContextElement}};

    # normalize all context elements
    foreach my $context_element (@context_elements) {

	foreach my $facet ($context_element->facets()) {

	    my $current = $context_element->text($facet);
	    $context_element->text($facet, WWW::String::normalize($current));

	}
    }

    return \@context_elements;

}

# get target entity name
sub getTargetEntityName {
    my $this = shift;
    my $tree = $this->{_data};
    #return $tree->{Context}->{TargetEntity}->{'-id'};
    return $TARGET_ENTITY_NAME;
}

# add target entity representation
sub addTargetRepresentation {

    my $this = shift;
    my $new_representation = shift;

    my $tree = $this->{_data};

    if ( ! defined($tree->{Context}->{TargetEntity}) ) {
	$tree->{Context}->{TargetEntity} = {};
	$tree->{Context}->{TargetEntity}->{'-id'} = $TARGET_ENTITY_NAME;
	$tree->{Context}->{TargetEntity}->{Representation} = [];
    }

    print STDERR "[$0] adding target representation: $new_representation\n";
    
    push @{$tree->{Context}->{TargetEntity}->{Representation}}, $new_representation;

}

# get all target representations
sub getTargetRepresentations {

    my $this = shift;
    
    my $tree = $this->{_data};
    return @{$tree->{Context}->{TargetEntity}->{Representation}};

}

# add vocabulary element
sub addVocabularyElement {

    my $this = shift;
    my $vocabulary_element = shift;

    my $tree = $this->{_data};
    
    if ( ! defined($tree->{Context}->{Vocabulary}) ) {
        $tree->{Context}->{Vocabulary} = {};
        $tree->{Context}->{Vocabulary}->{Element} = [];
    }
    elsif ( grep { $vocabulary_element =~ m/\Q$_\E/i } @{$tree->{Context}->{Vocabulary}->{Element}} ) {
	# already listed
	return;
    }

    print STDERR "[$0] adding vocabulary element: $vocabulary_element\n";

    push @{$tree->{Context}->{Vocabulary}->{Element}}, $vocabulary_element;

}

# add entity and all its representations
sub addEntity {

    my $this = shift;
    my $entity = shift;

    my $tree = $this->{_data};

    if ( ! defined($tree->{Context}->{Entities}) ) {
        $tree->{Context}->{Entities} = {};
        $tree->{Context}->{Entities}->{Entity} = [];
    }
    
    push @{$tree->{Context}->{Entities}->{Entity}}, $entity;

}

# get all entities
sub getEntities {

    my $this = shift;

    my $tree = $this->{_data};

    return map { WWW::Summarization::Chunk->newFromHash($_) } @{$tree->{Context}->{Entities}->{Entity}};

}


1;
