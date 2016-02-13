package SRILM::Mapper;

# encapsulate SRILM-specific token-id mapping

sub map_to_srilm {

    my $original_tokens = shift;
    my @mapped_tokens = map { if ( $_ =~ m/^\d+$/ ) { $_ + $srilm_offset; } else { $_ } } @$original_tokens;
    return \@mapped_tokens;

}

sub map_from_srilm {

    my $srilm_tokens = shift;
    my @mapped_tokens = map { if ( $_ =~ m/^\d+$/ ) { $_ - $srilm_offset; } else { $_ } } @$srilm_tokens;
    return \@mapped_tokens;

}

1;
