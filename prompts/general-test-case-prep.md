Look into the library `/home/pings/projects/cangjie-resumptions/cangjie_runtime/stdlib/libs/std/database`. 

I would like to create a fuzzer that executes the functions within the library randomly, such that the calls to the fuzzer should NEVER crash (unless it is a real bug within the implementation - in this case, if you believe there is a bug within the library, you should record its trigger, the expected behaviour, and the observed behaviour).

To run the function randomly, you need to create random inputs.
Some functions will have context dependent constraints for its inputs, and this means you need to define a context in which the generators and executors can depend on.
This means you may need to create custom random generators for your functions.

The functions can often have side effects. If these do, please either mock them within a context or perform the side effects in a controlled environment (e.g. filesystems fuzzer performs these in a controlled envrionment, and the net fuzzer mocks the effects). 
Keep the context and generators relatively small, so that bugs and interesting behaviour can be triggered through random execution.

The fuzzer should avoid using `try/catch` blocks to absorb errors as much as possible: the non-crashing behaviour should be from generating the correct inputs for the function. 
Additionally, if a function in the library takes a functional argument (e.g. of type A -> B), you can use the `randFunc<A, B>` function as a random generator of functions. 

Ensure you cover as much of the public functions of `database` as possible. 
If any functions are not possible/infeasible to cover, please document these with reasons why.

The task for the agnet is to create the files:
- `database_testing_entry.cj` - contains the entry point: it should contain the "dummyTester" function, defined as in the existing examples, and run the fuzzer in a loop for 1000 iterations. 
- `database_testing_generators.cj` - contains the actual random generator and calls to the libraries.
- `database_testing_lib.cj` - contains the defined executors: the function along with their generators.

The success criterion for a fuzzer is that running the fuzzer in a loop for 1000 iterations should pass without errors.

If you believe a genuine bug is found within the `database` library, in which case these should be recorded down in an .md file separately, then the bug trigger is to be skipped temporarily.

Let the agent know that the script `./cjpm-run.sh` can be used to run the function `main.cj`. A function call is alreayd present `main_io_testing()`: this is to be the entry point of the `database` fuzzer.

Please provide a plan for an agent to follow, by examining the `database` library.
Decide what information does the context need to include, what generators are to be used for each function in the `database` library.
You can refer to existing examples in `fs_testing_*` and `net_testing_*`. This testing campaign should follow a similar format. 

At the end of the task, please document the overall structure of the fuzzer, the design decisions made and their reasoning (from what has been discovered during development).
The document should be detailed enough to inform another agent, and humans, of how it was implemented, and allow another agent/human to reimplement the fuzzer, sidestepping the common mistakes that may occur.