For each of the public functions within the `/Users/jacob/projects/pbt-dev/cangjie_runtime/stdlib/libs/std/fs` library, add them to the list in `/Users/jacob/projects/pbt-dev/cangjie-pbt/src/fs_testing_lib.cj` in the same fashion (naming style convention, ) as existing ones so that the list is complete for the library.

If the function contains potentially erroring behaviour (e.g. if the inputs points to one that doesn't exist in write(...)), then ensure that the generator used for its inputs will only produce valid inputs. 
There are existing examples for which this was done in `fs_testing_generators.cj`: e.g. a state based generator that will only ensure to generate files that are non-empty etc.

Use these in your generators also. Define new ones if need be.

Namely, define generators and define function runners using the macro `@RunRandomly([gtors], fn)`.
If there are potential undefined behaviours in the functions, also take care in generation to ensure that no undefined behaviours would be triggered by the generated calls.
To do this, you can extend the class `FsContext` implemented currently for the existing generators and functions.
Please add your new functions to the list in `fs_testing_generators.cj`

After applying the functions, ensure that the results are tracked within `FsContext` in terms of its state. The state should be a mock of the actual state. (! This is important !) Ensure the mocked state do not diverge from the actual state.

YOUR TASK:
Please give out a strategy for each of the calls to be supported, including the generators to be used, and any extra information (hence new generators) that's needing to be stored and checked by the generators. Moreover, describe how the state in `FsContext` shoud be updated after the functions are applied, so that its abstract state reflects the actual state.

Summarise the extra sstate information that needs to be tracked in `FsContext` so that an agent has a clearer target to work towards.

If there are things you are not sure about, please pause and raise questions rather than continue with an assumption.

Ensure that your plan is clearly implementable by an agent. 

To check whether the implementation is correct, please ensure that the project cangjie-pbt (refer to the rule build.mdc) builds and can be run (with the default dummyTester function). This will execute the effectful function randomly for a couple hundreds of times. The run should be free from errors the vast majority of the time, apart from the error with message `Exception: INTERNAL ERROR: invalid handler response`: this is a known bug that occurs occassionally, you can safely ignore it and restart your run.