package NPModel::ConditionalRandomField;

use strict;
use warnings;

use Moose;

extends 'NPModel::Base';

# fields

# feature set
has 'features' => (is => 'rw', isa => 'HashRef', default => sub { {} }, lazy => 1, required => 0); 

# nodes
has 'nodes' => (is => 'ro', isa => 'ArrayRef[Num]', required => 1);

# edges
has 'edges' => (is => 'ro', isa => 'ArrayRef', required => 1);

use Digest::MD5 qw(md5 md5_hex md5_base64);
use Encode qw(encode_utf8);
use File::Path qw/make_path remove_tree/;

sub train {

    my $this = shift;

    # train underlying classifier
    $this->_train();

}

sub apply {

    my $this = shift;
    my $test_tokens = shift;

    my @matches;

    # assumes the instances (tokens) are the same as for the training phase
    my $result_tags = $this->_evaluate_mallet($test_tokens);

    # TODO

    return \@matches;

}

# create CRF model template
sub _create_crf_model_template {

    my $this = shift;
    
    my $template_file = $this->get_model_file("template");

    open TEMPLATE_FILE, ">$template_file" or die "Unable to create testing file $template_file: $!";

    # Create individual nodes
    foreach my $node (@{ $this->nodes() }) {
	print TEMPLATE_FILE "new ACRF.BigramTemplate ($node)\n";
    }

    # Create edges
    foreach my $edge (@{ $this->edges() }) {
	my ( $node_from_id , $node_to_id ) = @{ $edge };
	if ( !defined( $node_from_id ) || !defined( $node_to_id ) ) {
	    die "We have a problem ... undefined node id ...";
	}
	print TEMPLATE_FILE "new ACRF.PairwiseFactorTemplate ($node_from_id,$node_to_id)\n";
    }

    close TEMPLATE_FILE;

}

sub _train {

    my $this = shift;

    # ********************************************************************************
    # For now this is customized to use Mallet
    # ********************************************************************************

    # generate CRF model template
    $this->_create_crf_model_template();

    # generate training file
    $this->_write_training_file();

    # train WEKA classifier
    $this->_train_mallet();

}

sub _evaluate_mallet() {

    my $this = shift;
    my $test_tokens = shift;
    
    my $template_file = $this->get_model_file("template");
    my $testing_file = $this->get_model_file("testing");
    my $out_file = $this->get_model_file("testing.out");
    my $current_instance_features = $this->_generate_features($test_tokens);

    my @taggable_tokens;
    my %token_mapping;

    my $labels = [];
    my $features = $this->get_features( $test_tokens );

    # TODO

    open TESTING_FILE, ">$testing_file" or die "Unable to create testing file $testing_file: $!";
    print TRAINING_FILE join(" ---- ", join(" ", @{ $labels }), join(" ", map{ _encode_string($_) } @{ $features })) . "\n";
    close TESTING_FILE;

    my $model_file = $this->get_model_file("model");

    my @tagged_tokens;

    # call to underlying script
    my @result = grep { length($_) } map { chomp; $_; } `$this->{'bin_root'}/general-purpose-crf-mallet tag $template_file $testing_file $model_file $out_file 2>/dev/null`;
    if ( scalar(@taggable_tokens) != scalar(@result) ) {
	print STDERR "[NPModel::Extractor] mismatch between tokens and tags sequence ...";
    }
    else {
	for (my $i=0; $i<scalar(@taggable_tokens); $i++) {
	    push @tagged_tokens, [ $taggable_tokens[$i] , $result[$i] ];
	}
    }

    return \@tagged_tokens;

}

sub _write_training_file {

    my $this = shift;

    my $training_file = $this->get_model_file("crf");
    my $training_file_clear = $this->get_model_file("crf.clear");

    open TRAINING_FILE, ">$training_file" or die "[__PACKAGE__] Unable to open training file: $training_file";
    open TRAINING_FILE_CLEAR, ">$training_file_clear" or die "[__PACKAGE__] Unable to open training file clear: $training_file_clear";
    binmode(TRAINING_FILE_CLEAR, ':utf8');

    # loop over training instances
    for (my $i=0; $i<scalar(@{ $this->{contents} }); $i++) {

	my $labels = $this->{ground_truths}->[$i];
	my $features = $this->get_features( $this->{contents}->[$i] , 1 );

	print TRAINING_FILE join(" ---- ", join(" ", @{ $labels }), join(" ", map{ _encode_string($_) } @{ $features })) . "\n";
	print TRAINING_FILE_CLEAR join(" ---- ", join(" ", @{ $labels }), join(" ", map { "[$_]"; } @{ $features })) . "\n";

    }
 
    close TRAINING_FILE_CLEAR;
    close TRAINING_FILE;

}

