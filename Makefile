BUILDDIR := build

name := grund
modules := \
	core.g \
	extra.g \
	assembler.g
main := main.g

ifeq ($(MAKECMDGOALS),test)
name := tgrund
modules += $(wildcard *_test.g)
main := tmain.g
endif

$(BUILDDIR)/$(name): grund.s $(modules) $(main)
	mkdir -p $(BUILDDIR)
	cat $(modules) $(main) > $(BUILDDIR)/grund.g
	cd $(BUILDDIR) && \
		as -g -almnc=$(name).lst -o $(name).o ../grund.s && \
		ld -o $(name) $(name).o

test: $(BUILDDIR)/tgrund
	@$(BUILDDIR)/tgrund

.PHONY: clean
clean:
	rm -rf $(BUILDDIR)
