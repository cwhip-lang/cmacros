/*
 * src/processor.cw — Processor state and the first reported error.
 *
 * Created: 2026-10-17
 * Author: chuck
 *
 * Changelog:
 *   2026-10-17  Initial file.
 *   2026-11-15  Apply the shared Cwhip coding standard.
 */

/*
 * Expand macro source to text.
 *
 * The processor owns the definition table, the source cache, the import and
 * expansion notes, and the standard error stream it writes. The fields are the
 * shared processor state. Each method is documented at its definition.
 */
class Processor {
    public:
    enum {
        CODE_SYNTAX = 1000,
        CODE_REDEFINED = 1001,
        CODE_EXPANSION = 1002,
        CODE_ERROR_DIRECTIVE = 1003,
        CODE_ARGUMENTS = 1004,
        CODE_ARITY = 1005,
        CODE_MACRO_CYCLE = 1006,
        CODE_CONDITIONAL = 1007,
        CODE_MISPLACED_ELSE = 1008,
        CODE_CONDITION = 1009,
        CODE_INPUT = 2000,
        CODE_SOURCE_LIMIT = 2001,
        CODE_IMPORT_DEPTH = 2002,
        CODE_IMPORT_CYCLE = 2003,
        CODE_WORK_LIMIT = 2004,
        CODE_IMPORT_MISSING = 2005,
        CODE_OUTPUT_LIMIT = 2006,
        CODE_PASS_LIMIT = 2007,
        CODE_TEMP_EXISTS = 2008,
        CODE_OUTPUT_WRITE = 2009,
        LIMIT_PASSES = 256,
        LIMIT_NESTING = 128,
        LIMIT_SOURCE_BYTES = 16777216,
        LIMIT_READ_CHUNK = 65536,
        LIMIT_OUTPUT_BYTES = 7000000,
        LIMIT_WORK_PASS = 2000000,
        LIMIT_WORK_TOTAL = 20000000,
        PRIORITY_NONE = 0,
        PRIORITY_OR = 1,
        PRIORITY_AND = 2,
        PRIORITY_EQUAL = 3,
        PRIORITY_ORDER = 4,
        COMPARE_LESS = -1,
        COMPARE_EQUAL = 0,
        COMPARE_GREATER = 1,
        CHAR_BEL = 7,
        CHAR_BS = 8,
        CHAR_TAB = 9,
        CHAR_LF = 10,
        CHAR_VT = 11,
        CHAR_FF = 12,
        CHAR_CR = 13,
        CHAR_ESC = 27,
        CHAR_SPACE = 32,
        CHAR_QUOTE = 34,
        CHAR_APOSTROPHE = 39,
        CHAR_LPAREN = 40,
        CHAR_RPAREN = 41,
        CHAR_STAR = 42,
        CHAR_PLUS = 43,
        CHAR_COMMA = 44,
        CHAR_MINUS = 45,
        CHAR_DOT = 46,
        CHAR_SLASH = 47,
        CHAR_ZERO = 48,
        CHAR_NINE = 57,
        CHAR_AT = 64,
        CHAR_A = 65,
        CHAR_F = 70,
        CHAR_Z = 90,
        CHAR_LBRACKET = 91,
        CHAR_BACKSLASH = 92,
        CHAR_RBRACKET = 93,
        CHAR_UNDERSCORE = 95,
        CHAR_A_LOWER = 97,
        CHAR_B_LOWER = 98,
        CHAR_E_LOWER = 101,
        CHAR_F_LOWER = 102,
        CHAR_N_LOWER = 110,
        CHAR_R_LOWER = 114,
        CHAR_T_LOWER = 116,
        CHAR_V_LOWER = 118,
        CHAR_X_LOWER = 120,
        CHAR_Z_LOWER = 122,
        CHAR_LBRACE = 123,
        CHAR_RBRACE = 125,
        CHAR_ASCII = 128,
        CHAR_UTF8_2 = 192,
        CHAR_UTF8_3 = 224,
        CHAR_UTF8_4 = 240,
        HEX_OFFSET_UPPER = 55,
        HEX_OFFSET_LOWER = 87,
        HEX_RADIX = 16,
    }

    list macros
    list includePaths
    list cachedPaths
    list cachedContents
    list currentImports
    list currentTrace
    bool failed
    int64 work
    int64 totalWork
    int64 outputLimit
    String conditionFile
    int64 conditionLine
    int64 conditionColumn
    bool keepComments
    Sys.StandardIO io

