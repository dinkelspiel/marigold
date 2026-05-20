run:
	nasm -f elf64 program.asm -o program.o
	gcc -no-pie program.o 
	./a.out
