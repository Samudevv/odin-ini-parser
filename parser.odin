package ini

import "core:strings"

// INI is a map from section to a map from key to values.
// Pairs defined before the first section are put into the "" key: INI[""].
INI :: map[string]map[string]string

ini_delete :: proc(i: ^INI) {
    for k, v in i {
        for kk, vv in v {
            delete(kk)
            delete(vv)
        }

        delete(k)
        delete(v)
    }

    delete(i^)
}

ParseErr :: enum {
    EOF, // Probably not an error (returned when ok).
    IllegalToken,
    KeyWithoutEquals,
    ValueWithoutKey,
    UnexpectedEquals,
}

ParseResult :: struct {
    err: ParseErr,
    pos: Pos,
}

// Parser parses the tokens from the lexer into the ini map.
Parser :: struct {
    lexer:        ^Lexer,
    ini:          ^INI,
    curr_section: ^map[string]string,
}

make_parser :: proc(l: ^Lexer, ini: ^INI) -> Parser {
    p: Parser
    p.lexer = l
    p.ini = ini

    if !("" in p.ini) {
        p.ini[""] = map[string]string{}
    }
    p.curr_section = &p.ini[""]

    return p
}

parse_into :: proc(data: []byte, ini: ^INI) -> ParseResult {
    l := make_lexer(data)
    p := make_parser(&l, ini)
    res := parser_parse(&p)
    return res
}

parse :: proc(data: []byte) -> (INI, ParseResult) {
    ini: INI
    res := parse_into(data, &ini)
    if res.err != .EOF {
        ini_delete(&ini)
    }
    return ini, res
}

parser_parse :: proc(using p: ^Parser) -> ParseResult {
    for t := lexer_next(lexer);; t = lexer_next(lexer) {
        if res, ok := parser_parse_token(p, t).?; ok {
            return res
        }
    }
}

@(private = "file")
parser_parse_token :: proc(using p: ^Parser, t: Token) -> Maybe(ParseResult) {
    switch t.type {
    case .Illegal:
        return ParseResult{.IllegalToken, t.pos}
    case .Key:
        assignment := lexer_next(lexer)
        if assignment.type != .Assign {
            return ParseResult{.KeyWithoutEquals, t.pos}
        }

        key := strings.clone(strings.to_lower(string(t.value)))

        value := lexer_next(lexer)
        if value.type != .Value {
            // No value, value is empty string.
            curr_section[key] = ""
            return parser_parse_token(p, value)
        }

        curr_section[key] = strings.clone(string(value.value))
    case .Section:
        #no_bounds_check no_brackets := t.value[1:len(t.value) - 1]
        key := strings.to_lower(string(no_brackets))
        if !(string(key) in curr_section) {
            ini[strings.clone(key)] = map[string]string{}
        }
        curr_section = &ini[key]
    case .Value:
        return ParseResult{.ValueWithoutKey, t.pos}
    case .Assign:
        return ParseResult{.UnexpectedEquals, t.pos}
    // Ignoring comments.
    case .Comment:
    case .EOF:
        return ParseResult{.EOF, t.pos}
    }

    return nil
}

