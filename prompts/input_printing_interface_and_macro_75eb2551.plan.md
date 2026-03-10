---
name: Input printing interface and macro
overview: Add a shared InputPrintable interface in a submodule; extend the RunRandomly macro to print function and arguments on one line with brackets and commas; support randFunc by printing the generator type string; use a "printing not supported" placeholder for types without custom print; respect Cangjie's rule that imported types must extend the interface in the same module as the interface.
todos: []
isProject: false
---

# Plan: Input printing interface, macro printing, and fs fuzzer implementation

**Assumption:** All arguments to `RunRandomly` (other than those from `randFunc<...>`) are assumed to implement the printing interface `InputPrintable`. Call sites must ensure every such type has an extension implementing `InputPrintable`. For generator expressions that are `randFunc<A, B>`, the macro prints the type string (e.g. `randFunc<Int64, Bool>`) instead of calling `.inputPrintString()` on the function value. Types that cannot implement the interface (e.g. Rune, function types used elsewhere) must use `RunRandomlyQuiet` at that call site.

---

## 1. Add a printing interface and where to define extensions

**Goal:** A single interface that types implement to supply a string for logging. Types without a custom implementation return a placeholder string (not empty). **Extensions for imported/std types must live in the same module as the interface** (Cangjie restriction).

**Module layout (important):** The compiler expects `cangjie_experiments.input_print` to be a **submodule**. Create **`src/input_print/input_print.cj`** (directory + file), not a single file `src/input_print.cj`. Use `package cangjie_experiments.input_print`.

**Interface and placeholder:**

```cangjie
public interface InputPrintable {
    func inputPrintString(): String
}

let PRINT_NOT_SUPPORTED: String = "<printing not supported>"
```

- For types that have no custom printing yet, return `PRINT_NOT_SUPPORTED` (not `""`) so the log clearly indicates printing is not implemented for that type.

**Cangjie restriction — imported types:** In Cangjie, an **imported type cannot extend an imported interface** in another module. So extensions for std types (`stdFs.Path`, `SeekPosition`, `SocketAddress`, etc.) **must be defined in the same module that defines `InputPrintable`**, i.e. in `src/input_print/input_print.cj`. That module must import `std.fs as stdFs`, `std.io.*`, `std.net.*` as needed. Do **not** define `extend stdFs.Path <: InputPrintable` (or similar) in fs_testing_generators or other fuzzer modules—it will fail to compile.

**Where to define extensions:**

- **In `src/input_print/input_print.cj`** (same file as the interface): All extensions for types that are (a) shared by multiple fuzzers, or (b) from another package (std). Concretely:
  - **Shared / primitive / std:** `Int64`, `Bool`, `UInt8` (Byte), `Int8`, `String`, `Array<Byte>` (with custom `"<" + this.size.toString() + " bytes>"`), `ArrayList<T> where T <: InputPrintable` (return `PRINT_NOT_SUPPORTED`), `stdFs.Path` (custom: `this.normalize().toString()`), `SeekPosition`, `SocketAddress`. Use `PRINT_NOT_SUPPORTED` for any type that has no custom representation.
  - **Int8** is required so that `ArrayList<Int8>` satisfies `ArrayList<T> where T <: InputPrintable` in collections (e.g. reduce_, filterMap_).
- **Fuzzer-specific types that are not from std:** If a type is defined in the same package and used only by one fuzzer, the extension can in principle live in that fuzzer’s module—but because of the “imported type” rule, any type coming from std (Path, SeekPosition, SocketAddress, etc.) must stay in input_print.

**Macro usage:** The macro generates either `print(var.inputPrintString());` or, for `randFunc<...>` generators, `print("<generator token string>");` (see Section 2). Call sites must import `cangjie_experiments.input_print.*`. For extensions on std types (e.g. `SeekPosition`) to be visible, the call site may need to import the std module that defines that type (e.g. `import std.io.*` in io_testing_lib) so the compiler can apply the extension.

---

## 2. Macro: print function and arguments on one line with brackets and commas

**File:** [src/define/run_random_macro.cj](src/define/run_random_macro.cj)

**Goal:** One line per call: `starting: funcRef(arg1, arg2, ...)` so debugging shows the function and all arguments together. Use commas between arguments.

**Changes:**

1. **Starting line and opening bracket (when `verbose`):** Emit `print("starting: " + funcRefStr);` then `print("(");` (no newline yet).
2. **Variable bindings:** Unchanged: loop and emit `let var = generator()();` for each variable.
3. **Arguments on the same line:** In a loop over arguments:
   - **Special case for `randFunc`:** If `generators[i].toTokens().toString()` contains `"randFunc"`, emit `print(genStr);` where `genStr` is that token string (e.g. `"randFunc < Int64 , Bool >"`). This displays the function type (A → B) without requiring function values to implement `InputPrintable`.
   - **Otherwise:** Emit `print(var.inputPrintString());`.
   - **Separator:** Between arguments emit `print(", ");` (comma and space).
4. **Closing bracket and newline:** After the loop emit `print(")");` then `println();`.
5. **Ending line:** Keep `println("ending: " + funcRefStr);` as is when `verbose`.
6. **RunRandomlyQuiet:** When `verbose` is false, no "starting"/"ending" and no argument prints.

