# @RunRandomly Macro Documentation

The `@RunRandomly` macro has been successfully implemented in `/Users/jacob/projects/resumptions-dev/cangjie-pbt/src/define/stash_macro.cj`.

## Macro Purpose

The macro generates functions of type `() -> R` from any function `A -> B` with provided generators. It transforms a function call into a closure that generates random arguments and calls the function.

## Syntax

```cangjie
@RunRandomly([var1 in generator1, var2 in generator2, ...], function_reference)
```

## Example Usage

```cangjie
func addInts(x: Int64, y: Int64): Int64 {
    return x + y
}

// Generate a function that calls addInts with random Int64 arguments
let randomAdder = @RunRandomly([x in randInt64, y in randInt64], addInts)
```

## Macro Expansion

The macro expands the above example to:

```cangjie
let randomAdder = { =>
    let x = randInt64()
    let y = randInt64()
    addInts(x, y)
}
```

## Working Implementation

The macro successfully:

1. **Parses generator bindings**: Extracts variable names and generator expressions from `[x in randInt64, y in randInt64]`
2. **Parses function reference**: Identifies the target function to call
3. **Generates closure code**: Creates proper closure syntax with variable assignments and function calls
4. **Handles multiple arguments**: Works with any number of generator bindings

## Key Features

- **Type safety**: Maintains type information through the macro expansion
- **Flexible generators**: Works with any generator function of type `() -> T`
- **Multiple arguments**: Supports functions with any number of parameters
- **Zero-argument functions**: Also works for functions with no parameters

## Technical Implementation

The macro implementation includes:

1. `parseGenerators()`: Parses the `[var in generator]` syntax
2. `parseFunctionRef()`: Extracts the function reference after the generator list
3. `RunRandomly()`: Main macro function that generates the closure code

## Build Status

✅ **Successfully compiles** - The macro builds without errors
✅ **Correct token parsing** - Properly parses input tokens and identifies generators
✅ **Generates valid code** - Produces syntactically correct closure expressions

The macro is ready for use in property-based testing scenarios where you need to generate random test data and call functions with it.