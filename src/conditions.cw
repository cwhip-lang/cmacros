/*
 * src/conditions.cw — Conditional expression evaluation for Processor.
 *
 * Created: 2026-10-30
 * Author: chuck
 *
 * Changelog:
 *   2026-10-30  Initial file.
 *   2026-11-15  Apply the shared Cwhip coding standard.
 */

/*
 * Report a conditional-expression failure at the saved location.
 *
 * message explains the failure. Returns nothing. The location is
 * conditionFile, conditionLine, and conditionColumn.
 */
void Processor.condition_error(String message) {
    report(
            CODE_CONDITION,
            conditionFile,
            conditionLine,
            conditionColumn,
            message)
}

/*
 * Evaluate one conditional expression.
 *
 * expression is the text. recursion is the current nesting depth. Returns the
 * boolean result. A malformed expression is reported and returns false.
 */
bool Processor.eval_condition(String expression, int64 recursion) {
    if (recursion > LIMIT_NESTING) {
        condition_error("conditional expression nesting limit (128) exceeded")
        return(false)
    }
    String value = expression.trim()
    if (value.length == 0) {
        condition_error("empty conditional expression or operand")
        return(false)
    }

    int64 nesting = 0
    int64 scan = 0
    int64 quote = 0
    bool escaped = false
    while (scan < value.length) {
        int64 current = byte(value, scan)
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
                    nesting = nesting + 1
                }
                else {
                    if (current == CHAR_RPAREN) {
                        nesting = nesting - 1
                        if (nesting < 0) {
                            condition_error(
                                    "unbalanced parentheses in conditional expression")
                            return(false)
                        }
                    }
                }
            }
        }
        scan = scan + 1
    }

    if (nesting != 0) {
        condition_error("unbalanced parentheses in conditional expression")
        return(false)
    }
    while (wraps_whole_expression(value)) {
        value = byte_span(value, 1, value.length - 1).trim()
    }
    Operator operator = find_operator(value, PRIORITY_OR)
    if (operator.index >= 0) {
        bool left = eval_condition(byte_span(
                value, 0, operator.index), recursion
                + 1)
        bool right = eval_condition(byte_span(value, operator.index
                + operator.name.length, value.length), recursion
                + 1)
        return(left or right)
    }
    operator = find_operator(value, PRIORITY_AND)
    if (operator.index >= 0) {
        bool left = eval_condition(byte_span(
                value, 0, operator.index), recursion
                + 1)
        bool right = eval_condition(byte_span(value, operator.index
                + operator.name.length, value.length), recursion
                + 1)
        return(left and right)
    }
    operator = find_operator(value, PRIORITY_EQUAL)
    if (operator.index >= 0) {
        String left = byte_span(value, 0, operator.index).trim()
        String right = byte_span(value, operator.index
                + operator.name.length, value.length).trim()
        if (left.length == 0 or right.length == 0) {
            condition_error("comparison operator requires two operands")
            return(false)
        }
        return(compare_condition(left, right, operator.name))
    }
    operator = find_operator(value, PRIORITY_ORDER)
    if (operator.index >= 0) {
        String left = byte_span(value, 0, operator.index).trim()
        String right = byte_span(value, operator.index
                + operator.name.length, value.length).trim()
        if (left.length == 0 or right.length == 0) {
            condition_error("comparison operator requires two operands")
            return(false)
        }
        return(compare_condition(left, right, operator.name))
    }
    if (value.startsWith("!")) {
        if (value.length == 1) {
            condition_error("unary ! requires an operand")
            return(false)
        }
        return(not eval_condition(byte_span(value, 1, value.length), recursion
                + 1))
    }
    if (value.toUpper().startsWith("NOT ")) {
        return(not eval_condition(byte_span(value, 4, value.length), recursion
                + 1))
    }
    if (value.toUpper().equals("TRUE")) {
        return(true)
    }
    if (value.toUpper().equals("FALSE")) {
        return(false)
    }
    if (value.startsWith("@")) {
        return(at_reference_defined_nonempty(value, recursion + 1))
    }
    if (decimal_number(value)) {
        return(value_truth(value))
    }
    if (value.length > 0
            and name_start(byte(value, 0))
            and name_end(value, 0) == value.length) {
        return(find_macro(value) != null)
    }
    condition_error("invalid token in conditional expression")
    return(false)
}

