package Category::Fold::Storage;

use strict;
use warnings;

use Moose::Role;

use MooseX::Storage::Engine;
use String::RewritePrefix;

our $VERSION   = '0.XX';
our $AUTHORITY = 'cpan:YPETINOT';

sub pack {
    my ( $self, %args ) = @_;
    my $e = $self->_storage_get_engine_class(%args)->new( object => $self );
    $e->collapse_object(%args);
}

sub unpack {
    my ($class, $data, %args) = @_;
    my $e = $class->_storage_get_engine_class(%args)->new(class => $class);

    $class->_storage_construct_instance(
        $e->expand_object($data, %args),
        \%args
	);
}

sub _storage_get_engine_class {
    my ($self, %args) = @_;

    return 'MooseX::Storage::Engine'
	unless (
            exists $args{engine_traits}
	    && ref($args{engine_traits}) eq 'ARRAY'
	    && scalar(@{$args{engine_traits}})
	);

    my @roles = String::RewritePrefix->rewrite(
        {
            '' => 'MooseX::Storage::Engine::Trait::',
            '+' => '',
        },
        @{$args{engine_traits}}
	);

  Moose::Meta::Class->create_anon_class(
        superclasses => ['MooseX::Storage::Engine'],
        roles => [ @roles ],
        cache => 1,
      )->name;
}

sub _storage_construct_instance {
    my ($class, $args, $opts) = @_;
    my %i = defined $opts->{'inject'} ? %{ $opts->{'inject'} } : ();

    $class->new( %$args, %i );
}

no Moose::Role;

1;
