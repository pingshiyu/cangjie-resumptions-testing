// InputPrintable interface for debugging fuzzer runs: print randomly generated argument values.
// Shared types (used by more than one fuzzer) have extensions here. Extensions for
// imported types (Path, SocketAddress, SeekPosition) must also live here because
// Cangjie does not allow an imported type to extend an imported interface in another module.
package cangjie_experiments.input_print

import std.collection.*
import std.fs as stdFs
import std.io.*
import std.net.*

public interface InputPrintable {
    func inputPrintString(): String
}

// Shown when a type has no custom printing implementation yet.
let PRINT_NOT_SUPPORTED: String = "<printing not supported>"

// Shared types: used as RunRandomly arguments by multiple fuzzers (io, fs, net, collections).
extend Int64 <: InputPrintable {
    public func inputPrintString(): String {
        PRINT_NOT_SUPPORTED
    }
}

extend Bool <: InputPrintable {
    public func inputPrintString(): String {
        PRINT_NOT_SUPPORTED
    }
}

extend UInt8 <: InputPrintable {
    public func inputPrintString(): String {
        PRINT_NOT_SUPPORTED
    }
}

extend Int8 <: InputPrintable {
    public func inputPrintString(): String {
        PRINT_NOT_SUPPORTED
    }
}

extend Array<Byte> <: InputPrintable {
    public func inputPrintString(): String {
        "<" + this.size.toString() + " bytes>"
    }
}

extend String <: InputPrintable {
    public func inputPrintString(): String {
        PRINT_NOT_SUPPORTED
    }
}

extend<T> ArrayList<T> <: InputPrintable where T <: InputPrintable {
    public func inputPrintString(): String {
        PRINT_NOT_SUPPORTED
    }
}

// std.fs.Path (used by fs fuzzer)
extend stdFs.Path <: InputPrintable {
    public func inputPrintString(): String {
        this.normalize().toString()
    }
}

// std.io.SeekPosition (used by io fuzzer)
extend SeekPosition <: InputPrintable {
    public func inputPrintString(): String {
        PRINT_NOT_SUPPORTED
    }
}

// std.net.SocketAddress (used by net fuzzer)
extend SocketAddress <: InputPrintable {
    public func inputPrintString(): String {
        PRINT_NOT_SUPPORTED
    }
}
