package cangjie_experiments.resumptions

import std.collection.*
import cangjie_experiments.utils.*

// import functions from the std
// need some basic generators for basic types
// we can use generators for function types: 
// - either quickcheck approach of Gen (a -> b) = a -> Gen b
// - or using our approach of resuming, if possible, a resumption

/*
good options: 
- option.cj
- array.cj
- concurrent_hash_map.cj
- DONE: middle_operation.cj,
- DONE: end_operation.cj
*/


// reduce :: (A -> A -> A) -> Iter A -> Option A
public func reduce_<A>(r: ((A, A)) -> A, xs: List<A>): Option<A> {
    return reduce<A>(unpack(r))(xs)
}

// any :: (A -> Bool) -> Iter A -> Bool
public func any_<A>(p: (A) -> Bool, xs: List<A>): Bool {
    return any(p)(xs)
}

// none :: (A -> Bool) -> Iter A -> Bool
public func none_<A>(f: (A) -> Bool, xs: List<A>): Bool {
    return none(f)(xs)
}

// all :: (A -> Bool) -> Iter A -> Bool
public func all_<A>(f: (A) -> Bool, xs: List<A>): Bool {
    return all(f)(xs)
}

public func filter_<A>(f: (A) -> Bool, xs: List<A>): List<A> {
    asList(filter<A>(f)(xs))
}

public func map_<A, B>(f: (A) -> B, xs: List<A>): List<B> {
    asList(map(f)(xs))
}

public func filterMap_<A, B>(f: (A) -> ?B, xs: List<A>): List<B> {
    asList(filterMap<A, B>(f)(xs))
}

public func flatMap_<A, B>(f: (A) -> Iterable<B>, xs: List<A>): List<B> {
    asList(flatMap(f)(xs))
}

public func forEach_<A>(f: (A) -> Unit, xs: List<A>): Unit {
    forEach(f)(xs)
}

// End operations from end_operation.cj
public func fold_<T, R>(f: ((R, T)) -> R, initial: R, xs: List<T>): R {
    return fold(initial, unpack2(f))(xs)
}

public func contains_<T>(element: T, xs: List<T>): Bool where T <: Equatable<T> {
    return contains(element)(xs)
}

public func at_<T>(n: Int64, xs: List<T>): Option<T> {
    return at(n)(xs)
}

// Middle operations from middle_operation.cj
public func enumerate_<T>(xs: List<T>): List<(Int64, T)> {
    return asList(enumerate(xs))
}

public func flatten_<T, R>(xs: List<T>): List<R> where T <: Iterable<R> {
    return asList(flatten(xs))
}

public func zip_<T, R>(other: List<R>, xs: List<T>): List<(T, R)> {
    return asList(zip(other)(xs))
}

public func concat_<T>(other: List<T>, xs: List<T>): List<T> {
    return asList(concat(other)(xs))
}

public func skip_<T>(count: Int64, xs: List<T>): List<T> {
    return asList(skip(count)(xs))
}

public func take_<T>(count: Int64, xs: List<T>): List<T> {
    return asList(take(count)(xs))
}

public func step_<T>(count: Int64, xs: List<T>): List<T> {
    return asList(step(count)(xs))
}

public func inspect_<T>(f : (T) -> Unit, xs: List<T>) : List<T> {
    return asList(inspect(f)(xs))
}