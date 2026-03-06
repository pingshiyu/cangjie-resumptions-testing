// Entry point for std.net PBT. Registers all defined executors (TCP, Unix, UDP) and runs them via runInContext.
package cangjie_experiments

import std.collection.*
import std.runtime.*
import std.fs.*
import std.random.*
import std.math.*
import std.unittest.*
import cangjie_experiments.define.*
import cangjie_experiments.resumptions.*
import cangjie_experiments.generators.*


func dummyNetTester(): Unit {
    perform Switch()
    perform Switch()
    perform Switch()
}

// Entry: create NetContext, register all executors, initialise state, run dummyNetTester under executeUntilDone in runInContext.
// Each Switch() causes the handler to run a random UnitFn from the registered executors.
public func main_net_testing(): Unit {
    for (i in 0..1000) {
        let netCtx = NetContext("tmp")
        let lib = getLibNet(netCtx)
        netCtx.initialiseContext()
        withSeed(None) {
            executeUntilDone(
                lib, 
                3, 
                dummyNetTester)
        }
        netCtx.cleanup()
        println("********** Net iteration ${i + 1} completed **********")
    }
}
