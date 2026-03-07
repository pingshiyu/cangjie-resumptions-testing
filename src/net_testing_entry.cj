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

// #region agent log
private const debugLogPath: String = "/home/pings/projects/.cursor/debug-66d5f9.log"
private func debugLog(location: String, message: String, dataStr: String, hypothesisId: String): Unit {
    let line = "{\"sessionId\":\"66d5f9\",\"location\":\"" + location + "\",\"message\":\"" + message + "\",\"dataStr\":\"" + dataStr + "\",\"hypothesisId\":\"" + hypothesisId + "\"}\n"
    let _ = File.appendTo(Path(debugLogPath), line.toArray())
}
// #endregion


func dummyNetTester(): Unit {
    perform Switch()
    perform Switch()
    perform Switch()
}

// Entry: create NetContext, register all executors, initialise state, run dummyNetTester under executeUntilDone in runInContext.
// Each Switch() causes the handler to run a random UnitFn from the registered executors.
public func main_net_testing(): Unit {
    withSeed(None) {
        for (i in 0..1000) {
            // #region agent log
            debugLog("net_testing_entry.cj:iter", "iter_start", "i=" + i.toString(), "D")
            // #endregion
            let netCtx = NetContext("tmp")
            let lib = getLibNet(netCtx)
            // #region agent log
            debugLog("net_testing_entry.cj:init", "before_initialiseContext", "i=" + i.toString(), "D")
            // #endregion
            netCtx.initialiseContext()
            // #region agent log
            debugLog("net_testing_entry.cj:exec", "before_executeUntilDone", "i=" + i.toString(), "D")
            // #endregion
            executeUntilDone(
                lib, 
                25, 
                dummyNetTester)
            // #region agent log
            debugLog("net_testing_entry.cj:exec", "after_executeUntilDone", "i=" + i.toString(), "D")
            // #endregion
            // #region agent log
            debugLog("net_testing_entry.cj:cleanup", "before_cleanup", "i=" + i.toString(), "C")
            // #endregion
            netCtx.cleanup()
            // #region agent log
            debugLog("net_testing_entry.cj:cleanup", "after_cleanup", "i=" + i.toString(), "C")
            // #endregion
            println("********** Net iteration ${i + 1} completed **********")
        }
    }
}
