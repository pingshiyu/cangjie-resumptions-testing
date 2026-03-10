// IoContext and generators/executors for std.io PBT. In-memory streams only.
package cangjie_experiments.side_effects.io

import std.collection.*
import std.math.*
import std.random.*
import std.io.*
import cangjie_experiments.generators.*
import cangjie_experiments.resumptions.*

let MAX_BYTE_BUFFERS: Int64 = 16
let MAX_BUFFERED_STREAMS: Int64 = 8
let MAX_CHAINED_OR_MULTI: Int64 = 4
let MAX_STRING_READERS_WRITERS: Int64 = 4

public class IoContext {
    var byteBuffers: ArrayList<ByteBuffer> = ArrayList()
    // UTF-8 content ByteBuffers for readString/readToEnd (filled with randShortString().toArray())
    var utf8ByteBuffers: ArrayList<ByteBuffer> = ArrayList()
    var bufferedInputs: ArrayList<BufferedInputStream<ByteBuffer>> = ArrayList()
    var bufferedOutputs: ArrayList<BufferedOutputStream<ByteBuffer>> = ArrayList()
    var chainedInputs: ArrayList<ChainedInputStream<ByteBuffer>> = ArrayList()
    var multiOutputs: ArrayList<MultiOutputStream<ByteBuffer>> = ArrayList()
    var stringReaders: ArrayList<StringReader<BufferedInputStream<ByteBuffer>>> = ArrayList()
    var stringWriters: ArrayList<StringWriter<BufferedOutputStream<ByteBuffer>>> = ArrayList()

    public init() {}

    private func randIntRangeLocal(begin: Int64, end: Int64): Int64 {
        randomIntInRange(begin, end)
    }

    public func initialiseContext(): Unit {
        byteBuffers.clear()
        utf8ByteBuffers.clear()
        byteBuffers.add(ByteBuffer())
        byteBuffers.add(ByteBuffer(32))
        byteBuffers.add(ByteBuffer(randSmallBytes(n: 8)()))
        let utf8Bytes = randShortString(n: 5)().toArray()
        let utf8Buf = ByteBuffer(utf8Bytes)
        byteBuffers.add(utf8Buf)
        utf8ByteBuffers.add(utf8Buf)
        let utf8Buf2 = ByteBuffer(randShortString(n: 10)().toArray())
        byteBuffers.add(utf8Buf2)
        utf8ByteBuffers.add(utf8Buf2)
        bufferedInputs.add(BufferedInputStream(byteBuffers[0]))
        bufferedOutputs.add(BufferedOutputStream(byteBuffers[0]))
        chainedInputs.add(ChainedInputStream(Array<ByteBuffer>(1, repeat: byteBuffers[0])))
        multiOutputs.add(MultiOutputStream(Array<ByteBuffer>(1, repeat: byteBuffers[0])))
        let utf8Bis = BufferedInputStream(ByteBuffer(utf8ByteBuffers[0].bytes()))
        stringReaders.add(StringReader(utf8Bis))
        stringWriters.add(StringWriter(BufferedOutputStream(byteBuffers[0])))
    }

    public func cleanup(): Unit {
        // Replace lists with fresh ones so backing arrays (and any retained refs after clear()) are dropped.
        byteBuffers = ArrayList()
        utf8ByteBuffers = ArrayList()
        bufferedInputs = ArrayList()
        bufferedOutputs = ArrayList()
        chainedInputs = ArrayList()
        multiOutputs = ArrayList()
        stringReaders = ArrayList()
        stringWriters = ArrayList()
    }

    // --- Generators (return () -> T for use in @RunRandomly) ---

    public func randByteBufferIndex(): () -> Int64 {{ =>
        randIntRangeLocal(0, byteBuffers.size)
    }}

    public func randUtf8ByteBufferIndex(): () -> Int64 {{ =>
        randIntRangeLocal(0, utf8ByteBuffers.size)
    }}

    public func randCapacity(): () -> Int64 {{ =>
        randIntRangeLocal(0, 1025)
    }}

    public func randNonEmptyReadBuffer(): () -> Array<Byte> {{ =>
        let n = randIntRangeLocal(1, 65)
        randSmallBytes(n: n)()
    }}

    public func randByteArrayForSource(): () -> Array<Byte> {{ =>
        let n = randIntRangeLocal(0, 32)
        if (n == 0) {
            Array<Byte>(0, repeat: 0)
        } else {
            randSmallBytes(n: n)()
        }
    }}

    public func randSmallByteArray(): () -> Array<Byte> {{ =>
        randSmallBytes(n: randIntRangeLocal(1, 33))()
    }}

    public func randSeekPosition(): () -> SeekPosition {{ =>
        let i = randIntRangeLocal(0, byteBuffers.size)
        let bb = byteBuffers[i]
        let len = bb.length
        let choice = randIntRangeLocal(0, 3)
        if (choice == 0) {
            Current(0)
        } else if (choice == 1) {
            let pos = if (len > 0) { randIntRangeLocal(0, len) } else { 0 }
            Begin(pos)
        } else {
            End(0)
        }
    }}

