package WordGraph::Node;

use strict;
use warnings;

use Web::Summarizer::Token;

use Clone;

use Moose;
#use namespace::autoclean

use overload 
    q("")  => sub { return shift->id() },
    q(cmp) => sub { my $a = shift; my $b = shift; return ( $a->id() cmp $b->id() ); },
    q(ne)  => sub { my $a = shift; my $b = shift; return ( $a->id() ne  $b->id() );  },
    q(eq)  => sub { my $a = shift; my $b = shift; return ( $a->id() eq  $b->id() );  };

# parent graph
has 'graph' => ( is => 'ro' , isa => 'WordGraph' , required => 1 );

# TODO : extend Web::Summarizer::Token instead ?
# delegation to underlying token
has 'token' => ( is => 'ro' , isa => 'Web::Summarizer::Token' , handles => qr/^(?!id).*/ , required => 1 );

# key (should be unique at graph level)
has 'id' => ( is => 'ro' , isa => 'Str' , init_arg => undef , builder => '_build_id' , lazy => 1 );
sub _build_id {

    my $this = shift;

    # TODO: should the key generation function be configurable ?
    my $key = $this->shared_key . ( $this->index ? "/" . $this->index : '' );

    return $key;

}

### # Annotation
### has 'annotation' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } , required => 0 );

### # Annotation
### # TODO: should we allow for more than one annotation ?
### has 'annotation' => ( is => 'rw' , isa => 'Str' , default => '' , required => 0 );

# (replication) index
has 'index' => ( is => 'ro' , isa => 'Num' , default => 0 );

# clone of
has 'clone_of' => ( is => 'ro' , isa => 'WordGraph::Node' , required => 0 );

# TODO : create copy constructor instead ?
sub clone {

    my $this = shift;

    return $this->new( graph => $this->graph(),
		       #token => Clone::clone( $this->token() ),
		       token => $this->token(),
		       id => $this->id(),
		       index => $this->index(),
		       clone_of => $this
	);

}

# get realized form
sub realize {

    my $this = shift;
    my $instance = shift;

    my $surface = $this->token()->surface();

    return $surface;

}

# get realized form for debugging purposes
sub realize_debug {

    my $this = shift;
    my $instance = shift;

    return $this->realize( $instance );

}  

__PACKAGE__->meta->make_immutable;

1;
