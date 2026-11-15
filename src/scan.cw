/*
 * src/scan.cw — Byte, name, column, and slice helpers for Processor.
 *
 * Created: 2026-11-15
 * Author: Auto
 *
 * Changelog:
 *   2026-11-15  Initial file.
 */

/*
 * Read one byte from a source string.
 *
 * text is the source. index is the byte offset. Returns the byte as a
 * non-negative int64, or -1 when index is outside text.
 */
int64 Processor.byte(String text, int64 index) {
    if (index < 0 or index >= text.length) {
        return(-1)
    }
    return(int64(text[index]))
}

/*
 * Return the byte width of a UTF-8 sequence from its lead byte.
 *
 * firstByte is the lead byte. Returns 1, 2, 3, or 4. A continuation byte or
 * ASCII byte returns 1.
 */
int64 Processor.utf8_width(int64 firstByte) {
    if (firstByte >= CHAR_UTF8_4) {
        return(4)
    }
    if (firstByte >= CHAR_UTF8_3) {
        return(3)
    }
    if (firstByte >= CHAR_UTF8_2) {
        return(2)
    }
    return(1)
}

/*
 * Report whether a byte may start a macro name.
 *
 * value is a byte. Returns true for an ASCII letter or underscore.
 */
bool Processor.name_start(int64 value) {
    return((value >= CHAR_A and value <= CHAR_Z)
            or (value >= CHAR_A_LOWER and value <= CHAR_Z_LOWER)
            or value == CHAR_UNDERSCORE)
}

/*
 * Report whether a byte may continue a macro name.
 *
 * value is a byte. Returns true for a name start or an ASCII digit.
 */
bool Processor.name_part(int64 value) {
    return(name_start(value) or (value >= CHAR_ZERO and value <= CHAR_NINE))
}

/*
 * Report whether a byte is ASCII whitespace.
 *
 * value is a byte. Returns true for space, tab, LF, VT, FF, or CR.
 */
bool Processor.space(int64 value) {
    return(value == CHAR_SPACE
            or value == CHAR_TAB
            or value == CHAR_LF
            or value == CHAR_CR
            or value == CHAR_FF
            or value == CHAR_VT)
}

/*
 * Advance an index past ASCII whitespace.
 *
 * text is the source. index is the start offset. Returns the first index at or
 * after index that is not whitespace, or text.length.
 */
int64 Processor.skip_space(String text, int64 index) {
    while (index < text.length and space(byte(text, index))) {
        index = index + 1
    }
    return(index)
}

/*
 * Advance an index past spaces, tabs, and CR, stopping at LF.
 *
 * text is the source. index is the start offset. Returns the first index that
 * is not space, tab, or CR.
 */
int64 Processor.skip_horizontal(String text, int64 index) {
    while (index < text.length
            and (byte(text, index) == CHAR_SPACE
                    or byte(text, index) == CHAR_TAB
                    or byte(text, index) == CHAR_CR)) {
        index = index + 1
    }
    return(index)
}

/*
 * Compute the line number after walking a half-open byte span.
 *
 * text is the source. fromIndex and end bound the walk. startLine is the line
 * at fromIndex. Returns the line at end. LF increases the line.
 */
int64 Processor.line_after(
        String text,
        int64 fromIndex,
        int64 end,
        int64 startLine) {
    int64 line = startLine
    int64 cursor = fromIndex
    while (cursor < end and cursor < text.length) {
        if (byte(text, cursor) == CHAR_LF) {
            line = line + 1
        }
        cursor = cursor + 1
    }
    return(line)
}

/*
 * Compute the column after walking a half-open byte span.
 *
 * text is the source. fromIndex and end bound the walk. startColumn is the
 * column at fromIndex. Returns the column at end. LF resets the column to 1.
 */
int64 Processor.column_after(
        String text,
        int64 fromIndex,
        int64 end,
        int64 startColumn) {
    int64 column = startColumn
    int64 cursor = fromIndex
    while (cursor < end and cursor < text.length) {
        int64 current = byte(text, cursor)
        if (current == CHAR_LF) {
            column = 1
            cursor = cursor + 1
        }
        else {
            int64 width = utf8_width(current)
            if (current < CHAR_ASCII or current >= CHAR_UTF8_2) {
                column = column + 1
            }
            cursor = cursor + width
        }
    }

    return(column)
}

/*
 * Copy the name token that starts at an index.
 *
 * text is the source. first is the start index. last is the exclusive scan
 * limit. Returns the name bytes, which may be empty.
 */
String Processor.read_name(String text, int64 first, int64 last) {
    int64 end = first
    while (end < last and name_part(byte(text, end))) {
        end = end + 1
    }
    return(byte_span(text, first, end))
}

/*
 * Find the index just past a name token.
 *
 * text is the source. first is the start index. Returns the first later index
 * whose byte is not a name part, or text.length.
 */
int64 Processor.name_end(String text, int64 first) {
    int64 end = first
    while (end < text.length and name_part(byte(text, end))) {
        end = end + 1
    }
    return(end)
}

/*
 * Report whether a string is a single macro name.
 *
 * name is the candidate. Returns true when it is non-empty and every byte is a
 * name part, with a name start first.
 */
bool Processor.valid_name(String name) {
    if (name.length == 0 or not name_start(byte(name, 0))) {
        return(false)
    }
    int64 index = 1
    while (index < name.length) {
        if (not name_part(byte(name, index))) {
            return(false)
        }
        index = index + 1
    }
    return(true)
}

/*
 * Clamp a span endpoint into a byte length.
 *
 * value is the requested index. A negative value counts back from length.
 * length is the string length. Returns an index from 0 through length.
 */
int64 Processor.byte_span_bound(int64 value, int64 length) {
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
String Processor.byte_span(String text, int64 first, int64 last) {
    int64 lower = byte_span_bound(first, text.length)
    int64 end = byte_span_bound(last, text.length)
    if (end <= lower) {
        return("")
    }
    return(text[lower..(end - 1)])
}
