# Generating Random Functions Using Resumptions
Whilst primitive types (with explicit constructors) can be randomly generated fairly easily,
it is difficult to generate functions at random.

Existing approaches include enumerating program ASTs, which is a large undertaking.
Alternatively, QuickCheck's approach uses the fact that the types:
 - `Gen (a -> b) ~= a -> Gen b`
contains the same information (by expanding the definition of QuickCheck's 
`Gen a ~ Seed -> Integer -> a`). 

So implementing a random generator of functions involves augmenting a generator of type `b` 
using a known value of type `a`.

We use the fact that effect handlers allows program executions to be paused, altered and 
and resumed, to be a means to generate random behaviours in place of a function (something
of type `A -> B`).

More concretely, when we're faced with an unknown function of type `A -> B`, and given a 
cohort of existing functions `A -> B` (themselves may also contain unknown functions), we
either:
 - run one of the existing function, and resume a resumption `B -> R` on its output
 - run an existing resumption `A -> R` on te inputs of the function
 - as a backup, generate a random type `B` and resume a resumption `B -> R` (this is the
 approach implemented in QuickCheck)

## Initial Implementation
In place of a function of type `Unit -> Unit`, we use an effect `e` of type `Unit -> Unit`.

This effect is interpreted as:
- Save existing resumption to the function call
- Resume a random resumption, or start a new function call

#### Observation:
Note that throughout the execution process, the number:
- `#pending_function_calls + #pending_resumptions`
can only decrease through execution.

At every step, either one of the function calls, or a pending resumption is selected for 
execution. 

Since in the beginning, `pending_resumptions == 1`, we need multiple function calls in order
for the randomness of execution to take effect.

To do so, we start (in parallel) several functions calls to begin the execution. These function
calls are identical in this initial implementation.

```javascript
func handleUnknownUnit(fns: List<() -> Unit>, rs: List<Resumption<Unit, Unit>>, fn : () -> Unit): Unit {
    try {
        fn()
    } handle(f : UnknownFunction<Unit, Unit>, r : Resumption<Unit, Unit>) {
        // either resume an existing resumption, or start a function in the list
        rs.add(r)

        let path = randBool(0.50)
        if (path && !fns.isEmpty()) {
            let chosenFnIx = randIntRange(0, fns.size)
            let chosenFn = fns.remove(at:chosenFnIx)
            handleUnknownUnit(fns, rs) {
                chosenFn()
            }
        } else {
            // resume a random existing continuation
            let chosenRIx = randIntRange(0, rs.size)
            let chosenR = rs.remove(at:chosenRIx)
            handleUnknownUnit(fns, rs) {
                resume chosenR
            }
        }
    }
}
```

and then to actually execute, we populate `fn` initially with several functions, and `rs` initially being
empty.
Here we use another handler `runExtRand` which deals with the randomness that we needed during execution
(we used `randBool` and `randIntRange` effects).

```javascript
func executeUnitUnit() {
    let r: Random = Random()
    let fns: List<() -> Unit> = ArrayList<() -> Unit>([fi(1), fi(2), fi(3), fi(4)])
    let rs : List<Resumption<Unit, Unit>> = ArrayList<Resumption<Unit, Unit>>()
    runExtRand(r) {
        handleUnknownUnit(fns, rs) {
            let fn = fns.remove(at:0)
            fn()
        }
    }
}
```

## Generalising to Arbitrary Functions `A -> A`
However, the above only executes functions of type `Unit -> Unit`.

The issue is that behaviours of functions cannot be tested effectively - they execute 
independently apart from global side effects of the functions. 

We need to pass parameters into functions in a random way as well. This would introduce
dependence of one function's execution to another.

When functions return a value, we would also look for a resumptions that could take it,
and launch that resumption. 

If none could take it, we would need a fallback. We use a random value generator 
as a backup. I.e. throw away the value generated, and relaunch a resumption using what 
we have.

