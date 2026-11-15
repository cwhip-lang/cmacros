/*
 * src/condition_lex.cw — Conditional token and operator scan for Processor.
 *
 * Created: 2026-11-15
 * Author: Auto
 *
 * Changelog:
 *   2026-11-15  Initial file.
 */

/*
 * Report whether a condition operand is a bare macro name.
 *
 * expression is the operand text. Returns true when it is a name and not a
 * number, a boolean word, or an @ reference.
 */
bool Processor.is_definedness_operand(String expression) {
    String value = expression.trim()
    if (value.length == 0 or value.startsWith("@")) {
        return(false)
    }
    if (decimal_number(value)) {
        return(false)
    }
    String upper = value.toUpper()
    if (upper.equals("TRUE") or upper.equals("FALSE")) {
        return(false)
    }
    if (name_start(byte(value, 0)) and name_end(value, 0) == value.length) {
        return(true)
    }
    return(false)
}

/*
 * Report whether a condition operand is an @ reference.
 *
 * expression is the operand text. Returns true when the trimmed text starts
 * with @.
 */
bool Processor.is_at_operand(String expression) {
    return(expression.trim().startsWith("@"))
}

/*
 * Report whether an index is outside a name token.
 *
 * text is the expression. index is the byte offset. Returns true at either end
 * of the text and on space or a parenthesis.
 */
bool Processor.word_boundary(String text, int64 index) {
    if (index < 0 or index >= text.length) {
        return(true)
    }
    int64 value = byte(text, index)
    return(space(value) or value == CHAR_LPAREN or value == CHAR_RPAREN)
}

/*
 * Return the precedence of a condition operator.
 *
 * operator is the token, including a word form. Returns PRIORITY_OR,
 * PRIORITY_AND, PRIORITY_EQUAL, PRIORITY_ORDER, or PRIORITY_NONE.
 */
int64 Processor.operator_priority(String operator) {
    String upper = operator.toUpper()
    if (upper.equals("OR") or operator.equals("||")) {
        return(PRIORITY_OR)
    }
    if (upper.equals("AND") or operator.equals("&&")) {
        return(PRIORITY_AND)
    }
    if (upper.equals("==")
            or operator.equals("!=")
            or upper.equals("EQ")
            or upper.equals("NEQ")) {
        return(PRIORITY_EQUAL)
    }
    if (operator.equals("<")
            or operator.equals(">")
            or operator.equals("<=")
            or operator.equals(">=")
            or upper.equals("LT")
            or upper.equals("GT")
            or upper.equals("LTE")
            or upper.equals("GTE")) {
        return(PRIORITY_ORDER)
    }
    return(PRIORITY_NONE)
}

/*
 * Read the condition operator that starts at an index.
 *
 * text is the expression. index is the start byte. Returns the operator text,
 * or an empty string when no operator starts there. Word operators require a
 * boundary on each side.
 */
String Processor.operator_at(String text, int64 index) {
    if (index + 1 < text.length) {
        String pair = byte_span(text, index, index + 2)
        if (pair.equals("||")
                or pair.equals("&&")
                or pair.equals("==")
                or pair.equals("!=")
                or pair.equals("<=")
                or pair.equals(">=")) {
            return(pair)
        }
    }

    int64 remaining = text.length - index
    if (remaining >= 3) {
        String word = byte_span(text, index, index + 3).toUpper()
        if ((word.equals("AND")
                or word.equals("NEQ")
                or word.equals("LTE")
                or word.equals("GTE"))
                and word_boundary(text, index - 1)
                and word_boundary(text, index + 3)) {
            return(word)
        }
    }

    if (remaining >= 2) {
        String word = byte_span(text, index, index + 2).toUpper()
        if ((word.equals("OR")
                or word.equals("EQ")
                or word.equals("LT")
                or word.equals("GT"))
                and word_boundary(text, index - 1)
                and word_boundary(text, index + 2)) {
            return(word)
        }
    }

    if (byte_span(text, index, index + 1).equals("<")
            or byte_span(text, index, index + 1).equals(">")) {
        return(byte_span(text, index, index + 1))
    }
    return("")
}

/*
 * Find the rightmost condition operator of one precedence outside parentheses.
 *
 * expression is the text. wantedPriority is PRIORITY_OR, PRIORITY_AND,
 * PRIORITY_EQUAL, or PRIORITY_ORDER. Returns the operator and its index, or an
 * operator with index -1.
 */
Operator Processor.find_operator(String expression, int64 wantedPriority) {
    int64 parens = 0
    int64 index = 0
    int64 quote = 0
    bool escaped = false
    Operator found = Operator(-1, "")
    while (index < expression.length) {
        int64 current = byte(expression, index)
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
                        parens = parens - 1
                    }
                    else {
                        if (parens == 0) {
                            String operator = operator_at(expression, index)
                            if (operator_priority(
                                    operator) == wantedPriority) {
                                found = Operator(index, operator)
                            }
                        }
                    }
                }
            }
        }
        index = index + 1
    }

    return(found)
}

/*
 * Report whether one parenthesis pair wraps the whole expression.
 *
 * expression is the text. Returns true only when it starts and ends with a
 * pair that closes at the last byte.
 */
bool Processor.wraps_whole_expression(String expression) {
    if (expression.length < 2
            or byte(expression, 0) != CHAR_LPAREN
            or byte(expression, expression.length - 1) != CHAR_RPAREN) {
        return(false)
    }

    int64 depth = 0
    int64 index = 0
    int64 quote = 0
    bool escaped = false
    while (index < expression.length) {
        int64 current = byte(expression, index)
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
                    depth = depth + 1
                }
                else {
                    if (current == CHAR_RPAREN) {
                        depth = depth - 1
                        if (depth == 0 and index < expression.length - 1) {
                            return(false)
                        }
                    }
                }
            }
        }
        index = index + 1
    }

    return(depth == 0)
}
