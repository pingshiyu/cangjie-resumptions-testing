# When _doesn't_ immediate effects give expressibility advantages?

Currently it seems that whenever the effects are used like 
- State
- Exception
- Reader
monads, then there seems to be non-effects implementations that have similar expressibility,
i.e. using a similar amount of code to acheive the same implementation semantics. Albeit 
potentially using more function arguments, thus is not a completely local transformation
from the effects-based implementation to a non-effects based one. But who's to say that one
must start from the effects-based implementation?