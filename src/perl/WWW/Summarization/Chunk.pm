package WWW::Summarization::Chunk;

use strict;
use warnings;

use WWW::String;

# abstracts the notion of an Entity (Person, Country, Product, etc.)

use Digest::MD5 qw(md5 md5_hex md5_base64);

# constructor
sub new {

    my $that = shift;
    my $chunk = shift;
    my $name_prefix = shift;
    
    my $package = ref($that) || $that;

    my $hash = {
	'-id' => generateName($chunk, $name_prefix),
	'representation' => [],
	'group' =>[],
    };
    
    bless $hash, $package;

    $hash->addRepresentation($chunk);

    print STDERR "[$0] created chunk for: $chunk\n";

    return $hash;

}

# new from hash
sub newFromHash {

    my $that = shift;
    my $hash = shift;

    my $package = ref($that) || $that;

    bless $hash, $package;

    return $hash;

}

# generate name
sub generateName {

    my $string = shift;
    my $name_prefix = shift || 'CHUNK';

    return $name_prefix . "_" . md5_hex($string);

}

# add a representation for this entity
sub addRepresentation {

    my $this = shift;
    my $new_representation = shift;

    if ( grep { $new_representation eq $_; } ($this->getRepresentations()) ) {
	return 0;
    }

    push @{$this->{representation}}, $new_representation;

    return 1;

}

# get all the representations for this entity
sub getRepresentations {

    my $this = shift;

    return @{$this->{representation}};

}

# get all verbalizations // TODO
sub getVerbalizations {

    my $this = shift;
    
    my @result;
    push @result, $this->getRepresentations();
    push @result, $this->getGroups();

    return @result;

}


# get all groups listed for this entity
sub getGroups {

    my $this = shift;

    return @{$this->{group}};

}

