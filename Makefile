MACHINE ?= $(shell uname -m)

ifeq ($(MACHINE),x86_64)
core := core/x86_64.s
else ifeq ($(MACHINE),i686)
core := core/i686.s
else
$(error Unsupported machine: $(MACHINE))
endif

BUILDDIR := build

output := boden
forth_libs := core.b extra.b
forth_main := main.b

ifeq ($(MAKECMDGOALS),test)
output := boden_test
forth_libs += $(wildcard *_test.b)
forth_main := maint.b
endif

$(BUILDDIR)/$(output): $(core) $(forth_libs) $(forth_main)
	mkdir -p $(BUILDDIR)
	cat $(forth_libs) $(forth_main) > $(BUILDDIR)/boden.b
	cd $(BUILDDIR) && \
		as -g -almnc=$(output).lst -o $(output).o ../$(core) && \
		ld -o $(output) $(output).o

test: $(BUILDDIR)/boden_test
	@$(BUILDDIR)/boden_test

.PHONY: clean
clean:
	rm -rf $(BUILDDIR)
