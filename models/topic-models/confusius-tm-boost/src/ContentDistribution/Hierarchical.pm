package ContentDistribution::Hierarchical;

use strict;
use warnings;

use base 'ContentDistribution';

# load hierarchical model given its root location on disk
sub load {

    my $that = shift;
    my $root_path = shift;
    my $model_name = shift;
    my $modality_name = shift;
    my $path = shift || [];

    my $class = ref($that) || $that;

    if ( ! -d $root_path ) {
	return undef;
    }

    # load the first level only ?
    my $hash = ContentDistribution::loadFromFile(join("/", ($root_path, "$modality_name.$model_name")));
    $hash->{_root} = $root_path;
    $hash->{_model} = $model_name;
    $hash->{_modality} = $modality_name;
    $hash->{_path} = $path;

    bless $hash, $class;

    return $hash;

}

# recursively load children given root location
sub _load_children {
    
    my $this = shift;
    my $name = shift;
    
    # list all directories under root
    opendir(DIR, $this->{_root}) or die "Unable to open node dir:$!\n";
    my @names = grep { -d $_ } map { join("/", ($this->{_root}, $_)); } grep { $_ !~ /^\./ } readdir(DIR);
    closedir(DIR);
    
    # filter for the specified name if needed
    if ( $name ) {
	@names = grep { $_ eq join("/", ($this->{_root}, $name)) } @names;
    }

    # map each matching directory to a hierarchical model object
    my @new_path = (@{$this->{_path}}, $this); 
    return map { $this->load($_, $this->{_model}, $this->{_modality}, \@new_path); } @names;

}

# get the name of this topic
sub name {

    my $this = shift;

    return $this->{_root};

}

# get path from root to current node
sub path {

    my $this = shift;

    return (@{$this->{_path}}, $this);

}

# classify content model, starting from the root
sub recursive_classify {

    my $this = shift;
    my $input_model = shift;

    # check model compatibility
    # if ( ref($input_model) != 

    # compute similarity with current model
    my $current_similarity = $this->KLDivergence($input_model);
    print STDERR $this->name . ":$current_similarity\n";

    # compute similarity with each child of the current model
    my @children_models = $this->_load_children;
    my $best_children_match = undef;
    foreach my $child_model (@children_models) {
	
	my $child_similarity = $child_model->KLDivergence($input_model);
	my $current_winner = 0;
	if ( ($child_similarity > $current_similarity) || (abs($child_similarity - $current_similarity) < 0.1) ) {
	    $current_similarity = $child_similarity;
	    $best_children_match = $child_model;
	    $current_winner = 1;
	}

	print STDERR "\t" . $child_model->name . ":$child_similarity [" . ($current_winner?'x':'-') . "]\n";

    }

    if ( $best_children_match ) {
	print STDERR $best_children_match->name . " selected \n\n";
	return $best_children_match->recursive_classify($input_model);
    }

    return $this;

}

# return specified model
sub getCategoryModel {

    my $this = shift;
    my $category = shift;

    if ( ! $category ) {
	return undef;
    }

    my @sub_categories = split /\//, $category;

    my $category_model = undef;

    my $current_category = $this;
    foreach my $sub_category (@sub_categories) {

	my @matching_categories = $current_category->_load_children($sub_category);

	# either there is no children model or the name isn't unique (impossible ?)
	if ( scalar(@matching_categories) != 1 ) {
	    return undef;
	}

	$current_category = $matching_categories[0];
	$category_model = $current_category;

    }

    return $category_model;

}

=pod
sub new {

    my $that = shift;
    my $tfs = shift;
    my $n_documents = shift;
    my $n_words = shift;
    my $smoothing_mode = shift;

    my $class = ref($that) || $that;

    my $hash = {};

    $hash->{_tfs} = $tfs;
    $hash->{_n_docs} = $n_documents;
    $hash->{_n_words} = $n_words;
    $hash->{_smoothing_mode} = $smoothing_mode;

    bless $hash, $class;

    return $hash;

}
=cut

=pod
# get number of documents on which this distribution has been computed
sub number_of_documents {

    my $this = shift;
    
    return $this->{_n_docs};

}
=cut

=pod
# get number of words based on which this distribution has been computed
sub number_of_words {

    my $this = shift;

    return $this->{_n_words};

}
=cut

=pod
sub distribution {

    my $this = shift;
    my $n = shift;

    my %distribution = %{$this->{_tfs}};

    map { $distribution{$_} = $distribution{$_} / $this->{_n_words} } keys(%distribution);

    if ( defined($n) && ($n < scalar(keys(%distribution))) ) {
	my @sorted_keys = sort { $distribution{$b} <=> $distribution{$a} } keys(%distribution);
	splice @sorted_keys, $n;
	my %temp_distribution;
	map { $temp_distribution{$_} = $distribution{$_}; } @sorted_keys;
	%distribution = %temp_distribution;
    }

    return \%distribution;

}
=cut

=pod
sub dump {

    my $this = shift;
    my $n = shift;

    my $dist = $this->distribution($n);

    return join(" ", map { $_ . ":" . $dist->{$_} } sort { $dist->{$b} <=> $dist->{$a} } keys(%$dist) );

}
=cut

1;
