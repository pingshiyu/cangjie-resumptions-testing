package cangjie_experiments.resumptions

import stdx.effect.*
import std.collection.*
import std.random.*
import std.unittest.prop_test.*
import std.unittest.common.*
import cangjie_experiments.generators.*

public func randFuncAlt<A, B>(): (A) -> B where B <: Arbitrary<B> {{ a => 
    perform Switch()
    cjRandom<B>()
}}

public func executeUntilDone(lib: ArrayList<UnitFn>, maxFuel: Int64, fn: () -> Unit): Unit {
    let ress = ArrayList<Res>()
    let fuel = Box<Int64>(maxFuel)
    
    let done : Box<Bool> = Box(false)
    try {
        fn()
        done.value = true
    } handle (_ : Switch, res : Res) {
        ress.add(res)
    }
    while (!(done.value)) {
        // resume a random function or a resumption from the list
        let hasResumptions = ress.size > 0
        if (fuel.value > 0 && cjRandom<Bool>()) {
            fuel.value -= 1
            let chosenF = lib[randomIntInRange(0, lib.size)]
            chosenF()
        } else if (hasResumptions) {
            let chosenR = ress.remove(at: randomIntInRange(0, ress.size))
            resume chosenR with ()
        } else {
            println("WARNING: no resumptions, didn't choose to run a function. skipping")
        }
    }
}

public func ignoreOutput<B>(f : () -> B): () -> Unit {{ =>
    let b = f()
    return ()
}}

// given 2 functions f, g :: (A -> B) -> C
// check for equivalence, i.e. for all functions p,
// f(p) = g(p)
// need to ensure that the p :: (A -> B) used is always the same.
// firstly, if p is not called in the same order then we wouldn't assume
// them to be the same. So we need to guarantee:
// for the ith call of p, the output is the same.
// that is, the random choices made within the framework is the same.
// need to: 
// - track random choices made during each function call
// - replay the random choices made
// - (optional) ignore the random choices made by the function itself
// but first, see if we just get the same results by fixing the random seed
// this should work for determinisitic functions?

// the randomness should be consumed by the context

/*
Differential testing
 Randomly executing test suite
 \- need to record down the choices made (or maybe just use the random seed?)
Execution of a class's functions that's marked by @LibMember, or change the semantics of @Test based
 on the overall tag on the class.
*/

public func differntialTest<R>(seed: Int64, f: () -> R, g: () -> R): Bool where R <: Equal<R> {
    // execute both functions within the same context
    return true
}