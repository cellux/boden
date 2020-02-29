BUILDDIR := build

name := boden
sources := \
	core.b \
	extra.b \
	assembler.b
main := main.b

ifeq ($(MAKECMDGOALS),test)
name := boden_test
sources += $(wildcard *_test.b)
main := maint.b
endif

$(BUILDDIR)/$(name): core.s $(sources) $(main)
	mkdir -p $(BUILDDIR)
	cat $(sources) $(main) > $(BUILDDIR)/boden.b
	cd $(BUILDDIR) && \
		as -g -almnc=$(name).lst -o $(name).o ../core.s && \
		ld -o $(name) $(name).o

test: $(BUILDDIR)/boden_test
	@$(BUILDDIR)/boden_test

.PHONY: clean
clean:
	rm -rf $(BUILDDIR)
