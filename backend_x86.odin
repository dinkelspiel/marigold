package main

import "core:strings"
import "core:fmt"
import "core:crypto"
import "core:os"

X86Backend :: struct {
	out: strings.Builder,
	strings: strings.Builder
}

x86_gen :: proc(nodes: []AstNode) {
	backend := new(X86Backend)
	defer free(backend)

	strings.builder_init(&backend.out)
	strings.builder_init(&backend.strings)	
	defer strings.builder_destroy(&backend.out)
	defer strings.builder_destroy(&backend.strings)

	for node in nodes {
		#partial switch n in node {
			case AstFunctionDeclaration:
				x86_func_dec(backend, n)
		}
	}

	final: strings.Builder
	defer strings.builder_destroy(&final)

	strings.builder_init(&final)
	strings.write_string(&final, "global main\nextern puts\n")
	strings.write_string(&final, strings.to_string(backend.strings))
	strings.write_string(&final, strings.to_string(backend.out))
	out := strings.to_string(final)
	err := os.write_entire_file_from_string("mg.asm", out)
	if err != nil do fmt.println(err)
}

random_alphanumeric_except_first :: proc(n: int) -> string {
	chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

	result := make([]u8, n)

	random_bytes := make([]u8, n)
	defer delete(random_bytes)

	crypto.rand_bytes(random_bytes)

	result[0] = 'a'
	for i in 1..<n {
		result[i] = chars[int(random_bytes[i]) % len(chars)]
	}

	return string(result)
}

x86_func_dec :: proc(backend: ^X86Backend, node: AstFunctionDeclaration) {
	strings.write_string(&backend.out, node.identifier)
	strings.write_string(&backend.out, ":\n")

	x86_code_block(backend, node.code_block.nodes)	
}

x86_code_block :: proc(backend: ^X86Backend, nodes: []AstNode) {
	if len(nodes) == 0 do return
	node := nodes[0]
	#partial switch n in node {
		case AstFunctionCall:
			for arg in n.arguments {
				strings.write_string(&backend.out, "mov rdi, ")
				strings.write_string(&backend.out, x86_get_string_label(backend, arg))
				strings.write_string(&backend.out, "\n")
			}

			strings.write_string(&backend.out, "call ")
			strings.write_string(&backend.out, n.identifier)
			strings.write_string(&backend.out, "\n")
		case AstReturn:
			strings.write_string(&backend.out, "mov rax, 0\nret")
	}

	x86_code_block(backend, nodes[1:])
}

x86_get_string_label :: proc(backend: ^X86Backend, node: AstValue) -> string {
	switch n in node {
		case string:
			label :=random_alphanumeric_except_first(16) 
			strings.write_string(&backend.strings, label)
			strings.write_string(&backend.strings, ": db \"")
			strings.write_string(&backend.strings, n)
			strings.write_string(&backend.strings, "\",0\n")
			return label
	}
	fmt.println("", node)
	panic("string label idk")
}
