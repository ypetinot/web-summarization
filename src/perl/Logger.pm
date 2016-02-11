package Logger;

# TODO : add namespace ?

use strict;
use warnings;

use Log::Log4perl qw(:easy);

# TODO : could this be a better option ? (right now I don't think so)
#with('MooseX::Log::Log4perl::Easy');

# TODO : how can these changes be pushed to MooseX::Log::Log4perl
# From : http://stackoverflow.com/questions/3018528/making-self-logging-modules-with-loglog4perl

#use Moose::Role;
use MooseX::Role::Parameterized;

parameter level => (
    isa => 'Str',
    default => $DEBUG,
    required => 0
    );

role {

    my $p = shift;
    my $_debug_level = $p->level;
    
    my @methods = qw(
                     log trace debug info warn error fatal
                     is_trace is_debug is_info is_warn is_error is_fatal
                     logexit logwarn error_warn logdie error_die
                     logcarp logcluck logcroak logconfess
    );
    
    has logger => (
	is => 'ro',
	isa => 'Log::Log4perl::Logger',
	lazy_build => 1,
	handles => \@methods,
	);
    
    around $_ => sub {
	my $orig = shift;
	my $this = shift;
	
	# one level for this method itself
	# two levels for Class:;MOP::Method::Wrapped (the "around" wrapper)
	# one level for Moose::Meta::Method::Delegation (the "handles" wrapper)
	local $Log::Log4perl::caller_depth;
	$Log::Log4perl::caller_depth += 4;
	
	my $return = $this->$orig(@_);
	
	$Log::Log4perl::caller_depth -= 4;
	return $return;
	
    } foreach @methods;

    method "_build_logger" => sub {
	my $this = shift;
	
	my $loggerName = ref($this);
	Log::Log4perl->easy_init(
	    level  => $_debug_level,
	    layout => '%F{1}-%L-%M: %m%n',
# TODO : how do we enable logging with wide characters ?
#	    utf8 => 1
	    );

	my $logger = Log::Log4perl->get_logger($loggerName);

	return $logger;

    };
    
};

1;
