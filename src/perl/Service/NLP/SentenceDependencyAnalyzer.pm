package Service::NLP::SentenceDependencyAnalyzer;

use strict;
use warnings;

use Function::Parameters qw/:strict/;

use Moose;
use namespace::autoclean;

extends( 'Service::NLP::SentenceAnalyzer' );
# TODO : can we avoid respecifying the default host here ?
with( 'Service::ThriftBased' => { host => $ENV{ SERVICE_HOST_DEPENDENCY_PARSING } || $ENV{ SERVICE_HOST } , port => 8889 , client_class => 'CoreNLP::StanfordCoreNLPClient' } );

sub _use_shift_reduce_parser_builder {
    return 0;
}

# CURRENT : cache response ?
method get_dependencies ( $string , :$parse_dependencies = 0 ) {

    # TODO : rename chunk ?
    my $dependencies = $self->chunk( $string , [ "-outputFormat" , "typedDependencies" ] , 'dependencies' );
    #outputOptions = ["-outputFormat", "typedDependencies,penn", "-outputFormatOptions", "basicDependencies"]
	
    if ( $parse_dependencies ) {

	my @parsed_dependencies;

	foreach my $dependency_set (@{ $dependencies }) {

	    my $raw_data = $dependency_set->tree;
	    my @dependencies_raw = split /\n/ , $dependency_set->tree;

	    push @parsed_dependencies , map {
		my $dependency_object = new Service::NLP::Dependency( dependency_string => $_ );		
	    } @dependencies_raw;

	}
	    
	return \@parsed_dependencies;
	    
    }

    return $dependencies;

}

method get_dependencies_from_tokens ( $tokens , :$parse_dependencies = 0 ) {

    # TODO : rename chunk ?
    # Note : the regular parse_tokens seems more accurate than the shift-reduce version
    my $dependencies = $self->parse_tokens( $tokens , [ "-outputFormat" , "typedDependencies" ] , 'dependencies-from-tokens' );
    #my $dependencies = $self->sr_parse_tokens( $tokens , [ "-outputFormat" , "typedDependencies" ] , 'dependencies-from-tokens' );
	
    if ( $parse_dependencies ) {

	my @parsed_dependencies;

	foreach my $dependency_set (@{ $dependencies }) {

	    my $raw_data = $dependency_set->tree;
	    my @dependencies_raw = split /\n/ , $dependency_set->tree;

	    push @parsed_dependencies , map {
		my $dependency_object = new Service::NLP::Dependency( dependency_string => $_ );		
	    } @dependencies_raw;

	}
	    
	return \@parsed_dependencies;
	    
    }

    return $dependencies;

}

__PACKAGE__->meta->make_immutable;

1;