**Token building:** Use `Token(TokenKind.IDENTIFIER, varNames[i])` and `quote(print($(varToken).inputPrintString());)` for non-randFunc arguments. For randFunc, use `generators[i].toTokens().toString()` and `quote(print($(genStr));)`. Verified: splicing a Token as the receiver of a member call works (see [src/define/stash_macro.cj](src/define/stash_macro.cj)).

**Example output:** `starting: fg.fileWriteTo(tmp/foo, <12 bytes>)` or `starting: map_(randFunc < Int64 , Bool >, <printing not supported>)`.

---

## 3. Fs library fuzzer

**Scope:** [src/fs_testing_lib.cj](src/fs_testing_lib.cj) registers RunRandomly with argument types from [src/fs_testing_generators.cj](src/fs_testing_generators.cj): `stdFs.Path`, `Array<Byte>`.

**Implementation:** Because Path (and any std type) cannot extend InputPrintable in a fuzzer module, **do not add** `extend stdFs.Path` or `extend Array<Byte>` in fs_testing_generators. Define both extensions in **`src/input_print/input_print.cj`**:
- `extend stdFs.Path <: InputPrintable { public func inputPrintString(): String { this.normalize().toString() } }`
- `extend Array<Byte> <: InputPrintable { public func inputPrintString(): String { "<" + this.size.toString() + " bytes>" } }`

Fs_testing_lib (and fs_testing_entry) only need `import cangjie_experiments.input_print.*`; no extension code in the fs fuzzer files.

---

## 4. Other fuzzers (io, net, collections)

**Io:** Use **RunRandomlyQuiet** for the three calls whose argument types cannot implement InputPrintable: (1) `v in ctx.randRune()` (Rune is primitive), (2) `predicate in ctx.randPredicateRuneToBool()` (function type), (3) `v in ctx.randRune()` for stringWriterWriteRune. All other io RunRandomly calls can use RunRandomly. Ensure **io_testing_lib** has `import std.io.*` so the `SeekPosition` extension from input_print is applied.

**Net:** No extension in net_testing_generators; `SocketAddress` is extended in input_print. Net_testing_lib imports input_print.

**Collections:** Use **RunRandomly** (not Quiet) for all higher-order tests that use `randFunc<...>` (e.g. map_, filter_, all_, reduce_, filterMap_, flatMap_, forEach_, fold_, inspect_). The macro’s randFunc special case prints the generator type string. Ensure types like `ArrayList<Int8>` are supported by having `extend Int8 <: InputPrintable` in input_print (returning `PRINT_NOT_SUPPORTED`).

**Fs_testing_entry:** The call that uses `k in randFunc<File, Unit>` can stay as **RunRandomlyQuiet** (or be switched to RunRandomly if the randFunc special case is desired for that call; the plan leaves it as Quiet to avoid printing the continuation type).

---

## 5. Imports

- Every file that uses `RunRandomly` (or RunRandomlyQuiet) and has argument printing (or could have it) must **import** `cangjie_experiments.input_print.*`.
- **io_testing_lib.cj** must also **import std.io.*** so that the `SeekPosition` extension from input_print is visible when the argument type is SeekPosition.

---

## Summary and file list

| Step | Action |
|------|--------|
| 1 | Create **src/input_print/input_print.cj** (submodule) with `package cangjie_experiments.input_print`, interface `InputPrintable`, constant `PRINT_NOT_SUPPORTED = "<printing not supported>"`, and all extensions: Int64, Bool, UInt8, Int8, String, Array<Byte> (custom), ArrayList&lt;T&gt; where T &lt;: InputPrintable, stdFs.Path (custom), SeekPosition, SocketAddress. Import std.collection.*, std.fs as stdFs, std.io.*, std.net.*. |
| 2 | In [src/define/run_random_macro.cj](src/define/run_random_macro.cj): when verbose, emit `print("starting: " + funcRefStr); print("(");` then bind variables; then for each argument: if generator token string contains "randFunc" then `print(genStr);` else `print(var.inputPrintString());`; between args `print(", ");`; then `print(")"); println();`. Keep "ending" println. |
| 3 | Do **not** add Path/Array&lt;Byte&gt; extensions in fs fuzzer; they live in input_print. Add import input_print in fs_testing_lib, fs_testing_entry. |
| 4 | Io: RunRandomlyQuiet for the three Rune/predicate calls; io_testing_lib: add import std.io.*. Net: no extensions in net module. Collections: use RunRandomly for randFunc-based tests; Int8 extension in input_print for ArrayList&lt;Int8&gt;. |
| 5 | Add `import cangjie_experiments.input_print.*` in fs_testing_lib, fs_testing_entry, io_testing_lib, net_testing_lib, collections_testing_lib. |

**RunRandomlyQuiet:** When `verbose` is false, no "starting"/"ending" and no argument prints.

**Macro splice:** Splicing a Token as receiver works: `quote(print($(varToken).inputPrintString());)`. For randFunc, use `generators[i].toTokens().toString()` and `quote(print($(genStr));)`.
