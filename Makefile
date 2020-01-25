name := grund
modules := \
	modules/core.g \
	modules/extra.g \
	modules/assembler.g
main := main.g

ifeq ($(MAKECMDGOALS),test)
name := tgrund
modules += $(wildcard tests/*.g)
main := tmain.g
endif

$(name): $(name).o
	ld -o $@ $^

$(name).all: $(modules) $(main)
	cat $^ > $@

$(name).o: grund.s $(name).all
	cp $(name).all grund.g
	as -g -almnc=grund.lst -o $@ $<

test: tgrund
	@./tgrund
