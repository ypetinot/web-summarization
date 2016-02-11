package WWW::DMOZ;

=head1
This module provides an API to access to the DMOZ dataset.
=cut

=pod
Create new DMOZ object, given a database file
=cut
sub new {

    my $that = shift;
    my $dataset_location = shift;

    my $class = ref($that) || $that;

    my $hash = {};

    bless $hash, $class;

    $hash->_init();

    return $hash;

}

=pod
Initialization ...
=cut
sub _init {


}

1;
