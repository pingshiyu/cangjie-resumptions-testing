macro package cangjie_experiments.define

import std.ast.*

/*
Given a class C, a library l, a method to make objects of that class () -> C
- create object c : C
- create functions c.f for each function C.f of the class
- register all functions onto the library l
- optionally add an option during class declaration to make all private functions public too
*/

/* Structure:
@RunMember(fs, Cls, [
    [g1 in blah, ...], f1, 
    [g1 in blah, ...], f2,
    ...
    ])
@RunMembers(fs, Cls, randClsObj)
generates:
    o = randClsObj()
    fs = ArrayList([o.f1Run, o.f2Run, ...])
where o.f1Run, o.f2Run are functions that uses the default generator for each of its arguments
and runs them randomly
*/
public macro RunMembers(t: Tokens) {
    // make assign statement

    return quote()
}