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

-include build-aux/docs-addon.mk

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

doc ebin:
	mkdir -p $@

publish:
	$(REBAR) hex publish $(if $(replace),--replace)

tar:
	@rm -f $(TARBALL).tgz; \
    tar zcf $(TARBALL).tgz --transform 's|^|$(TARBALL)/|' --exclude="core*" --exclude="erl_crash.dump" \
		--exclude="*.tgz" --exclude="*.swp" --exclude="c_src" \
		--exclude="Makefile" --exclude="rebar.*" --exclude="*.mk" \
		--exclude="*.o" --exclude=".git*" * && \
		echo "Created $(TARBALL).tgz"

build-aux/docs-addon.mk:
	git co master build-aux/docs-addon.mk

.PHONY: test
