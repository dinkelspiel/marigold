package main

import "core:fmt"

Parser :: struct {
	current_token: ^Token
}

ParserErrorKind :: enum {
	None,
	AdvancedPastEOF,
	PeekedPastEOF,
	UnexpectedToken
}

ParserError :: struct {
	kind: ParserErrorKind,
	message: string
}

error :: proc(kind: ParserErrorKind, message: string = "") -> ParserError {
	return { kind, message };
}

AstFunctionCall :: struct {
	identifier: string,
	arguments: []AstValue
}

AstCodeBlock :: struct {
	nodes: []AstNode
}

AstFunctionDeclaration :: struct {
	identifier: string,
	code_block: AstCodeBlock
}

AstReturn :: struct {
	
}

AstValue :: union {
	string
}

AstNode :: union {
	AstFunctionCall,
	AstFunctionDeclaration,
	AstReturn
}

parse_root :: proc(parser: ^Parser, nodes: [dynamic]AstNode) -> (ast: []AstNode, err: ParserError) {
	token: ^Token
	token, err = peek_n(parser, 0)	
	if err.kind != .None do return nil, err 
	if token.kind != .Identifier do return nil, error(.UnexpectedToken, fmt.tprintf("expected identifier in root, found: %v", token.kind))

	followup: ^Token
	followup, err = peek_n(parser, 1)
	if err.kind != .None do return nil, err 
	if followup.kind != .TypeDec do return nil, error(.UnexpectedToken, fmt.tprintf("expected :: after identifier in root found: %v", followup.kind))

	paren: ^Token
	paren, err = peek_n(parser, 2)
	if paren.kind == .ParenOpen {
		func_dec, func_err := parse_function(parser)
		fmt.println(func_dec)

		if func_err.kind != .None do return nil, func_err

		next_nodes := nodes
		_, _ = append(&next_nodes, AstNode(func_dec.(AstFunctionDeclaration)))
		return next_nodes[:], error(.None)
	}

	return nodes[:], error(.None)

	//return parse_root(parser, nodes)
}

parse_function :: proc(parser: ^Parser) -> (node: Maybe(AstFunctionDeclaration), err: ParserError) {
	identifier: ^Token
	identifier, err = advance(parser) 
	if err.kind != .None do return nil, err
	
	_, err = advance_assert(parser, .TypeDec)
	if err.kind != .None do return nil, err

	if parser.current_token.kind != .ParenOpen {
		return nil, error(.UnexpectedToken, fmt.tprintf("expected ( at start of function arguments, found: %v", parser.current_token))
	}

	_, err = advance_assert(parser, .ParenOpen)
	if err.kind != .None do return nil, err

	_, err = advance_assert(parser, .ParenClose)	
	if err.kind != .None do return nil, err

	_, err = advance_assert(parser, .BracketOpen)
	if err.kind != .None do return nil, err

	block, block_err := parse_block(parser, {}) 
	if block_err.kind != .None do return nil, block_err

	return AstFunctionDeclaration { identifier = identifier.value.(string), code_block = block.(AstCodeBlock) }, error(.None)
}

parse_block :: proc(parser: ^Parser, nodes: [dynamic]AstNode) -> (node: Maybe(AstCodeBlock), err: ParserError) {
	#partial switch parser.current_token.kind {
		case .Identifier:
			if parser.current_token.next.kind == .ParenOpen {
				func_call, func_err := parse_function_call(parser)	
				if func_err.kind != nil do return nil, func_err

				next_nodes := nodes
				_, _ = append(&next_nodes, AstNode(func_call.(AstFunctionCall)))
				return parse_block(parser, next_nodes)
			} else do return nil, error(.UnexpectedToken, fmt.tprintf("expected ( for function call, found %v", parser.current_token.next) )
		case .Return:
			advance(parser)

			next_nodes := nodes
			_, _ = append(&next_nodes, AstReturn {})
			return parse_block(parser, next_nodes)
		case .BracketClose:
			node = AstCodeBlock { nodes[:] }
			advance(parser)
			return node, error(.None)
		case: return nil, error(.UnexpectedToken, fmt.tprintf("expected identifier in block root, found %v", parser.current_token.next.kind))
	}

	panic("progressed to end of parse block")
}

parse_function_call :: proc(parser: ^Parser) -> (node: Maybe(AstFunctionCall), err: ParserError) {
	identifier: ^Token
	identifier, err = advance_assert(parser, .Identifier)
	if err.kind != .None do return nil, err

	_, err = advance_assert(parser, .ParenOpen)
	if err.kind != .None do return nil, err

	value: ^Token
	value, err = advance_assert(parser, .String)
	if err.kind != .None do return nil, err

	value_node: AstValue = value.value.(string)
	
	_, err = advance_assert(parser, .ParenClose)
	if err.kind != .None do return nil, err

	arguments := [dynamic]AstValue {}
	append(&arguments, value_node)

	node = AstFunctionCall { identifier = identifier.value.(string), arguments = arguments[:] }
	return node, error(.None)	
}

advance :: proc(parser: ^Parser) -> (token: ^Token, err: ParserError) {
	token = parser.current_token
	if parser.current_token.next == nil do return nil, error(.AdvancedPastEOF)
	parser.current_token = parser.current_token.next
	return token, error(.None)
}

peek_n :: proc(parser: ^Parser, n: int) -> (token: ^Token, err: ParserError) {
	next := parser.current_token
	for i in 0..<n {
		if next == nil || next.next == nil do return nil, error(.PeekedPastEOF)
		next = next.next
	}

	return next, error(.None)
}

advance_assert :: proc(parser: ^Parser, assert_token: TokenKind) -> (token: ^Token, err: ParserError) {
	token, err = advance(parser)
	if err.kind != .None do return nil, err 
	if token.kind != assert_token {
		return nil, error(.UnexpectedToken, fmt.tprintf("expected '%v', found %v", assert_token, token))
	}
	return token, error(.None)
}
