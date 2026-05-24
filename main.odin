package main

import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {
	lexer := new(Lexer)
	defer free(lexer)

	lexer.acc = {}
	fmt.println(os.args)
	if len(os.args) < 2 {
		fmt.println("no file given")
		return
	}
	data, err := os.read_entire_file(os.args[1], context.allocator)
	if err != nil {
		fmt.println("Failed to read file", err)
		return
	}
	defer delete(data, context.allocator)

	contents := string(data)
	lexer.contents = strings.clone(contents)
	lexer.tokens_start = nil
	lexer.tokens_end = nil

	lexer_err := lex(lexer)
	if lexer_err != .None {
		fmt.println("Encountered lexer error", lexer_err)
	}

	next := lexer.tokens_start
	for next != nil {
		fmt.println(next)
		next = next.next
	}

	parser := new(Parser)
	defer free(parser)

	parser.current_token = lexer.tokens_start

	ast, parser_err := parse_root(parser, {})
	if parser_err != nil {
		//fmt.println(parser_err)
		fmt.println()

		err_tok := parser_err.(ParserError).token
		lines := strings.split(contents, "\n")

		if err_tok.row > 0 do fmt.println(lines[err_tok.row - 1])
		fmt.println(lines[err_tok.row])

		ptr, ptr_err := strings.right_justify("^", err_tok.col, " ")
		if ptr_err != nil do fmt.println("Padding error", ptr_err)
		fmt.println(ptr)
		fmt.println(parser_err.(ParserError).message, "\n")

		return
	}

	fmt.println(ast)
	llvm_gen(ast)
	//fmt.println(parser_err)
	//fmt.println(ast)
}
