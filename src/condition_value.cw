/*
 * src/condition_value.cw — Conditional decimal and operand comparison for
 * Processor.
 *
 * Created: 2026-11-15
 * Author: Auto
 *
 * Changelog:
 *   2026-11-15  Initial file.
 */

/*
 * Report whether a string is a signed decimal integer.
 *
 * value is the candidate. Returns true when it is an optional sign followed by
 * one or more digits.
 */
bool Processor.decimal_number(String value) {
    if (value.length == 0) {
        return(false)
    }
    int64 index = 0
    if (byte(value, 0) == CHAR_MINUS or byte(value, 0) == CHAR_PLUS) {
        index = 1
    }
    if (index == value.length) {
        return(false)
    }
    while (index < value.length) {
        if (byte(value, index) < CHAR_ZERO or byte(value, index) > CHAR_NINE) {
            return(false)
        }
        index = index + 1
    }
    return(true)
}

/*
 * Report whether a decimal operand has magnitude zero.
 *
 * value may include a leading sign. Returns true when every remaining byte is
 * the digit zero. An empty magnitude is true.
 */
bool Processor.decimal_zero(String value) {
    int64 index = 0
    if (byte(value, 0) == CHAR_MINUS or byte(value, 0) == CHAR_PLUS) {
        index = 1
    }
    while (index < value.length) {
        if (byte(value, index) != CHAR_ZERO) {
            return(false)
        }
        index = index + 1
    }
    return(true)
}

/*
 * Order two signed decimal integers.
 *
 * left and right are decimal text. Returns COMPARE_LESS, COMPARE_EQUAL, or
 * COMPARE_GREATER. A leading minus on only one side orders that side first,
 * including when both magnitudes are zero.
 */
int64 Processor.compare_decimals(String left, String right) {
    bool leftNegative = byte(left, 0) == CHAR_MINUS
    bool rightNegative = byte(right, 0) == CHAR_MINUS
    int64 leftStart = 0
    int64 rightStart = 0
    if (leftNegative or byte(left, 0) == CHAR_PLUS) {
        leftStart = 1
    }
    if (rightNegative or byte(right, 0) == CHAR_PLUS) {
        rightStart = 1
    }
    while (leftStart < left.length - 1
            and byte(left, leftStart) == CHAR_ZERO) {
        leftStart = leftStart + 1
    }
    while (rightStart < right.length - 1
            and byte(right, rightStart) == CHAR_ZERO) {
        rightStart = rightStart + 1
    }

    int64 leftLength = left.length - leftStart
    int64 rightLength = right.length - rightStart
    int64 magnitude = COMPARE_EQUAL
    if (leftLength < rightLength) {
        magnitude = COMPARE_LESS
    }
    else {
        if (leftLength > rightLength) {
            magnitude = COMPARE_GREATER
        }
        else {
            int64 index = 0
            while (index < leftLength and magnitude == 0) {
                int64 leftDigit = byte(left, leftStart + index)
                int64 rightDigit = byte(right, rightStart + index)
                if (leftDigit < rightDigit) {
                    magnitude = COMPARE_LESS
                }
                else {
                    if (leftDigit > rightDigit) {
                        magnitude = COMPARE_GREATER
                    }
                }
                index = index + 1
            }
        }
    }

    if (leftNegative and not rightNegative) {
        return(COMPARE_LESS)
    }
    if (not leftNegative and rightNegative) {
        return(COMPARE_GREATER)
    }
    if (leftNegative) {
        return(-magnitude)
    }
    return(magnitude)
}

/*
 * Report whether a condition value counts as true.
 *
 * value is the text. Returns false for empty text and for a decimal zero. Any
 * other text returns true.
 */
bool Processor.value_truth(String value) {
    String trimmed = value.trim()
    if (trimmed.length == 0) {
        return(false)
    }
    if (decimal_number(trimmed)) {
        return(not decimal_zero(trimmed))
    }
    return(true)
}

/*
 * Compare two condition operands with one operator.
 *
 * leftExpression and rightExpression are the operands. operator is the token.
 * Returns the comparison. Bare names only support equality. A non-numeric
 * relational comparison returns false so a later pass can settle it.
 */
bool Processor.compare_condition(
        String leftExpression,
        String rightExpression,
        String operator) {
    bool leftDefinedness = is_definedness_operand(leftExpression)
    bool rightDefinedness = is_definedness_operand(rightExpression)
    bool leftAt = is_at_operand(leftExpression)
    bool rightAt = is_at_operand(rightExpression)
    if ((leftAt and rightDefinedness) or (leftDefinedness and rightAt)) {
        condition_error("cannot mix @ and bare names in a comparison")
        return(false)
    }
    if (leftDefinedness != rightDefinedness) {
        condition_error(
                "cannot mix bare names and value operands in a comparison")
        return(false)
    }
    String upper = operator.toUpper()
    bool equality = upper.equals("==") or upper.equals("EQ") or upper.equals(
            "!=") or upper.equals("NEQ")

    if (leftDefinedness and rightDefinedness) {
        if (not equality) {
            condition_error("bare names only support == and != comparisons")
            return(false)
        }
        bool leftDefined = find_macro(leftExpression.trim()) != null
        bool rightDefined = find_macro(rightExpression.trim()) != null
        bool equal = leftDefined == rightDefined
        if (upper.equals("==") or upper.equals("EQ")) {
            return(equal)
        }
        return(not equal)
    }

    String left = resolve_condition_value(leftExpression, 0)
    String right = resolve_condition_value(rightExpression, 0)
    if (failed) {
        return(false)
    }

    bool equal = false
    bool less = false
    bool greater = false
    if (decimal_number(left) and decimal_number(right)) {
        int64 comparison = compare_decimals(left, right)
        equal = comparison == COMPARE_EQUAL
        less = comparison < COMPARE_EQUAL
        greater = comparison > COMPARE_EQUAL
    }
    else {
        if (not equality) {
            // Non-numeric relational results are false so forward
            // references in conditions can settle on later passes.
            return(false)
        }
        equal = left.equals(right)
    }

    if (upper.equals("==") or upper.equals("EQ")) {
        return(equal)
    }
    if (upper.equals("!=") or upper.equals("NEQ")) {
        return(not equal)
    }
    if (upper.equals("<") or upper.equals("LT")) {
        return(less)
    }
    if (upper.equals(">") or upper.equals("GT")) {
        return(greater)
    }
    if (upper.equals("<=") or upper.equals("LTE")) {
        return(less or equal)
    }
    return(greater or equal)
}
