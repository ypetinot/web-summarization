package Web::Document;

# CURRENT : what are the implications of enabling caching at this level ?
#           => what is caching is enabled in Web::Object ?
# => add one more level of abstraction => Web::Summarizer::Document ?
# => UrlData is really Web::Summarizer::UrlData => implicitly it is since it relies on MongoDB

use strict;
use warnings;

use Carp;
use Unicode::Normalize;
use MIME::Base64;
use URI;

sub raw_content_serializer {
    my $raw_content = shift;
    my $encoded_content = $raw_content;
    #print STDERR "is_utf8 => " . utf8::is_utf8( $encoded_content ) . "\n";
    utf8::encode( $encoded_content );
    $encoded_content = encode_base64( $encoded_content );
    return $encoded_content;
}

sub raw_content_deserializer {
    my $encoded_content = shift;
    my $decoded_content = decode_base64( $encoded_content );
    utf8::decode( $decoded_content );
    return $decoded_content;
}

# TODO : this should probably be a regular base class => not a case of horizontal code reuse
use Moose::Role;
#use namespace::autoclean;

with( 'Logger' );
with( 'WebAccess' );

sub data_generator {

    my $this = shift;

    my $url = $this->url;
#   print STDERR "downloading content for : $url\n";

    my $req = HTTP::Request->new(GET => $url);
    my $res = $this->_request_with_timeout( $req );

    # Check the outcome of the response
    # TODO : check for retrieval errors, etc.
    if ( ! defined( $res ) || ! $res->is_success) {
	return undef;
    }

    # TODO : [done]-type of display possible ?
#   print STDERR "done downloading content for : $url\n";

    my $content = $res->decoded_content;

    return $content;

}

sub raw_data {
    my $this = shift;

    # CURRENT : this is problematic since some application access get_data directly and therefore are not prevented from using invalid pages
    #           => is it possible to disable access to get_data ? => switch name to _get_data ?
    my $raw_data = $this->get_data;

    # Note : we throw an exception if no data can be obtained for this Url/Document
    if ( ! defined( $raw_data ) ) {
	my $url = $this->url;
	# TODO : should we add a message here ?
	croak;
    }

    return $raw_data;
}

# TODO : does the notion of "rendering" belong here ? Might ultimately want to create a Web::Document::TextDocument sub-class ?
has '_rendered' => (
    # CURRENT / TODO :
    #  traits => qw/CachedCollection/ ,
    is => 'ro' ,
    isa => 'ArrayRef[Str]' ,
    lazy => 1 ,
    builder => '_render' ,
    reader => 'render'
    );
requires('_render');

# TODO : should this be promoted to the parent class so that all Web::Object's can be cached/serialized ?
with(
    'Web::Object',
    'CachedCollection' => { namespace => 'web' ,
			    name => 'url_data_raw' , 
			    serializer => \&raw_content_serializer ,
			    deserializer => \&raw_content_deserializer }
    );

#__PACKAGE__->meta->make_immutable;

1;
