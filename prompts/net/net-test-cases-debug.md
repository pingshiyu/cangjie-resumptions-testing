We are working on a generator / executor of effects in the `net` component of the std library (`../src/net_testing_generators.cj`). 
The existing code generates inputs, and executes them on the functions in the `net` library. 
(See `../src/net_testing_entry.cj` for existing definitions and how the function executors are specified).

However, during execution, we are seeing runtime errors during random execution. Please fix the bugs here that are causing these so that execution succeeds always.

The current functions cover the `net` library, ensure that coverage stays the same, or is increased. 
For reference, the APIs being tested is in `cangjie/cangjie_runtime/stdlib/libs/std/net`.

Do not use try/catch statements to consume errors: ensure that only valid inputs are inputted into the functions and that after execution, the internal state models the concrete state accurately.
When possible, use debug traces during development to ensure that your internal abstract model captures the concrete state of the effect.

Take into consideration that execution of the effects (functions in the net library) should be quick. Thus long waits should be avoided. In those cases, if we are actually sending out network requests, it would be acceptable to timeout and give up to avoid waiting too long. Do make sure that we don't end up in the trivial case where no messages are being sent or received though (if we just time out everything).

In this task, only change the code inside the files `../src/net_testing_generators.cj` (updating generators), and `../src/net_testing_lib.cj` (registering generators).

Success criterion: `./cjpm-run.sh` runs successfully without errors.