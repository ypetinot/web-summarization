package HTMLRenderer;

use strict;
use warnings;

# this class and sub-classes abstracts the concept of HTML rendering
# the only method that needs to be implemented by sub-classes is the render method

use Moose;
use namespace::autoclean;

=pod
sub new {

    my $that = shift;
    
    my $ref = {};
    bless $ref, $that;

    return $ref;

}
=cut

sub render {

    my $this = shift;
    my $html_string = shift;

    # by default
    return $this->_render_html_default($html_string);

}

# fast HTML rendering (but is this any good ?)
sub _render_html_default {
    
    my $this = shift;
    my $html_string = shift;

    my $text = '';
    
    # render HTML
    eval {

        my $tree = HTML::TreeBuilder->new; # empty tree

	# Note: apparently this functionality is experimental
	$tree->no_space_compacting(1);

	$tree->utf8_mode(0);
        my $p = $tree->parse($html_string);
        $text = $p->as_trimmed_text;
	#$text = $p->as_text;
        #$p->delete;
        $tree = $tree->delete;

    };

    return $text;

}

__PACKAGE__->meta->make_immutable;

1;
