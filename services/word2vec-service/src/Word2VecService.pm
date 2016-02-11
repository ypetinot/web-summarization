package Word2VecService;

use strict;
use warnings;

use AppearanceModel::Individual;
use DMOZ::CategoryRepository;
use DMOZ::GlobalData;
use Environment;
use Word2Vec;

use FindBin;

use Moose;
#use MooseX::NonMoose::InsideOut;
use MooseX::ClassAttribute;
use MooseX::NonMoose;

extends 'JSON::RPC::Procedure';

# model file
has 'model_file' => ( is => 'ro' , isa => 'Str' , default => '/local/nlp/ypetinot/word2vec/GoogleNews-vectors-negative300.bin' );

sub analogy {
        
    my $this = shift;
    my $args = $_[ 0 ];
    
    my ( $word1 , $word2 , $word3 ) = @{ $args };
    my $analogies = Word2Vec::analogy( $word1 , $word2 , $word3 );

    return $analogies;

}

# no need to fiddle with inline_constructor here
__PACKAGE__->meta->make_immutable;

1;
