# std.io fuzzer: structure, design decisions, and reimplementation guide

This document describes the overall structure of the std.io property-based fuzzer, the design decisions made during development, and their reasoning. It is intended to allow another agent or human to understand the implementation and reimplement the fuzzer while avoiding common mistakes.

---

## 1. Overall structure

The fuzzer is split into three main files plus shared infrastructure:

| File | Role |
|------|------|
| **io_testing_entry.cj** | Entry point: defines `dummyTester`, runs the fuzzer in a loop for 1000 iterations, and wires randomness, context lifecycle, and memory management. |
| **io_testing_generators.cj** | Context, generators, and executors: `IoContext` (mutable pools of IO objects), generator functions `() -> T` for random inputs, and executor methods that perform library calls using context indices. |
| **io_testing_lib.cj** | Library of executors: builds an `ArrayList<UnitFn>` by registering each executor with the `@RunRandomly` / `@RunRandomlyQuiet` macro and the appropriate generators. |

Shared pieces:

- **resumptions/exec_loop.cj**: `executeUntilDone(lib, maxFuel, fn)` — runs `fn` under a `Switch` handler, collects resumptions, and in a loop either runs a random lib function (consuming fuel) or resumes a random stored resumption until `fn` completes.
- **define/run_random_macro.cj**: `RunRandomly` and `RunRandomlyQuiet` — expand to a closure that runs generators (with `cjRandom` / effectful randomness), calls the given function, and optionally prints "starting"/"ending" (RunRandomly only).
- **generators/base.cj**: `withSeed(Option<UInt64>, f)`, `cjRandom<T>()`, and base generators — provide effect-based randomness (`GetRandom`) and helpers used by context generators.

Execution flow at a high level:

1. **Entry**: `main_io_testing()` runs inside `withSeed(None)` so all randomness goes through one `GetRandom` handler.
2. **Per iteration**: Create or reuse `ctx` and `lib`; call `ctx.initialiseContext()`; run `executeUntilDone(lib, maxFuel, dummyTester)`; call `ctx.cleanup()`; call `gc(heavy: true)`; optionally refresh `ctx`/`lib` every N iterations.
3. **Inside executeUntilDone**: `dummyTester()` is run; it performs `Switch()` three times, so the handler gets three resumptions. The loop then either (a) runs a random closure from `lib` (each closure runs its generators then the executor) or (b) resumes one of the stored resumptions, until the initial `fn()` run completes (`done.value == true`).

---

## 2. Context: what it is and why

**Purpose:** Library calls need **context-dependent** inputs: e.g. "an index into existing ByteBuffers", "a ByteBuffer that contains valid UTF-8", "an existing BufferedInputStream". The context holds mutable pools of objects (ByteBuffers, streams, readers, writers) and ensures indices and references stay valid within an iteration.

**What the context holds (IoContext):**

- **byteBuffers** / **utf8ByteBuffers**: Pools of `ByteBuffer`; UTF-8 subset is used for `readString`/`readToEnd` and must contain valid UTF-8.
- **bufferedInputs** / **bufferedOutputs**: Wrappers around ByteBuffers.
- **chainedInputs** / **multiOutputs**: ChainedInputStream / MultiOutputStream.
- **stringReaders** / **stringWriters**: StringReader / StringWriter built on buffered streams.

All are **var** fields of type `ArrayList<...>` so that `cleanup()` can replace them with fresh lists (see below).

**Lifecycle per iteration:**

1. **initialiseContext()**: (Re)populate pools with a small, fixed set of objects so every iteration starts from a known state: e.g. a few ByteBuffers (empty, fixed capacity, with random bytes, with UTF-8 string bytes), one BufferedInputStream/OutputStream, one ChainedInputStream/MultiOutputStream, one StringReader/StringWriter. This keeps the context small and avoids unbounded growth at the start of the iteration.
2. **During executeUntilDone**: Lib functions may **add** to these lists (e.g. create new ByteBuffers, new streams) up to **capped sizes** (`MAX_BYTE_BUFFERS`, `MAX_BUFFERED_STREAMS`, etc.). Caps prevent a single iteration from growing pools without bound.
3. **cleanup()**: **Replace** each list with a new `ArrayList()`, rather than calling `clear()`. Rationale: in some implementations, `clear()` may only set logical size to 0 while the backing array still holds references to old elements; replacing the list drops the old backing storage and helps the GC. Using **var** list fields is required for this.

**Design decisions:**

