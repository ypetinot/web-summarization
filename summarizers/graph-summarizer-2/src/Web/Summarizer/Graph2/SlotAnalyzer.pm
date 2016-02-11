package Web::Summarizer::Graph2::SlotAnalyzer;

use Moose;

use Web::Summarizer::Graph2::Definitions;
use Web::Summarizer::Graph2::StringProcessor;

use Net::Dict;
#use Text::Trim;

my $DICTD_SERVER = "pan.alephnull.com";
my $dict = Net::Dict->new( $DICTD_SERVER );

# TODO : add context-based type detection ? --> doesn't seem necessary --> how would this affect caching
my %token2analysis;

sub analyze {

    my $string = shift;
    my @token_sequence = grep { defined($_) && length($_) && $_ !~ m/^[[:punct:]]+$/; } map { Web::Summarizer::Graph2::StringProcessor->cleanse( $_ ); } split /\s+/, $string;

    my @filler_candidates;
    my $token_sequence_length = scalar(@token_sequence);
    for (my $i=0; $i<$token_sequence_length; $i++) {

	    my $token = $token_sequence[ $i ];
	    
	    my $type = undef;
	    my @candidate;
	    
	    # not perfect
	    if ( defined ( $token2analysis{ $token } ) ) {
		
		my $cached_entry = $token2analysis{ $token };
		my @verification_tokens = @{ $cached_entry->[ 0 ] };
		
		my $cache_match = 1;
		for (my $j=0; $j<scalar(@verification_tokens); $j++) {
		    
		    if ( $i + $j > $#token_sequence ) {
			$cache_match = 0;
			last;
		    }
		    elsif ( $verification_tokens[ $j ] ne $token_sequence[ $i + $j ] ) {
			$cache_match = 0;
			last;
		    }
		    
		}
		
		if ( $cache_match ) {
		    push @filler_candidates, $cached_entry;
		    $i = $i + scalar(@verification_tokens);
		    next;
		}
		
	    }
	    
	    
	    if ( $token =~ m/^\d.+\d$/s ) {
		
		$type = '<number>';
		push @candidate, $token;
		
	    }
	    else {

		eval {
		    
		    my $wordnet_entries = $dict->match( $token , 'exact' , 'wn' );
		    if ( ! scalar(@{ $wordnet_entries }) ) {
			$wordnet_entries = $dict->match( $token , 'lev' , 'wn' );
		    }
		    
		  outer: foreach my $word_entry (@{ $wordnet_entries }) {
		      
		      my $definitions = $dict->define( $word_entry->[ 1 ] , $word_entry->[ 0 ] );
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
				  # Treat adverbs as regular tokens
				  #$type = $Web::Summarizer::Graph2::Definitions::POS_ADVERB;
				  last outer;
			      }
			      elsif ( $definition_line =~ m/^\s*v / ) {
				  $type = $Web::Summarizer::Graph2::Definitions::POS_VERB;
			      }
			      
			      if ( defined( $type ) ) {
				  push @candidate, $token;
				  last outer;
			      }
			      
			  }
			  
		      }	  
		      
		  }
		    
		}
	
	    }
	    
	    if ( ! defined( $type ) ) {
		
		# scan for Named Entities
		while ( $i < $token_sequence_length && $token =~ m/^[A-Z]\w+/s ) {
		    push @candidate, $token;
		    $type = $Web::Summarizer::Graph2::Definitions::POS_NAMED_ENTITY;
		    $token = $token_sequence[ ++$i ];
		}
		
	    }
	    
	    if ( defined( $type ) ) {
		
		my $entry = [ \@candidate , $type ];
		
		# update cache
		# TODO: ( should we store alternate possibilities ? )
		my $entry_key = $candidate[ 0 ];
		if ( ! defined( $entry_key ) ) {
		    die "Invalid entry key ...";
		}
		$token2analysis{ $entry_key } = $entry;
		
		push @filler_candidates, $entry;
		
	    }
	    
    }

    return \@filler_candidates;

}
    
no Moose;

1;
