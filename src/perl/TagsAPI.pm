my $TAGS_API_URL = 'http://10.46.60.166:8888/cgi-bin/allTags.cgi';

#    my $DATABASE = 'titan';
#    my $DATABASE = 'main_inc';
#    my $DATABASE = 'fresh_new';
#    my $DATABASE = 'main_batch';
     my $DATABASE = 'freshness';
#    my $DATABASE = 'fresh_test';

#----------------------------------------------------------------------------------------------------------------------------------------------
sub URLEncode
{
    my($url)=@_;

    if ( ! $url || ! defined($url) ) {
	return $url;
    }

    my(@characters)=split(/(\%[0-9a-fA-F]{2})/,$url);

    foreach(@characters)
    {
        if ( /\%[0-9a-fA-F]{2}/ ) # Escaped character set ...
        {
                # IF it is in the range of 0x00-0x20 or 0x7f-0xff
                #    or it is one of  "<", ">", """, "#", "%",
                #                     ";", "/", "?", ":", "@", "=" or "&"
                # THEN preserve its encoding
                #"
                unless ( /(20|7f|[0189a-fA-F][0-9a-fA-F])/i
                             || /2[2356fF]|3[a-fA-F]|40/i )
                {
                    s/\%([2-7][0-9a-fA-F])/sprintf "%c",hex($1)/e;
                }
            }
        else # Other stuff
        {
                # 0x00-0x20, 0x7f-0xff, <, >, and " ... "
                s/([\000-\040\177-\377\074\076\042])
                    /sprintf "%%%02x",unpack("C",$1)/egx;
            }
    }
    return join("",@characters);
}

sub getDMOZData {

    my ($url, $field) = @_;

    my $ENCODED_URL = URLEncode($url);

    my $data = `wget -q -O - $TAGS_API_URL?db=$DATABASE\\&query=tag\\&url=$ENCODED_URL`;

    my @result;
    if ( $data =~ m/Description Type \: dmoz\.description(.+)Description Type \: dmoz\.title(.+)$/s ) {

	my $temp;
	if ( $field eq 'description' ) {
	    $temp = $1;
	}
	else {
	    $temp = $2;
	}

	while ( $temp =~ m/\[([^\]]+)\]/g ) {
	    push @result, $1;
	}

    }

    return \@result;

}


sub getAnchorText {

    my ($url) = shift;
    my @result;

    my $ENCODED_URL = URLEncode($url);

    if ( $url ) {
	my $data = `wget -q -O - $TAGS_API_URL?db=$DATABASE\\&query=tag\\&url=$ENCODED_URL\\&type=anchortext`;
	
	while ( $data =~ m/\[([^\]]+)\]/g ) {
	    
	    my @tokens = split(/,/,$1);
	    map(s/^\"// & s/\"$//, @tokens);
	    push @result, join(" ", @tokens);
	
	}
    }

    return \@result;
    
}

sub getTagData {

    my $url = shift;
    my $type = shift;

#    print "getting tag data for ($url,$type)\n";

    my @result;

    my $ENCODED_URL = URLEncode($url);

    if ( $url ) {
        my $data = `wget -q -O - $TAGS_API_URL?db=$DATABASE\\&query=tag\\&url=$ENCODED_URL\\&type=$type`;

        while ( $data =~ m/\[([^\]]+)\]/g ) {

            my @tokens = split(/,/,$1);
            map(s/^\"// & s/\"$//, @tokens);
            push @result, join(" ", @tokens);

        }
    }

    return \@result;

}

1;
