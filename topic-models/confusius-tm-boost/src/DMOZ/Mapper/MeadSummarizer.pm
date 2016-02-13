package DMOZ::Mapper::MeadSummarizer;

# wrapper for MEAD Summarizer

use File::Path;
use XML::Generator;

use DMOZ::Mapper::EntryMapper;
use base qw(DMOZ::Mapper::EntryMapper);

use FindBin;

use Document;
use SentenceExtractor;

# processing method
sub process {

    my $this = shift;
    my $node = shift;
    my $path = shift;
    my $data = shift;

    my $url = $node->{url};

    my $summary = '';

    my $model_summary = $node->{description};

    print STDERR "processing $url\n";

    # get content
    #my $content = $node->get('content') || '';
    my $content = '<html>This is a sample document to test my system. In this document i discuss nothing interesting.</html>';
   
    # generate summary using MEAD
    if ( $content ) {

	# 1 - generate Document object
	my $document = new Document($url, $content);

	# 2 - get all sentences in this document
	my $sentence_extractor = new SentenceExtractor();
	my $sentences = $sentence_extractor->extract($document);

	# 3 - generate mead summary
	my $mead_summary = _run_mead($sentences);

	if ( $mead_summary ) {
	    $summary = $mead_summary;
	}

    }

    # output summary info
    print join("\t", (__PACKAGE__, $url, $summary, $model_summary, undef)) . "\n";

}

# generate mead summary given a cluster of sentences
sub _generate_mead_docsent {
    
    my $docid = shift;
    my $sentences = shift;

    if ( !scalar(@$sentences) ) {
	return;
    }

    # build docsent file
    my $docsent_file = '';
    
    $docsent_file .= "<?xml version='1.0' encoding='UTF-8'?>\n";
    $docsent_file .= "<DOCSENT DID='$docid' DOCNO='$docid' LANG='ENG' CORR-DOC='$docid.c'>\n";
    $docsent_file .= "<BODY>\n";
    $docsent_file .= "<TEXT>\n";
	
    my $count=0;
    my $xml_generator = XML::Generator->new(escape => 'always,high-bit');
    foreach my $sentence (@$sentences) {
	$count++;
	$docsent_file .= $xml_generator->S( { PAR => $count, RSNT => $count, SNO => $count }, 
					    $sentence ) . "\n";
    }
	
    $docsent_file .= "</TEXT>\n";
    $docsent_file .= "</BODY>\n";
    $docsent_file .= "</DOCSENT>\n";
	
    return $docsent_file;

}
	

# run mead
# TODO: this needs to be refactored and pushed back to the mead-summarizer directory
sub _run_mead {

    my $sentences = shift;

    # generate input files
    my $dir = File::Temp->newdir(CLEANUP => 0);
    my $cluster_dir = "$dir/temp/";
    my $docsent_dir = "$cluster_dir/docsent/";
    mkpath($docsent_dir);

    # create docsent file
    my $docsent_file = $docsent_dir . "/1.docsent";
    my $docsent = _generate_mead_docsent(1, $sentences);
    open DOCSENT, ">$docsent_file" or die "unable to open file $docsent_file: $!";
    binmode(DOCSENT, ':utf8');
    print DOCSENT $docsent;
    close DOCSENT;

    # create cluster file
    open CLUSTER_FILE, ">$cluster_dir/temp.cluster" or die "unable to create cluster file: $!";
    print CLUSTER_FILE "<?xml version='1.0'?>\n";
    print CLUSTER_FILE "<CLUSTER LANG='ENG'>\n";
    print CLUSTER_FILE "<D DID='1' />\n";
    print CLUSTER_FILE "</CLUSTER>\n";
    close CLUSTER_FILE;

    my $max_sentences = 1;
    my $max_words = 0;
    my $mead_options = "-s -absolute $max_sentences";
    if ( $max_words > 0 ) {
	$mead_options = "-w -a $max_words";
    }

    my $mead_output = `cd $dir && $FindBin::Bin/../../mead-summarizer/third-party/mead/bin/mead.pl -v $mead_options temp 2>/dev/null`;

    # delete input files
    rmtree $dir;
    
    # clean-up
    #$mead_output =~ s/^(!:\[\d+\]).*$//g; # remove info lines
    $mead_output =~ s/^\[\d+\]\s+//g; # strip sentence numbers
    $mead_output =~ s/\n/ /g; # remove newlines
    $mead_output =~ s/\s+/ /g; # remove extraneous spaces

    if ( $mead_output ) {
	return $mead_output;
    }
    else {
	return undef;
    }

}

#my $node = { url => 'http://www.yves.com' };
#process(undef, $node);


1;

