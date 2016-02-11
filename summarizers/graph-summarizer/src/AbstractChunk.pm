package AbstractChunk;

use strict;
use warnings;

use Moose;
use MooseX::Storage;

with Storage('format' => 'JSON', 'io' => 'File');

# ********************************************************************************* #
# fields 

# chunk id
has 'id' => (is => 'ro', isa => 'Str', required => 1);

# version
has 'version' => (is => 'ro', isa => 'Num', required => 0);

# semantic type
has 'type' => (is => 'ro', isa => 'Str', required => 1);

# ********************************************************************************* #

no Moose;

1;
