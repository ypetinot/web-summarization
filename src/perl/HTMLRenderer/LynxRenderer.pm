package HTMLRenderer::LynxRenderer;

use HTMLRenderer;

use Moose;
use namespace::autoclean;

extends('HTMLRenderer');

use File::Temp qw/ tempfile tempdir /;

# render HTML content
# the easiest and most robust way of doing this is to use an actual browser (library)
sub render {

    my $that = shift;
    my $html_string = shift;
    my $is_file = shift || 0;

    my $filename = undef;

    if ( ! $is_file ) {

	my $fh;

	# create temp file for HTML content
	($fh, $filename) = tempfile( TMPDIR => 1 );
	binmode($fh, ':utf8');
	print $fh $html_string;

    }
    else {

	$filename = $html_string;

    }

    # render using lynx
    # https://sourceware.org/ml/libc-help/2014-07/msg00008.html
    my $text = `LIBC_FATAL_STDERR_=bogus timeout 60 /proj/nlp/users/ypetinot/ocelot-working-copy/svn-research/trunk/experimental/lynx/bin/lynx -width=1000000000 -dump -nolist -force_html $filename | iconv -c -t utf8`;
    #my $text = $formatter->format_string ($html_string);

    if ( ! $is_file ) {

	# remove temp file
	unlink($filename);

    }

    return $text;

}

1;
