# TODO : to be removed
package Service::NLP::StanfordThrift;

use Thrift;

use Moose;
use MooseX::ClassAttribute;
use namespace::autoclean;

# Note : for now this is a local service
with( 'Service::Local' );

# thrift client
has '_thrift_client' => ( is => 'ro' , isa => 'Thrift' , init_arg => undef , lazy => , builder => '_thrift_client_builder' );
sub _thrift_client_builder {
    my $this = shift;
    return new Thrift;
}

sub run {

    my $this = shift;
    my $sentence = shift;
    
    # TODO : what if the sentence is actually many sentences ?
    return $this->chunk( $sentence );

}

sub chunk {

    my $this = shift;
    my $string = shift;

    # make sure the parser process is available
    my $h = $this->_parser_process;

    print CHLD_IN "$string\n";

    my $parsed_string = <CHLD_OUT>;
    print STDERR "[parse] $parsed_string\n";

    return $parsed_string;

}


__PACKAGE__->meta->make_immutable;

1;
