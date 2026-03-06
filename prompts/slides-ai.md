# Testing Higher-Order Functions Using Effects

---

## Slide 1: The problem and the idea

**Testing higher-order functions using effects**

- **Problem:** Higher-order functions take callbacks; we want to test them under *effectful* callbacks (side effects, non-determinism) to catch bugs that only appear with "bad" or unusual callback behaviour.
- **Idea:** Treat the higher-order function call as an **effect**. The interpreter:
  - Stores the **resumption** (continuation) when the callback is invoked.
  - Either runs a **random effectful function** from a library, or **resumes** a previously stored resumption.
- **Result:** Callback executions can be **composed and interleaved** in non-trivial ways, so we explore many execution orderings and effect combinations.

**Limitations of existing approaches:**

- Hard to test with **random** or **diverse** effects (often only hand-written mocks or a few fixed scenarios).
- Lack of **composability**: combining multiple effectful callbacks in varied orders is manual and limited.

---

## Slide 2: How it works — effects from the std library

**Effectful std library and composability**

- Effectful functions are drawn from the language's **std library** (filesystem, I/O, etc.), giving a realistic set of effects.
- **Any higher-order call inside the std library** is also turned into an effect: store resumption, then either run a random effectful function or resume a stored resumption.
- **Composability:** Because everything is expressed as effects, we can **compose** and **interleave** calls from different parts of the std library; the test harness explores their interleavings automatically.
- **Testing goal:** Check that the higher-order function is correct **with respect to** whatever effects its callback can perform — and catch bugs that only appear with side-effecting or "tricky" callbacks.

---

## Slide 3: Example — `withFile` (simplified)

**Example: `withFile(path, k)`**

- **Spec:** `withFile(path, k)` creates a file at `path`, opens it, runs `k(file)` (e.g. multiple times), then closes and checks invariants.
- **Bugs we can detect:**
  - Callback **deletes** the file → later existence check fails.
  - Callback **modifies** file content → "initial content unchanged" check fails.
  - File **already exists** when creating → creation fails.
- **Mechanism:** We pass **effectful** `k` (e.g. from a generator). The effect interpreter stores resumptions and interleaves; some schedules will trigger the buggy paths above.

```cj
func withFile(path: Path, k: (File) -> Unit): Unit {
  // open file for reading and apply k(f)
  for (fp in Subdirs(Parent(path))) {
    let f = File(fp, Mode.Read)
    k(f)
    f.close()
  }
  // open the file again for append
  let g = File(path, Mode.ReadWrite)
  // Write: end marker, e.g. ‘]’, ‘</tag>’
  closeStructure(g)
  fa.close()
}
```

---

## Slide 4: Meaningful execution — AI-generated stateful generators

**Making executions meaningful: stateful generators (with AI)**

- **Challenge:** We must run effectful functions in **meaningful** ways that respect preconditions (e.g. "open before read"), otherwise we only get crashes/no-ops.
- **Approach:** Use **AI agents** to build **stateful generators** per section of the std library:
  - For each library function, the generator produces **random but safe** calls (using state so that sequences are valid).
  - **Easily checkable outcome:** Any sequence of random calls from the generator should **not** crash or cause undefined behaviour. The process is self-checking and can be fuzzed rigorously.
- **Improving quality (optional):**
  - **Observability:** For effects like the filesystem, the agent can check that the generator's internal state **simulates** the real effect (e.g. file tree), so root causes of bugs become apparent earlier.
  - Prefer **no try/catch** in generators so that calls are not "wasted" on no-ops; the generator should produce valid sequences by construction.
- **Cycle:** Specify "build stateful generator for this part of the library" → agent produces/improves generators → execute random sequences and check for crashes/undefined behaviour → iterate.

**Summary:** This enables a **new kind of testing**: higher-order APIs tested under diverse, composable, effectful callbacks, with generators that keep executions valid and observable.
