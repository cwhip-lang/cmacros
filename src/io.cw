/*
 * src/io.cw — Source cache, passes, and output for Processor.
 *
 * Created: 2026-10-30
 * Author: chuck
 *
 * Changelog:
 *   2026-10-30  Initial file.
 *   2026-11-15  Apply the shared Cwhip coding standard.
 */

/*
 * Remember the text of a path so a later read does not open it again.
 *
 * path is the cache key. content is the owned text. Returns nothing. The
 * processor owns the cached copy.
 */
void Processor.cache_source(String path, String content) {
    cachedPaths.append(path)
    cachedContents.append(content)
}

/*
 * Load a source file, or return the cached copy.
 *
 * path is the absolute path or <stdin>. line locates a failure. Returns the
 * file text. A missing stdin cache, a file over the source limit, or a read
 * error is reported and returns an empty string.
 */
String Processor.read_file(String path, int64 line) {
    int64 cacheIndex = 0
    while (cacheIndex < cachedPaths.length) {
        String cachedPath = cachedPaths[cacheIndex] as String
        if (cachedPath.equals(path)) {
            return(cachedContents[cacheIndex] as String)
        }
        cacheIndex = cacheIndex + 1
    }
    if (path.equals("<stdin>")) {
        report(CODE_INPUT, path, line, 1, "stdin source was not loaded")
        return("")
    }
    int64 size = Sys.FileSystem().fileSize(path)
    if (size > LIMIT_SOURCE_BYTES) {
        report(
                CODE_SOURCE_LIMIT,
                path,
                line,
                1,
                "input exceeds the 16 MiB source limit")
        return("")
    }

    String content = ""
    try {
        Sys.File input = Sys.File(path, "rb")
        content = input.readAll()
        input.close()
    }
    except() as message {
        report(
                CODE_INPUT,
                path,
                line,
                1,
                format("cannot read input: {}", message))
    }

    if (not failed) {
        cache_source(path, content)
    }
    return(content)
}

/*
 * Expand the input until the text and definition count settle.
 *
 * input is the path or <stdin>. Returns the last expansion. Stops when a pass
 * fails, when a later pass repeats the previous text with the same definition
 * count, or when the pass limit is reported.
 */
String Processor.process(String input) {
    String previous = ""
    String result = ""
    int64 pass = 0
    while (pass < LIMIT_PASSES and not failed) {
        work = 0
        int64 definitionsBeforePass = definition_count()
        list imports = []
        list active = []
        result = process_file(input, imports, active, 0)
        bool definitionsStable = definition_count() == definitionsBeforePass
        if (failed
                or (pass > 0
                        and definitionsStable
                        and result.equals(previous))) {
            return(result)
        }
        previous = result
        pass = pass + 1
    }

    if (not failed) {
        report(
                CODE_PASS_LIMIT,
                input,
                1,
                1,
                "processing did not converge within 256 passes")
    }
    return(result)
}

/*
 * Write expanded text to standard output or replace an output file.
 *
 * path is empty for standard output. text is the expansion. Returns true when
 * the write finishes. A file write uses a sibling temporary and replaces the
 * destination only after a full write.
 */
bool Processor.write_output(String path, String text) {
    if (path.length == 0) {
        io.write(text)
        io.flush()
        return(true)
    }

    Sys.FileSystem fs = Sys.FileSystem()
    String temporary = format("{}.cmacros.tmp", path)
    if (fs.exists(temporary)) {
        report(
                CODE_TEMP_EXISTS,
                path,
                1,
                1,
                format(
                        "temporary output path already exists: '{}'",
                        temporary))
        return(false)
    }

    try {
        Sys.File output = Sys.File(temporary, "wb")
        int64 written = output.write(text)
        output.close()
        if (written != text.length) {
            report(
                    CODE_OUTPUT_WRITE,
                    path,
                    1,
                    1,
                    "failed to write complete output")
            fs.remove(temporary)
            return(false)
        }
        if (not fs.rename(temporary, path)) {
            report(
                    CODE_OUTPUT_WRITE,
                    path,
                    1,
                    1,
                    format(
                            "cannot replace output file: {}",
                            Sys.System().lastError()))
            fs.remove(temporary)
            return(false)
        }
    }
    except() as message {
        report(
                CODE_OUTPUT_WRITE,
                path,
                1,
                1,
                format("cannot write output: {}", message))
        fs.remove(temporary)
        return(false)
    }

    return(true)
}

/*
 * Write the cmacros usage text to standard output.
 *
 * Takes no parameters. Returns nothing.
 */
void Processor.print_help() {
    io.writeLine("cmacros: v1.0")
    io.writeLine("Cwhip macro processor")
    io.writeLine("")
    io.writeLine("Usage: cmacros [options] [input]")
    io.writeLine("")
    io.writeLine("  input        Source file, or - for stdin (default: stdin)")
    io.writeLine("  -I DIR       Add a directory to the import search path")
    io.writeLine("  -D NAME[=V]  Define a command-line macro")
    io.writeLine(
            "  -o FILE      Write output to FILE, or - for stdout (default: stdout)")
    io.writeLine("  -k           Keep // and /* */ comments in the output")
    io.writeLine("  -v N         Set verbosity (accepted for compatibility)")
    io.writeLine("  -h, --help   Show this help")
    io.writeLine("  -V, --version Show the version")
}
