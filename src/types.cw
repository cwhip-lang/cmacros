// Shared cmacros types.
class Macro {
    public:
    String name
    String body
    String file
    int64 line
    int64 column
    list parameters
    bool functionLike

    Macro(String macroName, String replacement, String sourceFile, int64 sourceLine,
          int64 sourceColumn,
          list parameterNames, bool takesParameters) {
        name = macroName
        body = replacement
        file = sourceFile
        line = sourceLine
        column = sourceColumn
        parameters = parameterNames
        functionLike = takesParameters
    }
}

class Arguments {
    public:
    list values
    int64 end
    bool valid

    Arguments(list parsedValues, int64 next, bool succeeded) {
        values = parsedValues
        end = next
        valid = succeeded
    }
}

class Operator {
    public:
    int64 index
    String name

    Operator(int64 position, String token) {
        index = position
        name = token
    }
}

class LiteralValue {
    public:
    String value
    int64 end
    bool valid

    LiteralValue(String decoded, int64 next, bool succeeded) {
        value = decoded
        end = next
        valid = succeeded
    }
}

class ByteSpan {
    public:
    int64 byteSpanBound(int64 value, int64 length) {
        int64 index = value
        if (index < 0) { index = index + length }
        if (index < 0) { return(0) }
        if (index > length) { return(length) }
        return(index)
    }
    String byteSpan(String text, int64 first, int64 last) {
        int64 lower = byteSpanBound(first, text.length)
        int64 end = byteSpanBound(last, text.length)
        if (end <= lower) { return("") }
        return(text[lower..(end - 1)])
    }
}

