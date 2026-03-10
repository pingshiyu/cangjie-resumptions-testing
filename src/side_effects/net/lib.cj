// NetContext: abstract state and wrappers for std.net PBT.
// Pre/postcondition specs: see plan (net-test-cases.md) and comments below.
// Wrappers perform the std.net call and update state so generated calls never need try/catch.
package cangjie_experiments.side_effects.net

import std.collection.*
import std.net.*
import std.fs.*
import cangjie_experiments.define.*
import cangjie_experiments.run_random_config.*
import cangjie_experiments.resumptions.*
import cangjie_experiments.resumptions.*
import cangjie_experiments.generators.*

@When[os != "Windows"]
func getUnixRunners(netCtx: NetContext): ArrayList<UnitFn> {
    let lib = ArrayList([
        @RunRandomly([path in netCtx.randFreshUnixPath], netCtx.unixServerCreateUnit),
        @RunRandomly([serverPath in netCtx.randUnixServerPathForBind], netCtx.unixServerBind),
        @RunRandomly([serverPath in netCtx.randUnixServerPath], netCtx.unixServerClose),
        @RunRandomly([path in netCtx.randUnixServerPathBound], netCtx.unixSocketCreateUnit),
        @RunRandomly([i in netCtx.randUnixClientIndex], netCtx.unixSocketConnectIndex),
        @RunRandomly([i in netCtx.randConnectedUnixSocketIndexWithData, buffer in netCtx.randSmallByteArray], netCtx.unixSocketReadIndex),
        @RunRandomly([i in netCtx.randConnectedUnixSocketIndex, payload in netCtx.randSmallByteArray], netCtx.unixSocketWriteIndex),
        @RunRandomly([i in netCtx.randUnixClientIndex], netCtx.unixSocketCloseIndex),
    ])
    lib.add(all: getUnixDgramRunners(netCtx))
    return lib
}

@When[os != "Windows"]
func getUnixDgramRunners(netCtx: NetContext): ArrayList<UnitFn> {
    ArrayList([
        @RunRandomly([path in netCtx.randFreshUnixPath], netCtx.unixDgramCreate),
        @RunRandomly([path in netCtx.randUnixDgramPathForBind], netCtx.unixDgramBind),
        @RunRandomly([path in netCtx.randBoundUnixDgramPath, remotePath in netCtx.randBoundUnixDgramPath], netCtx.unixDgramConnect),
        @RunRandomly([path in netCtx.randBoundUnixDgramPath], netCtx.unixDgramDisconnect),
        @RunRandomly([path in netCtx.randBoundUnixDgramPath, recipientPath in netCtx.randBoundUnixDgramPath, payload in netCtx.randSmallByteArray], netCtx.unixDgramSendTo),
        @RunRandomly([path in netCtx.randConnectedUnixDgramPath, payload in netCtx.randSmallByteArray], netCtx.unixDgramSend),
        @RunRandomly([path in netCtx.randBoundUnixDgramPathWithData, buffer in netCtx.randSmallByteArray], netCtx.unixDgramReceiveFrom),
        @RunRandomly([path in netCtx.randConnectedUnixDgramPathWithData, buffer in netCtx.randSmallByteArray], netCtx.unixDgramReceive),
        @RunRandomly([path in netCtx.randUnixDgramPath], netCtx.unixDgramClose),
    ])
}

@When[os == "Windows"]
func getUnixDgramRunners(netCtx: NetContext): ArrayList<UnitFn> {
    ArrayList()
}

@When[os == "Windows"]
func getUnixRunners(netCtx: NetContext): ArrayList<UnitFn> {
    ArrayList()
}

func getUdpRunners(netCtx: NetContext): ArrayList<UnitFn> {
    ArrayList([
        @RunRandomly([], netCtx.udpSocketCreateUnit),
        @RunRandomly([i in netCtx.randUdpSocketIndex], netCtx.udpSocketBind),
        @RunRandomly([i in netCtx.randBoundUdpSocketIndex], netCtx.udpSocketConnect),
        @RunRandomly([i in netCtx.randBoundUdpSocketIndex], netCtx.udpSocketDisconnect),
        @RunRandomly([i in netCtx.randBoundUdpSocketIndex, recipient in netCtx.randUdpRecipientAddress, payload in netCtx.randSmallByteArrayUdp], netCtx.udpSocketSendTo),
        @RunRandomly([i in netCtx.randConnectedUdpSocketIndex, payload in netCtx.randSmallByteArrayUdp], netCtx.udpSocketSend),
        @RunRandomly([i in netCtx.randBoundUdpSocketIndexWithData, buffer in netCtx.randSmallByteArray], netCtx.udpSocketReceiveFrom),
        @RunRandomly([i in netCtx.randConnectedUdpSocketIndexWithData, buffer in netCtx.randSmallByteArray], netCtx.udpSocketReceive),
        @RunRandomly([i in netCtx.randUdpSocketIndex], netCtx.udpSocketClose),
    ])
}

// TCP executor: server create/bind/accept/close, client create/connect/read/write/close.
public func getTcpRunners(netCtx: NetContext): ArrayList<UnitFn> {
    ArrayList([
        @RunRandomly([], netCtx.tcpServerCreateUnit),
        @RunRandomly([i in netCtx.randTcpServerIndex], netCtx.tcpServerBindIndex),
        @RunRandomly([i in netCtx.randTcpServerIndex], netCtx.tcpServerCloseIndex),
        @RunRandomly([address in netCtx.randTcpClientAddress], netCtx.tcpClientCreateUnit),
        @RunRandomly([i in netCtx.randTcpClientIndex], netCtx.tcpClientConnectIndex),
        @RunRandomly([i in netCtx.randConnectedTcpSocketIndexWithData, buffer in netCtx.randSmallByteArray], netCtx.tcpSocketReadIndex),
        @RunRandomly([i in netCtx.randConnectedTcpSocketIndex, payload in netCtx.randSmallByteArray], netCtx.tcpSocketWriteIndex),
        @RunRandomly([i in netCtx.randTcpClientIndex], netCtx.tcpSocketCloseIndex),
    ])
}

// Builds libNet: TCP + Unix (when os != "Windows") + UDP UnitFns. Uses NetContext so preconditions are satisfied.
public func getLibNet(netCtx: NetContext): ArrayList<UnitFn> {
    let lib = ArrayList<UnitFn>()
    lib.add(all: getTcpRunners(netCtx))
    lib.add(all: getUnixRunners(netCtx))
    lib.add(all: getUdpRunners(netCtx))
    return lib
}