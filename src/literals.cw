/*
 * src/literals.cw — Quoted-literal decoding for Processor.
 *
 * Created: 2026-11-15
 * Author: Auto
 *
 * Changelog:
 *   2026-11-15  Initial file.
 */

/*
 * Return the numeric value of one ASCII hex digit.
 *
 * value is a byte. Returns 0 through 15, or -1 when the byte is not a hex
 * digit.
 */
int64 Processor.hex_value(int64 value) {
    if (value >= CHAR_ZERO and value <= CHAR_NINE) {
        return(value - CHAR_ZERO)
    }
    if (value >= CHAR_A and value <= CHAR_F) {
        return(value - HEX_OFFSET_UPPER)
    }
    if (value >= CHAR_A_LOWER and value <= CHAR_F_LOWER) {
        return(value - HEX_OFFSET_LOWER)
    }
    return(-1)
}

/*
 * Decode one single-quoted or double-quoted literal.
 *
 * text is the source. open is the index of the opening quote. Returns the
 * decoded text, the index after the closing quote, and whether the literal was
 * valid.
 */
LiteralValue Processor.parse_literal(String text, int64 open) {
    int64 quote = byte(text, open)
    if (quote != CHAR_QUOTE and quote != CHAR_APOSTROPHE) {
        return(LiteralValue("", open, false))
    }

    String result = ""
    int64 index = open + 1
    while (index < text.length) {
        int64 current = byte(text, index)
        if (current == quote) {
            return(LiteralValue(result, index + 1, true))
        }
        if (current == CHAR_BACKSLASH) {
            index = index + 1
            if (index >= text.length) {
                return(LiteralValue("", open, false))
            }
            int64 escaped = byte(text, index)
            if (escaped == CHAR_N_LOWER) {
                result.append(format("{:c}", CHAR_LF))
            }
            else {
                if (escaped == CHAR_R_LOWER) {
                    result.append(format("{:c}", CHAR_CR))
                }
                else {
                    if (escaped == CHAR_T_LOWER) {
                        result.append(format("{:c}", CHAR_TAB))
                    }
                    else {
                        if (escaped == CHAR_A_LOWER) {
                            result.append(format("{:c}", CHAR_BEL))
                        }
                        else {
                            if (escaped == CHAR_B_LOWER) {
                                result.append(format("{:c}", CHAR_BS))
                            }
                            else {
                                if (escaped == CHAR_F_LOWER) {
                                    result.append(format("{:c}", CHAR_FF))
                                }
                                else {
                                    if (escaped == CHAR_V_LOWER) {
                                        result.append(format("{:c}", CHAR_VT))
                                    }
                                    else {
                                        if (escaped == CHAR_E_LOWER) {
                                            result.append(format(
                                                    "{:c}", CHAR_ESC))
                                        }
                                        else {
                                            if (escaped == CHAR_X_LOWER) {
                                                if (index + 2 >= text.length) {
                                                    return(LiteralValue(
                                                            "", open, false))
                                                }
                                                int64 high = hex_value(byte(
                                                        text, index
                                                        + 1))
                                                int64 low = hex_value(byte(
                                                        text, index
                                                        + 2))
                                                if (high < 0 or low < 0) {
                                                    return(LiteralValue(
                                                            "", open, false))
                                                }
                                                result.append(format(
                                                        "{:c}",
                                                        high * HEX_RADIX
                                                        + low))
                                                index = index + 2
                                            }
                                            else {
                                                result.append(byte_span(
                                                        text, index, index
                                                        + 1))
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
        else {
            int64 width = utf8_width(current)
            result.append(byte_span(text, index, index + width))
            index = index + width
        }
    }

    return(LiteralValue("", open, false))
}
