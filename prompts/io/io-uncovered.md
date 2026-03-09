# std.io fuzzer – uncovered / infeasible items

## StringReader.readUntil(predicate: (Rune) -> Bool)

**Reason:** The plan suggested using `randFunc<Rune, Bool>` for the predicate. The library calls the predicate from inside `readUntil`; that call is not run under our effect handler. If the predicate performs `Switch()` (as `randFunc` does), we get `UnhandledCommand`. So we use a **non-effect predicate**: `randPredicateRuneToBool()` returns a closure that ignores its argument and returns a pre-generated `Bool`. This still exercises `readUntil(predicate)` without performing effects inside the library.

## StringReader.runes() and StringReader.lines()

**Reason:** These return iterators. Not registered as separate executors to keep the fuzzer small; `read()`, `readln()`, and `readToEnd()` already cover the main StringReader API.

## StringWriter overload set

**Reason:** Only a subset is covered: `write(String)`, `write(Int64)`, `write(Bool)`, `write(Rune)`, `writeln()`, `flush()`. Other numeric/float overloads are omitted to keep the fuzzer size manageable.

## OOM investigation and re-evaluated hypotheses

### Hypothesis A: ArrayList.clear() retains references

**Idea:** In many implementations, `clear()` sets logical size to 0 but the backing array may still hold references to elements. During an iteration the context lists grow (e.g. `byteBuffers` 5→8 via lib calls). After `cleanup()` only indices 0..4 are overwritten by the next `initialiseContext()`; indices 5..7 could still reference previous ByteBuffers, so we retain objects across iterations.

**Test:** In `IoContext.cleanup()`, replace each list with a fresh `ArrayList()` instead of calling `clear()`, and use `var` for the list fields so they can be reassigned.

**Result:** OOM still occurs (high variance: ~14–56 iterations when using a single ctx/lib; ~38–56 with periodic refresh). So either the runtime’s `clear()` already drops refs, or the main retention is elsewhere. The list-replacement change is kept as a safe mitigation.

### Hypothesis B: Long-lived ctx/lib and effect runtime

**Idea:** The same `ctx` and `lib` (46 closures capturing `ctx`) are used for many iterations. Each step runs a lib closure that performs `GetRandom` (via `cjRandom`). The effect runtime may retain continuations or internal state that reference the current environment (lib, ctx). So as long as the same ctx/lib stay in scope, the live set or allocation pressure grows.

**Test:** Periodically replace ctx and lib (e.g. every 10 iterations) so the previous ctx/lib become unreachable, and call `gc(heavy: true)` after each iteration and after each refresh.

**Result:** Periodic refresh consistently allows more iterations (e.g. 171–207 with refresh every 10). Using a single ctx/lib (no refresh) causes OOM much earlier (~14 iters). So limiting the lifetime of ctx/lib helps.

### Current fixes in code

1. **cleanup():** Replace each context list with a new `ArrayList()` instead of `clear()` (and `var` list fields in `IoContext`).
2. **Explicit GC:** Call `gc(heavy: true)` after each iteration (and after each ctx/lib refresh).
3. **Periodic refresh:** Every 10 iterations set `ctx = IoContext()` and `lib = getLibIo(ctx)` so old references can be collected.
4. **Optional:** Use `@RunRandomlyQuiet` to reduce per-step allocation (fewer string/println allocations); or lower fuel if needed.

### Memory and iteration count

Context list sizes are capped (e.g. `MAX_BYTE_BUFFERS = 16`) to avoid unbounded growth during the random steps per iteration. Even with the above fixes, iteration count before OOM remains path-dependent; reaching a full 1000 may require lower fuel, Quiet mode, or a larger heap.
