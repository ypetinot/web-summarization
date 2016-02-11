package NPModel::BinaryClassifier;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

use NPModel::Base;
extends 'NPModel::Base';

use Text::Trim;

# TODO : maybe we should create a new class to handle multi-label classifier
has 'multi_label' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# TODO : move up ?
# sorted labels
has '_sorted_labels' => ( is => 'ro' , isa => 'ArrayRef' , lazy => 1 , init_arg => undef , builder => '_sorted_labels_builder' );
sub _sorted_labels_builder {
    my $this = shift;
    my @sorted_labels = sort { $this->_labels->{ $a } <=> $this->_labels->{ $b } } keys( %{ $this->_labels } );
    return \@sorted_labels;
}

# TODO : move up ?
# sorted features
has '_sorted_features' => ( is => 'ro' , isa => 'ArrayRef' , lazy => 1 , init_arg => undef , builder => '_sorted_features_builder' );
sub _sorted_features_builder {
    my $this = shift;
    my @sorted_features = sort { $this->_feature_names->{ $a } <=> $this->_feature_names->{ $b } } keys( %{ $this->_feature_names } );
    return \@sorted_features;
}

sub classify {

    my $this = shift;
    my $test_tokens = shift;

    my %appearance;

    # assumes the instances (tokens) are the same as for the training phase
    my $prediction = $this->_classify_weka($test_tokens);
    my $prediction_data = $prediction->[0];

    if ( $prediction_data =~ m/Confidences: \[([^\]]+)\]/s ) {

	my $data = $1;
	my @label_appearances = map { trim($_); } split(/,/, $data);
	
	# create label to node id mapping
	my %label2node;
	map { $label2node{ $this->_labels->{ $_ } } = $_; } keys( %{ $this->_labels } );
	
	# map label ids back to their originial node ids
	my $label_id = 0 + scalar( keys( %{ $this->_feature_names } ) );
	map { $appearance{ $label2node{ $label_id++ } } = $_; } @label_appearances;

    }

    return \%appearance;

}

sub _train {

    my $this = shift;
    my $training_set = shift;
    my $ground_truths = shift;

    # ********************************************************************************
    # For now this is customized to use Weka
    # ********************************************************************************

    # generate ARFF file
    my $arff_file = $this->get_model_file("training.arff");
    $this->_write_arff_file($arff_file,$training_set,$ground_truths);

    # train WEKA classifier
    $this->_train_weka($arff_file);

}

sub _classify_weka {

    my $this = shift;    
    my $test_tokens = shift;

    my $bin_root = $this->bin_root();

    my $arff_file = $this->get_model_file("testing.arff");
    my $out_file = $this->get_model_file("testing.out");
    $this->_write_arff_file($arff_file, [ $test_tokens ]);
    my $model_file = $this->get_model_file("model");

    # call to underlying script
    my @result = map { chomp; $_; } `$bin_root/binary-classifier-weka classify $arff_file $model_file $out_file 2>/dev/null`;

    return \@result;

}

sub _write_arff_file {

    my $this = shift;
    my $arff_file = shift;
    my $instances_features = shift;
    my $ground_truths = shift;

    my $description = $this->description;

    my @sorted_features = @{ $this->_sorted_features };
    my @sorted_labels = @{ $this->_sorted_labels };
    my $label_count = scalar(@sorted_labels);
 
    open ARFF_FILE, ">$arff_file" or die "[__PACKAGE__] Unable to open ARFF file: $arff_file";
    
    # print header
    print ARFF_FILE "% $description\n";
    print ARFF_FILE "\n";
    print ARFF_FILE "\@RELATION 'template: -C -${label_count}'\n";
    print ARFF_FILE "\n";

    foreach my $feature (@sorted_features) {
	my $feature_type = 'NUMERIC';
	my $feature_index = $this->_feature_names()->{ $feature };
	print ARFF_FILE "\@ATTRIBUTE $feature $feature_type \% ==> $feature_index\n";
    }

    my $labels_offset = scalar( @sorted_features );
    for ( my $i = 0 ; $i <= $#sorted_labels ; $i++ ) {
	my $label = $sorted_labels[ $i ];
	my $label_index = $labels_offset + $i;
	print ARFF_FILE "\@ATTRIBUTE $label {0,1} \% ==> $label_index\n";
    }

    print ARFF_FILE "\n";
    print ARFF_FILE "\@DATA\n";

    # print individual instances
    my $instances_out = 0;
    for (my $i=0; $i<scalar(@{$instances_features}); $i++) {

	my $instance_features = $instances_features->[ $i ];
	my $instance_ground_truths = $ground_truths->[ $i ];

	my @instance;
	my %instance_mapping;

	foreach my $feature (keys( %{ $instance_features } )) {
            # push @instance, $instance_features->{$feature} || 0;
	    my $feature_value = $instance_features->{$feature}?1:0;
	    my $feature_index = $this->_feature_names->{ $feature };
	    if ( !$feature_value || !$feature_index ) {
		next;
	    }
	    $instance_mapping{ $feature_index } = "$feature_index $feature_value";
        }

	if ( defined($ground_truths) ) {
	    
	    for ( my $i = 0 ; $i <= $#sorted_labels ; $i++ ) {

		my $label = $sorted_labels[ $i ];
		my $label_index = $labels_offset + $i;

		# TODO : not very clean, definitely needs some fixing
		my $ground_truth = $this->multi_label ? 1 : $instance_ground_truths->[ 0 ];

		$instance_mapping{ $label_index} = "$label_index $ground_truth";

	    }
        }

	print ARFF_FILE "{" . join(",", map { $instance_mapping{ $_ } } sort { $a <=> $b } keys( %instance_mapping ) ) . "}\n";
	$instances_out++;

    }

    close ARFF_FILE;

    if ( $instances_out != scalar( @{ $instances_features } ) ) {
	die "Problem , only $instances_out instances were written out ...";
    }

    # write out label file
    my $label_file = $this->get_model_file("labels.xml");
    open LABEL_FILE, ">$label_file" or die "[__PACKAGE__] Unable to create label file ($label_file): $!";
    print LABEL_FILE '<labels xmlns="http://mulan.sourceforge.net/labels">' . "\n";
    foreach my $label (@sorted_labels) {
	print LABEL_FILE '<label name="' . $label . '"></label>' . "\n";
    }
    print LABEL_FILE "</labels>";
    close LABEL_FILE;

}

sub _train_weka {

    my $this = shift;
    my $arff_file = shift;

    print STDERR "will now start training weka classifier using ARFF file: $arff_file\n";
    
    my $bin_root = $this->bin_root();

    # TODO : turn this into a configurable parameter
    my $model_class = 'weka.classifiers.bayes.NaiveBayes';
#    my $model_class = 'weka.classifiers.functions.Logistic';
#    my $model_class = 'weka.classifiers.bayes.BayesNet';
#    my $model_class = 'weka.classifiers.trees.J48';
#    my $model_class = 'weka.classifiers.functions.SMO';
#    my $model_class = 'weka.classifiers.functions.SimpleLogistic';

    my $model_file = $this->get_model_file("model");
    my $out_file = $this->get_model_file("training.output");
    my $labels_file = $this->get_model_file("labels.xml");

    # call to underlying script
    my $result = `$bin_root/binary-classifier-weka ${model_class} train $arff_file $model_file $out_file $labels_file`;
#2>/dev/null`;

}

__PACKAGE__->meta->make_immutable;

1;
