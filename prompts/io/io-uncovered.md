# std.io fuzzer – uncovered / infeasible items

## StringReader.readUntil(predicate: (Rune) -> Bool)

**Reason:** The plan suggested using `randFunc<Rune, Bool>` for the predicate. The library calls the predicate from inside `readUntil`; that call is not run under our effect handler. If the predicate performs `Switch()` (as `randFunc` does), we get `UnhandledCommand`. So we use a **non-effect predicate**: `randPredicateRuneToBool()` returns a closure that ignores its argument and returns a pre-generated `Bool`. This still exercises `readUntil(predicate)` without performing effects inside the library.

## StringReader.runes() and StringReader.lines()

**Reason:** These return iterators. Not registered as separate executors to keep the fuzzer small; `read()`, `readln()`, and `readToEnd()` already cover the main StringReader API.

## StringWriter overload set

**Reason:** Only a subset is covered: `write(String)`, `write(Int64)`, `write(Bool)`, `write(Rune)`, `writeln()`, `flush()`. Other numeric/float overloads are omitted to keep the fuzzer size manageable.

## Memory and iteration count

Context list sizes are capped (e.g. `MAX_BYTE_BUFFERS = 16`) to avoid unbounded growth and OOM during the 1000 random steps per iteration. In memory-constrained environments the process may hit "Out of memory" before completing 1000 iterations; using the project’s `profile.run.env` (large heap) or reducing fuel per iteration can help reach 1000 iterations.
