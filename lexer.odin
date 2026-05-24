package main

import "core:fmt"
import "core:strings"
import "core:strconv"

TokenKind :: enum {
	Identifier,
	TypeDec,
	ParenOpen,
	ParenClose,
	BracketOpen,
	BracketClose,
	String,
	Int,
	Return,
	For,
	Range,
	AssignInfer
}

TokenValue :: union {
	int,
	string
}

Token :: struct {
	kind:  TokenKind,
	value: Maybe(TokenValue),
	col:   int,
	row:   int,
	next:  ^Token,
}

Lexer :: struct {
	tokens_start: ^Token,
	tokens_end:   ^Token,
	current_col:  int,
	current_row:  int,
	contents:     string,
	acc:          [dynamic]u8,
}

LexerError :: enum {
	None,
	UnexpectedToken,
	FailedGettingString,
}

lex :: proc(lexer: ^Lexer) -> (err: LexerError) {
	if len(lexer.contents) == 0 do return .None

	first, ok := take_first(lexer)
	if !ok do return .None

	switch first {
	case ':':
		if peek_equals(lexer, ':') {
			pop_acc(lexer)
			take_first(lexer)

			push_token(
				lexer,
				{kind = .TypeDec, value = nil, col = lexer.current_col, row = lexer.current_row},
			)
		} else if peek_equals(lexer, '=') {
			pop_acc(lexer)
			take_first(lexer)

			push_token(
				lexer,
				{kind = .AssignInfer, value = nil, col = lexer.current_col, row = lexer.current_row},
			)
		} else do return .UnexpectedToken
	case '.':
		if !peek_equals(lexer, '.') do return .UnexpectedToken
		pop_acc(lexer)
		take_first(lexer)

		push_token(
			lexer,
			{kind = .Range, value = nil, col = lexer.current_col, row = lexer.current_row},
		)
	case '(':
		pop_acc(lexer)
		push_token(
			lexer,
			{kind = .ParenOpen, value = nil, col = lexer.current_col, row = lexer.current_row},
		)
	case ')':
		pop_acc(lexer)
		push_token(
			lexer,
			{kind = .ParenClose, value = nil, col = lexer.current_col, row = lexer.current_row},
		)
	case '{':
		pop_acc(lexer)
		push_token(
			lexer,
			{kind = .BracketOpen, value = nil, col = lexer.current_col, row = lexer.current_row},
		)
	case '}':
		pop_acc(lexer)
		push_token(
			lexer,
			{kind = .BracketClose, value = nil, col = lexer.current_col, row = lexer.current_row},
		)
	case '"':
		value, ok := lex_string(lexer)
		if !ok do return .FailedGettingString
		push_token(
			lexer,
			{
				kind = .String,
				value = value,
				col = lexer.current_col - len(value),
				row = lexer.current_row,
			},
		)
		lexer.current_col += len(value)
	case ' ':
		pop_acc(lexer)
	case '\n':
		lexer.current_col = 0
		lexer.current_row += 1
	case '\r':
		lexer.current_col = 0
		lexer.current_row += 1
		take_first(lexer)
	case '\t':
	case:
		append(&lexer.acc, first)
	}

	lexer.current_col += 1
	return lex(lexer)
}

pop_acc :: proc(lexer: ^Lexer) {
	value := string(lexer.acc[:])
	if value != "" {
		acc := strings.clone(string(lexer.acc[:]))
		if acc == "return" do push_token(lexer, {kind = .Return, value = "", col = lexer.current_col - len(acc), row = lexer.current_row})
		else if acc == "for" do push_token(lexer, {kind = .For, value = "", col = lexer.current_col - len(acc), row = lexer.current_row})
		else {
			intval, ok := strconv.parse_int(acc, 10)
			if ok do push_token(lexer, {kind = .Int, value = intval, col = lexer.current_col - len(acc), row = lexer.current_row})
			else do push_token(lexer, {kind = .Identifier, value = acc, col = lexer.current_col - len(acc), row = lexer.current_row})
		}

		clear(&lexer.acc)
	}
}

lex_string :: proc(lexer: ^Lexer) -> (value: string, ok: bool) {
	acc_builder := strings.Builder{}
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