```javascript
func handleUnknownSingleType<A>(fns: List<(A) -> A>, rs: List<Resumption<A, A>>, fn: (A) -> A): (A) -> A {{ a =>
    try {
        fn(a)
    } handle(f: UnknownFunction<A, A>, r: Resumption<A, A>) {
        rs.add(r)

        let path = randBool(0.50)
        if (path && !fns.isEmpty()) {
            let chosenFIx = randIntRange(0, fns.size)
            let chosenF = fns.remove(at:chosenFIx)
            handleUnknownSingleType<A>(fns, rs, chosenF)(f.arg)
        } else {
            let chosenRIx = randIntRange(0, rs.size)
            let chosenR = rs.remove(at:chosenRIx)
            let a0 = perform BackpocketGenerator<A>()
            handleUnknownSingleType<A>(fns, rs, { x: A => resume chosenR with x })(a0)
        }
    }
}}
```

## Effectification: State-based Effect Interpretation
The last implementation uses the args `fns`, `rs` as a part of the handler for the `UnknownFunction`
effect. 
We need to maintain the arguments at every step of the recursion, which is extra work in programming for 
maintenance, and makes the code less readable.

More importantly, our state can grow very quickly as we support more types (`n`) and their possible resumptions 
(`O(nˆ2)`), making the explicit state difficult and error-prone to maintain.

Function arguments could be replaced by immediate effects here: `fns` and `rs` are concrete state 
variables that the function call can possibily transform.
We can eliminate the need to supply these variables by using effects to deccribe every operations that
we might want to perform on these states. 

We use the existing state in following ways (along with their effects-based translation, code -> effect):
 * `!fns.isEmpty()` => `perform HasFns<A, B>()`
 * `let chosenRIx = randIntRange(0, rs.size); rs.remove(at:chosenRIx)` => `perform GetRandomResumption<A>()`
 * `rs.add(res)` => `perform AddResumption<A, Y>(rs)`
 * ... and so on.

```javascript
func handleUnknownSimplified<X, A, Y>(fn: (X) -> Y) : (X) -> Y {{ a =>
    try {
        fn(a)
    } handle(f: UnknownFunction<A, A>, r: Resumption<A, Y>) {
        perform AddResumption<A, Y>(r)
        let hasFns = perform HasFn<A, A>()

        let path = randBool(0.50)
        if (path && hasFns) {
            let chosenF = perform GetRandomFn<A, A>()
            let chosenR = perform GetRandomResumption<A, Y>()
            let fOut = handleUnknownSingleType<A, A, A>(chosenF)(f.arg)
            handleUnknownSingleType<A, A, Y>({ x: A => resume chosenR with x })(fOut)
        } else {
            let chosenR = perform GetRandomResumption<A, Y>()
            let a0 = perform BackpocketGenerator<A>()
            handleUnknownSingleType<A, A, Y>({ x: A => resume chosenR with x })(a0)
        }
    }
}}
```

Note that these effects are parameterised by generic type variables. 
Thus in order to extend the function to support more resumption types and function types, one simple has to
add implementations for effects at specific type variables.

We can provide handlers for these operations later on, for instance to support `Unit` and `Int64` resumptions,
functions and random generators:
```javascript
func handleStash<Y>(s: Stash<Y>, fn: () -> Y): Y {
    try {
        fn()
    } handle(e: AddResumption<Int64, Y>) {
        s.intRes.add(e.r)
        resume with ()
    } handle(e: AddResumption<Unit, Y>) {
        s.unitRes.add(e.r)
        resume with ()
    } handle(e: GetRandomResumption<Int64, Y>) {
        let chosenRIx = randIntRange(0, s.intRes.size)
        let chosenR = s.intRes.remove(at:chosenRIx)
        resume with chosenR
    } handle(e: GetRandomResumption<Unit, Y>) {
        let chosenRIx = randIntRange(0, s.unitRes.size)
        let chosenR = s.unitRes.remove(at:chosenRIx)
        resume with chosenR
    } handle(e: HasResumption<Unit, Y>) {
        resume with s.unitRes.isEmpty()
    } handle(e: HasResumption<Int64, Y>) {
        resume with s.intRes.isEmpty()
    } handle(e: GetRandomFn<Int64, Int64>) {
        let chosenFIx = randIntRange(0, s.intFns.size)
        let chosenF = s.intFns.remove(at:chosenFIx)
        resume with chosenF
    } handle(e: GetRandomFn<Unit, Unit>) {
        let chosenFIx = randIntRange(0, s.unitFns.size)
        let chosenF = s.unitFns.remove(at:chosenFIx)
        resume with chosenF
    } handle(e: HasFns<Int64, Int64>) {
        resume with !s.intFns.isEmpty()
    } handle(e: HasFns<Unit, Unit>) {
        resume with !s.unitFns.isEmpty()
    } handle(e: BackpocketGenerator<Int64>) {
        resume with randSmallInt64()
    } handle(e: BackpocketGenerator<Unit>) {
        resume with ()
    }
}
```
Extending to other types (meaning more functions where `HandleUnknown` would be usable) would involve
extending the implementations seen here. 
`HandleUnknown` itself doesn't actually need to change: separation of concerns, and code is easier
to understand / read / maintain.

