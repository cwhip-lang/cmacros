/*
 * src/expand.cw — Source expansion scan for Processor.
 *
 * Created: 2026-11-15
 * Author: Auto
 *
 * Changelog:
 *   2026-11-15  Initial file.
 */

/*
 * Expand one source span to output text.
 *
 * file locates diagnostics. source is the span. firstLine and firstColumn
 * locate its start. parameterNames and parameterValues are the active call.
 * active is the expansion stack. imports is the import chain. depth is the
 * expansion depth. Returns the expanded text. The first reported failure stops
 * the scan.
 */
String Processor.process_text(
        String file,
        String source,
        int64 firstLine,
        int64 firstColumn,
        list parameterNames,
        list parameterValues,
        list active,
        list imports,
        int64 depth) {
    String output = ""
    if (depth > LIMIT_NESTING) {
        report(
                CODE_EXPANSION,
                file,
                firstLine,
                firstColumn,
                "macro expansion nesting limit (128) exceeded")
        return(output)
    }

    int64 index = 0
    int64 line = firstLine
    int64 column = firstColumn
    int64 literalQuote = 0
    bool literalEscaped = false
    while (index < source.length and not failed) {
        int64 startIndex = index
        work = work + 1
        totalWork = totalWork + 1
        if (work > LIMIT_WORK_PASS or totalWork > LIMIT_WORK_TOTAL) {
            report(
                    CODE_WORK_LIMIT,
                    file,
                    line,
                    column,
                    "processing work limit (2,000,000 per pass; 20,000,000 total) exceeded")
            break
        }
        int64 current = byte(source, index)
        int64 next = byte(source, index + 1)
        bool handled = false
        if (current == CHAR_BACKSLASH and next == CHAR_AT) {
            output.append("@")
            index = index + 2
            literalEscaped = false
            handled = true
        }
        if (not handled
                and literalQuote == 0
                and current == CHAR_SLASH
                and next == CHAR_SLASH) {
            int64 end = index
            while (end < source.length and byte(source, end) != CHAR_LF) {
                end = end + 1
            }
            if (keepComments) {
                output.append(byte_span(source, index, end))
            }
            index = end
            handled = true
        }
        if (not handled
                and literalQuote == 0
                and current == CHAR_SLASH
                and next == CHAR_STAR) {
            int64 end = index + 2
            while (end
                    + 1 < source.length
                    and not (byte(source, end) == CHAR_STAR
                            and byte(source, end + 1) == CHAR_SLASH)) {
                end = end + 1
            }
            if (end + 1 >= source.length) {
                report(
                        CODE_EXPANSION,
                        file,
                        line,
                        column,
                        "unterminated block comment")
                break
            }
            if (keepComments) {
                output.append(byte_span(source, index, end + 2))
            }
            else {
                output.append(" ")
                String comment = byte_span(source, index + 2, end)
                int64 ci = 0
                while (ci < comment.length) {
                    if (byte(comment, ci) == CHAR_LF) {
                        output.append("\n")
                    }
                    ci = ci + 1
                }
            }
            index = end + 2
            handled = true
        }
        if (not handled
                and literalQuote == 0
                and current == CHAR_DOT
                and name_start(next)) {
            int64 wordEnd = name_end(source, index + 1)
            String directive = byte_span(source, index + 1, wordEnd).toLower()
            int64 argumentStart = skip_space(source, wordEnd)
            if (directive.equals("if")) {
                if (byte(source, argumentStart) != CHAR_LPAREN) {
                    report(
                            CODE_CONDITIONAL,
                            file,
                            line,
                            column,
                            ".if requires a parenthesized expression")
                    break
                }
                int64 expressionEnd = close_paren(source, argumentStart)
                if (expressionEnd < 0) {
                    report(
                            CODE_CONDITIONAL,
                            file,
                            line,
                            column,
                            "unterminated .if expression")
                    break
                }
                int64 bodyStart = skip_space(source, expressionEnd + 1)
                if (byte(source, bodyStart) != CHAR_LBRACE) {
                    report(
                            CODE_CONDITIONAL,
                            file,
                            line,
                            column,
                            ".if requires a braced body")
                    break
                }
                int64 bodyEnd = close_brace(source, bodyStart)
                if (bodyEnd < 0) {
                    report(
                            CODE_CONDITIONAL,
                            file,
                            line,
                            column,
                            "unterminated .if body")
                    break
                }
                conditionFile = file
                conditionLine = line
                conditionColumn = column
                bool selected = eval_condition( byte_span(source, argumentStart
                        + 1, expressionEnd), 0)
                String selectedBody = ""
                int64 selectedLine = line_after(source, startIndex, bodyStart
                        + 1, line)
                int64 selectedColumn = column_after(
                        source, startIndex, bodyStart
                        + 1, column)
                if (selected) {
                    selectedBody = byte_span(source, bodyStart + 1, bodyEnd)
                }
                index = bodyEnd + 1
                bool lookingAtElse = true
                while (lookingAtElse and not failed) {
                    int64 elseStart = skip_space(source, index)
                    if (byte(source, elseStart) != 46) {
                        lookingAtElse = false
                    }
                    else {
                        int64 elseNameEnd = name_end(source, elseStart + 1)
                        String elseName = byte_span(source, elseStart
                                + 1, elseNameEnd).toLower()
                        if (not elseName.equals("else")) {
                            lookingAtElse = false
                        }
                        else {
                            int64 elseArgs = skip_space(source, elseNameEnd)
                            bool elseHasExpression = byte(
                                    source,
                                    elseArgs) == CHAR_LPAREN
                            bool elseMatches = true
                            if (elseHasExpression) {
                                int64 elseExpressionEnd = close_paren(
                                        source,
                                        elseArgs)
                                if (elseExpressionEnd < 0) {
                                    report(
                                            CODE_CONDITIONAL,
                                            file,
                                            line_after(
                                                    source,
                                                    startIndex,
                                                    elseStart,
                                                    line),
                                            column_after(
                                                    source,
                                                    startIndex,
                                                    elseStart,
                                                    column),
                                            "unterminated .else expression")
                                    break
                                }
                                conditionFile = file
                                conditionLine = line_after(
                                        source,
                                        startIndex,
                                        elseStart,
                                        line)
                                conditionColumn = column_after(
                                        source,
                                        startIndex,
                                        elseStart,
                                        column)
                                elseMatches = eval_condition( byte_span(
                                        source, elseArgs
                                        + 1, elseExpressionEnd), 0)
                                elseArgs = skip_space(source, elseExpressionEnd
                                        + 1)
                            }
                            if (byte(source, elseArgs) != CHAR_LBRACE) {
                                report(
                                        CODE_CONDITIONAL,
                                        file,
                                        line_after(
                                                source,
                                                startIndex,
                                                elseStart,
                                                line),
                                        column_after(
                                                source,
                                                startIndex,
                                                elseStart,
                                                column),
                                        ".else requires a braced body")
                                break
                            }
                            int64 elseBodyEnd = close_brace(source, elseArgs)
                            if (elseBodyEnd < 0) {
                                report(
                                        CODE_CONDITIONAL,
                                        file,
                                        line_after(
                                                source,
                                                startIndex,
                                                elseStart,
                                                line),
                                        column_after(
                                                source,
                                                startIndex,
                                                elseStart,
                                                column),
                                        "unterminated .else body")
                                break
                            }
                            if (not selected
                                    and (not elseHasExpression
                                            or elseMatches)) {
                                selected = true
                                selectedBody = byte_span(source, elseArgs
                                        + 1, elseBodyEnd)
                                selectedLine = line_after(
                                        source, startIndex, elseArgs
                                        + 1, line)
                                selectedColumn = column_after(
                                        source, startIndex, elseArgs
                                        + 1, column)
                            }
                            index = elseBodyEnd + 1
                        }
                    }
                }
                if (selected and not failed) {
                    output.append(process_text(
                            file,
                            selectedBody,
                            selectedLine,
                            selectedColumn,
                            parameterNames,
                            parameterValues,
                            active,
                            imports,
                            depth
                            + 1))
                }
            }
            else {
            if (directive.equals("else")) {
                report(
                        CODE_MISPLACED_ELSE,
                        file,
                        line,
                        column,
                        "misplaced .else directive")
            }
            else {
            if (directive.equals("define")) {
                int64 nameStartIndex = argumentStart
                int64 nameStop = name_end(source, nameStartIndex)
                if (nameStop == nameStartIndex) {
                    report(
                            CODE_SYNTAX,
                            file,
                            line,
                            column,
                            "expected a macro name after .define")
                    break
                }
                String macroName = byte_span(source, nameStartIndex, nameStop)
                int64 cursor = skip_horizontal(source, nameStop)
                list parameters = []
                bool functionLike = false
                if (byte(source, cursor) == CHAR_LPAREN) {
                    functionLike = true
                    int64 close = cursor + 1
                    int64 parenDepth = 1
                    int64 paramStart = close
                    while (close < source.length and parenDepth > 0) {
                        if (byte(source, close) == CHAR_LPAREN) {
                            parenDepth = parenDepth + 1
                        }
                        if (byte(source, close) == CHAR_RPAREN
                                and parenDepth > 0) {
                            parenDepth = parenDepth - 1
                            if (parenDepth == 0) {
                                String param = byte_span(
                                        source,
                                        paramStart,
                                        close).trim()
                                if (param.length > 0
                                        or parameters.length > 0) {
                                    parameters.append(param)
                                }
                                break
                            }
                        }
                        if (byte(source, close) == CHAR_COMMA
                                and parenDepth == 1) {
                            parameters.append(byte_span(
                                    source, paramStart, close).trim())
                            paramStart = close + 1
                        }
                        close = close + 1
                    }
                    if (parenDepth != 0) {
                        report(
                                CODE_SYNTAX,
                                file,
                                line,
                                column,
                                "unterminated .define parameter list")
                        break
                    }
                    cursor = skip_space(source, close + 1)
                }
                else {
                    cursor = skip_horizontal(source, nameStop)
                }
                String body = ""
                int64 bodyLine = line_after(source, startIndex, cursor, line)
                if (byte(source, cursor) == CHAR_LBRACE) {
                    int64 closeBody = close_brace(source, cursor)
                    if (closeBody < 0) {
                        report(
                                CODE_SYNTAX,
                                file,
                                bodyLine,
                                column_after(
                                        source,
                                        startIndex,
                                        cursor,
                                        column),
                                "unterminated .define body")
                        break
                    }
                    body = byte_span(source, cursor + 1, closeBody)
                    bodyLine = line_after(source, startIndex, cursor + 1, line)
                    index = closeBody + 1
                }
                else {
                    if (functionLike) {
                        report(
                                CODE_SYNTAX,
                                file,
                                line,
                                column,
                                "a parameterized .define requires a braced body")
                        break
                    }
                    else {
                        index = nameStop
                    }
                }
                add_definition(macroName, body, file, bodyLine, column_after(
                        source, startIndex, cursor
                        + 1, column), parameters, functionLike)
            }
            else {
            if (directive.equals("undef")) {
                int64 nameStop = name_end(source, argumentStart)
                if (nameStop == argumentStart) {
                    report(
                            CODE_SYNTAX,
                            file,
                            line,
                            column,
                            "expected a macro name after .undef")
                    break
                }
                String undefName = byte_span(source, argumentStart, nameStop)
                remove_definition(undefName, file, line, column)
                index = nameStop
            }
            else {
                if (directive.equals("import")
                        or directive.equals("include")) {
                if (byte(source, argumentStart) != CHAR_QUOTE) {
                    report(
                            CODE_SYNTAX,
                            file,
                            line,
                            column,
                            ".import requires a quoted path")
                    break
                }
                LiteralValue importPath = parse_literal(source, argumentStart)
                if (not importPath.valid) {
                    report(
                            CODE_SYNTAX,
                            file,
                            line,
                            column,
                            "invalid or unterminated .import path")
                    break
                }
                String requested = importPath.value
                String imported = resolve_import(file, requested)
                if (imported.length == 0) {
                    report(
                            CODE_IMPORT_MISSING,
                            file,
                            line,
                            column,
                            format(
                                    "cannot find imported file '{}'",
                                    requested))
                    break
                }
                output.append(process_file(imported, imports, active, depth
                        + 1))
                index = importPath.end
                }
                else {
                if (directive.equals("error") or directive.equals("message")) {
                if (byte(source, argumentStart) != CHAR_QUOTE) {
                    report(
                            CODE_SYNTAX,
                            file,
                            line,
                            column,
                            format(".{} requires a quoted message", directive))
                    break
                }
                LiteralValue directiveMessage = parse_literal(
                        source,
                        argumentStart)
                if (not directiveMessage.valid) {
                    report(
                            CODE_SYNTAX,
                            file,
                            line,
                            column,
                            "invalid or unterminated directive message")
                    break
                }
                String message = directiveMessage.value
                if (directive.equals("error")) {
                    report(CODE_ERROR_DIRECTIVE, file, line, column, message)
                }
                else {
                    io.writeErrorLine(format(
                            "{}:{}: message: {}", file, line, message))
                }
                index = directiveMessage.end
                }
                else {
                    output.append(".")
                    index = index + 1
                }
                }
            }
            }
            }
            }
            handled = true
        }
        if (not handled and current == CHAR_AT and name_start(next)) {
            int64 endName = name_end(source, index + 1)
            String name = byte_span(source, index + 1, endName)
            int64 localIndex = find_parameter(parameterNames, name)
            if (localIndex >= 0) {
                String value = parameterValues[localIndex] as String
                output.append(process_text(
                        file,
                        value,
                        line,
                        column,
                        [],
                        [],
                        active,
                        imports,
                        depth
                        + 1))
                index = endName
            }
            else {
                Macro macro = find_macro(name)
                int64 cursor = skip_horizontal(source, endName)
                list arguments = []
                int64 afterReference = endName
                bool callSyntax = false
                if (macro != null) {
                    callSyntax = (
                            macro.functionLike
                            and macro.parameters.length > 0)
                }
                if (callSyntax) {
                    if (byte(source, cursor) != CHAR_LPAREN) {
                        report(
                                CODE_ARGUMENTS,
                                file,
                                line,
                                column,
                                format(
                                        "macro '{}' requires an argument list",
                                        name))
                        break
                    }
                    Arguments parsed = parse_arguments(source, cursor)
                    if (not parsed.valid) {
                        report(
                                CODE_ARGUMENTS,
                                file,
                                line,
                                column,
                                format(
                                        "unterminated argument list for macro '{}'",

                                        name))
                        break
                    }
                    arguments = parsed.values
                    afterReference = parsed.end
                    if (arguments.length != macro.parameters.length) {
                        report(
                                CODE_ARITY,
                                file,
                                line,
                                column,
                                format(
                                        "macro '{}' expects {} argument(s), got {}",

                                        name,
                                        macro.parameters.length,
                                        arguments.length))
                        break
                    }
                }
                if (macro != null
                        and macro.functionLike
                        and macro.parameters.length == 0
                        and byte(source, cursor) == CHAR_LPAREN) {
                    Arguments parsedEmpty = parse_arguments(source, cursor)
                    if (not parsedEmpty.valid
                            or parsedEmpty.values.length > 0) {
                        report(
                                CODE_ARITY,
                                file,
                                line,
                                column,
                                format("macro '{}' takes no arguments", name))
                        break
                    }
                    afterReference = parsedEmpty.end
                }
                if (macro == null) {
                    output.append(byte_span(source, index, endName))
                    index = endName
                }
                else {
                    if (in_list(active, name)) {
                        report(
                                CODE_MACRO_CYCLE,
                                file,
                                line,
                                column,
                                format(
                                        "macro expansion cycle involving '{}'",
                                        name))
                        break
                    }
                    else {
                        list nestedActive = []
                        int64 activeIndex = 0
                        while (activeIndex < active.length) {
                            nestedActive.append(active[activeIndex])
                            activeIndex = activeIndex + 1
                        }
                        nestedActive.append(name)
                        list parentTrace = currentTrace
                        list nestedTrace = []
                        int64 traceIndex = 0
                        while (traceIndex < currentTrace.length) {
                            nestedTrace.append(currentTrace[traceIndex])
                            traceIndex = traceIndex + 1
                        }
                        nestedTrace.append(format(
                                "expanded macro @{} at {}:{} (defined at {}:{})",

                                name,
                                file,
                                line,
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
                                nestedActive,
                                imports,
                                depth
                                + 1)
                        currentTrace = parentTrace
                        output.append(expanded)
                        index = afterReference
                    }
                }
            }
            handled = true
        }
        if (not handled) {
            int64 width = utf8_width(current)
            output.append(byte_span(source, index, index + width))
            if (literalQuote != 0) {
                if (literalEscaped) {
                    literalEscaped = false
                }
                else {
                    if (current == CHAR_BACKSLASH) {
                        literalEscaped = true
                    }
                    else {
                        if (current == literalQuote) {
                            literalQuote = 0
                        }
                    }
                }
            }
            else {
                if (current == CHAR_QUOTE or current == CHAR_APOSTROPHE) {
                    literalQuote = current
                }
            }
            index = index + width
        }
        if (output.length > outputLimit) {
            report(
                    CODE_OUTPUT_LIMIT,
                    file,
                    line,
                    column,
                    "expanded output exceeds the 7,000,000-byte limit")
            break
        }
        int64 lineCursor = startIndex
        while (lineCursor < index) {
            if (byte(source, lineCursor) == CHAR_LF) {
                line = line + 1
                column = 1
            }
            else {
                int64 currentByte = byte(source, lineCursor)
                if (currentByte < CHAR_ASCII or currentByte >= CHAR_UTF8_2) {
                    column = column + 1
                }
            }
            lineCursor = lineCursor + 1
        }
    }

    if (literalQuote != 0 and not failed) {
        report(
                CODE_EXPANSION,
                file,
                line,
                column,
                "unterminated quoted literal")
    }
    return(output)
}
