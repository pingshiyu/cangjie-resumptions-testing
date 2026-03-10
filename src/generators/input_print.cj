// InputPrintable interface for debugging fuzzer runs: print randomly generated argument values.
// Defined here together with the generators; all extensions (primitives, collections, and
// imported std types) must live in this package since Cangjie does not allow primitive or
// imported types to extend an imported interface in another module.
package cangjie_experiments.generators

import std.collection.*
import std.fs as stdFs
import std.io.*
import std.net.*

public interface InputPrintable {
    func inputPrintString(): String
}

// Shown when a type has no custom printing implementation yet.
let PRINT_NOT_SUPPORTED: String = "<printing not supported>"

// --- Primitives and base types (generator outputs) ---
extend Int64 <: InputPrintable {
    public func inputPrintString(): String {
        this.toString()
    }
}

extend Int8 <: InputPrintable {
    public func inputPrintString(): String {
        this.toString()
    }
}

extend Int16 <: InputPrintable {
    public func inputPrintString(): String {
        this.toString()
    }
}

extend Int32 <: InputPrintable {
    public func inputPrintString(): String {
        this.toString()
    }
}

extend UInt8 <: InputPrintable {
    public func inputPrintString(): String {
        this.toString()
    }
}

extend UInt16 <: InputPrintable {
    public func inputPrintString(): String {
        this.toString()
    }
}

extend UInt32 <: InputPrintable {
    public func inputPrintString(): String {
        this.toString()
    }
}

extend UInt64 <: InputPrintable {
    public func inputPrintString(): String {
        this.toString()
    }
}

extend Bool <: InputPrintable {
    public func inputPrintString(): String {
        if (this) { "true" } else { "false" }
    }
}

extend String <: InputPrintable {
    public func inputPrintString(): String {
        "\"" + this + "\""
    }
}

extend Array<Byte> <: InputPrintable {
    public func inputPrintString(): String {
        "<" + this.size.toString() + " bytes>"
    }
}

extend<T> ArrayList<T> <: InputPrintable where T <: InputPrintable {
    public func inputPrintString(): String {
        var out = "["
        for (i in 0..this.size) {
            if (i > 0) {
                out += ", "
            }
            out += this[i].inputPrintString()
        }
        out + "]"
    }
}

// --- Imported std types (must extend in same package as interface) ---
// std.fs.Path (used by fs fuzzer)
extend stdFs.Path <: InputPrintable {
    public func inputPrintString(): String {
        this.normalize().toString()
    }
}

// std.io.SeekPosition (used by io fuzzer)
extend SeekPosition <: InputPrintable {
    public func inputPrintString(): String {
        match (this) {
            case Current(off) => "Current(" + off.toString() + ")"
            case Begin(off) => "Begin(" + off.toString() + ")"
            case End(off) => "End(" + off.toString() + ")"
        }
    }
}

// std.net.SocketAddress (used by net fuzzer)
extend SocketAddress <: InputPrintable {
    public func inputPrintString(): String {
        this.toString()
    }
}
