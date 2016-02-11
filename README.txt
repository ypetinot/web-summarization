# Open issues:
--> domain takeovers, e.g. http://www.paulmonte.com/ ==> at the very least should we ignore redirects when collecting data ?

# crawl
cat ../dmoz.en.randomized.urls | grep -v "'" | xargs --max-args=1 --max-procs=100 -i{} sh -c "wget -t 1 -T 5 -q '{}' -O - | perl ../line-remover '{}'" > dmoz.all.data.raw

# anchor-text collection
cat ../dmoz.en.randomized | awk -F"\t" '{ print $1 }' > dmoz.urls
split -l 50000 dmoz.urls
/proj/nlp/users/ypetinot/ocelot/svn-research/trunk/bin/distribute /proj/nlp/users/ypetinot/ocelot/svn-research/trunk/bin/get-context-urls-wrapper servers.list

# tags collection
split -l 50000 ../anchor-text/dmoz.urls
find ./ -name 'x*' | /proj/nlp/users/ypetinot/ocelot/svn-research/trunk/bin/distribute-2 /proj/nlp/users/ypetinot/ocelot/svn-research/trunk/bin/get-tags <( head -n3 ../anchor-text/servers.list )

# generic dmoz data preparation --> dmoz-prepare <dmoz-raw-data> <target-directory>

# field-specific processing (dmoz-prepare-map ?)

# generate subtrees
for file in `find ./ -type f`; do FILENAME=`basename $file | tr '[:upper:]' '[:lower:]'`; echo "processing $FILENAME"; TARGET_DIRNAME="dmoz-corpus-$FILENAME"; mkdir -p $TARGET_DIRNAME; /proj/nlp/users/ypetinot/ocelot/svn-research/trunk/bin/dmoz-build-corpus $file $TARGET_DIRNAME; done;

# distribute tag/anchor-text collection
find ./ -name 'x*' | /proj/nlp/users/ypetinot/ocelot/svn-research/trunk/bin/distribute-2 /proj/nlp/users/ypetinot/ocelot/svn-research/trunk/bin/get-tags <( head -n3 ../anchor-text/servers.list )

# generate category statistics / per-category url listing
cat /proj/nlp/users/ypetinot/data/raw-data-current/dmoz.all.data | /proj/nlp/users/ypetinot/ocelot/svn-research/trunk/bin/dmoz-filter 2>/dev/null | awk -F"\t" '{ print $1 "\t" $4 }' | /proj/nlp/users/ypetinot/ocelot/svn-research/trunk/bin/dmoz-category-statistics > dmoz.full.categories.stats
