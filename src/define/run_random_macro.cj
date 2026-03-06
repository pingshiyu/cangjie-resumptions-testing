macro package cangjie_experiments.define

import std.collection.*
import std.ast.*

// Parse generator bindings like [x in randInt64, y in randBool]
func parseGenerators(input: Tokens): (List<String>, List<Expr>) {
    let varNames = ArrayList<String>()
    let generators = ArrayList<Expr>()
    var i : Int64 = 1 // skip '['
    
    // Find the closing bracket to limit parsing
    var endIndex = input.size
    for (j in 1..input.size) {
        if (input[j].value == "]") {
            endIndex = j
            break
        }
    }
    
    while (i < endIndex) {
        // Parse variable name (expect identifier)
        let varToken = input[i]
        if (varToken.kind != TokenKind.IDENTIFIER) {
            throw Exception("Expected identifier for variable name")
        }
        varNames.add(varToken.value)
        i++
        
        // Expect 'in' keyword
        if (i < endIndex && input[i].kind == TokenKind.IN) {
            i++
        } else {
            throw Exception("Expected 'in' keyword")
        }
        
        // Parse generator expression
        let parseGenRes : (Expr, Int64) = parseExprFragment(input, startFrom: i)
        generators.add(parseGenRes[0])
        i = parseGenRes[1]
        
        // Skip comma if present
        if (i < endIndex && input[i].value == ",") {
            i++
        }
    }
    
    return (varNames, generators)
}

// Parse the function reference after the generator list
func parseFunctionRef(input: Tokens, startIdx: Int64): (Expr, Int64) {
    var i = startIdx
    
    // Skip the closing bracket and any comma/space
    while (i < input.size && (input[i].value == "]" || input[i].value == ",")) {
        i++
    }
    
    if (i >= input.size) {
        throw Exception("Expected function reference after generator list")
    }
    
    let parseFnRes : (Expr, Int64) = parseExprFragment(input, startFrom: i)
    return parseFnRes
}

public macro RunRandomly(input: Tokens): Tokens {
    // Parse input: [x in randInt64, y in randBool], f
    let (varNames, generators) = parseGenerators(input)
    
    // Find the closing bracket ']' and parse the function reference
    var bracketIdx = 1
    var depth = 1
    while (bracketIdx < input.size && depth > 0) {
        if (input[bracketIdx].value == "[") {
            depth++
        } else if (input[bracketIdx].value == "]") {
            depth--
        }
        bracketIdx++
    }
    
    let (funcRef, _) = parseFunctionRef(input, bracketIdx)
    
    // Generate the closure: {=> let x = randInt64(); let y = randBool(); f(x, y)}
    var result = quote(ignoreOutput) + Token(TokenKind.LPAREN, "(") + quote({=>)

    let funcRefStr = funcRef.toTokens().toString()
    result += quote(println("starting: " + $(funcRefStr));)
    
    // Add variable assignments
    for (i in 0..varNames.size) {
        let varToken = Token(TokenKind.IDENTIFIER, varNames[i])
        result += quote(
            let $(varToken) = $(generators[i])()
        )
    }
    
    // Add function call with all variables
    var funcCallTokens = quote(let out = $(funcRef))
    if (varNames.size > 0) {
        funcCallTokens += Token(TokenKind.LPAREN, "(")
        for (i in 0..varNames.size) {
            if (i > 0) {
                funcCallTokens += Token(TokenKind.COMMA, ",")
            }
            let varToken = Token(TokenKind.IDENTIFIER, varNames[i])
            funcCallTokens += varToken
        }
        funcCallTokens += Token(TokenKind.RPAREN, ")")
    }
    result += funcCallTokens + quote(;)
    result += quote(println("ending: " + $(funcRefStr));)
    result += quote(return out)
    result += quote(}) + Token(TokenKind.RPAREN, ")")
    
    return result
}