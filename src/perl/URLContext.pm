package URLContext;

use ContextElement;
use Sentence;
use TagsAPI qw(getTagData);

sub new {
    my $this = shift;
    my $class = $this || ref($this);

    my $url = shift;

    my $hash = {};
    $hash->{_url} = $url;

    my $ref = bless $hash, $class;

    $ref->populate();

    return $ref;
}


sub populate {
    my $this = shift;

    my @context_elements;
    $this->{_context_elements} = \@context_elements;

    # acquire the url's anchortext
    my @anchortext_data = @{ getTagData($this->{_url},'anchortext') };
    push @context_elements, map { new ContextElement($_, undef, $this->{_url}) } @anchortext_data;
    $this->{_anchortext} = new Sentence(join (" ", @anchortext_data) || '');

    # acquire the url's dmoz titles (we concatenate them for now ... until we have something better)
    $this->{_dmoz_titles} = new Sentence(join (" ", @{getDMOZData($this->{_url},'title')}) || '');

    # acquire the url's dmoz descriptions (we concatenate them for now ... until we have something better)
    $this->{_dmoz_descriptions} = new Sentence(join (" ", @{getDMOZData($this->{_url},'description')}) || '');

}

sub anchorText {
    my $this = shift;
    return $this->{_anchortext};
}

sub anchorTextLight {
    my $this = shift;
    return $this->{_anchortext_light};
}

sub relatedQueries {
    my $this = shift;
    return $this->{_revrel};
}

sub dmozTitles {
    my $this = shift;
    return $this->{_dmoz_titles};
}

sub dmozDescriptions {
    my $this = shift;
    return $this->{_dmoz_descriptions};
}

sub contextElements {
    my $this = shift;
    return $this->{_context_elements};
}

1;
