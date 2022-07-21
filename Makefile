MACHINE ?= $(shell uname -m)

ifeq ($(MACHINE),x86_64)
core := core/x86_64.s
as_flags := --64
ld_flags := -m elf_x86_64
else ifeq ($(MACHINE),i686)
core := core/i686.s
as_flags := --32
ld_flags := -m elf_i386
else
$(error Unsupported machine: $(MACHINE))
endif

BUILDDIR := build/$(MACHINE)

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
		as $(as_flags) -g -almnc=$(output).lst -o $(output).o ../../$(core) && \
		ld $(ld_flags) -o $(output) $(output).o

test: $(BUILDDIR)/boden_test
	@$(BUILDDIR)/boden_test

.PHONY: clean
clean:
	rm -rf build
