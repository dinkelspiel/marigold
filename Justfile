x86 PATH:
	echo $(rm mg.asm)
	odin run . -- {{ PATH }}
	nasm -f elf64 mg.asm -o program.o
	gcc -no-pie program.o 
	./a.out

llvm PATH:
	echo $(rm mg.ll)
	odin run . -- {{ PATH }}
	lli mg.ll	

asm:
	nasm -f elf64 program.asm -o program.o
	gcc -no-pie program.o 
	./a.out
