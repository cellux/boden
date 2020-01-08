forth: forth.o
	ld -o forth forth.o

forth.o: forth.s forth.f
	as -g -almnc=forth.lst -o forth.o forth.s

test: forth
	@./forth