    Processor(list paths)
    int64 byte(String text, int64 index)
    int64 utf8_width(int64 firstByte)
    bool name_start(int64 value)
    bool name_part(int64 value)
    bool space(int64 value)
    int64 skip_space(String text, int64 index)
    int64 skip_horizontal(String text, int64 index)
    int64 line_after(String text, int64 fromIndex, int64 end, int64 startLine)
    int64 column_after(
            String text,
            int64 fromIndex,
            int64 end,
            int64 startColumn)
    String read_name(String text, int64 first, int64 last)
    int64 name_end(String text, int64 first)
    bool valid_name(String name)
    int64 byte_span_bound(int64 value, int64 length)
    String byte_span(String text, int64 first, int64 last)
    Macro find_macro(String name)
    void remove_definition(String name, String file, int64 line, int64 column)
    int64 find_parameter(list names, String name)
    void report(
            int64 code,
            String file,
            int64 line,
            int64 column,
            String message)
    int64 definition_count()
    String resolve_import(String currentFile, String requested)
    bool in_list(list values, String name)
    String process_file(String file, list imports, list active, int64 depth)
    Arguments parse_arguments(String text, int64 open)
    bool valid_argument_literal(String value)
    String unquote(String value)
    int64 hex_value(int64 value)
    LiteralValue parse_literal(String text, int64 open)
    int64 close_brace(String text, int64 open)
    int64 close_paren(String text, int64 open)
    void add_definition(
            String name,
            String body,
            String file,
            int64 line,
            int64 column,
            list parameters,
            bool functionLike)
    String process_text(
            String file,
            String source,
            int64 firstLine,
            int64 firstColumn,
            list parameterNames,
            list parameterValues,
            list active,
            list imports,
            int64 depth)
    bool is_definedness_operand(String expression)
    bool is_at_operand(String expression)
    void condition_error(String message)
    bool word_boundary(String text, int64 index)
    int64 operator_priority(String operator)
    String operator_at(String text, int64 index)
    Operator find_operator(String expression, int64 wantedPriority)
    bool wraps_whole_expression(String expression)
    bool decimal_number(String value)
    bool decimal_zero(String value)
    int64 compare_decimals(String left, String right)
    bool value_truth(String value)
    bool eval_condition(String expression, int64 recursion)
    bool at_reference_defined_nonempty(String expression, int64 recursion)
    String resolve_condition_value(String expression, int64 recursion)
    bool compare_condition(
            String leftExpression,
            String rightExpression,
            String operator)
    void cache_source(String path, String content)
    String read_file(String path, int64 line)
    String process(String input)
    bool write_output(String path, String text)
    void print_help()
}

/*
 * Build a processor that owns its definition table, caches, and error output.
 *
 * paths is the import search list. The constructor copies that list and sets
 * the output and location defaults. Returns the processor.
 */
Processor Processor.Processor(list paths) {
    macros = []
    includePaths = paths
    cachedPaths = []
    cachedContents = []
    currentImports = []
    currentTrace = []
    failed = false
    work = 0
    totalWork = 0
    outputLimit = LIMIT_OUTPUT_BYTES
    conditionFile = ""
    conditionLine = 1
    conditionColumn = 1
    keepComments = false
    io = Sys.System().io()
}

/*
 * Record the first failure and write it to standard error.
 *
 * code is the CMACRO numeric code. file, line, and column locate it. message
 * is the explanation. Returns nothing. A later call does nothing once failed
 * is set. Import and expansion notes follow the error line.
 */
void Processor.report(
        int64 code,
        String file,
        int64 line,
        int64 column,
        String message) {
    if (failed) {
        return
    }
    failed = true
    io.writeErrorLine(format(
            "cmacros: error[CMACRO{:04}]: {}:{}:{}: {}",
            code,
            file,
            line,
            column,
            message))
    int64 importIndex = 0
    while (importIndex < currentImports.length) {
        String imported = currentImports[importIndex] as String
        io.writeErrorLine(format(
                "cmacros: note: imported from '{}'", imported))
        importIndex = importIndex + 1
    }
    int64 traceIndex = 0
    while (traceIndex < currentTrace.length) {
        String frame = currentTrace[traceIndex] as String
        io.writeErrorLine(format("cmacros: note: {}", frame))
        traceIndex = traceIndex + 1
    }
}
