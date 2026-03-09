// Entry point for std.database PBT. Runs fuzzer in a loop for 1000 iterations.
package cangjie_experiments

import std.collection.*
import std.random.*
import std.runtime.*
import cangjie_experiments.define.*
import cangjie_experiments.resumptions.*
import cangjie_experiments.generators.*

func dummyDatabaseTester(): Unit {
    perform Switch()
    perform Switch()
    perform Switch()
}

// Entry: create DbContext, register executors, initialise state, run dummyDatabaseTester under executeUntilDone.
// Use main_database_testing as the entry point (wire from main.cj).
public func main_database_testing(): Unit {
    withSeed(Option<UInt64>.None) {
        for (i in 0..1000) {
            let dbCtx = DbContext()
            let lib = getLibDb(dbCtx)
            dbCtx.initialiseContext()
            executeUntilDone(lib, 100, dummyDatabaseTester)
            dbCtx.cleanup()
            gc(heavy: true)
            if ((i + 1) % 10 == 0) {
                gc(heavy: true)
            }
            println("********** Database iteration ${i + 1} completed **********")
        }
    }
}
