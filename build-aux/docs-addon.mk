docs::
	@mkdir -p build-aux
	@for f in docs-addon.mk edoc.css md-to-edoc.awk md-to-edoc.sh module-template.html; do \
    if [ -f build-aux/$$f ]; then \
	    true; \
		else \
		  echo "Fetching $$f from github.com/saleyn/util" && \
      curl -s -o build-aux/$$f https://raw.githubusercontent.com/saleyn/util/master/build-aux/$$f; \
		fi; \
   done
	@sh build-aux/md-to-edoc.sh README.md > build-aux/overview.edoc
docs:: BG=$(shell sed -n '/background-color:/{s/[^#]\+#\([^;]\+\);.*/\1/p;q}' build-aux/edoc.css)
docs::
docs:: clean-docs
ifeq (rebar3,$(REBAR))
	@$(REBAR) edoc
else ifeq (rebar,$(REBAR))
	@$(REBAR) doc skip_deps=true
else
	@rebar3 edoc
endif
	@sed -i -e 's/<body bgcolor="[^"]\+">/<body>\n<a name="top"><\/a>/' doc/*.html
	@sed -i -e '/^<body/s/<body>/<body class="src">/' \
          -e '/a name=".navbar_/d' \
 					-e '/<p><i>Generated by EDoc/d' \
					-e 's/&amp;\(quot\|apos\|grave\|commat\|copy\|reg\|commat\);/\&\1;/g' \
					-e 's!<pre>!<pre ><code class="language-erlang">!g' \
					-e 's!</pre>!</code></pre >!g' \
					-e 's/\t/    /g' \
      $$(ls -1 doc/*.html | egrep -v '(modules-frame|index)\.html')
	@sed -i -e '/^<body>/s/<body>/<body class="src">/' \
					-e '/<a href="'#'description">Description<\/a>/d' \
	        -e '/navbar/!s/ cellspacing="[^"]\+"/ class="tab"/g' \
		      -e '/navbar/!s/ cellpadding=\"[^"]\+"//g' \
          -e '/navbar/!s/ border="1"//' \
	        -e '/^<table/s/^<table *\(class=[^"]\+"\)\?\(.*\)/<table class="tab" \2/' \
		      -e '/<t[rd]/s/<t\([rd]\)[^>]*>/<t\1 class="tab">/g' \
          -e "/^<h3 class=\"function\"><a [^h]/s/^\(<h3 class=\"function\">\)\(<a \)/\1<a href=\""'#'"index\"><i class=\"arrow up\"><\/i><\/a>\2 class=\"function\" /" \
          -e "s/<a name=\"\(description\|types\|index\|functions\)\"/<a href=\""'#top'"\" name=\"\1\"/" \
          -e "s/<a name=\"\(description\|types\|index\|functions\)\"/<a href=\""'#top'"\" name=\"\1\"/" \
      $$(ls -1 doc/*.html | egrep -v '(modules-frame|overview-summary|index)\.html')
	@cp build-aux/module-template.html doc/.template
	@mv doc/overview-summary.html doc/index.html
	@rm doc/modules-frame.html
	@cd doc && ls -1 *.html | grep -v "index.html" | \
			awk '{ \
		      	m=$$0; \
		      	sub("\\.html",""); printf("<a class=\"mod\" href=\"%s\">%s</a>\n", m, $$0); \
				  }' > .files && \
			sed -i -e '/<!-- MODULE LINK -->/{r .files' -e 'd}' .template
	@cd doc && \
			ls -1 *.html | while read f; do \
		  		cp .template $$f.new; \
					awk '!body && /^<body/ { body=1; next } body && /^<\/body>/ { exit } body { print }' $$f > $$f.tmp; \
		  		sed -i -e "/<\!-- BODY -->/{r $$f.tmp" -e 'd}' $$f.new && rm $$f.tmp; \
					if [ "$$f" = "index.html" ]; then \
						TITLE="$$(sed -n 's/ *{title, *"\([^"]\+\)" *},.*$$/\1/p' ../rebar.config)"; \
						KEYWORDS="$$(sed -n '/{keywords, *"/,/"}/{s/.*{keywords, *"//; s/"} *,\? *$$//; s/[ \t\r\n]\+/ /g; p;}' ../rebar.config)"; \
						sed -i -e '/<!-- MODULE MENU BEGIN -->/,/<!-- MODULE MENU END -->/d' \
						       -e 's;<!-- TITLE -->;<title>'"$$TITLE"'</title>\n<meta name="keywords" content='"$$KEYWORDS"'>;' \
								$$f.new; \
					fi; \
					mv -f $$f.new $$f; \
			done
	@rm	doc/.files doc/.template
	@#rm doc/stylesheet.css && cd doc && ln -s ../build-aux/edoc.css stylesheet.css

clean-docs::
	@rm -f doc/*.{css,html,png} doc/edoc-info

get-version set-version: APPFILE:=$(shell find -name $(PROJECT).app.src)
get-version set-version: PROJECT:=$(if $(PROJECT),$(PROJECT),$(notdir $(PWD)))
get-version:
	@printf "%-20s: %s\n" "$(notdir $(APPFILE))" "$$(sed -n 's/.*{vsn, \"\([0-9]\+\)\(\(\.[0-9]\+\)\+\)\"}.*/\1\2/p' $(APPFILE))"
	@printf "%-20s: %s\n" "rebar.config" "$$(sed -n 's/.*{$(PROJECT), *\"\([0-9]\+\)\(\(\.[0-9]\+\)\+\)\"}.*/\1\2/p' rebar.config)"

