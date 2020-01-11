name := grund
modules := $(wildcard modules/*.f)

ifeq ($(MAKECMDGOALS),test)
name := tgrund
modules += $(wildcard tests/*.f)
endif

$(name): $(name).o
	ld -o $@ $^

$(name).all: $(modules) main.f
	cat $^ > $@

$(name).o: grund.s $(name).all
	cp $(name).all grund.f
	as -g -almnc=grund.lst -o $@ $<

test: tgrund
	@./tgrund
