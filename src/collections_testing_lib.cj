package cangjie_experiments

import cangjie_experiments.define.*
import cangjie_experiments.input_print.*
import stdx.effect.*
import std.collection.*
import std.random.*
import std.unittest.prop_test.*
import std.unittest.common.*
import cangjie_experiments.resumptions.*
import cangjie_experiments.resumptions.*
import cangjie_experiments.utils.*
import cangjie_experiments.generators.*

// User code.
// example functions
func effectfulFunction(label: String): UnitFn {{ =>
    println("${label}: entry")
    perform Switch() // call ext function
    println("${label}: called Switch 1")
    perform Switch() // call ext function
    println("${label}: called Switch 2")
}}

func randObject<T>() : T {
    perform GenRandom<T>()
}

class ExampleClass {
    public ExampleClass() {}
    public func f1() {}
    public func f2(i : Int64) : String { "f2 called" }
    private func p1() {}
    private func p2(s : String) : Int64 { -1 }
}

func getContext() : ArrayList<UnitFn> {
    // let lib = ArrayList<UnitFn>([ // these may produce Switch effects.
    //     effectfulFunction("one"),
    //     effectfulFunction("two"),
    //     effectfulFunction("three"),
    // ])
    let o1_ExampleClass = ExampleClass()
    let o1_fns = ArrayList([
        @RunRandomly([], o1_ExampleClass.f1),
        @RunRandomly([x in randInt64], o1_ExampleClass.f2)
    ])

    let o2_ExampleClass = ExampleClass()
    let o2_fns = ArrayList([
        @RunRandomly([], o2_ExampleClass.f1),
        @RunRandomly([x in randInt64], o2_ExampleClass.f2)
    ])

    let libCollectionsH = ArrayList([
        // these functions are higher order; randFunc<...> args are printed as the type string (e.g. randFunc<Int64, Bool>)
        @RunRandomly([f in randFunc<Int64, Int64>, ls in cjRandom<ArrayList<Int64>>], map_),
        @RunRandomly([f in randFunc<Int64, Bool>, ls in cjRandom<ArrayList<Int64>>], map_),
        @RunRandomly([f in randFunc<Int64, Bool>, ls in cjRandom<ArrayList<Int64>>], filter_),
        @RunRandomly([f in randFunc<Int64, Bool>, ls in cjRandom<ArrayList<Int64>>], all_),
        @RunRandomly([f in randFunc<Int64, Bool>, ls in cjRandom<ArrayList<Int64>>], none_),
        @RunRandomly([f in randFunc<Int64, Bool>, ls in cjRandom<ArrayList<Int64>>], any_),
        @RunRandomly([f in randFunc<(Int8, Int8), Int8>, ls in cjRandom<ArrayList<Int8>>], reduce_),
        @RunRandomly([f in randFunc<Int8, ?Bool>, ls in cjRandom<ArrayList<Int8>>], filterMap_),
        @RunRandomly([f in randFunc<Bool, ArrayList<Bool>>, ls in cjRandom<ArrayList<Bool>>], flatMap_),
        @RunRandomly([f in randFunc<Bool, Unit>, ls in cjRandom<ArrayList<Bool>>], forEach_),
        @RunRandomly([f in randFunc<(Int64, Bool), Int64>, e in randInt64, ls in cjRandom<ArrayList<Bool>>], fold_),
        @RunRandomly([f in randFunc<Int64, Unit>, ls in cjRandom<ArrayList<Int64>>], inspect_),
    ])
    let libCollections = ArrayList([
        // End operations from end_operation.cj
        @RunRandomly([ls in cjRandom<ArrayList<Int64>>], isEmpty),
        @RunRandomly([ls in cjRandom<ArrayList<Int64>>], count),
        @RunRandomly([element in cjRandom<Int64>, ls in cjRandom<ArrayList<Int64>>], contains_),
        @RunRandomly([ls in cjRandom<ArrayList<Int64>>], max),
        @RunRandomly([ls in cjRandom<ArrayList<Int64>>], min),
        @RunRandomly([ls in cjRandom<ArrayList<Int64>>], first),
        @RunRandomly([ls in cjRandom<ArrayList<Int64>>], last),
        @RunRandomly([n in cjRandom<Int64>, ls in cjRandom<ArrayList<Int64>>], at_),
        
        // Middle operations from middle_operation.cj
        @RunRandomly([ls in cjRandom<ArrayList<Int64>>], enumerate_),
        @RunRandomly([ls in cjRandom<ArrayList<ArrayList<Int64>>>], flatten_),
        @RunRandomly([other in cjRandom<ArrayList<Int64>>, ls in cjRandom<ArrayList<Int64>>], zip_),
        @RunRandomly([other in cjRandom<ArrayList<Int64>>, ls in cjRandom<ArrayList<Int64>>], concat_),
        @RunRandomly([count in randIntRange_(0, 10), ls in cjRandom<ArrayList<Int64>>], skip_),
        @RunRandomly([count in randIntRange_(0, 10), ls in cjRandom<ArrayList<Int64>>], take_),
        @RunRandomly([count in randIntRange_(1, 5), ls in cjRandom<ArrayList<Int64>>], step_),
        // @RunMembers(ExampleClass, randObject<ExampleClass>)
    ])
    let overallLib : ArrayList<UnitFn> = ArrayList()
    overallLib.add(all: libCollectionsH)
    overallLib.add(all:libCollections)
    overallLib.add(all:o1_fns)
    overallLib.add(all:o2_fns)

    return overallLib
}

func main_collections_testing() {
    let lib = getContext()
    // runInContext(None, lib, 100) {
    //     executeRandomly(100)
    // }

    // expectation: two runs should result in the same sequence of functions called: the 
    // calls to the unknown functions `f` are controlled.
    println("comparing two runs of functions:")
    let seed : Option<UInt64> = Some(55)
    withSeed(seed) {
        executeUntilDone(
            lib,
            20,
            @RunRandomly([f in randFunc<Int64, Bool>, ls in cjRandom<ArrayList<Int64>>], map_))
    }
    println("================================================")
    withSeed(seed) {
        executeUntilDone(
            lib,
            20,
            @RunRandomly([f in randFunc<Int64, Bool>, ls in cjRandom<ArrayList<Int64>>], filter_))
    }
    return 0
}