- **Index-based access**: Executors take indices (e.g. `i: Int64`) and do `byteBuffers[i]`, not raw references. Generators like `randByteBufferIndex()` return `() -> Int64` that sample from `0..byteBuffers.size`. This keeps the API uniform and avoids passing long-lived references that might outlive the context.
- **Small initial state + caps**: Initial state is minimal (a few buffers/streams); caps limit growth during the iteration so that bugs and interesting behaviour can still be triggered without blowing memory or making the search space huge.
- **In-memory only**: All streams are backed by ByteBuffers (no real files/sockets). This keeps the fuzzer deterministic and avoids external state; the goal is to stress the library API, not the OS.

---

## 3. Generators and executors

**Generator shape:** Generators used by the macro are **thunks** `() -> T`: each call produces one random value. They are defined as closures, e.g. `randByteBufferIndex(): () -> Int64 {{ => randIntRangeLocal(0, byteBuffers.size) }}`. They are **effectful**: they call `randomIntInRange` / `cjRandom` (which performs `GetRandom`), so they must run inside `withSeed`.

**Executor shape:** An executor is a method on the context that performs the actual library call and has a fixed signature (e.g. `(i: Int64, buffer: Array<Byte>) -> Unit`). It does **not** perform `Switch`; it just does IO. The macro wraps it so that **arguments are generated at call time** (when the closure is invoked by the execution loop), not when the lib is built.

**RunRandomly / RunRandomlyQuiet:** The macro takes a list of bindings `[x in g1(), y in g2()]` and a function reference (e.g. `ctx.byteBufferRead`). It expands to a closure that: (1) runs each generator and binds the result; (2) calls the function with those arguments; (3) (RunRandomly only) prints "starting: ..." and "ending: ...". The result is wrapped in `ignoreOutput(...)` so the closure type is `() -> Unit` (UnitFn). **RunRandomlyQuiet** omits the two printlns to reduce allocation when running many iterations (important for the IO fuzzer; see OOM section).

**Why not try/catch:** The requirement is that the fuzzer should not crash unless there is a real bug; correct behaviour should come from **generating valid inputs** (e.g. indices in range, UTF-8 buffers for readString). So generators must respect preconditions (buffer index in `0..byteBuffers.size`, etc.). Wrapping calls in try/catch would hide precondition violations and is avoided.

---

## 4. Execution loop and effects

**dummyTester:** Defined exactly as in existing examples: it performs `Switch()` three times and then returns. So the first time `fn()` is run in `executeUntilDone`, the handler intercepts three Switches and stores three resumptions; `fn()` does not complete yet (`done.value` stays false).

**executeUntilDone:**

- **try/handle**: Runs `fn()`; on `Switch`, the handler adds the resumption to `ress` and does not resume (so the initial `fn()` is effectively suspended).
- **while (!done.value)**: Either (1) if there is fuel and a random choice, run a random lib function `chosenF()` (and decrement fuel), or (2) if there are resumptions, pick one at random, remove it from `ress`, and `resume chosenR with ()`. When the original `fn()` eventually completes, `done.value` is set to true and the loop exits.

So the same "run" interleaves execution of the initial tester (via resumptions) with random library calls. All of this runs inside the same `withSeed` and the same `Switch` handler, so randomness and resumptions are consistent.

**Fuel:** `maxFuel` limits how many random lib calls can be made per iteration so that a single iteration does not run forever and does not allocate unboundedly. Tuning fuel (e.g. 100) trades off coverage per iteration vs. total iterations achievable before OOM.

---

## 5. Randomness

- **withSeed(Option<UInt64>, f)**: Runs `f()` under a handler for `GetRandom`. If `Some(s)`, uses `Random(s)` for reproducibility; if `None`, uses `Random()` for different runs. All `cjRandom<T>()` and hence all generators that use it are driven by this single handler.
- **No randFunc for some library parameters:** If a library function takes a **callback** (e.g. predicate `(Rune) -> Bool`) and **calls that callback internally**, that call is **not** under our effect handler. So if the callback performs `Switch()` (as `randFunc` would), we get `UnhandledCommand`. For such parameters we use **non-effect** generators (e.g. `randPredicateRuneToBool()` returning a closure that ignores its argument and returns a pre-generated Bool). See `prompts/io/io-uncovered.md` for the readUntil(predicate) case.

---

## 6. OOM and memory (design and pitfalls)

**Observed behaviour:** Running 1000 iterations with a single context and single lib, and only calling `cleanup()` + GC between iterations, often leads to `OutOfMemoryError` after a relatively small number of iterations (e.g. tens to low hundreds), with high variance depending on the random path.

**Hypotheses that were tested:**