set-version:
	@[ -z $(version) ] && echo "Missing version=X.Y.Z!" && exit 1 || true
	@sed -i "s/{vsn, \"\([0-9]\+\)\(\(\.[0-9]\+\)\+\)\"}/{vsn, \"$(version)\"}/" $(APPFILE)
	@sed -i "s/{$(PROJECT), \"[[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+\"}/{$(PROJECT), \"$(version)\"}/" rebar.config

github-docs gh-pages: GVER=$(shell git ls-tree --name-only -r master build-aux | grep 'google.*\.html')
github-docs gh-pages: LOCAL_GVER=$(notdir $(GVER))
github-docs gh-pages:
	@# The git config params must be set when this target is executed by a GitHub workflow
	@[ -z "$(git config user.name)" ] && \
		git config user.name  github-actions
		git config user.email github-actions@github.com
	@if git branch | grep -q gh-pages ; then \
		git checkout gh-pages; \
	else \
		git checkout -b gh-pages; \
	fi
	rm -f rebar.lock
	git checkout master -- src $(shell [ -d include ] && echo include)
	git checkout master -- Makefile rebar.* README.md
	@# Create google verification file if one exists in the master
	[ -n "$(GVER)" ] && git show master:$(GVER) 2>/dev/null > "$(LOCAL_GVER)" || true
	make docs
	mv doc/*.* .
	make clean
	find . -maxdepth 1 -type d -not -name ".git" -a -not -name "." -exec rm -fr {} \;
	find . -maxdepth 1 -type f -not -name ".git" -a -not -name "*.html" -a -not -name "*.css" -a -not -name "*.js" -a -not -name "*.png" -exec rm -f {} \;
	@FILES=`git status -uall --porcelain | sed -n '/^?? [A-Za-z0-9]/{s/?? //p}'`; \
	for f in $$FILES ; do \
		echo "Adding $$f"; git add $$f; \
	done
	@sh -c "ret=0; set +e; \
		if   git commit -a --amend -m 'Documentation updated'; \
		then git push origin +gh-pages; echo 'Pushed gh-pages to origin'; \
		else ret=1; git reset --hard; \
		fi; \
		set -e; git checkout master && echo 'Switched to master'; exit $$ret"

