package Service::NLP::DependencyList;

use strict;
use warnings;

use JSON;

use Moose;
use namespace::autoclean;

has 'dependency_data' => ( is => 'ro' , isa => 'HashRef' , required => 1 );

=pod
sub TO_JSON {

    my $this = shift;

    die "Not supported (yet)";

}

sub FROM_JSON {
    return {};
}
=cut

sub from_json_compatible {

    my $this = shift;
    my $raw_structure = shift;

    my @dependencies;

    map {
	
	my @copy = @{ $_ };
	my @_dependencies = map { new Service::NLP::Dependency( dependency_string => $_ ) } @{ $copy[ 3 ] };
	$copy[ 3 ] = \@_dependencies;
	
	push @dependencies , \@copy;

    } @{ $raw_structure };

    return \@dependencies;

}

__PACKAGE__->meta->make_immutable;

1;
