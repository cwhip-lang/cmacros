/*
 * src/arguments.cw — Argument-list parsing for Processor.
 *
 * Created: 2026-11-15
 * Author: Auto
 *
 * Changelog:
 *   2026-11-15  Initial file.
 */

/*
 * Parse a parenthesized comma-separated argument list.
 *
 * text is the source. open is the index of the opening parenthesis. Returns
 * the arguments, the index after the closing parenthesis, and whether the list
 * was valid. Quoted arguments are unquoted.
 */
Arguments Processor.parse_arguments(String text, int64 open) {
    list result = []
    int64 index = open + 1
    int64 valueStart = index
    int64 parens = 0
    int64 brackets = 0
    int64 braces = 0
    int64 quote = 0
    bool escaped = false
    bool finished = false
    while (index < text.length and not finished) {
        int64 current = byte(text, index)
        if (quote != 0) {
            if (escaped) {
                escaped = false
            }
            else {
                if (current == CHAR_BACKSLASH) {
                    escaped = true
                }
                else {
                    if (current == quote) {
                        quote = 0
                    }
                }
            }
        }
        else {
            if (current == CHAR_QUOTE or current == CHAR_APOSTROPHE) {
                quote = current
            }
            else {
                if (current == CHAR_LPAREN) {
                    parens = parens + 1
                }
                else {
                    if (current == CHAR_RPAREN) {
                        if (parens == 0 and brackets == 0 and braces == 0) {
                            String value = byte_span(
                                    text,
                                    valueStart,
                                    index).trim()
                            if (value.length > 0 or result.length > 0) {
                                if (not valid_argument_literal(value)) {
                                    return(Arguments([], open, false))
                                }
                                result.append(unquote(value))
                            }
                            index = index + 1
                            finished = true
                            continue
                        }
                        parens = parens - 1
                    }
                    else {
                        if (current == CHAR_LBRACKET) {
                            brackets = brackets + 1
                        }
                        else {
                            if (current == CHAR_RBRACKET) {
                                brackets = brackets - 1
                            }
                            else {
                                if (current == CHAR_LBRACE) {
                                    braces = braces + 1
                                }
                                else {
                                    if (current == CHAR_RBRACE) {
                                        braces = braces - 1
                                    }
                                    else {
                                        if (current == CHAR_COMMA
                                                and parens == 0
                                                and brackets == 0
                                                and braces == 0) {
                                            String value = byte_span(
                                                    text,
                                                    valueStart,
                                                    index).trim()
                                            if (not valid_argument_literal(
                                                    value)) {
                                                return(Arguments(
                                                        [], open, false))
                                            }
                                            result.append(unquote(value))
                                            valueStart = index + 1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        index = index + 1
    }

    if (not finished) {
        return(Arguments([], open, false))
    }
    if (quote != 0 or parens != 0 or brackets != 0 or braces != 0) {
        return(Arguments([], open, false))
    }
    return(Arguments(result, index, true))
}

/*
 * Accept a bare argument or a complete quoted literal.
 *
 * value is one trimmed argument. Returns true when it is not quoted, or when
 * the quotes decode and consume the whole value.
 */
bool Processor.valid_argument_literal(String value) {
    if (value.length > 0
            and (byte(value, 0) == CHAR_QUOTE
                    or byte(value, 0) == CHAR_APOSTROPHE)) {
        LiteralValue parsed = parse_literal(value, 0)
        return(parsed.valid and parsed.end == value.length)
    }
    return(true)
}

/*
 * Decode a quoted argument, leaving other text unchanged.
 *
 * value is one argument. Returns the decoded characters when the whole value
 * is one quoted literal, otherwise value itself.
 */
String Processor.unquote(String value) {
    if (value.length >= 2
            and ((byte(value, 0) == CHAR_QUOTE
                    and byte(value, value.length - 1) == CHAR_QUOTE)
                    or (byte(value, 0) == CHAR_APOSTROPHE
                            and byte(
                                    value,
                                    value.length - 1) == CHAR_APOSTROPHE))) {
        LiteralValue decoded = parse_literal(value, 0)
        if (decoded.valid) {
            return(decoded.value)
        }
    }

    return(value)
}
