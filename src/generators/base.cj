package cangjie_experiments.generators

import std.math.*
import std.random.*
import std.collection.*
import std.unittest.prop_test.*
import std.unittest.common.*
import stdx.effect.*

public class ChooseFromEmptyListError <: Exception {
    public ChooseFromEmptyListError(message: String) {
        super(message)
    }
}

public class GetRandom <: Command<Random> {}

public func withSeed<R>(seed: Option<UInt64>, f: () -> R): R {
    let r = match (seed) {
        case Some(s) => Random(s)
        case None => Random()
    }

    try {
        f()
    } handle (e : GetRandom) {
        resume with r
    }
}

public func cjRandom<T>() : T where T <: Arbitrary<T> {
    return T.arbitrary(perform GetRandom()).next()
}

public func cjRandomAlt<T>(r : Random) : T where T <: Arbitrary<T> {
    return T.arbitrary(r).next()
}

// Map one cjRandom<Int8>() to a byte value in [0, 255] for building larger integers.
func byteFromInt8() : Int64 {
    return (Int64(cjRandom<Int8>()) + 128) % 256
}

public func randBool(p : Float64) : Bool {
    return cjRandom<Bool>()
}

public func randBool_(p : Float64) : () -> Bool {{ =>
    randBool(p)
}}

public func randInt8() : Int8 {
    return cjRandom<Int8>()
}

public func randSmallInt64() : Int64 {
    return Int64(cjRandom<Int8>())
}

public func randInt64() : Int64 {
    var finalVal : Int64 = 0
    for (_ in 0..7) {
        finalVal = finalVal * 256 + byteFromInt8()
    }
    return finalVal
}

public func randNat() : List<UInt64> {
    let ns : ArrayList<UInt64> = ArrayList<UInt64>()
    var keepGoing : Bool = false
    do {
        ns.add(UInt64(cjRandom<Int8>()))
        keepGoing = randBool(0.50)
    } while (keepGoing)
    return ns
}

public func randIntRange(begin : Int64, end : Int64) : Int64 {
    let range = end - begin
    let chosenInt = abs(randInt64())
    let width = chosenInt % range
    return begin + width
}

public func randomIntInRange(begin : Int64, end : Int64) : Int64 {
    return randIntRange(begin, end)
}

public func randElem<T>(ls : List<T>) : T {
    let n : Int64 = ls.size
    if (n == 0) {
        throw ChooseFromEmptyListError("randElem: list is empty")
    }
    let ix : Int64 = randIntRange(0, n)
    return ls[ix]
}

public func randList<T>(eLen : Int64, g : () -> T) : () -> List<T> {{ =>
    let p : Float64 = 1.0 - 1.0 / Float64(eLen)
    let l : List<T> = ArrayList<T>()
    var cont : Bool = randBool(p)
    while (cont) {
        l.add(g())
        cont = randBool(p)
    }
    return l
}}

public func randIntListAlt() : List<Int64> {
    let n : Int64 = abs(randInt64())
    let l : List<Int64> = ArrayList<Int64>()
    for (_ in 0..n) {
        l.add(Int64(cjRandom<Int8>()))
    }
    return l
}

public func randOption<T>(p : Float64, g : () -> T) : () -> Option<T> {{ =>
    if (randBool(p)) {
        return Some(g())
    } else {
        return None
    }
}}

public func randInt64_() : () -> Int64 {{ =>
    randInt64()
}}

public func randIntRange_(begin : Int64, end : Int64) : () -> Int64 {{ =>
    randIntRange(begin, end)
}}

public func randNestedList<T>(eLen : Int64, g : () -> T) : () -> List<List<T>> {{ =>
    let p : Float64 = 1.0 - 1.0 / Float64(eLen)
    let outerList : List<List<T>> = ArrayList<List<T>>()
    while (randBool(p)) {
        let innerList : List<T> = randList(eLen, g)()
        outerList.add(innerList)
    }
    return outerList
}}

public func randAlphanumericChar() : () -> Rune {{ =>
    let c = Rune(randIntRange(0, 128))
    if (c.isAsciiNumberOrLetter()) {
        return c
    } else {
        return randAlphanumericChar()()
    }
}}

public func randString(sLen : Int64) : () -> String {{ =>
    var s : String = ""
    for (_ in 0..sLen) {
        s += randAlphanumericChar()().toString()
    }
    return s
}}

public func randShortString(n !: Int64 = 1, alphabet !: List<String> = ArrayList(["a", "b"])) : () -> String {{ =>
    var s = ""
    for (_ in 0..n) {
        s += randElem(alphabet)
    }
    return s
}}

public func randSmallBytes(n !: Int64 = 5) : () -> Array<Byte> {{ =>
    return randShortString(n:n)().toArray()
}}