/*
 * Report whether an @ reference names a macro whose expansion is non-empty.
 *
 * expression is the @ reference. recursion is the nesting depth. Returns false
 * when the name is missing, the expansion fails, or the trimmed expansion is
 * empty.
 */
bool Processor.at_reference_defined_nonempty(
        String expression,
        int64 recursion) {
    String value = expression.trim()
    int64 end = name_end(value, 1)
    if (end == 1) {
        condition_error("expected a macro name after @")
        return(false)
    }
    String name = byte_span(value, 1, end)
    Macro macro = find_macro(name)
    if (macro == null) {
        return(false)
    }
    String expanded = resolve_condition_value(value, recursion)
    if (failed) {
        return(false)
    }
    return(expanded.length > 0)
}

/*
 * Expand a condition operand to comparison text.
 *
 * expression is an @ reference, a decimal, or a bare name. recursion is the
 * nesting depth. Returns the expanded text, a decimal unchanged, 1 or 0 for a
 * bare name, or an empty string after a reported failure.
 */
String Processor.resolve_condition_value(String expression, int64 recursion) {
    String value = expression.trim()
    if (value.startsWith("@")) {
        int64 end = name_end(value, 1)
        if (end == 1) {
            condition_error("expected a macro name after @")
            return("")
        }
        String name = byte_span(value, 1, end)
        Macro macro = find_macro(name)
        int64 cursor = skip_horizontal(value, end)
        list arguments = []
        int64 afterReference = end
        if (cursor < value.length) {
            if (byte(value, cursor) != CHAR_LPAREN
                    or macro == null
                    or not macro.functionLike) {
                condition_error(
                        "invalid text after macro reference in conditional expression")
                return("")
            }
            Arguments parsed = parse_arguments(value, cursor)
            if (not parsed.valid or parsed.end != value.length) {
                condition_error(
                        "invalid macro argument list in conditional expression")
                return("")
            }
            arguments = parsed.values
            afterReference = parsed.end
        }
        else {
            if (macro != null
                    and macro.functionLike
                    and macro.parameters.length > 0) {
                condition_error(format(
                        "macro '{}' requires an argument list", name))
                return("")
            }
        }
        if (macro == null) {
            return("")
        }
        if (arguments.length != macro.parameters.length) {
            condition_error(format(
                    "macro '{}' expects {} argument(s), got {}",
                    name,
                    macro.parameters.length,
                    arguments.length))
            return("")
        }
        list active = [name]
        list parentTrace = currentTrace
        list nestedTrace = []
        int64 traceIndex = 0
        while (traceIndex < currentTrace.length) {
            nestedTrace.append(currentTrace[traceIndex])
            traceIndex = traceIndex + 1
        }
        nestedTrace.append(format(
                "expanded macro @{} in condition at {}:{} (defined at {}:{})",
                name,
                conditionFile,
                conditionLine,
                macro.file,
                macro.line))
        currentTrace = nestedTrace
        String expanded = process_text(
                macro.file,
                macro.body,
                macro.line,
                macro.column,
                macro.parameters,
                arguments,
                active,
                currentImports,
                recursion
                + 1).trim()
        currentTrace = parentTrace
        return(expanded)
    }

    if (decimal_number(value)) {
        return(value)
    }

    if (value.length > 0 and name_start(byte(value, 0))) {
        if (name_end(value, 0) != value.length) {
            condition_error("invalid token in conditional expression")
            return("")
        }
        Macro macro = find_macro(value)
        if (macro != null) {
            return("1")
        }
        return("0")
    }

    condition_error("invalid token in conditional expression")
    return("")
}
