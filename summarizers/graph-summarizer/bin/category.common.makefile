# list all the category file in the current directory, these are our candidate targets
#CATEGORY_FILES := $(shell find $(CURDIR) -maxdepth 1 -type f -not -name '*.*' -exec basename {} \; )
#$(error $(CATEGORY_FILES))

#$(info available categories: $(CATEGORY_FILES))                                                                                                                                            
#.PHONY: $(CATEGORY_FILES) clean

# By default all categories in the target directory
#default: clean ${CATEGORY_FILES}
#	@echo "Done !";

clean:
	find -maxdepth 1 -type f -size 0 -delete
	rm -rf *~
	rm -rf *.tmp

%::
	@echo "Catch-all rule in category.common.makefile ..."