# Diagnostics and limits

Source-processing errors use the stable form

```text
cmacros: error[CMACROxxxx]: path:line:column: explanation
```

Locations refer to the original file and a one-based line and column, with
the exceptions below. When useful, import and macro expansion notes follow
the error. An import note is `cmacros: note: imported from '{path}'` and has
no line number. A macro note names the expansion site and where the macro
was defined. Startup/usage errors and the initial cannot-open-input error
do not include a source location. Startup/usage errors use exit status 2;
source, resource, and output failures use status 1; success, help, and
version use status 0. No ANSI color is required.

`.message` writes a separate line, `{path}:{line}: message: {text}`, to
standard error and continues. That line has no `cmacros:` prefix, column, or
`CMACRO` code.

The code ranges follow the
[canonical Cwhip diagnostic contract](https://github.com/cwhip-lang/cwhip/blob/master/doc/DIAGNOSTICS.md):
0001-0999 usage/startup, 1000-1999 source or language errors, 2000-2999
resources and configuration, 3000-3999 subprocess/transport, and 9000-9999
unexpected or cleanup failures. `cmacros` currently uses:

| Code(s) | Meaning |
| --- | --- |
| 0001 | Argv parse failure or more than one positional input |
| 1000-1009 | Invalid directive/definition (including `.undef` of an unknown name), expansion depth or cycle, `.error`, macro call/arity, malformed conditional (including mixed `@`/bare comparisons and a bare name compared with a value), or misplaced `.else` |
| 2000-2009 | Input/output failure, source/work/import/output limits, import lookup/cycle, or non-convergent passes |

`CMACRO0001` exits 2. It covers argv parse failures and more than one
positional argument. Omitting the input reads standard input; that is not
`CMACRO0001`. A positional path that cannot be opened, including after the
`.txt` suffix step, is `CMACRO2000` and exits 1, with no source location.

`CMACRO2002` (import nesting) and `CMACRO2003` (import cycle) are reported
at column 1 of line 1 of the file being entered. That location is not the
`.import` line. `CMACRO2008` and `CMACRO2009` are reported at column 1 of
line 1 of the destination path. `CMACRO2008` means the sibling
`{dest}.cmacros.tmp` already exists. The destination is left untouched, and
the temporary file is left in place, so a leftover temporary blocks
replacement. `CMACRO2009` is a failure while writing that temporary or
renaming it onto the destination.

The implementation has no subprocess or transport phase, so 3000-3999 is
reserved. No current `cmacros` path allocates codes in 9000-9999; that range
remains reserved for future unexpected-runtime or cleanup diagnostics.

The finite processing limits are deliberate safeguards:

| Resource | Limit |
| --- | ---: |
| One source file | 16 MiB |
| Import nesting | 128 |
| Macro/conditional expansion nesting | 128 |
| Work iterations | 2,000,000 per pass; 20,000,000 total |
| Expanded output | 7,000,000 bytes |
| Passes before non-convergence error | 256 |

Limits are checked before standard output is emitted and before an output
file is replaced. Limits and code assignments are part of the CLI contract;
the 3000-3999 and 9000-9999 ranges remain available for future errors without
renumbering existing codes.
