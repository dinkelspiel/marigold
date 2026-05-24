package main

import "core:fmt"

Parser :: struct {
	current_token: ^Token,
}

ParserErrorKind :: enum {
	AdvancedPastEOF,
	PeekedPastEOF,
	UnexpectedToken,
}

ParserError :: struct {
	kind:    ParserErrorKind,
	token:	 ^Token,
	message: string,
}

error :: proc(kind: ParserErrorKind, token: ^Token, message: string = "") -> ParserError {
	return {kind, token, message}
}

AstAssignVariable :: struct {
	identifier: string,
	value: AstValue
}

AstFunctionCall :: struct {
	identifier: string,
	arguments:  []AstValue,
}

AstCodeBlock :: struct {
	nodes: []AstNode,
}

AstFunctionDeclaration :: struct {
	identifier: string,
	code_block: AstCodeBlock,
}

AstReturn :: struct {}

AstFor :: struct {
	range_min: int,
	range_max: int,
	code_block: AstCodeBlock
}

AstIdentifier :: struct {
	identifier: string
}

AstValue :: union {
	string,
	int,
	AstIdentifier
}

AstNode :: union {
	AstFunctionCall,
	AstFunctionDeclaration,
	AstReturn,
	AstFor,
	AstAssignVariable
}

parse_root :: proc(
	parser: ^Parser,
	nodes: [dynamic]AstNode,
) -> (
	ast: []AstNode,
	err: Maybe(ParserError),
) {
	if parser.current_token == nil do return nodes[:], nil

	token: ^Token
	token, err = peek_n(parser, 0)
	if err != nil do return nil, err
	if token.kind != .Identifier do return nil, error(.UnexpectedToken, token, fmt.tprintf("expected identifier in root, found: %v", token.kind))

	followup: ^Token
	followup, err = peek_n(parser, 1)
	if err != nil do return nil, err
	if followup.kind != .TypeDec do return nil, error(.UnexpectedToken, followup, fmt.tprintf("expected :: after identifier in root found: %v", followup.kind))

	paren: ^Token
	paren, err = peek_n(parser, 2)
	if err != nil do return nil, err

	if paren.kind == .ParenOpen {
		func_dec, func_err := parse_function(parser)
		if func_err != nil do return nil, func_err

		next_nodes := nodes
		append(&next_nodes, AstNode(func_dec.(AstFunctionDeclaration)))

		return parse_root(parser, next_nodes)
	}

	return nodes[:], nil
}

parse_function :: proc(
	parser: ^Parser,
) -> (
	node: Maybe(AstFunctionDeclaration),
	err: Maybe(ParserError),
) {
	identifier: ^Token
	identifier, err = advance(parser)
	if err != nil do return nil, err

	_, err = advance_assert(parser, .TypeDec)
	if err != nil do return nil, err

	if parser.current_token.kind != .ParenOpen {
		return nil, error(
			.UnexpectedToken,
			parser.current_token,
			fmt.tprintf(
				"expected ( at start of function arguments, found: %v",
				parser.current_token,
			),
		)
	}

	_, err = advance_assert(parser, .ParenOpen)
	if err != nil do return nil, err

	_, err = advance_assert(parser, .ParenClose)
	if err != nil do return nil, err

	_, err = advance_assert(parser, .BracketOpen)
	if err != nil do return nil, err

	block, block_err := parse_block(parser, {})
	if block_err != nil do return nil, block_err

	fmt.println("parsed function")
	fmt.println(parser.current_token)

	return AstFunctionDeclaration {
			identifier = identifier.value.(TokenValue).(string),
			code_block = block.(AstCodeBlock),
		},
		nil
}

