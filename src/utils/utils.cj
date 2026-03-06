package cangjie_experiments.utils

import std.collection.*
import std.core.*

public func showList<T>(sep : String, l : List<T>): String where T <: ToString {
    return "[" + showInterleave(sep, l) + "]"
}

public func showInterleave<T>(sep : String, l : List<T>) : String where T <: ToString {
    if (l.isEmpty()) { return "" }
    if (l.size == 1) { return l[0].toString() }

    let sb = StringBuilder()
    sb.append(l[0].toString())
    for (i in 1..l.size) {
        sb.append(sep)
        sb.append(l[i].toString())
    }
    sb.toString()
}

public func showTabs(n : Int64) : String {
    return "    " * n
}

public func showMaybe<T>(n : Option<T>) : String where T <: ToString {
    match (n) {
        case None => "None"
        case Some(t) => t.toString()
    }
}

public func pop<T>(al : List<T>) : T {
    let rv = al[0]
    al.remove(0..1)
    return rv
}

public func printSep() {
    println("------------------")
}

public func unpack<T>(f: ((T, T)) -> T): (T, T) -> T {
    return { x, y => f((x, y)) }
}

public func pack<T>(f: (T, T) -> T): ((T, T)) -> T {
    return { t => f(t[0], t[1]) }
}

// More general unpack functions for different input/output types
public func unpack2<A, B, R>(f: ((A, B)) -> R): (A, B) -> R {
    return { x, y => f((x, y)) }
}

public func pack2<A, B, R>(f: (A, B) -> R): ((A, B)) -> R {
    return { t => f(t[0], t[1]) }
}

// Three-parameter versions
public func unpack3<A, B, C, R>(f: ((A, B, C)) -> R): (A, B, C) -> R {
    return { x, y, z => f((x, y, z)) }
}

public func pack3<A, B, C, R>(f: (A, B, C) -> R): ((A, B, C)) -> R {
    return { t => f(t[0], t[1], t[2]) }
}

public func asList<A>(it: Iterable<A>): List<A> {
    let o: List<A> = ArrayList<A>()
    for (e in it) {
        o.add(e)
    }
    return o
}