// libIo: list of UnitFns for std.io PBT. Uses IoContext for generators and executors.
package cangjie_experiments

import std.collection.*
import std.io.*
import stdx.effect.*
import cangjie_experiments.define.*
import cangjie_experiments.run_random_config.*
import cangjie_experiments.resumptions.*
import cangjie_experiments.generators.*

public func getLibIo(ctx: IoContext): ArrayList<UnitFn> {
    ArrayList([
        @RunRandomly([], ctx.byteBufferCreateEmpty),
        @RunRandomly([capacity in ctx.randCapacity()], ctx.byteBufferCreateCapacity),
        @RunRandomly([source in ctx.randByteArrayForSource()], ctx.byteBufferCreateSource),
        @RunRandomly([i in ctx.randByteBufferIndex()], ctx.byteBufferClone),
        @RunRandomly([i in ctx.randByteBufferIndex()], ctx.byteBufferClear),
        @RunRandomly([i in ctx.randByteBufferIndex()], ctx.byteBufferBytes),
        @RunRandomly([i in ctx.randByteBufferIndex(), buffer in ctx.randNonEmptyReadBuffer()], ctx.byteBufferRead),
        @RunRandomly([i in ctx.randByteBufferIndex()], ctx.byteBufferReadByte),
        @RunRandomly([i in ctx.randByteBufferIndex(), buffer in ctx.randSmallByteArray()], ctx.byteBufferWrite),
        @RunRandomly([i in ctx.randByteBufferIndex(), v in ctx.randByteValue()], ctx.byteBufferWriteByte),
        @RunRandomly([i in ctx.randByteBufferIndex(), length in ctx.randSetLengthValue()], ctx.byteBufferSetLength),
        @RunRandomly([i in ctx.randByteBufferIndex(), addition in ctx.randReserveAddition()], ctx.byteBufferReserve),
        @RunRandomly([i in ctx.randByteBufferIndex(), sp in ctx.randSeekPosition()], ctx.byteBufferSeek),
        @RunRandomly([fromIndex in ctx.randByteBufferIndex(), toIndex in ctx.randByteBufferIndex()], ctx.copyFromTo),
        @RunRandomly([i in ctx.randUtf8ByteBufferIndex()], ctx.readStringFromUtf8),
        @RunRandomly([i in ctx.randUtf8ByteBufferIndex()], ctx.readStringUncheckedFromUtf8),
        @RunRandomly([i in ctx.randUtf8ByteBufferIndex()], ctx.readToEndFromUtf8),
        @RunRandomly([bbIndex in ctx.randByteBufferIndex()], ctx.bisCreate),
        @RunRandomly([bbIndex in ctx.randByteBufferIndex(), capacity in ctx.randBISCapacity()], ctx.bisCreateWithCapacity),
        @RunRandomly([i in ctx.randBISIndex(), buffer in ctx.randNonEmptyReadBuffer()], ctx.bisRead),
        @RunRandomly([i in ctx.randBISIndex()], ctx.bisReadByte),
        @RunRandomly([i in ctx.randBISIndex(), bbIndex in ctx.randByteBufferIndex()], ctx.bisReset),
        @RunRandomly([bbIndex in ctx.randByteBufferIndex()], ctx.bosCreate),
        @RunRandomly([bbIndex in ctx.randByteBufferIndex(), capacity in ctx.randBISCapacity()], ctx.bosCreateWithCapacity),
        @RunRandomly([i in ctx.randBOSIndex(), buffer in ctx.randSmallByteArray()], ctx.bosWrite),
        @RunRandomly([i in ctx.randBOSIndex(), v in ctx.randByteValue()], ctx.bosWriteByte),
        @RunRandomly([i in ctx.randBOSIndex()], ctx.bosFlush),
        @RunRandomly([i in ctx.randBOSIndex(), bbIndex in ctx.randByteBufferIndex()], ctx.bosReset),
        @RunRandomly([bbIndex in ctx.randByteBufferIndex()], ctx.chainedCreate),
        @RunRandomly([i in ctx.randChainedIndex(), buffer in ctx.randNonEmptyReadBuffer()], ctx.chainedRead),
        @RunRandomly([bbIndex in ctx.randByteBufferIndex()], ctx.multiCreate),
        @RunRandomly([i in ctx.randMultiIndex(), buffer in ctx.randSmallByteArray()], ctx.multiWrite),
        @RunRandomly([i in ctx.randMultiIndex()], ctx.multiFlush),
        @RunRandomly([utf8Index in ctx.randUtf8ByteBufferIndex()], ctx.stringReaderCreate),
        @RunRandomly([i in ctx.randStringReaderIndex()], ctx.stringReaderRead),
        @RunRandomly([i in ctx.randStringReaderIndex()], ctx.stringReaderReadln),
        @RunRandomly([i in ctx.randStringReaderIndex()], ctx.stringReaderReadToEnd),
        @RunRandomlyQuiet([i in ctx.randStringReaderIndex(), v in ctx.randRune()], ctx.stringReaderReadUntilRune),
        @RunRandomlyQuiet([i in ctx.randStringReaderIndex(), predicate in ctx.randPredicateRuneToBool()], ctx.stringReaderReadUntilPred),
        @RunRandomly([bbIndex in ctx.randByteBufferIndex()], ctx.stringWriterCreate),
        @RunRandomly([i in ctx.randStringWriterIndex(), v in ctx.randShortStringForWrite()], ctx.stringWriterWriteString),
        @RunRandomly([i in ctx.randStringWriterIndex(), v in ctx.randInt64ForWrite()], ctx.stringWriterWriteInt64),
        @RunRandomly([i in ctx.randStringWriterIndex(), v in ctx.randBoolForWrite()], ctx.stringWriterWriteBool),
        @RunRandomlyQuiet([i in ctx.randStringWriterIndex(), v in ctx.randRune()], ctx.stringWriterWriteRune),
        @RunRandomly([i in ctx.randStringWriterIndex()], ctx.stringWriterWriteln),
        @RunRandomly([i in ctx.randStringWriterIndex()], ctx.stringWriterFlush),
    ])
}