1. **ArrayList.clear() retention:** The idea that `clear()` might only set size to 0 and leave references in the backing array, so that old ByteBuffers/streams stay reachable. **Mitigation:** Use **var** list fields and in `cleanup()` **replace** each list with a new `ArrayList()` instead of calling `clear()`. This is kept as a safe practice; alone it did not remove OOM in testing.
2. **Long-lived ctx/lib and effect runtime:** Keeping the same ctx and lib for many iterations, with many steps that perform `GetRandom`, may cause the effect runtime or GC to retain state or continuations that reference the current environment. **Mitigation:** Periodically **refresh** ctx and lib (e.g. every 10 iterations: `ctx = IoContext(); lib = getLibIo(ctx)`) and call `gc(heavy: true)` after each iteration and after each refresh. This **consistently** allows more iterations (e.g. 171–207 with refresh every 10).

**Design decisions in code:**

- **cleanup()** replaces lists with new `ArrayList()` and uses **var** list fields.
- **Explicit GC:** `gc(heavy: true)` (from `std.runtime`) after each iteration and after each ctx/lib refresh.
- **Periodic refresh:** Every N iterations (e.g. 10), assign new `IoContext()` and new `getLibIo(ctx)` so the previous ctx/lib become unreachable.
- **RunRandomlyQuiet:** Used in the IO lib to avoid two printlns per step; reduces allocation and helps run more iterations when combined with the above.
- **Caps on pool sizes:** `MAX_BYTE_BUFFERS`, etc., limit growth **within** an iteration so that a single iteration does not allocate unboundedly.

**Common mistakes to avoid:**

- Do not assume that `clear()` alone is enough to drop references; prefer replacing lists in cleanup when the context is long-lived or reused.
- Do not keep a single ctx/lib for the entire 1000 iterations without periodic refresh and explicit GC; OOM is much more likely.
- Do not use `randFunc` (or any effectful callback) for library parameters that are **invoked by the library** outside our handlers; use a non-effect generator that returns a plain closure instead.
- If the goal is to run 1000 iterations reliably, consider lower fuel, RunRandomlyQuiet, and/or a larger heap in addition to refresh and GC.

---

## 7. Uncovered / infeasible API surface

Documented in **prompts/io/io-uncovered.md**:

- **StringReader.readUntil(predicate):** Use a non-effect predicate generator (e.g. `randPredicateRuneToBool()`), not `randFunc<Rune, Bool>`, because the library calls the predicate outside our effect handler.
- **StringReader.runes() / lines():** Not registered as separate executors; other read methods cover the main API to keep the fuzzer smaller.
- **StringWriter overloads:** Only a subset of write overloads are covered; others omitted for size.

---

## 8. Reimplementation checklist

When reimplementing this fuzzer (or a similar one for another library):

1. **Entry:** One main entry (e.g. `main_io_testing`) that runs inside `withSeed`; loop for the desired iterations; per iteration: initialise context, run `executeUntilDone(lib, fuel, dummyTester)`, cleanup context, `gc(heavy: true)`, and optionally refresh ctx/lib every N iterations.
2. **Context:** Define a context type with **var** list fields for mutable pools; implement `initialiseContext()` to set a small, deterministic starting state; implement `cleanup()` by **replacing** each list with a new `ArrayList()`, not only `clear()`.
3. **Caps:** Enforce maximum sizes on all pools (e.g. MAX_BYTE_BUFFERS) and check before adding in executors.
4. **Generators:** Expose thunks `() -> T` that use `randomIntInRange` / `cjRandom` and read from context (e.g. indices in range). For callbacks that the library will call outside our handlers, provide **non-effect** generators (no perform).
5. **Executors:** One method per library operation; they take indices and/or generated values and call the library; they do not perform effects (no Switch).
6. **Lib:** Build `ArrayList<UnitFn>` by registering each executor with `@RunRandomly` or `@RunRandomlyQuiet` and the correct generators. Use Quiet if you need to run many iterations and allocation is a concern.
7. **dummyTester:** Implement exactly as in examples (e.g. three `perform Switch()` then return) so the execution loop has resumptions to interleave with lib calls.
8. **No try/catch:** Rely on valid generators and precondition checks so that normal runs do not throw; reserve throws for real bugs and document/skip those cases if needed.
9. **Memory:** Use periodic ctx/lib refresh, explicit GC after each iteration (and after refresh), and list replacement in cleanup; consider Quiet and fuel tuning for long runs.

---

## 9. Running the fuzzer

- Use **./cjpm-run.sh** to run the binary (which calls `main_io_testing()` when wired from `main.cj`).
- Success criterion: the fuzzer runs for the intended number of iterations (e.g. 1000) without errors. If OOM or other resource limits are hit, apply the memory measures above and/or reduce fuel or increase heap (e.g. via `cjpm.toml` profile.run.env).

This document and **prompts/io/io-uncovered.md** together provide the rationale for the current implementation and the main pitfalls to avoid when reimplementing or extending the fuzzer.
