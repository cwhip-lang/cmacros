/*
 * src/imports.cw — Import lookup and per-file expansion for Processor.
 *
 * Created: 2026-11-15
 * Author: Auto
 *
 * Changelog:
 *   2026-11-15  Initial file.
 */

/*
 * Find an imported file next to the current file, then on the include path.
 *
 * currentFile is the file that contains the import. requested is the path text
 * from the directive. Returns the absolute path, trying a .txt suffix, or an
 * empty string when nothing is found.
 */
String Processor.resolve_import(String currentFile, String requested) {
    Sys.FileSystem fs = Sys.FileSystem()
    String local = fs.join(fs.dirname(currentFile), requested)
    if (fs.isFile(local)) {
        return(fs.absolutePath(local))
    }
    if (fs.isFile(format("{}.txt", local))) {
        return(fs.absolutePath(format("{}.txt", local)))
    }

    int64 index = 0
    while (index < includePaths.length) {
        String directory = includePaths[index] as String
        String candidate = fs.join(directory, requested)
        if (fs.isFile(candidate)) {
            return(fs.absolutePath(candidate))
        }
        if (fs.isFile(format("{}.txt", candidate))) {
            return(fs.absolutePath(format("{}.txt", candidate)))
        }
        index = index + 1
    }

    return("")
}

/*
 * Report whether a string list contains a name.
 *
 * values is the list. name is the string to find. Returns true when an element
 * equals name.
 */
bool Processor.in_list(list values, String name) {
    int64 index = 0
    while (index < values.length) {
        String value = values[index] as String
        if (value.equals(name)) {
            return(true)
        }
        index = index + 1
    }
    return(false)
}

/*
 * Read one file and expand it, tracking import nesting.
 *
 * file is the path or <stdin>. imports is the chain already entered. active is
 * the macro expansion stack. depth is the import depth. Returns the expanded
 * text, or an empty string after a reported failure.
 */
String Processor.process_file(
        String file,
        list imports,
        list active,
        int64 depth) {
    list parentImports = currentImports
    currentImports = imports
    if (failed) {
        currentImports = parentImports
        return("")
    }
    if (depth > LIMIT_NESTING) {
        report(
                CODE_IMPORT_DEPTH,
                file,
                1,
                1,
                "maximum import nesting depth (128) exceeded")
        currentImports = parentImports
        return("")
    }
    String canonical = file
    if (not file.equals("<stdin>")) {
        canonical = Sys.FileSystem().absolutePath(file)
        if (canonical.length == 0) {
            report(CODE_INPUT, file, 1, 1, "cannot resolve source path")
            currentImports = parentImports
            return("")
        }
    }
    if (in_list(imports, canonical)) {
        report(CODE_IMPORT_CYCLE, file, 1, 1, "import cycle detected")
        currentImports = parentImports
        return("")
    }
    list nestedImports = []
    int64 importIndex = 0
    while (importIndex < imports.length) {
        nestedImports.append(imports[importIndex])
        importIndex = importIndex + 1
    }
    nestedImports.append(canonical)
    currentImports = nestedImports
    String content = read_file(canonical, 1)
    String output = process_text(
            canonical,
            content,
            1,
            1,
            [],
            [],
            active,
            nestedImports,
            depth)
    currentImports = parentImports
    return(output)
}
