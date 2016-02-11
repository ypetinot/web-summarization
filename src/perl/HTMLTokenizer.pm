package HTMLTokenizer;

use strict;
use warnings;

use String::Tokenizer;
use base('String::Tokenizer');

use HTMLRenderer;

use File::Temp qw/tempfile/;
use HTML::TreeBuilder;

# constructor
sub new {

    my $that = shift;
    my %options = @_;

    my $class = ref($that) || $that;
    
    my $ref = new String::Tokenizer( %options );

    # set HTML renderer
    if ( ! defined( $options{'renderer'} ) ) {
	$ref->{_html_renderer} = new HTMLRenderer;
    }
    else {
	require join('/', split /::/, $options{'renderer'} ) . ".pm";
	$ref->{_html_renderer} = "$options{'renderer'}"->new();
    }

    bless $ref, $class;

    return $ref;
}

# tokenize text
sub tokenize {

    my $this = shift;
    my $raw_html = shift;

    my $plain_text = '';
    $plain_text = $this->{_html_renderer}->render($raw_html);

    # perform preprocessing (OCELOT-specific)
    my $ocelot_text = $this->_ocelot_preprocess($plain_text);

    # split into sentences ??
    # TODO

    # use regular tokenization algorithm
    return $this->SUPER::tokenize($ocelot_text);

}


# perform OCELOT preprocessing
# (note that most of the original preprocessing is implemented by rendering the page)
sub _ocelot_preprocess {

    my $this = shift;
    my $text = shift;

    # remove punctuation
    $text =~ s/(^|\W)[[:punct:]]+($|\W)/$1 $2/sg;

=pod
    # TODO: re-enable and turn this into an option
    # lower-case text
    $text = lc($text);
=cut

    return $text;

}

1;