parse_block :: proc(
	parser: ^Parser,
	nodes: [dynamic]AstNode,
) -> (
	node: Maybe(AstCodeBlock),
	err: Maybe(ParserError),
) {
	fmt.println("block")
	fmt.println(parser.current_token)
	#partial switch parser.current_token.kind {
	case .Identifier:
		if parser.current_token.next.kind == .ParenOpen {
			func_call, func_err := parse_function_call(parser)
			if func_err != nil do return nil, func_err

			next_nodes := nodes
			_, _ = append(&next_nodes, func_call.(AstFunctionCall))
			return parse_block(parser, next_nodes)
		} else if parser.current_token.next.kind == .AssignInfer {
			identifier := parser.current_token.value.(TokenValue).(string)
			advance(parser)
			advance(parser)
			value := parser.current_token.value.(TokenValue).(string)
			advance(parser)

			next_nodes := nodes
			_, _ = append(&next_nodes, AstAssignVariable {
				identifier,
				value
			})
			return parse_block(parser, next_nodes)
		} else do return nil, error(
			.UnexpectedToken,
			parser.current_token,
			fmt.tprintf("expected ( for function call, found %v", parser.current_token.next),
		)
	case .Return:
		advance(parser)

		next_nodes := nodes
		_, _ = append(&next_nodes, AstReturn{})
		return parse_block(parser, next_nodes)
	case .For:
		advance(parser)

		range_min, range_max: ^Token 
		range_min, err = advance_assert(parser, TokenKind.Int)
		if err != nil do return nil, err
		_, err := advance_assert(parser, TokenKind.Range)
		if err != nil do return nil, err
		range_max, err = advance_assert(parser, TokenKind.Int)
		if err != nil do return nil, err

		if parser.current_token.kind == .BracketOpen {
			advance(parser)

			code_block, cb_err := parse_block(parser, {})
			if cb_err != nil do return nil, cb_err

			next_nodes := nodes
			_, _ = append(&next_nodes, AstNode(AstFor { 
				range_min = range_min.value.(TokenValue).(int), 
				range_max = range_max.value.(TokenValue).(int), 
				code_block = code_block.(AstCodeBlock) 
			}))
			return parse_block(parser, next_nodes)
		}

	case .BracketClose:
		node = AstCodeBlock{nodes[:]}
		advance(parser)
		return node, nil
	case:
		return nil, error(
			.UnexpectedToken,
			parser.current_token,
			fmt.tprintf(
				"expected identifier in block root, found %v",
				parser.current_token.kind,
			),
		)
	}

	panic("progressed to end of parse block")
}

parse_function_call :: proc(
	parser: ^Parser,
) -> (
	node: Maybe(AstFunctionCall),
	err: Maybe(ParserError),
) {
	identifier: ^Token
	identifier, err = advance_assert(parser, .Identifier)
	if err != nil do return nil, err

	_, err = advance_assert(parser, .ParenOpen)
	if err != nil do return nil, err

	arguments, arg_err := parse_function_call_args(parser, {})
	if arg_err != nil do return nil, arg_err

	node = AstFunctionCall {
		identifier = identifier.value.(TokenValue).(string),
		arguments  = arguments,
	}
	return node, nil
}

parse_function_call_args :: proc(
	parser: ^Parser,
	acc: [dynamic]AstValue,
) -> (
	args: []AstValue,
	err: Maybe(ParserError),
) {
	token: ^Token
	token, err = advance(parser)
	if err != nil do return nil, err
	if token.kind == .ParenClose do return acc[:], nil

	next := acc
	
	if token.kind == .String || token.kind == .Int {
		switch n in token.value.(TokenValue) {
			case int:
				append(&next, AstValue(n))
			case string:
				append(&next, AstValue(n))
		}
	} else if token.kind == .Identifier {
		append(&next, AstIdentifier { identifier = token.value.(TokenValue).(string) })  
	} else {
		return nil, error(.UnexpectedToken, token, "Expected string or int")
	}
	return parse_function_call_args(parser, next)
}

advance :: proc(parser: ^Parser) -> (token: ^Token, err: Maybe(ParserError)) {
	token = parser.current_token
	parser.current_token = parser.current_token.next
	return token, nil
}

peek_n :: proc(parser: ^Parser, n: int) -> (token: ^Token, err: Maybe(ParserError)) {
	next := parser.current_token
	for i in 0 ..< n {
		if next == nil || next.next == nil do return nil, error(.PeekedPastEOF, next)
		next = next.next
	}

	return next, nil
}

advance_assert :: proc(
	parser: ^Parser,
	assert_token: TokenKind,
) -> (
	token: ^Token,
	err: Maybe(ParserError),
) {
	token, err = advance(parser)
	if err != nil do return nil, err
	if token.kind != assert_token {
		return nil, error(
			.UnexpectedToken,
			token,
			fmt.tprintf("expected '%v', found %v", assert_token, token),
		)
	}
	return token, nil
}
