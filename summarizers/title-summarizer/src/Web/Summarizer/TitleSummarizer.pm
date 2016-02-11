package Web::Summarizer::TitleSummarizer;

# title summarizer

use strict;
use warnings;

use Digest::MD5 qw(md5 md5_hex md5_base64);
use Getopt::Long;
use JSON;
use Pod::Usage;
use URI;
use URI::URL;
use File::Path;
use File::Temp qw/tempfile/;
use XML::Generator escape => 'always';
use XML::TreePP;
use Lingua::EN::Sentence qw( get_sentences add_acronyms set_EOS );
use Text::Trim;

use Moose;
use namespace::autoclean;

with('Web::Summarizer');

# id
has 'id' => ( is => 'ro' , isa => 'Str' , default => "title" );

sub summarize {
    
    my $this = shift;
    my $instance = shift;
    
    my $title_utterance = $instance->title_modality->utterance;
    my $summary_object = defined( $title_utterance ) ? $title_utterance : new Web::Summarizer::Sentence( raw_string => '' , object => $instance , source_id => __PACKAGE__ , chunk => 0 );

    return $summary_object;

}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 NAME
    
    title-summarizer - Title summarization algorithms
    
=head1 SYNOPSIS
    
    run-summarizer [options]

    Options:
       -help            brief help message
       -man             full documentation

=head1 OPTIONS

=over 8

=item B<-help>

    Print a brief help message and exits.

=item B<-man>

    Prints the manual page and exits.

=back

=head1 DESCRIPTION

    Simply return the title of the target URL.

=cut
