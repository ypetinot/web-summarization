package Dictionary;

use strict;
use warnings;

use Memoize;
use Net::Dict;

use Moose::Role;

my $DICTD_SERVER = "pan.alephnull.com";

has 'dict' => ( is => 'ro' , isa => 'Net::Dict' , init_arg => undef , lazy => 1 , builder => '_dict_builder' );
sub _dict_builder {
    my $this = shift;
    return Net::Dict->new( $DICTD_SERVER );    
}

# Note : apparantly we can't use memoize inside a role => use alternative memoization module or leave it to the client package to memoize ?
#memoize('dict_pos');
sub dict_pos {

    my $this = shift;
    my $string = shift;

    my $type = undef;

    my $wordnet_entries = $this->dict->match( $string , 'exact' , 'wn' );
    if ( ! scalar(@{ $wordnet_entries }) ) {
        $wordnet_entries = $this->dict->match( $string , 'lev' , 'wn' );
    }

=pod
    my $wordnet_entries = $this->dict->match( $string , 'exact' );
    if ( ! scalar(@{ $wordnet_entries }) ) {
        $wordnet_entries = $this->dict->match( $string , 'lev' );
    }
=cut

    # TODO : add caching                                                                                                                                                                       
  outer: foreach my $word_entry (@{ $wordnet_entries }) {

      my $definitions = $this->dict->define( $word_entry->[ 1 ] , $word_entry->[ 0 ] );
      foreach my $definition_entry (@{ $definitions }) {

          # TODO: use definitions to identify dependencies with the other terms in the gist ?
          my $definition_from = $definition_entry->[ 0 ];
          my $definition = $definition_entry->[ 1 ];
          my @definition_lines = split /\n/, $definition;

          foreach my $definition_line (@definition_lines) {

              if ( $definition_line =~ m/^\s*adj / ) {
                  $type = $Web::Summarizer::Graph2::Definitions::POS_ADJECTIVE;
              }
              elsif ( $definition_line =~ m/^\s*adv / ) {
                  $type = $Web::Summarizer::Graph2::Definitions::POS_ADVERB;
              }
              elsif ( $definition_line =~ m/^\s*v / ) {
                  $type = $Web::Summarizer::Graph2::Definitions::POS_VERB;
              }

              if ( defined( $type ) ) {
                  last outer;
              }

          }

      }

  }

    return $type;
    #|| $Web::Summarizer::Graph2::Definitions::POS_OTHER;

}

1;
