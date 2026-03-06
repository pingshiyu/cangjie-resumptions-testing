I have a testing system for testing function behaviours. How it work is this: 
- Whenever we have a function that takes as an input another function A -> B, we treat this as an opportunity to "switch context". 
    - Operationally, we've implmented this as the effect "Switch()".
    - A function can be replaced by first doing `perform Switch()`, followed by generating a random value of type B. 
- We have a bunch of functions prepared from a library, which we provide a random input for, so that they can all be executed at random.
- To keep a state, we can use a class, as is done ins library_testing.cj, in the examples.

The idea is that for a library of side-effecting functions `lib`, we assume that the anonymous functions can potentially trigger these side effects.
The main approach above is implemented in the file /Users/jacob/projects/pbt-dev/cangjie-pbt/src/library_testing.cj. 

I would like to expand the testing method further to file systems. 
For this, I would like to prepare calls of functions within `/Users/jacob/projects/pbt-dev/cangjie_runtime/stdlib/libs/std/fs`. They should work within some folder, say `tmp` within the source repo.
I would like to have the function being tested be something akin to the following: running a withFile function which can perform some continuation `k :: FileHandle -> Output`.
```
function withFile(path, k) {
  let f = open(path)
  try {
    k(f)
  } finally {
    close(f)
  }
}
```
The function can be invaliated if we close the file within the continuation k. 
But the user doesn't know it and we want to expose this with the testing framework. Thus we want the function call to close the file `n` to be one that has a decent chance of being sampled.

YOUR TASK:
 - For the function calls in `libs/std/fs`, collect them into a list of `UnitFn`s, called `libFs`. In the same way as what has been done for the collections library in `library_testing.cj`. 
  - For this, you are going to need to supply random arguments for the `@RunRandomly` macro, of type `() -> Args`. You will need to write your own generator for filepaths, filenames that are in the `/tmp` folder. The file contents can be done using the default `cjRandom<String>` function or similar.
  - The random arguments should refer to files within within the `tmp` folder of `cangjie-pbt`, and contain small arguments.
  - In particular, file names should be short so that it is likely that a clash of double close described above can happen.
- In your entry point, the `withFile` function should be run with `executeUntilDone(@RunRandomly([cjRandom<Path>, randFunc<File, ()>], withFile))` arguments (adapt the type accrodingly depending on how you set things up). Moreover, it should be wrapped around in a `runInContext(seed, lib, 20) {..}` scope like in `library_testing`. 

DOCUMENTATION AND EXECUTION:
Please code up this in Cangjie. To refer to the relevant documentation in Cangjie, there is a script to perform semantic/textual searches of the Cangjie documentation. More details are in the document `/Users/jacob/projects/pbt-dev/cangjie_docs_db/LLM_INSTRUCTIONS.md`.

This is important. You need to read the documentation to code correctly. Therefore, if you cannot run the script described in LLM_INSTRUCTIONS, then stop rather than continue.

Please create new files rather than modifying old files for your changes.
The main function in `/Users/jacob/projects/pbt-dev/cangjie-pbt/src/main.cj` can be used as an entry point for your program.

To run the program for testing, please first set up the environment with:
`source /Users/jacob/projects/resumptions-dev/software/cangjie/envsetup.sh`
Then, inside `/Users/jacob/projects/pbt-dev/cangjie-pbt`
run the command `cjpm build` to build and expand macros, and `cjpm run` to execute. 
If build fails, try first `cjpm clean` for a fresh environment.