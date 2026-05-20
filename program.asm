		global	main
		extern	puts

msg:	db		"Hello World!",0

printme:
		mov		rdi, msg
		call	puts
		mov		rax, 0
		ret

main:
		call	printme	
		mov		rax, 0
		ret
