package WebAccess;

use strict;
use warnings;

use WWW::Mechanize;

use Moose::Role;

with( 'MongoDBAccess' );

# TODO : could part of all of this functionality be moved to a Role that further abstracts MongoDBAccess ?
has '_mongodb_collection_url_status' => ( is => 'ro' , isa => 'MongoDB::Collection' , init_arg => undef , lazy => 1 , builder => '_mongodb_collection_url_status_builder' );
sub _mongodb_collection_url_status_builder {
    my $this = shift;
    return $this->get_collection( 'web' , 'url_status' );
}

# Note : should we turn this into a singleton ?

# TODO : timeout setting should be read from a configuration file
has 'lwp_timeout' => ( is => 'ro' , isa => 'Num' , required => 0 , default => 60 );

has '_lwp_user_agent' => ( is => 'ro' , isa => 'LWP::UserAgent' , init_arg => undef , lazy => 1 , builder => '_lwp_user_agent_builder' );
sub _lwp_user_agent_builder {

    my $this = shift;

    # Note : note that WWW::Mechanize is a sub-class of LWP::UserAgent, however we (should) restrict ourselves to the interface offered by a LWP::UserAgent
    my $ua = new WWW::Mechanize( timeout => $this->lwp_timeout );

    #    $ua->agent("Web-summarizer - Columbia University");
    # Note : to avoid being blacklist not based on traffic but simply based on the fact that our user agent string doesn't look legit
    $ua->agent( "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36" );

    return $ua;

}

# CURRENT : enable caching ...
sub _request_with_timeout {

    my $this = shift;
    my $request_object = shift;

    my $request_timeout = $this->lwp_timeout;
    my $request_type = $request_object->method;
    my $request_url = $request_object->uri->as_string;

    # check whether we have checked this URL recently
    my $request_url_local_status = $this->get_database_collection_single_field( 'web' , 'url_status' , $request_url );

    # TODO : we should be able to do more with the status information
    if ( defined( $request_url_local_status ) && ! $request_url_local_status ) {
	return undef;
    }

    # Note : http://docstore.mik.ua/orelly/perl4/cook/ch16_22.htm
    # CURRENT : nested eval + final alarm reset to avoid race conditions don't quite make sense to me
    #           => main alarm statement below is not contained without this
    my $request_response = undef;
    eval {

	# http://www.mail-archive.com/libwww@perl.org/msg00405.html
	local $SIG{ALRM} = sub { print STDERR "$request_type request did not succeed within allocated time: $request_url\n"; die; };
	alarm $request_timeout;
	eval {
	    print STDERR "[" . __PACKAGE__ . "] $request_type (timeout: $request_timeout) => $request_url\n";
	    $request_response = $this->_lwp_user_agent->request( $request_object );
	};
	alarm 0;

	if ( $@ ) {
	    print STDERR "An error occurred during $request_type/$request_url ...\n";
	    # TODO : URL should be disabled permanently at this point
	    $this->set_database_collection_single_field( 'web' , 'url_status' , $request_url , 0 );
	}

    };
    alarm 0;

    return $request_response;

}

1;