    public func randSetLengthValue(): () -> Int64 {{ =>
        let i = randIntRangeLocal(0, byteBuffers.size)
        let cap = byteBuffers[i].capacity
        randIntRangeLocal(0, cap + 1)
    }}

    public func randReserveAddition(): () -> Int64 {{ =>
        randIntRangeLocal(0, 256)
    }}

    public func randByteValue(): () -> Byte {{ =>
        let arr = randSmallBytes(n: 1)()
        arr[0]
    }}

    public func randBISIndex(): () -> Int64 {{ =>
        randIntRangeLocal(0, bufferedInputs.size)
    }}

    public func randBOSIndex(): () -> Int64 {{ =>
        randIntRangeLocal(0, bufferedOutputs.size)
    }}

    public func randBISCapacity(): () -> Int64 {{ =>
        randIntRangeLocal(1, 1025)
    }}

    public func randChainedIndex(): () -> Int64 {{ =>
        randIntRangeLocal(0, chainedInputs.size)
    }}

    public func randMultiIndex(): () -> Int64 {{ =>
        randIntRangeLocal(0, multiOutputs.size)
    }}

    public func randStringReaderIndex(): () -> Int64 {{ =>
        randIntRangeLocal(0, stringReaders.size)
    }}

    public func randStringWriterIndex(): () -> Int64 {{ =>
        randIntRangeLocal(0, stringWriters.size)
    }}

    public func randRune(): () -> Rune {{ =>
        Rune(randIntRangeLocal(0, 128))
    }}

    public func randShortStringForWrite(): () -> String {{ =>
        randShortString(n: randIntRangeLocal(0, 8))()
    }}

    public func randInt64ForWrite(): () -> Int64 {{ =>
        randInt64()
    }}

    public func randBoolForWrite(): () -> Bool {{ =>
        randBool(0.5)
    }}

    // Predicate (Rune) -> Bool that does not perform effects (library will call it outside our handler).
    public func randPredicateRuneToBool(): () -> (Rune) -> Bool {{ =>
        let b = randBool(0.5)
        { _: Rune => b }
    }}

    // --- ByteBuffer executors ---

    public func byteBufferCreateEmpty(): Unit {
        if (byteBuffers.size < MAX_BYTE_BUFFERS) {
            byteBuffers.add(ByteBuffer())
        }
    }

    public func byteBufferCreateCapacity(capacity: Int64): Unit {
        if (byteBuffers.size < MAX_BYTE_BUFFERS) {
            byteBuffers.add(ByteBuffer(capacity))
        }
    }

    public func byteBufferCreateSource(source: Array<Byte>): Unit {
        if (byteBuffers.size < MAX_BYTE_BUFFERS) {
            byteBuffers.add(ByteBuffer(source))
        }
    }

    public func byteBufferClone(i: Int64): Unit {
        if (byteBuffers.size < MAX_BYTE_BUFFERS) {
            let bb = byteBuffers[i]
            byteBuffers.add(bb.clone())
        }
    }

    public func byteBufferClear(i: Int64): Unit {
        byteBuffers[i].clear()
    }

    public func byteBufferBytes(i: Int64): Unit {
        let _ = byteBuffers[i].bytes()
    }

    public func byteBufferRead(i: Int64, buffer: Array<Byte>): Unit {
        let _ = byteBuffers[i].read(buffer)
    }

    public func byteBufferReadByte(i: Int64): Unit {
        let _ = byteBuffers[i].readByte()
    }

    public func byteBufferWrite(i: Int64, buffer: Array<Byte>): Unit {
        byteBuffers[i].write(buffer)
    }

    public func byteBufferWriteByte(i: Int64, v: Byte): Unit {
        byteBuffers[i].writeByte(v)
    }

    public func byteBufferSetLength(i: Int64, length: Int64): Unit {
        byteBuffers[i].setLength(length)
    }

    public func byteBufferReserve(i: Int64, addition: Int64): Unit {
        byteBuffers[i].reserve(addition)
    }

    public func byteBufferSeek(i: Int64, sp: SeekPosition): Unit {
        let _ = byteBuffers[i].seek(sp)
    }

    // --- io_utils executors ---

    public func copyFromTo(fromIndex: Int64, toIndex: Int64): Unit {
        let from = byteBuffers[fromIndex]
        let to = byteBuffers[toIndex]
        let _ = copy(from, to: to)
    }

    public func readStringFromUtf8(i: Int64): Unit {
        let bb = utf8ByteBuffers[i]
        bb.seek(Begin(0))
        let _ = readString(bb)
    }

    public func readStringUncheckedFromUtf8(i: Int64): Unit {
        let bb = utf8ByteBuffers[i]
        bb.seek(Begin(0))
        let _ = unsafe { readStringUnchecked(bb) }
    }

    public func readToEndFromUtf8(i: Int64): Unit {
        let bb = utf8ByteBuffers[i]
        bb.seek(Begin(0))
        let _ = readToEnd(bb)
    }

    // --- BufferedInputStream / BufferedOutputStream executors ---

