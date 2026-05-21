package main

import "core:os"
import "core:fmt"

main :: proc() {
	lexer := new(Lexer)
	defer free(lexer)

	lexer.acc = {}
	data, err := os.read_entire_file("./hw.mg", context.allocator)
	if err != nil {
		fmt.println("Failed to read file", err)
		return
	}
	defer delete(data, context.allocator)
	
	lexer.contents = string(data)
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
	
	x86_gen(ast)
	//fmt.println(parser_err)
	//fmt.println(ast)
}




