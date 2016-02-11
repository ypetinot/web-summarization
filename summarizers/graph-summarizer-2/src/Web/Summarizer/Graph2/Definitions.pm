package Web::Summarizer::Graph2::Definitions;

our $NODE_BOG = "<bog>";
our $NODE_EOG = "<eog>";

our $INFINITY = LONG_MAX;
our $FEATURE_DEFAULT = 0;
our $WEIGHT_DEFAULT = 0;
our $FEATURES_KEY_EDGE = 'edge';
our $FEATURES_KEY_OBJECT = 'object';

our $FILE_FEATURES = "features";
our $FILE_FEATURE_WEIGHTS = "weights";
our $FILE_PARAMS = "param";

our $NODE_ATTRIBUTE_VERBALIZATION = 'verbalization';
our $EDGE_ATTRIBUTE_WIDTH = 'weight';
our $GRAPH_PROPERTY_PATH_COUNT = 'graph-path-count';
our $NODE_ATTRIBUTE_PRIOR = 'node-prior';
our $EDGE_ATTRIBUTE_PRIOR = 'edge-prior';
our $NODE_ATTRIBUTE_IS_SLOT = "is_slot";
our $NODE_ATTRIBUTE_DATA = "data";

our $EDGE_ATTRIBUTE_EXPECTED_FREQUENCY = 'expected-edge-frequency';
our $EDGE_ATTRIBUTE_TARGET_FREQUENCY = 'target-edge-frequency';
our $NODE_ATTRIBUTE_TARGET_FREQUENCY = 'target-node-frequency';
our $NODE_ATTRIBUTE_EXPECTED_FREQUENCY = 'expected-node-frequency';

our $FEATURE_EDGE_TARGET_FREQUENCY = 'target-edge-frequency';
our $FEATURE_SOURCE_TARGET_FREQUENCY = 'target-source-frequency';
our $FEATURE_SINK_TARGET_FREQUENCY = 'target-sink-frequency';

our $FEATURE_EDGE_PRIOR = 'feature_edge_prior';
our $FEATURE_SOURCE_PRIOR = 'feature_source_prior';
our $FEATURE_SINK_PRIOR = 'feature_sink_prior';

our $FEATURE_ADJUSTED_EDGE_PRIOR = 'adjusted_edge_prior';
our $FEATURE_ADJUSTED_SOURCE_PRIOR = 'adjusted_source_prior';
our $FEATURE_ADJUSTED_SINK_PRIOR = 'adjusted_sink_prior';

our $EDGE_ATTRIBUTE_FEATURES = 'features';

our $POS_NAMED_ENTITY = "<NAMED_ENTITY_SLOT>";
our $POS_ADVERB = "<adverb>";
our $POS_ADJECTIVE = "<adjective>";
our $POS_VERB = "<verb>";
our $POS_OTHER = "<other>";

1;
