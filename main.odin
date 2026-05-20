package main

import "core:os"
import "core:fmt"
import "core:strings"

main :: proc() {
	lexer: ^Lexer = new(Lexer)
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
}

TokenKind :: enum {
	Identifier,
	TypeDec,
	ParenOpen,
	ParenClose,
	BracketOpen,
	BracketClose,
	String,
	Int
}

TokenValue :: union {
	string,
	int
}

Token :: struct {
	kind: TokenKind,
	value: Maybe(TokenValue), 

	next: ^Token
}

Lexer :: struct {
	tokens_start: ^Token,
	tokens_end: ^Token,
	
	contents: string, 
	acc: [dynamic]u8 
}

LexerError :: enum {
	None,
	UnexpectedToken,
	FailedGettingString
}

lex :: proc(lexer: ^Lexer) -> (err: LexerError) {
	if len(lexer.contents) == 0 do return .None 

	first, ok := take_first(lexer) 
	if !ok do return .None

	switch first {
	case ':':
		pop_acc(lexer)	
		if !peek_equals(lexer, ':') do return .UnexpectedToken
		_, _ = take_first(lexer)
		push_token(lexer, { kind = .TypeDec, value = nil })
	case '(':
		pop_acc(lexer)	
		push_token(lexer, { kind = .ParenOpen, value = nil })
	case ')':
		pop_acc(lexer)	
		push_token(lexer, { kind = .ParenClose, value = nil })
	case '{':
		pop_acc(lexer)	
		push_token(lexer, { kind = .BracketOpen, value = nil })
	case '}':
		pop_acc(lexer)	
		push_token(lexer, { kind = .BracketClose, value = nil })
	case '"':
		value, ok := lex_string(lexer)	
		if !ok do return .FailedGettingString
		push_token(lexer, { kind = .String, value = value })
	case ' ': 
		pop_acc(lexer)	
	case '\t', '\n', '\r':
	case:
		append(&lexer.acc, first)
	}

	return lex(lexer) 
}

pop_acc :: proc(lexer: ^Lexer) {
	value := string(lexer.acc[:])
	if value != "" {
		push_token(lexer, { kind = .Identifier, value = strings.clone(string(lexer.acc[:])) })
		clear(&lexer.acc)
	}
}

lex_string :: proc(lexer: ^Lexer) -> (value: string, ok: bool) {
	acc_builder := strings.Builder {}
	strings.builder_init(&acc_builder)
	defer strings.builder_destroy(&acc_builder)

	first: u8
	first, ok = take_first(lexer)
	if !ok do return "", false 
	for first != '"' {
		strings.write_byte(&acc_builder, first)
		first, ok = take_first(lexer)
		if !ok do return "", false 
	}
	
	value = strings.clone(strings.to_string(acc_builder))
	return value, true
}

push_token :: proc(lexer: ^Lexer, token: Token) {
	token_ptr := new(Token)
	token_ptr^ = token
	token_ptr.next = nil

	if lexer.tokens_start == nil do lexer.tokens_start = token_ptr
	if lexer.tokens_end == nil do lexer.tokens_end = token_ptr
	else {
		lexer.tokens_end.next = token_ptr
		lexer.tokens_end = token_ptr
	}
}

take_first :: proc(lexer: ^Lexer) -> (first: u8, ok: bool) {
	if len(lexer.contents) == 0 do return ' ', false
	
	first = lexer.contents[0]
	lexer.contents = lexer.contents[1:]
	return first, true
}

peek_equals :: proc(lexer: ^Lexer, eq: u8) -> bool {
	if len(lexer.contents) == 0 do return false
	return lexer.contents[0] == eq
}
