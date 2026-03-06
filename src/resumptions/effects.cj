package cangjie_experiments.resumptions

import stdx.effect.*
import std.random.*

// ================ Unit public type resumptions ================
/*
Todo:
- Turn library functions into ones that uses Switch
- Try running a library of functions
- Running functions that requires a state (part of an object) 
- make private fns public, and run them
*/

// Switch: effect that takes an A and returns a B
public class Switch <: Command<Unit> {}

public type Res = Resumption<Unit, Unit>
public type UnitFn = () -> Unit

public class AddRes <: Command<Unit> {
    public AddRes(public let r : Res) {}
}

public func handleSwitch(f : UnitFn) : Unit {
    try {
        f()
    } handle (e : Switch, r : Res) {
        perform AddRes(r)
    }
}

public class GetRandomRes <: Command<Res> {}
public class HasRes <: Command<Bool> {}
public class GetRandomUnitFn <: Command<() -> Unit> {}

public class UnhandledInstance <: Exception {
    public init(msg: String) {
        super(msg)
    }

    public override func getClassName(): String {
        "UnhandledInstance"
    }
}

class IsDone <: Command<Bool> {}
class SetDone <: Command<Unit> {
    public SetDone(public let s : Bool) {}
}
class StoreV<R> <: Command<Unit> {
    public StoreV(public let s : R) {}
}
class GetV<R> <: Command<R> {}

public class RunFunction <: Command<Bool> {
    public RunFunction(public let p : Float64) {}
}

public class SetFuel <: Command<Unit> {
    public SetFuel(public let f : Int64) {}
}
public class ConsumeFuel <: Command<Unit> {}
public class HasFuel <: Command<Bool> {}

// ================ Template public type resumptions ================

// UnknownFunction :: A -> B
public class UnknownFunction<A, B> <: Command<B> {
    public UnknownFunction(public let arg : A) {}
    public func defaultImpl() : B {
        throw UnhandledInstance("UnknownFunction")
    }
}

public class GenRandom<B> <: Command<B> {
    public func defaultImpl() : B {
        throw UnhandledInstance("GenRandom")
    }
}

public func fake<A, B>(a : A): B {
    return perform UnknownFunction<A, B>(a)
}

public class GetRandomFn<A, B> <: Command<(A) -> B> {
    public func defaultImpl() : (A) -> B {
        throw UnhandledInstance("GetRandomFn")
    }
}

public class GetRandomResumption<X, Y> <: Command<Resumption<X, Y>> {
    public func defaultImpl() : Resumption<X, Y> {
        throw UnhandledInstance("GetRandomResumption")
    }
}

public class AddResumption<X, Y> <: Command<Unit> {
    public AddResumption(public let r: Resumption<X, Y>) {}
    public func defaultImpl() : Unit {
        throw UnhandledInstance("AddResumption")
    }
}

public class HasResumption<X, Y> <: Command<Bool> {
    public func defaultImpl(): Bool {
        println("warning: defaultImpl for HasResumption used")
        return false
    }
}

public class HasFn<A, B> <: Command<Bool> {
    public func defaultImpl(): Bool {
        println("warning: defaultImpl for HasFn used")
        return false
    }
}

