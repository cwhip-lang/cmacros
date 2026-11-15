/*
 * src/types.cw — Value records shared by the processor.
 *
 * Created: 2026-10-30
 * Author: chuck
 *
 * Changelog:
 *   2026-10-30  Initial file.
 *   2026-11-15  Apply the shared Cwhip coding standard.
 */

/*
 * One stored macro definition.
 *
 * The processor owns the list of these records. name, body, and parameters are
 * the definition. file, line, and column locate it. functionLike is true when
 * the definition has a parameter list.
 */
class Macro {
    public:
    String name
    String body
    String file
    int64 line
    int64 column
    list parameters
    bool functionLike

    Macro(
            String macroName,
            String replacement,
            String sourceFile,
            int64 sourceLine,
            int64 sourceColumn,
            list parameterNames,
            bool takesParameters)
}

/*
 * Store one macro definition.
 *
 * macroName and replacement are the name and body. sourceFile, sourceLine, and
 * sourceColumn locate the definition. parameterNames are the formals.
 * takesParameters records a function-like definition. Returns the definition.
 */
Macro Macro.Macro(
        String macroName,
        String replacement,
        String sourceFile,
        int64 sourceLine,
        int64 sourceColumn,
        list parameterNames,
        bool takesParameters) {
    name = macroName
    body = replacement
    file = sourceFile
    line = sourceLine
    column = sourceColumn
    parameters = parameterNames
    functionLike = takesParameters
}

/*
 * One parsed macro argument list.
 *
 * values holds the argument strings. end is the source index after the closing
 * parenthesis. valid is false when the list could not be parsed.
 */
class Arguments {
    public:
    list values
    int64 end
    bool valid

    Arguments(list parsedValues, int64 next, bool succeeded)
}

/*
 * Store a parsed argument list.
 *
 * parsedValues are the argument strings. next is the index after the list.
 * succeeded is false when the list is malformed. Returns the record.
 */
Arguments Arguments.Arguments(list parsedValues, int64 next, bool succeeded) {
    values = parsedValues
    end = next
    valid = succeeded
}

/*
 * One condition operator found in an expression.
 *
 * index is the byte offset, or -1 when the search found nothing. name is the
 * operator text.
 */
class Operator {
    public:
    int64 index
    String name

    Operator(int64 position, String token)
}

/*
 * Store a condition operator and where it was found.
 *
 * position is the byte index, or -1 when no operator was found. token is the
 * operator text. Returns the record.
 */
Operator Operator.Operator(int64 position, String token) {
    index = position
    name = token
}

/*
 * One decoded quoted literal.
 *
 * value is the decoded text. end is the source index after the closing quote.
 * valid is false when the quotes are missing or the escape is incomplete.
 */
class LiteralValue {
    public:
    String value
    int64 end
    bool valid

    LiteralValue(String decoded, int64 next, bool succeeded)
}

/*
 * Store a decoded quoted literal.
 *
 * decoded is the text. next is the index after the closing quote. succeeded is
 * false when the literal is malformed. Returns the record.
 */
LiteralValue LiteralValue.LiteralValue(
        String decoded,
        int64 next,
        bool succeeded) {
    value = decoded
    end = next
    valid = succeeded
}

/*
 * Copy a half-open slice of a string by byte index.
 *
 * Negative endpoints count back from the length. The main program uses this
 * for command-line NAME=value splits. Processor keeps its own copy of the same
 * steps for expansion.
 */
class ByteSpan {
    public:

    int64 byte_span_bound(int64 value, int64 length)
    String byte_span(String text, int64 first, int64 last)
}

/*
 * Clamp a span endpoint into a byte length.
 *
 * value is the requested index. A negative value counts back from length.
 * length is the string length. Returns an index from 0 through length.
 */
int64 ByteSpan.byte_span_bound(int64 value, int64 length) {
    int64 index = value
    if (index < 0) {
        index = index + length
    }
    if (index < 0) {
        return(0)
    }
    if (index > length) {
        return(length)
    }
    return(index)
}

/*
 * Copy a half-open byte slice of a string.
 *
 * text is the source. first and last are endpoints, possibly negative. Returns
 * the slice, or an empty string when the clamped end is not after the start.
 */
String ByteSpan.byte_span(String text, int64 first, int64 last) {
    int64 lower = byte_span_bound(first, text.length)
    int64 end = byte_span_bound(last, text.length)
    if (end <= lower) {
        return("")
    }
    return(text[lower..(end - 1)])
}
