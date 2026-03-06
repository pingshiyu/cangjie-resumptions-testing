Please prepare me a few slides to show case the technique of testing higher-order functions using effects.
The idea is this: when we have a higher-order function, we treat this as an effect.
In the interpreter of the effect, we store the resumption, and jump into either a random effectful function, or resuming an existing resumption stored earlier. 

The effectful functions are taken from the existing std library of the programming language, which covers a range of effects available to the language.
Within the STD library as well, any higher-order function call is also turned into an effect and treated similarly (store resumption to be restarted later). 
Using effects means the effects (function calls) can be composed together easily in a nontrivial way: their executions gets interleaved.

This allows us to test functions that takes as arguments function calls for correctness, with respect to the effects that the function call can perform: allowing us to detect bugs that would be triggered with side-effecting functions as inputs. An example of this can be found in `cangjie/cangjie-pbt/src/fs_testing_entry.cj`, in particular the `withFile` function. (Please shorten and simplify the function in the presentation to ensure clarity, only include essential details).

To address the issue of executing effects in a meaningful way, we use AI agents to produce generators that will run the effectful functions in a meaningful way that satisfies the function's preconditions.
In an iterative process, we specify, for sections of the std library:
- A stateful generator is to be built
- For each function of the library, have a generator that produces random safe function calls to the function. Using the state to ensure the calls are valid. Easily checkable outcome: any sequences of the calls in the function should not crash or trigger undefined behaviour.
The above enables a cycle for the agent to optimise the generators. To help with the quality of the generators produced, we could also specify further:
- If observability is possible, e.g. filesystem effects, we could also the agent to check that the internal state of the generator being used is a simulation of the filesystem effect. This allows bugs to be detected early.
- Ask the agent to avoid using try/catch blocks in the generators, so that the calls are not "wasted" on noops.

Please prepare some slides to highlight the advantages of this approach, and the new kind of testing that this enables.
Also highlight the limitations of existing testing approaches (e.g. not being able to test for random effects, lack of composability).
Please limit the slides to 3-4 pages.