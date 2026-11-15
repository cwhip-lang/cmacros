/*
 * src/definitions.cw — Definition table updates for Processor.
 *
 * Created: 2026-11-15
 * Author: Auto
 *
 * Changelog:
 *   2026-11-15  Initial file.
 */

/*
 * Look up a stored definition by name.
 *
 * name is the macro name. Returns that definition, or null when it is absent.
 */
Macro Processor.find_macro(String name) {
    int64 index = 0
    while (index < macros.length) {
        Macro macro = macros[index] as Macro
        if (macro.name.equals(name)) {
            return(macro)
        }
        index = index + 1
    }
    return(null)
}

/*
 * Delete one stored definition.
 *
 * name is the macro. file, line, and column locate the .undef. Returns
 * nothing. An unknown or invalid name is reported and the table is left
 * unchanged for that call.
 */
void Processor.remove_definition(
        String name,
        String file,
        int64 line,
        int64 column) {
    if (not valid_name(name)) {
        report(
                CODE_SYNTAX,
                file,
                line,
                column,
                format("invalid macro name '{}'", name))
        return
    }
    int64 index = 0
    while (index < macros.length) {
        Macro macro = macros[index] as Macro
        if (macro.name.equals(name)) {
            macros.remove(index..index)
            return
        }
        index = index + 1
    }
    report(
            CODE_SYNTAX,
            file,
            line,
            column,
            format("macro '{}' is not defined", name))
}

/*
 * Find a parameter name in a definition's parameter list.
 *
 * names is the parameter list. name is the sought parameter. Returns its
 * index, or -1 when it is absent.
 */
int64 Processor.find_parameter(list names, String name) {
    int64 index = 0
    while (index < names.length) {
        String current = names[index] as String
        if (current.equals(name)) {
            return(index)
        }
        index = index + 1
    }
    return(-1)
}

/*
 * Return how many definitions are stored.
 *
 * Takes no parameters. Returns macros.length. Defining one name and undefining
 * another can leave this count unchanged.
 */
int64 Processor.definition_count() {
    return(macros.length)
}

/*
 * Store a macro definition, rejecting an incompatible redefinition.
 *
 * name and body are the definition. file, line, and column locate it.
 * parameters are the formal names. functionLike is true when the definition
 * takes a parameter list. Returns nothing. An identical redefinition is
 * ignored.
 */
void Processor.add_definition(
        String name,
        String body,
        String file,
        int64 line,
        int64 column,
        list parameters,
        bool functionLike) {
    if (not valid_name(name)) {
        report(
                CODE_SYNTAX,
                file,
                line,
                1,
                format("invalid macro name '{}'", name))
        return
    }

    int64 parameterIndex = 0
    while (parameterIndex < parameters.length) {
        String parameter = parameters[parameterIndex] as String
        if (not valid_name(parameter)) {
            report(
                    CODE_SYNTAX,
                    file,
                    line,
                    1,
                    format(
                            "invalid parameter name '{}' in macro '{}'",
                            parameter,
                            name))
            return
        }
        int64 previousIndex = 0
        while (previousIndex < parameterIndex) {
            String previousParameter = parameters[previousIndex] as String
            if (previousParameter.equals(parameter)) {
                report(
                        CODE_SYNTAX,
                        file,
                        line,
                        1,
                        format(
                                "duplicate parameter '{}' in macro '{}'",
                                parameter,
                                name))
                return
            }
            previousIndex = previousIndex + 1
        }
        parameterIndex = parameterIndex + 1
    }

    Macro existing = find_macro(name)
    if (existing != null) {
        bool sameParameters = existing.parameters.length == parameters.length
        int64 index = 0
        while (index < existing.parameters.length and sameParameters) {
            String oldParameter = existing.parameters[index] as String
            String newParameter = parameters[index] as String
            if (not oldParameter.equals(newParameter)) {
                sameParameters = false
            }
            index = index + 1
        }
        if (not existing.body.equals(body)
                or existing.functionLike != functionLike
                or not sameParameters) {
            report(
                    CODE_REDEFINED,
                    file,
                    line,
                    1,
                    format("macro '{}' is already defined", name))
        }
        return
    }

    macros.append(Macro(
            name, body, file, line, column, parameters, functionLike))
}
