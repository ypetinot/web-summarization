package Word2Vec;

use Inline C;

print "9 + 16 = ", Word2Vec::add(9, 16), "\n";
print "9 - 16 = ", main::subtract(9, 16), "\n";

sub _word2vec_analogy {

    my $this = shift;
    my $word1 = shift;
    my $word2 = shift;
    my $word3 = shift;

    my %analogies;
    
    return \%analogies;

}

__END__
__C__

int add(int x, int y) {
	return x + y;
}

int subtract(int x, int y) {
      return x - y;
}
