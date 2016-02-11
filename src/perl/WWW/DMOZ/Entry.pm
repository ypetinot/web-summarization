package WWW::DMOZ::Entry;

=head
Objects of this class represent a specific entry in the DMOZ directory
=cut

=pod
Create new entry
=cut
sub new {

    my $that = shift;
    my @fields = @_;

    my $class = ref($that)||$that;

    my $hash = {};

    while(my $key = shift(@fields)) {
	$hash->{$key} = shift@fields;
    }

    bless $hash, $class;
    
    return $hash;

}

1;