    public func bisCreate(bbIndex: Int64): Unit {
        if (bufferedInputs.size < MAX_BUFFERED_STREAMS) {
            let bb = byteBuffers[bbIndex]
            bufferedInputs.add(BufferedInputStream(bb))
        }
    }

    public func bisCreateWithCapacity(bbIndex: Int64, capacity: Int64): Unit {
        if (bufferedInputs.size < MAX_BUFFERED_STREAMS) {
            let bb = byteBuffers[bbIndex]
            bufferedInputs.add(BufferedInputStream(bb, capacity))
        }
    }

    public func bisRead(i: Int64, buffer: Array<Byte>): Unit {
        let _ = bufferedInputs[i].read(buffer)
    }

    public func bisReadByte(i: Int64): Unit {
        let _ = bufferedInputs[i].readByte()
    }

    public func bisReset(i: Int64, bbIndex: Int64): Unit {
        bufferedInputs[i].reset(byteBuffers[bbIndex])
    }

    public func bosCreate(bbIndex: Int64): Unit {
        if (bufferedOutputs.size < MAX_BUFFERED_STREAMS) {
            let bb = byteBuffers[bbIndex]
            bufferedOutputs.add(BufferedOutputStream(bb))
        }
    }

    public func bosCreateWithCapacity(bbIndex: Int64, capacity: Int64): Unit {
        if (bufferedOutputs.size < MAX_BUFFERED_STREAMS) {
            let bb = byteBuffers[bbIndex]
            bufferedOutputs.add(BufferedOutputStream(bb, capacity))
        }
    }

    public func bosWrite(i: Int64, buffer: Array<Byte>): Unit {
        bufferedOutputs[i].write(buffer)
    }

    public func bosWriteByte(i: Int64, v: Byte): Unit {
        bufferedOutputs[i].writeByte(v)
    }

    public func bosFlush(i: Int64): Unit {
        bufferedOutputs[i].flush()
    }

    public func bosReset(i: Int64, bbIndex: Int64): Unit {
        bufferedOutputs[i].reset(byteBuffers[bbIndex])
    }

    // --- ChainedInputStream / MultiOutputStream executors ---

    public func chainedCreate(bbIndex: Int64): Unit {
        if (chainedInputs.size < MAX_CHAINED_OR_MULTI) {
            let arr = Array<ByteBuffer>(1, repeat: byteBuffers[bbIndex])
            chainedInputs.add(ChainedInputStream(arr))
        }
    }

    public func chainedRead(i: Int64, buffer: Array<Byte>): Unit {
        let _ = chainedInputs[i].read(buffer)
    }

    public func multiCreate(bbIndex: Int64): Unit {
        if (multiOutputs.size < MAX_CHAINED_OR_MULTI) {
            let arr = Array<ByteBuffer>(1, repeat: byteBuffers[bbIndex])
            multiOutputs.add(MultiOutputStream(arr))
        }
    }

    public func multiWrite(i: Int64, buffer: Array<Byte>): Unit {
        multiOutputs[i].write(buffer)
    }

    public func multiFlush(i: Int64): Unit {
        multiOutputs[i].flush()
    }

    // --- StringReader / StringWriter executors ---

    public func stringReaderCreate(utf8Index: Int64): Unit {
        if (stringReaders.size < MAX_STRING_READERS_WRITERS) {
            let bb = ByteBuffer(utf8ByteBuffers[utf8Index].bytes())
            let bis = BufferedInputStream(bb)
            stringReaders.add(StringReader(bis))
        }
    }

    public func stringReaderRead(i: Int64): Unit {
        let _ = stringReaders[i].read()
    }

    public func stringReaderReadln(i: Int64): Unit {
        let _ = stringReaders[i].readln()
    }

    public func stringReaderReadToEnd(i: Int64): Unit {
        let _ = stringReaders[i].readToEnd()
    }

    public func stringReaderReadUntilRune(i: Int64, v: Rune): Unit {
        let _ = stringReaders[i].readUntil(v)
    }

    public func stringReaderReadUntilPred(i: Int64, predicate: (Rune) -> Bool): Unit {
        let _ = stringReaders[i].readUntil(predicate)
    }

    public func stringWriterCreate(bbIndex: Int64): Unit {
        if (stringWriters.size < MAX_STRING_READERS_WRITERS) {
            let bos = BufferedOutputStream(byteBuffers[bbIndex])
            stringWriters.add(StringWriter(bos))
        }
    }

    public func stringWriterWriteString(i: Int64, v: String): Unit {
        stringWriters[i].write(v)
    }

    public func stringWriterWriteInt64(i: Int64, v: Int64): Unit {
        stringWriters[i].write(v)
    }

    public func stringWriterWriteBool(i: Int64, v: Bool): Unit {
        stringWriters[i].write(v)
    }

    public func stringWriterWriteRune(i: Int64, v: Rune): Unit {
        stringWriters[i].write(v)
    }

    public func stringWriterWriteln(i: Int64): Unit {
        stringWriters[i].writeln()
    }

    public func stringWriterFlush(i: Int64): Unit {
        stringWriters[i].flush()
    }
}
