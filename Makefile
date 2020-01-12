name := grund
modules := $(wildcard modules/*.g)

ifeq ($(MAKECMDGOALS),test)
name := tgrund
modules += $(wildcard tests/*.g)
endif

$(name): $(name).o
	ld -o $@ $^

$(name).all: $(modules) main.g
	cat $^ > $@

$(name).o: grund.s $(name).all
	cp $(name).all grund.g
	as -g -almnc=grund.lst -o $@ $<

test: tgrund
	@./tgrund
