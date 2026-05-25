package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

LLVMBackend :: struct {
	out:     [dynamic]string,
	strings: strings.Builder,
}

llvm_gen :: proc(nodes: []AstNode) {
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
			llvm_func_dec(backend, n)
		}
	}

	final: strings.Builder
	defer strings.builder_destroy(&final)

	strings.builder_init(&final)
	strings.write_string(&final, "declare i32 @puts(ptr)\n")
	strings.write_string(&final, "declare i32 @printf(ptr, ...)\n")
	strings.write_string(&final, strings.to_string(backend.strings))
	fmt.println("test", backend.out)
	for i in backend.out {
		strings.write_string(&final, i)
	}
	out := strings.to_string(final)
	err := os.write_entire_file_from_string("mg.ll", out)
	if err != nil do fmt.println(err)
}

llvm_func_dec :: proc(backend: ^X86Backend, node: AstFunctionDeclaration) {
	builder: strings.Builder
	strings.builder_init(&builder)
	defer strings.builder_destroy(&builder)
	
	strings.write_string(&builder, "define void @")
	strings.write_string(&builder, node.identifier)
	strings.write_string(&builder, "() {\n")
	llvm_code_block(backend, &builder, node.code_block.nodes)
	strings.write_string(&builder, "}\n")

	out := backend.out
	append(&out, strings.clone(strings.to_string(builder)))
	backend.out = out
}

llvm_do_code_block :: proc(backend: ^X86Backend, nodes: []AstNode) {
	builder: strings.Builder
	strings.builder_init(&builder)
	defer strings.builder_destroy(&builder)

	llvm_code_block(backend, &builder, nodes)

	out := backend.out
	append(&out, strings.clone(strings.to_string(builder)))
	backend.out = out
}

llvm_code_block :: proc(backend: ^X86Backend, builder: ^strings.Builder, nodes: []AstNode) {
	if len(nodes) == 0 do return
	node := nodes[0]

	switch n in node {
	case AstFunctionDeclaration:
		panic("Can't declare function in codeblock")
	case AstFunctionCall:
		func_label := random_alphanumeric_except_first(16)
		func_builder: strings.Builder
		strings.builder_init(&func_builder)
		defer strings.builder_destroy(&func_builder)

		i := 0
		for arg in n.arguments {
			if i > 0 do strings.write_string(&func_builder, ", ")

			i += 1
			switch a in arg {
				case string:
					strings.write_string(&func_builder, "ptr @")
					strings.write_string(&func_builder, llvm_get_string_label(backend, arg))
				case int:
					panic("int is unhandled for function arguments")
				case AstIdentifier:
					strings.write_string(builder, fmt.tprintf("%%{}.{} = load i32, ptr %%{}\n", func_label, i, a.identifier))
					strings.write_string(&func_builder, fmt.tprintf("i32 %%{}.{}", func_label, i))
				case AstAdd:
					panic("Ast add unimplemented")
			}
		}
		
		strings.write_string(builder, "call i32 @")
		strings.write_string(builder, n.identifier)
		strings.write_string(builder, "(")
		
		strings.write_string(builder, strings.to_string(func_builder))	
		
		strings.write_string(builder, ")\n")
	case AstAssignVariable:
		fmt.println("reached assign var")

		#partial switch value in n.value {
			case string:
				buf: [4]byte
				strlen := strconv.write_int(buf[:], transmute(i64)len(n.value.(string)) + 1, 10)	

				strings.write_string(builder, 
					fmt.tprintf("%%{} = alloca [{} x i8]\nstore [{} x i8] c\"{}\\00\", ptr %%{}\n", n.identifier, strlen, strlen, value, n.identifier))
			case int:
				strings.write_string(builder, fmt.tprintf("%%{} = alloca i32\nstore i32 {}, ptr %%{}\n", n.identifier, value, n.identifier))
		}

			case AstFor:
		for_builder: strings.Builder
		strings.builder_init(&for_builder)
		defer strings.builder_destroy(&for_builder)

		for_loop_label := random_alphanumeric_except_first(16)

		strings.write_string(
			builder,
			fmt.tprintf(
				"%%{}.i = alloca i32\n" +
				"store i32 {}, ptr %%{}.i\n" +
				"br label %%{}_start\n" +
				"{}_start:\n" +
				"%%{}.val = load i32, ptr %%{}.i\n" +
				"%%{}.cmp = icmp eq i32 %%{}.val, {}\n" +
				"br i1 %%{}.cmp, label %%{}_exit, label %%{}\n" +
				"{}:\n" +
				"%%{}.old = load i32, ptr %%{}.i\n" +
				"%%{}.new = add i32 %%{}.old, 1\n" +
				"store i32 %%{}.new, ptr %%{}.i\n",
				for_loop_label,
				n.range_min,
				for_loop_label,
				for_loop_label,
				for_loop_label,
				for_loop_label,
				for_loop_label,
				for_loop_label,
				for_loop_label,
				n.range_max,
				for_loop_label,
				for_loop_label,
				for_loop_label,
				for_loop_label,
				for_loop_label,
				for_loop_label,
				for_loop_label,
				for_loop_label,
				for_loop_label,
				for_loop_label
			),
		)

		llvm_code_block(backend, builder, n.code_block.nodes)

		strings.write_string(
			builder,
			fmt.tprintf(
				"br label %%{}_start\n" +
				"{}_exit:\n",
				for_loop_label,
				for_loop_label
			),
		)

		out := backend.out
		append(&out, strings.clone(strings.to_string(for_builder)))
		backend.out = out

	case AstReturn:
		strings.write_string(builder, "ret void\n")
	}

	llvm_code_block(backend, builder, nodes[1:])
}

llvm_get_string_label :: proc(backend: ^X86Backend, node: AstValue) -> string {
	#partial switch n in node {
	case string:
		label := random_alphanumeric_except_first(16)
		strings.write_string(&backend.strings, "@")
		strings.write_string(&backend.strings, label)
		strings.write_string(&backend.strings, " = constant [")
	
		buf: [4]byte
		strlen := strconv.write_int(buf[:], transmute(i64)len(n) + 1, 10)

		strings.write_string(&backend.strings, strlen)
		strings.write_string(&backend.strings, " x i8] c\"")
		strings.write_string(&backend.strings, n)
		strings.write_string(&backend.strings, "\\00\"\n")
		return label
	}
	fmt.println("string label error", node)
	panic("string label idk")
}