Moreover, this is a handler of _only_ immediate effects, meaning we incur minimal runtime cost by using
effects for our implementation, in the meanwhile buying a lot more extensibility and maintainability.

Such a pattern of separating the deferred and immediate handlers can be useful elsewhere too.

## Supporting Arbitrary Types
Building on the previous implementation, it becomes a type-puzzles problem to generalise it to arbitrary
function types `UnknownFunction<A, B>`. 

Our handlers are parameterised by `<X, A, B, Y>`, which can be read as: "handle the `UnknownFunction<A, B>`
instances (`A -> B`) within a function of type `X -> Y`.

We call recursively these handlers, potentially paremeterised with different types:
```javascript
func handleUnknown<X, A, B, Y>(fn: (X) -> Y): (X) -> Y {{ x => 
    /*
    requires implementation of:
    - {Add, GetRandom}Resumption<B, Y>
    - {Has, GetRandom}Resumption<A, Y>
    - {Has, GetRandom}Fn<A, B>
    - BackpocketGenerator<B>
    */
    try {
        fn(x)
    } handle(f: UnknownFunction<A, B>, r: Resumption<B, Y>) {
        // stash the current resumption
        perform AddResumption<B, Y>(r) // <B, Y>
        let hasFns = perform HasFn<A, B>()
        let hasPreRs = perform HasResumption<A, Y>()
        // POST: !(perform GetResumptions<B, Y>()).isEmpty()

        let path = randBool(0.20)
        if (path && hasFns) {
            // start a new function, then use post_rs
            let chosenF = perform GetRandomFn<A, B>()
            let chosenR = perform GetRandomResumption<B, Y>()
            let fOut = handleUnknown<A, A, B, B>(chosenF)(f.arg)
            handleUnknown<B, A, B, Y>({ b : B => resume chosenR with b })(fOut)
        } else if (hasPreRs) {
            // resume directly from the function inputs
            let chosenR = perform GetRandomResumption<A, Y>()
            handleUnknown<A, A, B, Y>({ a : A => resume chosenR with a })(f.arg)
        } else {
            // backup: resume by generating a fresh random argument to r
            let b0 = perform BackpocketGenerator<B>()
            let chosenR = perform GetRandomResumption<B, Y>()
            handleUnknown<B, A, B, Y>({ b : B => resume chosenR with b })(b0)
        }
    }
}}
```

Executing this can be done in a similar way to the `Unit -> Unit` case:
```javascript
let fns: List<(Int64) -> Int64> = ArrayList<(Int64) -> Int64>()
for (i in 0..50) {
    // prepare 100 random functions
    fns.add(fint_add(i))
    fns.add(fint_mul(i))
}

let r : Random = Random()
let s : Stash<Int64> = Stash<Int64>(fns)
runExtRand(r) {
    handleStash(s) {
        handleUnknown<Int64, Int64, Int64, Int64>(fns[0])(randSmallInt64())
    }
} 
```
where we need to be careful when layering our handlers: ensuring that the handlers
in higher scopes is going to catch the effects emitted by lower scopes.

## On Termination and Complexity
Suppose a single function terminates in `ns` steps, running a maximum of concurrent
`nf` functions, starting from 1 function, and starting new functions with probability
`p`.

This has minimum runtime of `ns`, and maximum runtime of `ns * nf`, with higher 
runtime based on the value of `p` chosen.

We don't have a theoretical analysis of the expected runtime, however here is a plot 
of how the growth varies with `p`.

![](relation_simulate_p.png "Growth of Runtime with `p` Chosen")

