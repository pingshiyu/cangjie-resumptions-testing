# Property-Based Testing Using Effects

Traditional unit tests can test the behaviour of a program on one input at a time.

For the implementation `f`:
```
f : a -> b
```
There is a list of concrete-value inputs `[a_0, ..., a_n]` and associated expectated 
behaviours `[B_0, ..., B_n]`, such that the exectuion
```
exec(f(a_i)) \in B_i
```
are all within the expected behaviours.

Property-based testing generalises what can be checked to more general statements. Given
a triple:
```
{ pre(a) } 
f(a) 
{ post } 
```
validate that the triple holds in all cases.

So one test describes a potentially infinite family of unit-tests based on concrete inputs.

# Generators and Reducers
Property-based testing is powered by random generation. 
To verify the property `{ pre(a) } f(a) { post }`, random test cases are generated for the
type `a` satisfying `pre(a)`, applied to `f(a)`, finding a bug (wrt the specification) if 
`post` is not satisfied.

Whilst it is possible, for every type `a`, to prepare a custom generator `Gen a`, this is 
actually often insuffucient.

This is because of preconditions: rejection sampling can be used to satisfy these, but this 
process can potentially resulting in intractable runtimes. (For probability `p` of uniformly
drawn `a` satisfying condition `pre`, one needs `1/p` expected samples, and this can easily
be exponential.)

## Generators
Thus PBT libraries needs to provide a means of writing your _own_ generators, custom made to 
satisfy the required predicates when the default case using rejection sample does not work 
satisfactorily.

Generators can be considered usual code with access to a syntax `Rand` that returns random 
values. As long as `Rand` returns random values, programs using `Rand` can exhibit random 
behaviour. 

In PBT libraries, generators are usually written using pseudo-random number generators, and 
composing random procedures together to create more sophisticated generators.

## Reducers
When a random case has been generated that triggers a bug, it's often that there is a simpler
input that still triggers the bug. 

A reducer is used to reduce the genrated input, to a smaller one that still triggers the bug.

Reducers are often written once for every type that is generated. However, another approach
as implemented in Hypothesis involves modifying the input random sequences to generate smaller
test cases, using the observation that generally, "smaller" or "simpler" input sequences 
result in simpler outputs from random functions.

# Applying Effects
We model the syntax `Rand` as an effect. This allows us to give several possible interpre-
-tations to it. It can output either:
- A pseudo-randomlly-generated output (number): used when applying generators
- The head of a fixed sequence of finite random numbers: used to treat random functions as 
deterministic functions, allowing it to be used for optimisation (reduction).
- Outputs of an SMT sampler (NOT DONE): this allows an oracle to be called, instead of 
writing a custom generator to create a value satisfying some precondition.
- Enumerated outputs (NOT DONE): this allows us to turn class QuickCheck/PBT behaviour of 
generators into SmallCheck-like behaviour, enumerating through all test cases.

Within any procedure, altering the random numbers used can often result in a "small" change
in the procedure's output. This is not always the case with any samll changes: small changes
that go over the boundary between two procedure's usage can result in big changes in the 
overall output (e.g. one changed bit can makes the previous procedure abandon, and therfore
the next part of the sequence is used by another entire generator).

Keeping track of the generator's usage of the random bits is thus important if we want to do
reductions: we want to ideally make them in regions where the output is continuous (w.r.t 
the input). This allows us to "slowly" optimise the generator to create the smallest test case,
continuous here being used so that it's more likely for the bug-triggering property to be 
maintained.

To keep track of each generator's usage, we thus introduce two more effects:
- `EnterScope : FunctionName x Params -> ()`
- `CloseScope : () -> ()`

These are called, respectively, at the beginning and end of each random generator. 
Their interpretation involves keep track of the random bits used through the call, with
`EnterScope` introducing a new node into the tree, `CloseScope` moving up a level, and `Rand`
gets additional semantics of saving the random bit drawn into the tree.

So all in all, here are the effects used, and how they are interpreted (at various points) in 
the PBT framework. Each use case corresponds to a distinct handler for the effect.
- `Rand :: () -> Int8`
    - During generation: receives random bits from source source, e.g. a PRNG
    - During generation: optionally, save the generated bits into a tree-like-structure.
    - During reduction and output: receives random bits from a finite list, e.g. the list of 
        randomness that triggered the bug, and displaying to the user the small, reduced test
        case at the end.
- `EnterScope :: String -> ()`
    - During generation and reduction: create a new node in the tree of random 
        numbers. Can also just ignore this effect if we are not going to reduce.
    - During output: ignore this effect - just continue with the resumption. We don't need to
        track how the random numbers are being used if we are just displaying an output.
- `CloseScope :: () -> ()`
    - During genration and reduction: similar to `EnterScope`, but move to the parent of the 
        current node.
    - During output: ignore this effect, as in the `EnterScope` case.
- `OutOfRand :: () -> ()`
    - This effect is called when there are no randomness left (when passing a finite sequence),
        and is handled like an exception.
    - During reduction: handles and performs some default behaviour, as it means the reduction
        applied have resulted in more randomness being consumed (thus a _more_ complex input
        being generated). We should abandon here. 
    - During output: raises an error if we ran out of randomness (when given a finite sequence)

# Example Executions

## Buggy Sorting Algorithm
Suppose we have a sorting algorithm that is obviously wrong:
```
func crappySort(l : List<Int8>) : List<Int8> {
    let ls : Set<Int8> = HashSet<Int8>(l)
    let shortl = ArrayList<Int8>(ls)
    sort(shortl, descending: true, stable: true)
    return shortl
}
```
It is wrong because it deletes repeated elements in the sorted list.

We write a desired property (in Cangjie), in that it should keep the size of the list constant.
```
func testCrappySort(l : List<Int8>) : Bool {
    return crappySort(l).size == l.size
}
```

We supply it with a generator of random lists, we just want them to have length 10. This is
using a pre-written generator of lists, composed with a generator of ints.
```
let gtor = randList(10, randInt8)
```

Running the generator on the property reveals this bug-triggering input:
```
let bugTrigger : Option<List<Int8>> = findCounterExample(42, 100, gtor, testCrappySort)
match (bugTrigger) {
    case Some(bt) => 
        println("bug found, the bug-triggering input is:");
        println(showList(", ", bt));
    case None =>
        throw Exception("oops we should've triggered a bug.")
}
```

But it is rather big... It is not clear why this triggered the bug.
```
bug found, the bug-triggering input is:
[34, -52, 74, 55, -53, -5, 55, -40, -79, -90, 80, 92, 33, -90, 18, -78, -40, -27, 72, -7, -75, -74, 23, -28, -12, 0, 45, -100, 70, -71, 106, -94]
```

We run the reducer to find a smaller input that still triggers the bug:
```
let smallBugTrigger: Option<List<Int8>> = findSmallCounterExample(42, 100, gtor, testCrappySort)
match (smallBugTrigger) {
    case Some(bt) => // bug triggered
        // reduce the BugTrigger
        println("the reduced bug-triggering input is:");
        println(showList(", ", bt));
    case None => 
        throw Exception("bug should have been triggered.")
}
```

Ahh, much better.
```
the reduced bug-triggering input is:
[0, 0]
```

## Finding a random input with a property
We don't need to strictly use the random generators as reducers. We can also use them as optimisers to find 
some output of the generator that satisfies a property.

# Future Work
- Generic optimisation framework, rather than just reductions
- SmallCheck-based interpretation of randomness
- SMT-based interpretation of randomness

- More friendly UI