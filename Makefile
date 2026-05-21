run:
	nasm -f elf64 mg.asm -o program.o
	gcc -no-pie program.o 
	./a.out
