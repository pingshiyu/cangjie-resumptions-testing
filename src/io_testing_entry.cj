// Entry point for std.io PBT. Runs fuzzer in a loop for 1000 iterations.
package cangjie_experiments

import std.collection.*
import std.random.*
import std.runtime.*
import cangjie_experiments.define.*
import cangjie_experiments.resumptions.*
import cangjie_experiments.generators.*

func dummyTester(): Unit {
    perform Switch()
    perform Switch()
    perform Switch()
}

public func main_io_testing(): Unit {
    withSeed(None) {
        var ctx = IoContext()
        var lib = getLibIo(ctx)
        for (i in 0..1000) {
            ctx.initialiseContext()
            executeUntilDone(lib, 100, dummyTester)
            ctx.cleanup()
            gc(heavy: true)
            if ((i + 1) % 10 == 0) {
                ctx = IoContext()
                lib = getLibIo(ctx)
                gc(heavy: true)
            }
            println("********** IO iteration ${i + 1} completed **********")
        }
    }
}
