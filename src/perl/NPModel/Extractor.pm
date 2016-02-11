package NPModel::Extractor;

use strict;
use warnings;

use NPModel::Base;
use base 'NPModel::Base';

use Digest::MD5 qw(md5 md5_hex md5_base64);
use Encode qw(encode_utf8);
use File::Path qw/make_path remove_tree/;

sub train {

    my $this = shift;

    # train underlying classifier
    $this->_train();

}

sub extract {

    my $this = shift;
    my $test_tokens = shift;

    my @matches;

    # assumes the instances (tokens) are the same as for the training phase
    my $result_tags = $this->_tag_mallet($test_tokens);

    for (my $i=0; $i<scalar(@$result_tags); $i++) {
	
	my ($token, $tag) = @{ $result_tags->[$i] };

	if ( $tag =~ m/target/ ) {
	    push @matches, $token;
	}
	
    }

    return \@matches;

}

sub _train {

    my $this = shift;

    # ********************************************************************************
    # For now this is customized to use Mallet
    # ********************************************************************************

    # generate training file
    $this->_write_training_file();

    # train WEKA classifier
    $this->_train_mallet();

}

sub _tag_mallet() {

    my $this = shift;
    my $test_tokens = shift;
    
    my $testing_file = $this->get_model_file("testing");
    my $out_file = $this->get_model_file("testing.out");
    my $current_instance_features = $this->_generate_features($test_tokens);

    my @taggable_tokens;
    my %token_mapping;

    open TESTING_FILE, ">$testing_file" or die "Unable to create testing file $testing_file: $!";

    binmode(TESTING_FILE, ':utf8');
    for (my $i=0; $i<scalar(@$test_tokens); $i++) {
	
	my $test_token = $test_tokens->[$i];
	my $token_features = $current_instance_features->[$i];

	if ( ! defined($token_features) ) {
	    next;
	}

	push @taggable_tokens, $test_token;

	if ( ! defined($token_mapping{$test_token}) ) {
	    $token_mapping{$test_token} = $this->_encode_string( $test_token );
	}

	my @token_data;
	push @token_data, $token_mapping{$test_token};
	push @token_data, @{ $token_features };
	print TESTING_FILE join(" ", @token_data) . "\n";

    }

    close TESTING_FILE;

    my $model_file = $this->get_model_file("model");

    my @tagged_tokens;

    # call to underlying script
    my @result = grep { length($_) } map { chomp; $_; } `$this->{'bin_root'}/extractor-mallet tag $testing_file $model_file $out_file 2>/dev/null`;
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

# produces linearized version of features
sub _linearized_features {

    my $this = shift;
    my $features = shift;

}

sub _write_training_file {

    my $this = shift;

    my $training_file = $this->get_model_file("seq");
    my $training_file_clear = $this->get_model_file("seq.clear");

    open TRAINING_FILE, ">$training_file" or die "[__PACKAGE__] Unable to open training file: $training_file";
    open TRAINING_FILE_CLEAR, ">$training_file_clear" or die "[__PACKAGE__] Unable to open training file clear: $training_file_clear";
    binmode(TRAINING_FILE_CLEAR, ':utf8');

    # loop over training instances
    for (my $i=0; $i<scalar(@{ $this->{contents} }); $i++) {

	my $current_instance = $this->{contents}->[$i];
	my $current_instance_features = $this->_generate_features($current_instance);

	if ( scalar(@$current_instance_features) != scalar(@$current_instance) ) {
	    die "Mismatch between content and feature entries ...";
	}

	my $target = $this->{target};
	if ( ref($target) ) { # we may specify multiple ids for the extraction target
	    $target = join("|", @{ $target });
	}

	for (my $j=0; $j<scalar(@{$current_instance}); $j++) {

	    my $token = $current_instance->[$j];
	    my $token_features = $current_instance_features->[$j];
	    if ( !defined $token_features ) {
		next;
	    }

	    my @token_data;
	    push @token_data, $this->_encode_string( $current_instance->[$j] );
	    push @token_data, @{ $token_features };
	    push @token_data, ( $token =~ m/$target/ ) ? "extraction-target" : "regular";

	    print TRAINING_FILE join(" ", @token_data) . "\n";

	    my @token_data_clear;
	    push @token_data_clear, $current_instance->[$j];
	    push @token_data_clear, @{ $token_features };
	    push @token_data_clear, ( $token =~ m/$target/ ) ? "extraction-target" : "regular";

	    print TRAINING_FILE_CLEAR join(" ", @token_data_clear) . "\n";

	}

	print TRAINING_FILE "\n";
	print TRAINING_FILE_CLEAR "\n";

    }
 
    close TRAINING_FILE_CLEAR;
    close TRAINING_FILE;

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
    
    my $training_file = $this->get_model_file("seq");
    my $out_file = $this->get_model_file("training.out");
    my $model_file = $this->get_model_file("model");

    # call to underlying script
    my $result = `$this->{'bin_root'}/extractor-mallet train $training_file $model_file $out_file 2>&1`;

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

1;
