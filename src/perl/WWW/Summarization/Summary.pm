# API to manipulate a Web Summary

package WWW::Summarization::Summary;

use strict;
use warnings;

use Carp;
use URI;
use XML::TreePP;

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

    my $tpp = XML::TreePP->new();
    $tpp->set( indent => 2 );
    
    return $tpp->write($this->{_data});

}

# write to specified directory
sub write {

    my $this = shift;
    my $destination_dir = shift;

    # 1 - serialize
    my $serialized_content = $this->serialize();

    # 2 - write to file
    my $destination_file = "$destination_dir/" . $this->summarizerId() . ".summary";
    if ( open (SUMMARY, "> $destination_file" ) ) {
	print SUMMARY "$serialized_content\n";
	close SUMMARY;
    }
    else {
	croak "unable to create file $destination_file";
    }
    
}

# load from file
sub load {

    my $file = shift;

    if ( ! -f $file ) {
	return undef;
    }

    # parse summary file
    my $tpp = XML::TreePP->new();
    my $tree = $tpp->parsefile( $file );
    if ( ! $tree ) {
        croak "invalid summary data: $file";
	return undef;
    }

    if ( !$tree->{summary} || !$tree->{summary}->{value} ) {
        if ( $tree->{summary} && $tree->{summary}->{status} ) {
            #print STDERR "skipping $source_file: " . $tree->{summary}->{status} . "\n";
            #return;
        }   
        else {
            croak "invalid summary data: $file";
	    return undef;
        }
    }

    return new($tree);

}

# get target
sub getTarget {

    my $this = shift;

    return new URI($this->{_data}->{summary}->{'-target'});

}

# get summarizer id
sub summarizerId {

    my $this = shift;
    my $summarizer_id = shift;

    if ( defined($summarizer_id) ) {
	$this->{_data}->{summary}->{'-summarizer-id'} = $summarizer_id;
    }
    
    return $this->{_data}->{summary}->{'-summarizer-id'};

}

# get context location
sub getContextLocation {

    my $this = shift;

    return $this->{_data}->{summary}->{'-context'};

}

# get summary text
sub text {

    my $this = shift;
    my $new_text = shift;

    if ( defined($new_text) ) {
	$this->{_data}->{summary}->{value} = $new_text;
    }

    return $this->{_data}->{summary}->{value} || '';

}

# get word length
sub getWordLength {

    my $this = shift;
    
    # tokenize content
    my @tokens = split /(?:\s|[[:punct:]])+/, $this->text();

    return scalar(@tokens);

}

1;
