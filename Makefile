forth: forth.o
	ld -o forth forth.o

forth.o: forth.s
	as -g -almnc=forth.lst -o forth.o forth.s
