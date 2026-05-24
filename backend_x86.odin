package main

import "core:crypto"
import "core:fmt"
import "core:os"
import "core:strings"

X86Backend :: struct {
	out:     [dynamic]string,
	strings: strings.Builder,
}

x86_gen :: proc(nodes: []AstNode) {
	backend := new(X86Backend)
	defer free(backend)

	backend.out = {}
	strings.builder_init(&backend.strings)
	defer strings.builder_destroy(&backend.strings)

	fmt.println("codegen")
	for node in nodes {
		fmt.println(node)
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
	fmt.println("test", backend.out)
	for i in backend.out {
		strings.write_string(&final, i)
	}
	out := strings.to_string(final)
	err := os.write_entire_file_from_string("mg.asm", out)
	if err != nil do fmt.println(err)
}

random_alphanumeric_except_first :: proc(n: int) -> string {
	chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

	result := make([]u8, n)
	defer delete(result)

	random_bytes := make([]u8, n)
	defer delete(random_bytes)

	crypto.rand_bytes(random_bytes)

	result[0] = 'a'
	for i in 1 ..< n {
		result[i] = chars[int(random_bytes[i]) % len(chars)]
	}

	return strings.clone(string(result))
}

x86_func_dec :: proc(backend: ^X86Backend, node: AstFunctionDeclaration) {
	builder: strings.Builder
	strings.builder_init(&builder)
	defer strings.builder_destroy(&builder)

	strings.write_string(&builder, node.identifier)
	strings.write_string(&builder, ":\n")
	
	label := x86_do_code_block(backend, node.code_block.nodes)

	strings.write_string(&builder, "call ")
	strings.write_string(&builder, label)
	strings.write_string(&builder, "\n")
	strings.write_string(&builder, "mov rax, 0\nret\n")

	out := backend.out
	append(&out, strings.clone(strings.to_string(builder)))
	backend.out = out
}

x86_do_code_block_unmanaged :: proc(backend: ^X86Backend, nodes: []AstNode, builder: ^strings.Builder) -> (label: string) {
	label = random_alphanumeric_except_first(16)
	strings.write_string(builder, label)
	strings.write_string(builder, ":\n")
	x86_code_block(backend, builder, nodes) 
	return label
}

x86_do_code_block :: proc(backend: ^X86Backend, nodes: []AstNode) -> (label: string) {
	builder: strings.Builder
	strings.builder_init(&builder)
	defer strings.builder_destroy(&builder)

	label = x86_do_code_block_unmanaged(backend, nodes, &builder)

	out := backend.out
	append(&out, strings.clone(strings.to_string(builder)))
	backend.out = out
	return label
}

x86_code_block :: proc(backend: ^X86Backend, builder: ^strings.Builder, nodes: []AstNode) {
	if len(nodes) == 0 do return
	node := nodes[0]

	#partial switch n in node {
	case AstFunctionCall:
		for arg in n.arguments {
			strings.write_string(builder, "mov rdi, ")
			strings.write_string(builder, x86_get_string_label(backend, arg))
			strings.write_string(builder, "\n")
		}

		strings.write_string(builder, "call ")
		strings.write_string(builder, n.identifier)
		strings.write_string(builder, "\n")
	case AstFor:
		strings.write_string(builder, "mov rbp, 10\n")	
		
		for_builder: strings.Builder
		strings.builder_init(&for_builder)
		defer strings.builder_destroy(&for_builder)

		label := x86_do_code_block_unmanaged(backend, n.code_block.nodes, &for_builder)
		strings.write_string(&for_builder, "dec rbp\njnz ")
		strings.write_string(&for_builder, label)
		strings.write_string(&for_builder, "\nmov rax, 0\nret\n")
		  
		out := backend.out
		append(&out, strings.clone(strings.to_string(for_builder)))
		backend.out = out
		
		strings.write_string(builder, "push rbp\n")
		strings.write_string(builder, "call ")
		strings.write_string(builder, label)
		strings.write_string(builder, "\n")
		strings.write_string(builder, "pop rbp\n")
	case AstReturn:
		strings.write_string(builder, "mov rax, 0\nret\n")
	}

	x86_code_block(backend, builder, nodes[1:])
}

x86_get_string_label :: proc(backend: ^X86Backend, node: AstValue) -> string {
	#partial switch n in node {
	case string:
		label := random_alphanumeric_except_first(16)
		strings.write_string(&backend.strings, label)
		strings.write_string(&backend.strings, ": db \"")
		strings.write_string(&backend.strings, n)
		strings.write_string(&backend.strings, "\",0\n")
		return label
	}
	fmt.println("", node)
	panic("string label idk")
}
