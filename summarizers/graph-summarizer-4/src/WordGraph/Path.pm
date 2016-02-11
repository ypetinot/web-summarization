package WordGraph::Path;

use strict;
use warnings;

use Moose;
use MooseX::Aliases;
use namespace::autoclean;

extends 'Web::Summarizer::Sequence';

# graph to which this path belongs
has 'graph' => ( is => 'ro' , isa => 'WordGraph' , required => 1 );

# node sequence
# Note: initially tried --> http://stackoverflow.com/questions/10051181/how-can-i-provide-an-alternate-init-arg-for-an-attribute-in-moose
has '+object_sequence' => ( is => 'ro' , isa => 'ArrayRef[WordGraph::Node]' , required => 1 , alias => 'node_sequence');

=pod # at least one method relies on the full path length, cannot be activated for now / as is
around 'length' => sub {

    my $orig = shift;
    my $self = shift;

    my $raw_length = $self->$orig();
    if ( ! $raw_length ) {
	$self->warning( "Word-graph path has length 0 ..." );
    }

    return $raw_length - 2;

};
=cut

# Note : this is only for compatibility with sequence processing in Web::Summarizer::SentenceAnalyzer
# TODO : can we do better ?
sub raw_string {
    my $this = shift;
    my $raw_string = join( ' ' , map { $_->surface } grep { ! $_->is_special } map { $_->token } @{ $this->node_sequence } );
    return $raw_string;
}

sub as_sentence {

    my $this = shift;

    # 1 - get token sequence
    my @token_sequence = map { $_->token } @{ $this->node_sequence };

    # 2 - create new Sentence based on this token sequence
    my $sentence = new Web::Summarizer::Sentence( token_sequence => \@token_sequence , string => '__created_from_path__' , object => $this->object ,
						  source_id => $this->source_id );

    return $sentence;

}

sub verbalize {
    
    my $this = shift;
    
    return join(" ", map { $_ =~ s/\<[^>]+\>(\/\d+)?:://s; $_ =~ s/\/\d+$//s; $_ } map { $_->realize( $this->object ); } grep { $_ !~ m/\<bog\>/ && $_ !~ m/\<eog\>/ } @{ $this->node_sequence });
    
}

sub verbalize_debug {

    my $this = shift;

    return join(" ", map { $_->realize_debug( $this->object ) } @{ $this->node_sequence });

}

# TODO : could be promoted to a more generic role/class ? e.g. Sequence ?
sub decompose {

    my $this = shift;

    my @decomposed;

    my @components = @{ $this };

    if ( $this->length > 1 ) {
	my $final_component = splice @components , 0 , $#components - 1;
	unshift @decomposed , $final_component;
    }
    unshift @decomposed , \@components;
    
    return \@decomposed;

}

with('Decomposable');

__PACKAGE__->meta->make_immutable;

1;
