package Vocabulary;

# TODO : convert to Moose

use strict;
use warnings;

use Vector;

# constructor
sub new {
    
    my $that = shift;
    my $words = shift;
    my $poss = shift;
    my $alts = shift;
    my $tfs = shift;
    my $semantic = shift;

    my $class = ref($that) || $that;
    
    # obj ref
    my $ref = {};
    $ref->{_word2id} = {};
    $ref->{_id2word} = [];
    $ref->{_id2pos}  = [];
    $ref->{_id2tf}   = [];
    $ref->{_alt2id}  = {};
    $ref->{_id2semantic} = [];

    # is verbose >
    $ref->{_verbose} = 0;

    # vocabulary size
    $ref->{_size} = 0;

    # bless reference
    bless $ref, $class;

    # create word --> index / index --> word mappings
    for (my $i=0; $i<scalar(@$words); $i++) {

	my $current_word = $words->[$i];
	my $current_pos  = $poss->[$i];
	my $current_alt  = $alts->[$i];
	my $current_tf   = $tfs->[$i];
	my $current_sem  = $semantic->[$i];

	$ref->add_word($current_word, $current_pos, $current_alt, $current_tf, $current_sem);

    }

    return $ref;

}

# load vocabulary from file
sub load {

    my $that = shift;
    my $vocabulary_file = shift;

    my @ids;
    my @words;
    my @tfs;
    my @semantic;

    # open vocabulary file
    # open VOCABULARY_FILE, "<:utf8", $vocabulary_file or die "Unable to open vocabulary file $vocabulary_file: $!";
    open VOCABULARY_FILE, $vocabulary_file or die "Unable to open vocabulary file $vocabulary_file: $!";

    # read vocabulary data
    my $vocabulary_count = 0;
    while(<VOCABULARY_FILE>) {

=pod
	if ( ! ( $vocabulary_count++ % 1000 ) ) {
	    print STDERR "Loading vocabulary file $vocabulary_file ~ $vocabulary_count ...\n";
	}
=cut

	chomp;
	my $line = $_;

	my @fields = split /\t/, $line;
	my $id = shift @fields;
	my $word = shift @fields;
	my $tf = shift @fields;
	my $semantic_data = shift @fields;

	push @ids, $id;
	push @words, $word;
	push @tfs, $tf;

	my $size_semantic_data = length( $semantic_data );
	#print STDERR ">> loading vocabulary entry ($id/word) $size_semantic_data\n";
	# TODO : null vector ?
	eval {
	    push @semantic, $size_semantic_data ? Vector->thaw( $semantic_data ) : new Vector( coordinates => {} ) ;
	};
	if ( $@ ) {
	    print STDERR "An error occurred while loading vocabulary entry ($id/$word) : $@\n";
	}

    }

    # close vocabulary file
    close VOCABULARY_FILE;

    # create new Vocabulary instance and return
    return new Vocabulary(\@words, [], [], \@tfs, \@semantic);

}

# return all words in this vocabulary
sub words {

    my $this = shift;

    my @words = keys( %{ $this->{_word2id} } );
    return \@words;

}

# return all word indexes in this vocabulary;
sub word_indices {

    my $this = shift;

    my @word_indices = values( %{ $this->{_word2id} } );
    return \@word_indices;

}

# add a word to this vocabulary
sub add_word {
    
    my $this = shift;
    my $current_word = shift;
    my $current_pos = shift;
    my $current_alt = shift;
    my $current_tf = shift;
    my $current_sem = shift;

    $this->{_size}++;
    my $word_id = $this->{_size};

    if ( $this->{_verbose} ) {
	print STDERR "creating new vocabulary entry [$word_id]: $current_word / $current_pos / $current_alt\n";
    }

    $this->{_word2id}->{$current_word} = $word_id;
    push @{$this->{_id2word}}, $current_word;
    push @{$this->{_id2pos}}, $current_pos;
    push @{$this->{_id2tf}}, $current_tf;
    push @{$this->{_id2semantic}}, $current_sem;

    if ( defined( $current_alt ) ) {
	$this->{_alt2id}->{$current_alt} = $word_id;
    }

    return $word_id;

}

# what is the index for a particular word ?
sub word_index {

    my $this = shift;
    my $word = shift;
    my $dynamically_create = shift || 0;

    my $index = ( $this->{_word2id}->{$word} || $this->{_alt2id}->{$word} );

    # can add this word to the vocabulary on the fly ?
    if ( $dynamically_create && !defined($index) ) {
	$index = $this->add_word($word, undef, undef);
    }

    return $index;

}

# return the POS for a particular word
sub get_pos {

    my $this = shift;
    my $word = shift;

    return $this->{_id2pos}->[$this->_vocabulary_id($word) - 1];

}

# return the string representation of a particular word
sub get_word {

    my $this = shift;
    my $word = shift;

    return $this->{_id2word}->[$this->_vocabulary_id($word) - 1];

}

# return the tf for a particular word
sub get_tf {

    my $this = shift;
    my $word = shift;

    return $this->{_id2tf}->[$this->_vocabulary_id($word) - 1];

}

# map word to its id if needed
sub _vocabulary_id {

    my $this = shift;
    my $word = shift;

    if ( $word =~ m/^\d+$/ ) {
	return $word;
    }

    return $this->word_index($word);

}

# returns the size of this vocabulary
sub size {

    my $this = shift;
    
    return $this->{_size};

}

# set/get verbose mode
sub verbose {

    my $this = shift;
    my $value = shift;

    if ( defined($value) ) {
	$this->{_verbose} = $value;
    }

    return $value;
    
}

# get semantic representation
sub semantic_representation {
    
    my $this = shift;
    my $word = shift;

    my $semantic_representation = undef;

    my $word_id = $this->_vocabulary_id($word);
    if ( $word_id && $word_id < scalar(@{ $this->{_id2semantic} }) ) {
	$semantic_representation = $this->{_id2semantic}->[ $word_id - 1 ];
    }

    return $semantic_representation;

}

# get word entry
sub get_entry {

    my $this = shift;
    my $word = shift;

    my $entry = {};

    my $word_id = $this->_vocabulary_id($word);
    if ( $word_id && $word_id < scalar(@{ $this->{_id2semantic} }) ) {
	$entry->{ 'word' } = $word;
	$entry->{ 'pos' } = $this->{_id2pos}->[ $word_id - 1 ];
	$entry->{ 'tf' } = $this->{_id2tf}->[ $word_id - 1 ];
    }

    return $entry;

}

sub map_to_ids {

    my $this = shift;
    my $sequence = shift;
    my $default = shift;

    return $this->_map_sequence( \&word_index , $sequence , $default );

}

sub map_to_words {

    my $this = shift;
    my $sequence = shift;
    my $default = shift;

    return $this->_map_sequence( \&get_word , $sequence , $default );

}

sub _map_sequence {

    my $this = shift;
    my $mapper = shift;
    my $sequence = shift;
    my $default = shift || '';

    # TODO : use logger instead
    if ( ! defined( $sequence ) || ! length( $sequence ) ) {
	print STDERR "[Vocabulary::_map_sequence] sequence is empty ...\n";
	$sequence = '';
    }

    # TODO : can we do better ?
    my @sequence_elements = ref( $sequence ) ? @{ $sequence } : ( split /\s+/ , $sequence );
    my @sequence_mapped = map { 
	my $mapped_element = $mapper->( $this , $_ );
	defined( $mapped_element ) ? $mapped_element : $default;
    } @sequence_elements;

    if ( ! ref( $sequence ) ) {
	return join( " " , @sequence_mapped );
    }

    return \@sequence_mapped;

}

1;
