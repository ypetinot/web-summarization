package DataManager;

# base class for all data managers

# constructor
sub new {
    my $package = ref($_) || $_;
    my $hash = ();
    bless $hash, $package;
}

# get data from associated file
sub get_data_from_file {

    my $this = shift;
    my $url_obj = shift;
   
#    print STDERR "looking for data file for $url_obj" . $this->data_type() . "\n";

    my $data_file = $url_obj->get_data_directory() . "/" . $this->data_type();

    # read from data file
    open DATA_FILE, $data_file or ( warn "unable to open data-file $data_file: $!" && return undef );
    local $/ = undef;
    my $data = <DATA_FILE>;
    close DATA_FILE;

    return $data;

}

1;
