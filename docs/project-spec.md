Suppose we have a bunch of API calls `A = {c1, c2, .., cn}`,
where `ci` takes args in set `Pi`
and they come with some predicate deciding whether they can be legally called in the current state `S`:
    `pi : Pi x S -> Bool`

We would like to explore the space of possible behavious formed by sequences of the API calls, essentially behaviours from
programs
`{[c{i_0}; c{i_1}; ... ; c{i_n}] : i_k some finite int sequence on [1, n], forall k. c{i_k} is called legally, satisfying preconds for its execution}`
being executed on all possible program states `S`.

For instance, using some kind of randomised, depth-first strategy as Dan's example suggests.

-- Usage of effects:
- Each API is modelled as an effect. If
    - c_i is an API call with input Pi, output Oi, then it would be modelled as an effect:
        -  ce_i : Pi -> Oi ! effs
    - Handler for `c_i` would turn it into a function `S x Pi -> S`, for input `(s, p)`:
        - Set up state `s`
        - Execute the API call `c_i(p)` in state `s'`
        - Add `s'` to set of available states. 
- For the user, using another handler would give them the usual execution semantics of `c_i`s. i.e. a handler that makes the API call only.

-- Discussion
- Seems like a challenge is describing the state of the program in a generic way. I.e. tracking the values of all variables. 
    - We need to be able to save and load Cangjie program states.
    - Are the libraries being tested pre-existing, or can we make assumptions on their structure? E.g. being written in a certain way.
    - For instance, if we can assert that the code being tested only used effects for all ops, particularly for assignment operations. Then we can interpret assignments and track states explicitly.
- How powerful are the APIs we're interested in testing? Do we just do straight-line calls, or is it important they contain control-flow structures, lambdas etc, so would be modelled more as a DSL rather than an API?