## One Handler, Many `UnkownFunction`s
The previous implementation does not allow for the execution of multiple `UnknownFunction`
types. 
This limits its applicability: we can only use the handler to execute functions which all 
have the same types.
However, in a library, we would like to ideally execute, in the same run, multiple function
and resumptions of different types.

The reason we are fixed to a single function type is because in the recursion, we specifically
recur with the handler for `UnknownFunction<A, B>`.

In this version, we leave the job of recursion to a top-level handler:
```javascript
func fillFunction<A, B, Y>(f: UnknownFunction<A, B>, r: Resumption<B, Y>): Y {
    // stash the current resumption
    perform AddResumption<B, Y>(r) // <B, Y>
    // idea: library fns might have Unknowns too, so those will trigger recursively
    let hasFns = perform HasFn<A, B>()
    let hasPreRs = perform HasResumption<A, Y>()
    // POST: !(perform GetResumptions<B, Y>()).isEmpty()

    let path = randBool(0.20)
    if (path && hasFns) {
        // start a new function, then use post_rs
        let chosenF = perform GetRandomFn<A, B>()
        let chosenR = perform GetRandomResumption<B, Y>()
        let fOut = chosenF(f.arg)
        resume chosenR with fOut
    } else if (hasPreRs) {
        // resume directly from the function inputs
        let chosenR = perform GetRandomResumption<A, Y>()
        resume chosenR with f.arg
    } else {
        // backup: resume by generating a fresh random argument to r
        let b0 = perform BackpocketGenerator<B>()
        let chosenR = perform GetRandomResumption<B, Y>()
        resume chosenR with b0
    }
}

func handleUnknown<Y>(fn: () -> Y): Y {
    try {
        fn()
    } handle(f: UnknownFunction<Int64, Bool>, r: Resumption<Bool, Y>) {
        handleUnknown<Y> { fillFunction<Int64, Bool, Y>(f, r) }
    } handle(f: UnknownFunction<Int64, Int64>, r: Resumption<Int64, Y>) {
        handleUnknown<Y> { fillFunction<Int64, Int64, Y>(f, r) }
    } handle(f: UnknownFunction<List<Int64>, Bool>, r: Resumption<Bool, Y>) {
        handleUnknown<Y> { fillFunction<List<Int64>, Bool, Y>(f, r) }
    } handle(f: UnknownFunction<List<Int64>, List<Int64>>, r: Resumption<List<Int64>, Y>) {
        handleUnknown<Y> { fillFunction<List<Int64>, List<Int64>, Y>(f, r) }
    }
}
```

Note here, `handleUnknown` can now deal with an set of `UnknownFunction<A, B>` instances, and
the implementation is also extensible to other function types. 
Within `fillFunction`, the handler for the resumed program is left unspecified: effects generated
here will be captured by the top-level handler `handleUnknown`, who is responsible for dispatching
the correct handler of `UnknownFunction<A, B>`.

We also explicitly treat the handler as a handler of `UnknownFunction<A, B>` terms, thus simplifying
the handler's signature to use just one generic type argument, `Y`. 
This also simplifies the usage of the handler:
```javascript
let s : Stash = Stash()
s.intIntFns = ArrayList<(Int64) -> Int64>([
    fint_mul(0), fint_add(1), fint_mul(2), fint_add(3) 
])
s.lintLintFns = ArrayList<(List<Int64>) -> List<Int64>>([
    mapEFaked<Int64, Int64>, map2EFaked<Int64, Int64>, filterEFaked<Int64>
])
s.lintBoolFns = ArrayList<(List<Int64>) -> Bool>([
    anyFaked<Int64>, noneFaked<Int64>, isEmpty<Int64>, contains<Int64>(0), contains<Int64>(1)
])
s.lintOintFns = ArrayList<(List<Int64>) -> Option<Int64>>([
    reduceFaked<Int64>
])
s.lintIntFns = ArrayList<(List<Int64>) -> Int64>([
    count<Int64>
])

let r : Random = Random()
let output: List<Int64> = runExtRand(r) { handleStash(s) { handleUnknown {
    let input : List<Int64> = randList<Int64>(10, randInt64)()
    println("input: ${showList(", ", input)}")
    map2EFaked(input)
}}}

println("output: ${showList(", ", output)}")
```

Note that the stash contains functions of arbitrary types, all of which may be executed (as long
as there exists an opportunity to execute them).