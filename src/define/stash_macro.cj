macro package cangjie_experiments.define

import std.collection.*
import std.ast.*

/* Get types from the input tokens
Expects input to be a list of types, surrounded by [] characters.
*/
func parseAsTypes(input: Tokens): List<TypeNode> {
    let tys = ArrayList<TypeNode>()
    // assume the first character is a '['
    var i : Int64 = 1
    while (i < input.size - 1) {
        let parseRes : (TypeNode, Int64) = parseTypeFragment(input, startFrom: i)
        tys.add(parseRes[0])
        i = parseRes[1] + 1
    }
    return tys
}

func genStashes(tys: List<TypeNode>): Tokens {
    // form the Stash class
    var result = quote(
        class StashG_ {
            let arb = ArbitraryGen()
    )

    for (i1 in 0..tys.size) {
        for (i2 in 0..tys.size) {
            let fns_vn = Token(TokenKind.IDENTIFIER, "fns_${i1}_${i2}")
            let res_vn = Token(TokenKind.IDENTIFIER, "res_${i1}_${i2}")
            result += quote(
                let $(fns_vn) = FnStash<$(tys[i1]), $(tys[i2])>()
                let $(res_vn) = ResStash<$(tys[i1]), $(tys[i2])>()
            )
        }
    }

    result += quote(func handleStash<Y>(fn: () -> Y): Y {
        arb.sHandle { 
            try {
                fn()
            })
    for (i1 in 0..tys.size) {
        for (i2 in 0..tys.size) {
            let fns_vn = Token(TokenKind.IDENTIFIER, "fns_${i1}_${i2}")
            let res_vn = Token(TokenKind.IDENTIFIER, "res_${i1}_${i2}")
            let t1 = tys[i1]
            let t2 = tys[i2]
            result += quote(
              handle(_: GetRandomFn<$(t1), $(t2)>) {
                resume with $(fns_vn).randomFunction()
            } handle(_: HasFn<$(t1), $(t2)>) {
                resume with $(fns_vn).hasFunction()
            } handle(_: GetRandomResumption<$(t1), $(t2)>) {
                resume with $(res_vn).randomResumption()
            } handle(_: HasResumption<$(t1), $(t2)>) {
                resume with $(res_vn).hasResumption()
            } handle(e: AddResumption<$(t1), $(t2)>) {
                resume with $(res_vn).addResumption(e.r)
            })
        }
    }

    /*
    for (i1 in 0..tys.size) {
        for (i2 in 0..tys.size) {
            let fns_vn = Token(TokenKind.IDENTIFIER, "fns_${i1}_${i2}")
            let res_vn = Token(TokenKind.IDENTIFIER, "res_${i1}_${i2}")
            result += quote(
                $(fns_vn).sHandle {
                $(res_vn).sHandle {
            )
        }
    }
    result += quote(fn())

    for (_ in 0..tys.size) {
        for (_ in 0..tys.size) {
            result += quote(}}) // closes fns_i.handle{; res_i.handle{
        }
    }
    */

    result += quote(}) // closes arb.sHandle {
    result += quote(}}) // closes func.handleStash<..>(..) {; class StashG_ {

    return result
}

/*
func handleUnknown<Y>(fn: () -> Y): Y {
    try {
        fn()
    } handle(f: UnknownFunction<Int64, Bool>, r: Resumption<Bool, Y>) {
        handleUnknown<Y> { fillFunction<Int64, Bool, Y>(f, r) }
    } ...
}
*/
func genUnknownHandlers(tys: List<TypeNode>): Tokens {
    var res = quote(
        func handleUnknownG<Y>(fn: () -> Y) : Y {
            try {
                fn()
            }
    )

    for (i1 in 0..tys.size) {
        for (i2 in 0..tys.size) {
            res += quote(
                handle(f : UnknownFunction<$(tys[i1]), $(tys[i2])>, r : Resumption<$(tys[i2]), Y>) {
                    handleUnknownG<Y> { fillFunction<$(tys[i1]), $(tys[i2]), Y>(f, r) }
                })
        }
    }

    res += quote(}) // func handleUnknown<Y>(...) : Y {
    return res
}

public macro StashFromTypes(input: Tokens): Tokens {
    println("inputs are: ${input}")
    var res = genStashes(parseAsTypes(input))
    res += genUnknownHandlers(parseAsTypes(input))
    return res
}

func parseAsFuncExprs(input: Tokens): (List<Expr>, List<FuncType>) {
    let exps = ArrayList<Expr>()
    let tys = ArrayList<FuncType>()
    var i : Int64 = 1 // skip '['
    while (i < input.size - 1) {
        let parseExprRes : (Expr, Int64) = parseExprFragment(input, startFrom: i) // function expression
        exps.add(parseExprRes[0])
        i = parseExprRes[1] + 1 // skip ':'
        let parseTypeRes : (TypeNode, Int64) = parseTypeFragment(input, startFrom: i) // type of expression
        let ft = (parseTypeRes[0] as FuncType).getOrThrow()
        tys.add(ft)
        i = parseTypeRes[1] + 1 // skip ','
    }
    return (exps, tys)
}

func getFnTypes(ft: FuncType): (TypeNode, TypeNode) {
    return (ft.types[0], ft.returnType)
}

type TypeNodeRepr = String

func getTypeRepr(tn : TypeNode): TypeNodeRepr {
    return tn.toTokens().toString()
}

func getTypesInvolved(fnTys: List<FuncType>): List<TypeNode> {
    let out = ArrayList<TypeNode>()
    let uniqueTypes = HashSet<TypeNodeRepr>()
    for (ft in fnTys) {
        let (tIn, tOut) = getFnTypes(ft)
        if (!uniqueTypes.contains(getTypeRepr(tIn))) { 
            out.add(tIn)
            uniqueTypes.add(getTypeRepr(tIn))
        }
        if (!uniqueTypes.contains(getTypeRepr(tOut))) { 
            out.add(tOut)
            uniqueTypes.add(getTypeRepr(tOut))
        }
    }
    return ArrayList<TypeNode>(out)
}

public macro CreateTest(input: Tokens): Tokens {
    println("inputs are: ${input}")
    let (exprs, tys) = parseAsFuncExprs(input)
    // assert: exprs.size == tys.size

    let allTys = getTypesInvolved(tys)
    var out = quote()

    println("expanding on these types:")
    for (ty in allTys) {
        ty.dump()
    }

    out += genStashes(allTys)
    out += genUnknownHandlers(allTys)
    return out
}