# get features for an instance and update feature set if requested
sub get_features {

    my $this = shift;
    my $current_instance = shift;
    my $update_features = shift || 0;

    my $current_instance_features = $this->_generate_features($current_instance);

    my %features_counts;
    for (my $j=0; $j<scalar(@{$current_instance}); $j++) {
	
	my $token = $current_instance->[$j];
	my $token_features = $current_instance_features->[$j];
	if ( ! defined( $token_features ) ) {
	    next;
	}
	
	if ( $update_features ) {
	    $this->features()->{ $token }++;
	}
	else { # if the current feature is not known we just skip it
	    if ( ! defined( $this->features()->{ $token } ) ) {
		next;
	    }
	}

	# for now we only use 1-gram features
	$features_counts{ $token }++;

    }
    my @features = grep{ $features_counts{$_} > 2; } keys( %features_counts );
    
    return \@features;

}

# encode string
sub _encode_string {

    my $this = shift;
    my $string = shift;

    return md5_hex( encode_utf8( $string ) );

}

sub _train_mallet {

    my $this = shift;

    print STDERR "will now start training mallet extractor ...\n";
    
    my $template_file = $this->get_model_file("template");
    my $training_file = $this->get_model_file("crf");
    my $model_file = $this->get_model_file("model");

    # call to underlying script
    my $result = `$this->{'bin_root'}/general-purpose-crf-mallet train $template_file $training_file $model_file 2>&1`;

    print STDERR "$result\n";

}

# generate features for an instance
sub _generate_features {

    my $this = shift;
    my $content = shift;

    my @features;

    # TODO: balance HTML tags

    # include variations on all features as to whether it appears in title/body/link ?

    # Is this token present in the anchortext ?
    # TODO
    # 'is_in_anchortext'

    # position
    # style
    # leading n-grams
    # following n-grams (TODO)

    my @tag_stack;
    my @style_stack;
    my @prefix_stack;

    for (my $i=0; $i<scalar(@$content); $i++) {

	my $token = $content->[$i];
	my @token_features;

	if ( $token =~ m/^\</ ) {

	    # update tag stacks
	    if ( $token =~ m/^\<([a-zA-Z]+)\>/ ) {
		my $opening = $1;
		unshift @tag_stack, $opening;
		if ( _is_style_tag($opening) ) {
		    unshift @style_stack, $opening;
		}
	    }
	    elsif ( $token =~ m/^\<\/([a-zA-Z]+)\>/ ) {
		
		my $closing = $1;
		while ( scalar(@tag_stack) ) {
		    my $current_tag = shift @tag_stack;
		    if ( _is_style_tag($closing) ) {
			shift @style_stack;
		    }
		    if ( $current_tag eq $closing ) {
			last;
		    }
		}


	    }

	    # no features for tag tokens

	}
	else {

	    # feature #1: tag signature
	    my $tag_signature = join("-", "feature-tag-signature", md5_hex( encode_utf8( join( " " , @tag_stack ) ) ) );
	    push @token_features, $tag_signature;

	    # feature #2: style
	    my $style = join("-", "feature-style", @style_stack);
	    push @token_features, $style;

	    # feature #3: prefix
	    for (my $j=0; $j<scalar(@prefix_stack); $j++) {
		my @local_prefix = @prefix_stack;
		my $prefix = join("-", "feature-prefix-$j", md5_hex( encode_utf8( join( " " , splice(@local_prefix,$j+1) ) ) ) );
		push @token_features, $prefix;
	    }

	    # update prefix
	    unshift @prefix_stack, $token;
	    my $prefix_max_length = 3;
	    if ( scalar(@prefix_stack) > $prefix_max_length ) {
		splice @prefix_stack, $prefix_max_length;
	    }

	}

	push @features, scalar(@token_features)?\@token_features:undef;

    } 

    return \@features;
    
}

sub reset {

    my $this = shift;

    # nothing
    
}

sub _is_style_tag {

    my $tag = shift;

    if ( $tag =~ m/^h\d$/i ||
	 $tag eq "b" ||
	 $tag eq "i"
	) {
	return 1;
    }

    return 0;

}

no Moose;

1;