# generate a regular expression that can identify occurrences of this chunk in an arbitrary string
sub getRegexRepresentation {

    my $this = shift;

    my @ordered_representations = sort { length($b) <=> length($a) } $this->getRepresentations();

    # basic
    my $representation_regex_basic = join('|', map { "\Q$_\E"; } @ordered_representations);

    # flexible
    my $representation_regex_flexible = join('|', map { "\Q$_\E"; } map { s/[[:punct:]]/ /g; WWW::String::normalize($_); } @ordered_representations);

    # space-free
    my $representation_regex_nospace = join('|', map { "\Q$_\E"; } map { s/\s+//g; WWW::String::normalize($_); } @ordered_representations);
                   
    # character sequence
    my $representation_regex_sequence = join('|', map { my @representation_characters = split /[[:punct:]]| |/, $_; join('[[:punct:]]*\s*', @representation_characters) } @ordered_representations);
    
    my $representation_regex = qr/(?:\W|^)(?:$representation_regex_basic|$representation_regex_flexible|$representation_regex_nospace|$representation_regex_sequence)(?:\W|$)/si;

    # print "regex: $representation_regex\n";

    return $representation_regex;

}

# check whether a string is an exact match for this entity
sub matches {

    my $this = shift;
    my $object = shift;

    my $regex = $this->getRegexRepresentation();

    my @strings;

    if ( ref($object) ) {
	@strings = $object->getRepresentations();
    }
    else {
	push @strings, $object;
    }

    foreach my $string (@strings) {
	if ( $string =~ m/$regex/ ) {
	    return 1;
	}
    }

    return 0;

}

# get this entities name
sub getName {

    my $this = shift;
    
    return $this->{'-id'};

}

# get this entities main representation
sub getMainRepresentation {

    my $this = shift;

    if ( scalar($this->getRepresentations()) ) {
	return ($this->getRepresentations())[0];
    }
    
    return undef;

}

# computes distance between this entity and another string or entity
sub distance {

    my $this = shift;
    my $object = shift;

    my $distance = 1;

    if ( ! defined($object) ) {
	return $distance;
    }

    if ( ref($object) ) {
	
	foreach my $object_representation ($object->getRepresentations()) {
	    
	    my $current_distance = $this->distance($object_representation);
	    if ( $current_distance < $distance ) {
		$distance = $current_distance;
	    }

	}

    }
    else {
	
	# compute distance to each representation of this entity
	foreach my $entity_representation ($this->getRepresentations()) {
	    
	    my $current_distance = WWW::String::distance_wordoverlap($object, $entity_representation);
	    if ( $current_distance < $distance ) {
                $distance = $current_distance;
            }

	}

    }

    return $distance;

}

# merge two entities
sub mergeWith {

    my $this = shift;
    my $entity = shift;

    foreach my $entity_representation ($entity->getRepresentations()) {
	$this->addRepresentation($entity_representation);
    }

    foreach my $group ($entity->getGroups()) {
	$this->addGroup($group);
    }

}

# dump entity data
sub dump {

    my $this = shift;

    my $result = '';
    
    $result .= "chunk >> " . $this->getName() . "\n";
    foreach my $representation ($this->getRepresentations()) {
	$result .= "\t$representation\n";
    }
    
    return $result;
    
}

# split this chunk on an existing set of chunks
# use entities as chunk delimiters
sub splitOn {

    my $this = shift;
    my $reference_chunks = shift;

    # print STDERR "[$0] call to splitOn ...\n";
    # print STDERR $this->dump() . "\n";

    my @result_chunks;
    
    my $regex = undef;

    if ( ref($reference_chunks) eq 'ARRAY' ) {
	
	$regex = join ( "|", map { $_->getRegexRepresentation(); } @$reference_chunks );
	
    }
    else {
	
        $regex = $reference_chunks->getRegexRepresentation();

    }

    # print STDERR "regex >> $regex\n";

    # Now split each representation individually
    foreach my $representation ($this->getRepresentations()) {

	my @representation_splits = grep { defined($_) && length($_); } map { WWW::String::normalize($_); } split $regex, $representation;

	if ( !scalar(@representation_splits) ) {
	    # ignore known entities ?
	    next;
	}
	
	if ( $representation_splits[0] eq $representation ) {
	    push @result_chunks, $this;
	    next;
	}

	foreach my $representation_split (@representation_splits) {
	    
	    my $matching_chunk = undef;
	    foreach my $result_chunk (@result_chunks) {
		
		if ( $result_chunk->matches($representation_split) ) {
		    $matching_chunk = $result_chunk;
		    last;
		}
		
	    }

	    if ( defined($matching_chunk) ) {
		# not sure that's even necessary, but doesn't hurt
		$matching_chunk->addRepresentation($representation_split);
	    }
	    else {
		push @result_chunks, WWW::Summarization::Chunk->new( $representation_split );
	    }


	}

    }

    # only keep unique chunks
    my %seen;
    @result_chunks = grep { ! $seen{$_}++; } @result_chunks;

    # print STDERR "[$0] done with splitOn.\n";
    # if ( scalar(@result_chunks) ) {
    #	print STDERR "[$0] returning the following chunks:\n";
    #	foreach my $result_chunk (@result_chunks) {
    #	    print STDERR $result_chunk->dump();
    #	    print STDERR "\n";
    #	}
    # }

    return @result_chunks;

}

# computes average length of all the representations for this chunk
sub averageLength {

    my $this = shift;

    my $sum = 0;
    my $n = 0;

    # for now
    foreach my $representation ($this->getRepresentations()) {

	# TODO: do not take into account space, punctuation, etc ?
	$sum += length($representation);

	$n++;

    }

    my $average_length = $n?($sum/$n):0;

    return $average_length;

}

# check whether this Chunk contains another one
sub includes {

    my $this = shift;
    my $chunk = shift;

    # print STDERR "[$0] checking if " . $this->getMainRepresentation() . " includes " . $chunk->getMainRepresentation() . "\n";

    my $chunk_regex = $chunk->getRegexRepresentation();
    foreach my $representation ($this->getRepresentations()) {

	# print STDERR "[$0] \t\t checking if [$representation] matches [$chunk_regex]\n";

	if ( $representation =~ m/$chunk_regex/ ) {
	    # print STDERR "[$0] \t\t match !\n";
	    return 1;
	}

	# print STDERR "[$0] \t\t no match\n"

    }

    return 0;

}

# mark sub-string as group
sub addGroup {

    my $this = shift;
    my $chunk = shift;

    if ( ! $this->includes($chunk) ) {
	return 0;
    }

    push @{$this->{group}}, $chunk;

}

1;
