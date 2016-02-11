DATA_MAKEFILE_DIR:=$(realpath $(dir $(lastword $(MAKEFILE_LIST))))

include $(DATA_MAKEFILE_DIR)/bin/makefile.data
#include $(DATA_MAKEFILE_DIR)/../bin/makefile.common
#include $(DATA_MAKEFILE_DIR)/../bin/makefile.fold

BINDIR:=$(DATA_MAKEFILE_DIR)/bin/
WIKIPEDIA_DATA_URL=dumps.wikimedia.org/enwiki/20121101/enwiki-20121101-pages-articles-multistream.xml.bz2
DBPEDIA_DATA_URL=article_categories_en.nt.bz2

DBPEDIA_INSTANCE_TYPES_URL=downloads.dbpedia.org/3.8/en/instance_types_en.nt.bz2
DBPEDIA_INSTANCE_TYPES=$(notdir $(DBPEDIA_INSTANCE_TYPES_URL))

URLS_TO_DOWNLOAD=$(DBPEDIA_INSTANCE_TYPES_URL)
#ARCHIVES_TO_DOWNLOAD=$(notdir $(URLS_TO_DOWNLOAD))

DMOZ_GLOBAL_VOCABULARY:=dmoz.vocabulary
DMOZ_GLOBAL_VOCABULARY_WIKIPEDIA_MAPPING:=$(DMOZ_GLOBAL_VOCABULARY).wikipedia
DMOZ_GLOBAL_VOCABULARY_FEATURES:=$(DMOZ_GLOBAL_VOCABULARY).features

FIELDS_REQUIRED:=content.rendered title url.words
FIELDS_DESIRED:=anchortext.basic anchortext.sentence

FIELDS_REQUIRED_NGRAMS:=$(FIELDS_REQUIRED)
FIELDS_DESIRED_NGRAMS:=$(FIELDS_DESIRED)
N_GRAM_ORDERS=1 2 3 4 5
N_GRAM_THRESHOLD=10
JOINT_COUNTS_THRESHOLD=5

FIELDS_CONDITIONAL:=$(FIELDS_REQUIRED) $(FIELDS_DESIRED)
FIELDS=summary $(FIELDS_CONDITIONAL)

# global vocabulary
GLOBAL_VOCABULARY:=vocabulary-data

default:

global-vocabulary: $(DMOZ_GLOBAL_VOCABULARY_FEATURES)
global-vocabulary-clean:
	rm -rf $(GLOBAL_VOCABULARY)*

global-ngrams: $(call dmoz_language_model,summary,$(lastword $(N_GRAM_ORDERS)),$(foreach ngram_order,$(N_GRAM_ORDERS),-gt$(ngram_order)min $(N_GRAM_THRESHOLD)) -unk)
### options that will probably not be needed (?) : -no-sos -no-eos

_map_fields = $(foreach field_type,$(1),dmoz.$(field_type).$(2))

##### dmoz.conditional.raw:
##### 	cat $(CATEGORY_LIST) | perl $(BINDIR)/global-category-processor $(FOLD_ID) ConditionalProcessor --fields=$(FIELDS_CONDITIONAL) --ngram_orders=$(N_GRAM_ORDERS) --ngram_count_threshold=$(N_GRAM_THRESHOLD) --joint_count_threshold=3 --summary_reference=dmoz.summary.ngrams --global_data_directory=$(CURDIR) --batch=500 --output_directory=$@.temp

# sequential version ...
#### conditional for a specific field/order
###$(foreach field_conditional,$(FIELDS_CONDITIONAL),dmoz.$(field_conditional).conditional): $(foreach field_conditional,$(FIELDS_CONDITIONAL),dmoz.$(field_conditional).ngrams) dmoz.summary.ngrams
###	mkdir -p $(foreach field_conditional,$(FIELDS_CONDITIONAL),dmoz.${field_conditional}.conditional)
###	cat $(CATEGORY_LIST) | perl $(BINDIR)/global-category-processor $(FOLD_ID) ConditionalProcessor --fields=$(FIELDS_CONDITIONAL) --ngram_orders=$(N_GRAM_ORDERS) --ngram_count_threshold=$(N_GRAM_THRESHOLD) --joint_count_threshold=3 --summary_reference=dmoz.summary.ngrams --global_data_directory=$(CURDIR) --stdout_only=1 | sort -T /tmp/ -t'	' -k1,3 | perl $(BINDIR)/merge-counts | perl $(BINDIR)/generate-conditional-features --joint-counts-threshold=$(JOINT_COUNTS_THRESHOLD) $(CURDIR) | awk -F"\t" '{ print $$0 > "dmoz." $$2 ".conditional/" $$2 ".features" }'

