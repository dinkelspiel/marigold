		global	main
		extern	puts

msg:	db		"Hello World!",0

printme:
		; for
		mov		rbp, 10  ; index
		call	loop_abc ; codeblock
		; endfor

		mov		rax, 0
		ret

loop_abc:
		mov		rdi, msg
		call	puts

		; i--
		dec		rbp
		jnz		loop_abc ; continue if i != 0 || i > 0	
		
		mov		rax, 0
		ret

main:
		call	printme	

		mov		rax, 0
		ret

