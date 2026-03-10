// Runtime verbosity for RunRandomly printing.
// Set from entry points (e.g. main_collections_testing, main_net_testing) before calling
// executeUntilDone so that generated closures optionally hide start/end lines or argument values.
// Any module that uses @RunRandomly must import cangjie_experiments.run_random_config.*
package cangjie_experiments.run_random_config

public enum RunRandomlyVerbosity {
    | Quiet   // no output
    | StartEnd  // "starting: f(...)" and "ending: f" only (no argument values)
    | Full   // start, full argument list, end
}

var runRandomlyVerbosity: RunRandomlyVerbosity = RunRandomlyVerbosity.Full

public func setRunRandomlyVerbosity(v: RunRandomlyVerbosity): Unit {
    runRandomlyVerbosity = v
}

public func runRandomlyShowStartEnd(): Bool {
    match (runRandomlyVerbosity) {
        case Quiet => false
        case StartEnd => true
        case Full => true
    }
}

public func runRandomlyShowArgs(): Bool {
    match (runRandomlyVerbosity) {
        case Quiet => false
        case StartEnd => false
        case Full => true
    }
}