# conditional for a specific field/order
$(foreach field_conditional,$(FIELDS_CONDITIONAL),dmoz.$(field_conditional).conditional): $(foreach field_conditional,$(FIELDS_CONDITIONAL),dmoz.$(field_conditional).ngrams) dmoz.summary.ngrams
	mkdir -p $(foreach field_conditional,$(FIELDS_CONDITIONAL),dmoz.${field_conditional}.conditional)
	cat $(CATEGORY_LIST) | $(BINDIR_PARALLEL)/parallel --pipe -N 1000 --no-notice -j 1 --use-cpus-instead-of-cores --sshloginfile $(PARALLEL_SERVERS_LIST_8) $(BINDIR)/global-category-processor $(FOLD_ID) ConditionalProcessor --fields=$(FIELDS_CONDITIONAL) --ngram_orders=$(N_GRAM_ORDERS) --ngram_count_threshold=$(N_GRAM_THRESHOLD) --joint_count_threshold=3 --summary_reference=dmoz.summary.ngrams --global_data_directory=$(CURDIR) --stdout_only=1 | sort -T /tmp/ -t'	' -k1,3 | perl $(BINDIR)/merge-counts | perl $(BINDIR)/generate-conditional-features --joint-counts-threshold=$(JOINT_COUNTS_THRESHOLD) $(CURDIR) | awk -F"\t" '{ print $$0 > "dmoz." $$2 ".conditional/" $$2 ".features" }'

##### # conditional for a specific field/order
##### dmoz.%.conditional: dmoz.conditional.raw dmoz.%.ngrams dmoz.summary.ngrams
##### ###	cat $(CATEGORY_LIST) | perl $(BINDIR)/global-category-processor $(FOLD_ID) ConditionalProcessor --fields=$* --ngram_orders=$(N_GRAM_ORDERS) --ngram_count_threshold=$(N_GRAM_THRESHOLD) --joint_count_threshold=3 --summary_reference=dmoz.summary.ngrams --global_data_directory=$(CURDIR) --output_directory=$@.temp > $@.temp/$*.raw
##### #| awk -F"\t" '{ print $$2 "\t" $$3 "\t" $$4 "\t" $$5 > "$@.temp/" $$1 ".raw" }'
##### 	cat dmoz.conditional.raw/$*.raw.reference | sort -t'	' -k1,2 | perl $(BINDIR)/merge-counts > $@.temp/$*.reference
##### ###	rm -f $@.temp/$*.reference.raw
##### 	cat dmoz.conditional.raw/$*.raw | sort -t'	' -k1,3 | perl $(BINDIR)/merge-counts | perl $(BINDIR)/generate-conditional-features --joint-counts-threshold=$(JOINT_COUNTS_THRESHOLD) --joint-counts-reference=$@.temp/$*.reference $(CURDIR) $* > $@.temp/$*.features

.DELETE_ON_ERROR:
$(DMOZ_GLOBAL_VOCABULARY): /proj/nlp/users/ypetinot/data/dmoz-corpus-12-07-2010/training/dmoz.mapped.description.vocabulary
	cat $< | sort -k 2 > $@

$(DMOZ_GLOBAL_VOCABULARY_WIKIPEDIA_MAPPING): $(DMOZ_GLOBAL_VOCABULARY)
	cat $< | $(CURDIR)/bin/get-wikipedia-entry > $@

# TODO : turn rendered.temp into a intermediary target (i.e. one that would not be preserved) ?
$(DMOZ_GLOBAL_VOCABULARY_FEATURES): $(DMOZ_GLOBAL_VOCABULARY_WIKIPEDIA_MAPPING)
	cat $(DMOZ_GLOBAL_VOCABULARY_WIKIPEDIA_MAPPING) | $(CURDIR)/../bin/html-renderer 2>/dev/null > $@.rendered.temp
	join -1 2 -2 1 -t'	' $(DMOZ_GLOBAL_VOCABULARY) $@.rendered.temp | $(CURDIR)/bin/generate-term-features > $@
	rm -f $@.rendered.temp

ARCHIVES_TO_DOWNLOAD=$(URLS_TO_DOWNLOAD)

$(ARCHIVES_TO_DOWNLOAD):
	wget -c $@
	find $(CURDIR)/ -type f -name '*.bz2' -exec touch {} \;

dbpedia_instance_ontology_mapping.json: $(DBPEDIA_INSTANCE_TYPES)
	bunzip2 -c $< | grep 'dbpedia.org\/ontology' | awk '{ print $$1 " " $$3 }' | tr -d '<>' | $(CURDIR)/generate-dbpedia-mapping > $@

dbpedia_instance_ontology_mapping_store: dbpedia_instance_ontology_mapping.json
	curl 'http://southpaw.cs.columbia.edu:8080/solr/dbpedia-ontology-mapping/update/json?commit=true' --data-binary \@$< -H 'Content-type:application/json'

clean: global-inverted-index-clean global-conditional-clean global-vocabulary-clean
# TODO : recreate that rule/recipe
#global-ngrams-clean
	rm -rf *~
	rm -rf *.bz2
	rm -rf *.temp
