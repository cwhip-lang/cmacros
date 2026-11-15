/*
 * src/delimiters.cw — Brace and parenthesis matching for Processor.
 *
 * Created: 2026-11-15
 * Author: Auto
 *
 * Changelog:
 *   2026-11-15  Initial file.
 */

/*
 * Find the brace that closes the group opened at an index.
 *
 * text is the source. open is the index of the opening brace. Returns the
 * index of the matching closing brace, or -1. Quotes and comments are not
 * brace text.
 */
int64 Processor.close_brace(String text, int64 open) {
    int64 depth = 1
    int64 index = open + 1
    int64 quote = 0
    bool escaped = false
    while (index < text.length) {
        int64 current = byte(text, index)
        int64 next = byte(text, index + 1)
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
                if (current == CHAR_SLASH and next == CHAR_SLASH) {
                    index = index + 2
                    while (index < text.length
                            and byte(text, index) != CHAR_LF) {
                        index = index + 1
                    }
                    continue
                }
                else {
                    if (current == CHAR_SLASH and next == CHAR_STAR) {
                        index = index + 2
                        while (index
                                + 1 < text.length
                                and not (byte(text, index) == CHAR_STAR
                                        and byte(text, index
                                                + 1) == CHAR_SLASH)) {
                            index = index + 1
                        }
                        index = index + 1
                    }
                    else {
                        if (current == CHAR_LBRACE) {
                            depth = depth + 1
                        }
                        else {
                            if (current == CHAR_RBRACE) {
                                depth = depth - 1
                                if (depth == 0) {
                                    return(index)
                                }
                            }
                        }
                    }
                }
            }
        }
        index = index + 1
    }

    return(-1)
}

/*
 * Find the parenthesis that closes the group opened at an index.
 *
 * text is the source. open is the index of the opening parenthesis. Returns
 * the matching index, or -1. Quoted text is skipped.
 */
int64 Processor.close_paren(String text, int64 open) {
    int64 depth = 1
    int64 index = open + 1
    int64 quote = 0
    bool escaped = false
    while (index < text.length) {
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
                    depth = depth + 1
                }
                else {
                    if (current == CHAR_RPAREN) {
                        depth = depth - 1
                        if (depth == 0) {
                            return(index)
                        }
                    }
                }
            }
        }
        index = index + 1
    }

    return(-1)
}
