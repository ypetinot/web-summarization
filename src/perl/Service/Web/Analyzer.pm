package Service::Web::Analyzer;

use strict;
use warnings;

use File::Slurp;
use Text::Trim;

use Moose;
use namespace::autoclean;

sub content {

    my $this = shift;
    my $raw_content = shift;

    my @rendered_content;

    # TODO : use the server version of tika instead ?
    #`wget -O - --timeout=20 --quiet '$url'
    my $tika_parameters = '--text';
    my $tika_output = $this->_run_tika( $raw_content , $tika_parameters );
    if ( $tika_output ) {
	#@rendered_content = grep { length($_); } map { chomp; s/^\s+//; s/\s+$//; trim( $_ ); } @command_output;
	@rendered_content = @{ $tika_output };
    }
    
    return \@rendered_content;
    
}

sub metadata {

    my $this = shift;
    my $raw_content = shift;

    my %metadata;

    my $tika_parameters = '--metadata';
    my $tika_output = $this->_run_tika( $raw_content , $tika_parameters );

    if ( $tika_output ) {

	map {
	    my $metadata_entry = $_;
	    my @metadata_entry_fields = split /\:/ , $metadata_entry;
	    if ( $#metadata_entry_fields >= 1 ) {
		my $metadata_key = shift @metadata_entry_fields;
		my $metadata_value = trim( join( ":" , @metadata_entry_fields ) );
		$metadata{ $metadata_key } = trim( $metadata_value );
	    }
	} @{ $tika_output };

    }

    return \%metadata;

}

sub _run_tika {

    my $this = shift;
    my $raw_content = shift;
    my $parameters = shift || '';

    my $output = undef;

    # 0 - clean up content (should this happen here ?)
    my $raw_content_clean = $raw_content;

    # 1 - create temp file to write raw content to
    my $raw_content_file = File::Temp->new( UNLINK => 1 );
    $raw_content_file->autoflush( 1 );
    binmode( $raw_content_file , ':utf8' );
    print $raw_content_file $raw_content;

    # 2 - create temp file to write analyzed content to
    # Note/TODO : this should not be necessary but the ouput read directly from the backtick operator does not (seem to) have the proper encoding
    #             => could this be a similar problem to the one described here => http://www.nisus.com/forum/viewtopic.php?t=2994 ?
    my $analyzed_content_file = File::Temp->new( UNLINK => 1 );
    binmode( $analyzed_content_file , ':utf8' );

    # CURRENT : perfect solution would be to have tika handle the download as well => problem redownload for title => unless we use a single-threaded cache/proxy ? => we really don't needed to store the raw data in mongodb (i mean it's nice and maybe the cache/proxy can still do that, but it's not necessary)
    my $command = "cat $raw_content_file | java -jar $ENV{ROOTDIR_THIRD_PARTY}/tika/tika-1.6/tika-app/target/tika-app-1.6.jar ${parameters} > $analyzed_content_file";
### my @command_output = `$command`;
    `$command`;
    my @command_output = read_file( $analyzed_content_file );

    if ( $? ) {
	print STDERR "[" . __PACKAGE__ . "] An error occurred during raw content processing with parameters : $? ...\n";
    }
    else {
	my @output_content = grep { length($_); } map { chomp; s/^\s+//; s/\s+$//; trim( $_ ); } @command_output;
	$output = \@output_content;
    }

    return $output;

}

__PACKAGE__->meta->make_immutable;

1;
