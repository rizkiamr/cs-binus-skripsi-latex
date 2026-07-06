.PHONY: all build clean validate lint

# Log-warning classes that latexmk exits 0 on, yet silently corrupt the PDF
# (dangling \ref -> "??", dangling \cite -> "[?]") or mean the build never
# converged. Patterns are deliberately specific to avoid matching benign
# "... has changed." / "float specifier changed" info lines.
VALIDATE_PATTERNS = LaTeX Warning: (Reference|Citation).*undefined|There were undefined references|multiply defined|Label\(s\) may have changed|Rerun to get

all: clean build

build:
	mkdir -p dist
	mkdir -p build
	latexmk -pdf -bibtex -outdir=../build -cd src/thesis.tex
	mv build/thesis.pdf dist

# validate: cheap pre-flight for errors that are expensive to *diagnose* in a
# full build. Two tiers, cheapest first:
#   1. Draft compile  - single pdflatex pass, no PDF/image output, halts at the
#      FIRST syntax/structure error (~1s) instead of burying the real cause in a
#      cascade deep in the build log.
#   2. Resolved scan  - full latexmk run (multi-pass + bibtex so refs actually
#      resolve), then grep the log for the "silent" errors latexmk exits 0 on.
validate:
	mkdir -p build
	@echo ">> [1/2] draft compile (fast syntax/structure check)"
	@( cd src && pdflatex -draftmode -halt-on-error -interaction=nonstopmode -output-directory=../build thesis.tex >/dev/null 2>&1 ) \
		|| { echo "!! DRAFT COMPILE FAILED - first error:"; grep -A3 -m1 '^!' build/thesis.log; exit 1; }
	@echo ">> [2/2] resolved build + log scan (undefined refs/citations, pending rerun)"
	@latexmk -pdf -bibtex -interaction=nonstopmode -halt-on-error -outdir=../build -cd src/thesis.tex >/dev/null 2>&1 \
		|| { echo "!! BUILD FAILED - first error:"; grep -A3 -m1 '^!' build/thesis.log; exit 1; }
	@if grep -nqE '$(VALIDATE_PATTERNS)' build/thesis.log; then \
		echo "!! VALIDATION FAILED - unresolved references/citations or pending rerun:"; \
		grep -nE '$(VALIDATE_PATTERNS)' build/thesis.log; \
		exit 1; \
	else \
		echo ">> OK: compiles cleanly; all references and citations resolved."; \
	fi

# lint: stylistic linting (kept separate from validate - style nits do not
# break the build). Was previously the whole of `validate`.
lint:
	find src -name '*.tex' -print0 | xargs -0 chktex -l .chktexrc

clean:
	rm -f dist/* build/*
	find . -iname "*~" -exec rm '{}' ';'
