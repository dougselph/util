# See LICENSE for licensing information.

ifeq ($(shell uname -o), Cygwin)
	EXT=".cmd"
else
  EXT=
endif

.PHONY: all all-fast clean clean-docs github-docs tar

PROJECT := $(notdir $(PWD))
TARBALL := $(PROJECT)

REBAR   := $(which rebar3 2> /dev/null)
REBAR   := $(if $(REBAR),$(REBAR),rebar)$(EXT)

empty   :=
space   := $(empty) $(empty)
delim   := $(empty),\n        $(empty)

all:
	@$(REBAR) compile

test eunit:
	@$(REBAR) eunit

# This is just an example of using make instead of rebar to do fast compilation
all-fast: $(patsubst src/%.app.src,ebin/%.app,$(wildcard src/*.app.src))

ebin/%.app: src/%.app.src $(wildcard src/*.erl)
	@sed 's!{modules, *\[.*\]!{modules, [\
        $(subst $(space),$(delim),$(sort $(basename $(notdir $(filter-out $<,$^)))))]!' \
		$< > $@
	erlc +debug_info -I include -o ebin $(filter-out $<,$?)

clean:
	@$(REBAR) clean
	@rm -fr ebin doc

docs: doc ebin clean-docs
	@gawk -f bin/md-edoc.awk version=$(shell git descr --abbrev=1 --tags) README.md > src/overview.edoc
	@$(REBAR) doc skip_deps=true

doc ebin:
	mkdir -p $@

clean-docs:
	rm -f doc/*.{css,html,png} doc/edoc-info

set-version:
	@[ -z $(version) ] && echo "Missing version=X.Y.Z!" && exit 1 || true
	@sed -i "s/{$(PROJECT), \"[[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+\"}/{$(PROJECT), \"$(version)\"}/" rebar.config
	@sed -i "s/{vsn, \"[[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+\"}/{vsn, \"$(version)\"}/" src/$(PROJECT).app.src

publish:
	$(REBAR) hex publish --replace

github-docs gh-pages:
	@if git branch | grep -q gh-pages ; then \
		git checkout gh-pages; \
	else \
		git checkout -b gh-pages; \
	fi
	rm -f rebar.lock
	git checkout master -- src include
	git checkout master -- Makefile rebar.*
	make docs
	mv doc/*.* .
	make clean
	rm -fr src c_src include Makefile erl_crash.dump priv rebar.* README*
	@FILES=`git st -uall --porcelain | sed -n '/^?? [A-Za-z0-9]/{s/?? //p}'`; \
	for f in $$FILES ; do \
		echo "Adding $$f"; git add $$f; \
	done
	@sh -c "ret=0; set +e; \
		if   git commit -a --amend -m 'Documentation updated'; \
		then git push origin +gh-pages; echo 'Pushed gh-pages to origin'; \
		else ret=1; git reset --hard; \
		fi; \
		set -e; git checkout master && echo 'Switched to master'; exit $$ret"


tar:
	@rm -f $(TARBALL).tgz; \
    tar zcf $(TARBALL).tgz --transform 's|^|$(TARBALL)/|' --exclude="core*" --exclude="erl_crash.dump" \
		--exclude="*.tgz" --exclude="*.swp" --exclude="c_src" \
		--exclude="Makefile" --exclude="rebar.*" --exclude="*.mk" \
		--exclude="*.o" --exclude=".git*" * && \
		echo "Created $(TARBALL).tgz"

.PHONY: test
