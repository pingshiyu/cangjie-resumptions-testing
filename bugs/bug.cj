import stdx.effect.*

class BuggyException <: Command<Unit> {}

interface ReductionInterface {
    func makeReduction(hasProp: () -> Bool) : Bool {
        try {
            perform BuggyException()
            true
        } handle(e: BuggyException) {
            false
        }
    }

    static func someMember(): Unit {}
}