// Optional shared/pure generators for net PBT (e.g. randPortInRange) can go here.
// Currently all generators are methods on NetContext in net_testing_lib.cj.
package cangjie_experiments

import std.collection.*
import std.net.*
import std.fs.*
import std.math.*
import std.random.*
import cangjie_experiments.define.*
import cangjie_experiments.resumptions.*
import std.unittest.*
import cangjie_experiments.generators.*

// --- TCP state: servers (socket, bound, closed); clients (socket, connected, closed).
// We use parallel lists; index i in each list corresponds to the same entry.
// After bind(), server's localAddress (as IPSocketAddress).port is used for client connect to localhost.

public class NetContext {
    // TCP servers: created by tcpServerCreate; after bind() the entry is marked bound.
    let tcpServers: ArrayList<TcpServerSocket> = ArrayList()
    var tcpServerBound: ArrayList<Bool> = ArrayList()
    var tcpServerClosed: ArrayList<Bool> = ArrayList()

    // TCP clients: created by tcpClientCreate; after connect() the entry is marked connected.
    // Peer/hasData: peer index (-1 = none); hasData set when peer writes; serverIndex for pairing on accept.
    let tcpClients: ArrayList<TcpSocket> = ArrayList()
    var tcpClientConnected: ArrayList<Bool> = ArrayList()
    var tcpClientClosed: ArrayList<Bool> = ArrayList()
    var tcpClientServerIndex: ArrayList<Int64> = ArrayList()
    var tcpClientPeerIndex: ArrayList<Int64> = ArrayList()
    var tcpClientHasData: ArrayList<Bool> = ArrayList()

    // Unix (non-Windows): paths in use by bind(); server list keyed by path (path, server, bound, closed); client list.
    let unixPathsInUse: ArrayList<String> = ArrayList()
    let unixServerPath: ArrayList<String> = ArrayList()
    let unixServers: ArrayList<UnixServerSocket> = ArrayList()
    var unixServerBound: ArrayList<Bool> = ArrayList()
    var unixServerClosed: ArrayList<Bool> = ArrayList()
    let unixClients: ArrayList<UnixSocket> = ArrayList()
    let unixClientServerPath: ArrayList<String> = ArrayList()
    var unixClientConnected: ArrayList<Bool> = ArrayList()
    var unixClientClosed: ArrayList<Bool> = ArrayList()
    var unixClientPeerIndex: ArrayList<Int64> = ArrayList()
    var unixClientHasData: ArrayList<Bool> = ArrayList()

    // Unix datagram: path, socket, bound, connected, closed; hasData so receive won't block.
    let unixDgramPath: ArrayList<String> = ArrayList()
    let unixDgramSockets: ArrayList<UnixDatagramSocket> = ArrayList()
    var unixDgramBound: ArrayList<Bool> = ArrayList()
    var unixDgramConnected: ArrayList<Bool> = ArrayList()
    var unixDgramClosed: ArrayList<Bool> = ArrayList()
    var unixDgramHasData: ArrayList<Bool> = ArrayList()
    var unixDgramRemotePath: ArrayList<String> = ArrayList()

    // UDP: socket, bound, connected, closed; boundPort for pairing send->receive; hasData so receive won't block/timeout.
    let udpSockets: ArrayList<UdpSocket> = ArrayList()
    var udpBound: ArrayList<Bool> = ArrayList()
    var udpConnected: ArrayList<Bool> = ArrayList()
    var udpClosed: ArrayList<Bool> = ArrayList()
    var udpBoundPort: ArrayList<UInt16> = ArrayList()
    var udpHasData: ArrayList<Bool> = ArrayList()

    let tmpRoot: String

    public init(tmpRoot: String) {
        this.tmpRoot = tmpRoot
    }

    private func randIntRangeLocal(begin: Int64, end: Int64): Int64 {
        randomIntInRange(begin, end)
    }

    private func randElemLocal<T>(ls: List<T>): T {
        let n: Int64 = ls.size
        if (n == 0) {
            throw ChooseFromEmptyListError("randElem: list is empty")
        }
        let ix = randIntRangeLocal(0, n)
        return ls[ix]
    }

    private static let randShortStringAlphabet: ArrayList<String> = ArrayList(["a", "b"])

    private func randShortStringLocal(n: Int64): String {
        var s = ""
        for (_ in 0..n) {
            s += randElemLocal(randShortStringAlphabet)
        }
        return s
    }

    private func randSmallBytesLocal(n: Int64): Array<Byte> {
        randShortStringLocal(n).toArray()
    }

    // --- Helpers: get port from a bound TCP server (localAddress is Option<SocketAddress>; cast to IPSocketAddress yields Option<IPSocketAddress>).
    private func tcpServerPortAtIndex(i: Int64): UInt16 {
        let opt: Option<SocketAddress> = tcpServers[i].localAddress
        if (!opt.isSome()) {
            throw Exception("tcpServerPortAtIndex: server not bound")
        }
        let raw: SocketAddress = opt.getOrThrow()
        let addrOpt: Option<IPSocketAddress> = raw as IPSocketAddress
        if (!addrOpt.isSome()) {
            throw Exception("tcpServerPortAtIndex: localAddress not IPSocketAddress")
        }
        let addr: IPSocketAddress = addrOpt.getOrThrow()
        return addr.port
    }

    /** Port from SocketAddress if it is IPSocketAddress, else None. */
    private func portFromSocketAddress(addr: SocketAddress): Option<UInt16> {
        let opt: Option<IPSocketAddress> = addr as IPSocketAddress
        if (opt.isSome()) {
            return Some(opt.getOrThrow().port)
        }
        return None
    }

    /** Index of a bound TCP server with the given port, or -1 if not found. */
    private func tcpServerIndexByPort(port: UInt16): Int64 {
        for (i in 0..tcpServers.size) {
            if (tcpServerBound[i] && !tcpServerClosed[i] && tcpServerPortAtIndex(i) == port) {
                return i
            }
        }
        return -1
    }

    // --- Generators (TCP, index-based like UDP so we avoid socket equality)

    // Returns an index of a TcpServerSocket that is bound and not closed; creates one if none exist.
    public func randBoundTcpServerIndex(): Int64 {
        for (i in 0..tcpServers.size) {
            if (tcpServerBound[i] && !tcpServerClosed[i]) {
                return i
            }
        }
        let server = TcpServerSocket(bindAt: 0u16)
        tcpServers.add(server)
        tcpServerBound.add(false)
        tcpServerClosed.add(false)
        server.bind()
        tcpServerBound[tcpServerBound.size - 1] = true
        return tcpServers.size - 1
    }

    // Returns any TcpServerSocket index we track that is not closed (for bind/accept/close).
    public func randTcpServerIndex(): Int64 {
        var open = ArrayList<Int64>()
        for (i in 0..tcpServers.size) {
            if (!tcpServerClosed[i]) {
                open.add(i)
            }
        }
        if (open.isEmpty()) {
            let server = TcpServerSocket(bindAt: 0u16)
            tcpServers.add(server)
            tcpServerBound.add(false)
            tcpServerClosed.add(false)
            return tcpServers.size - 1
        }
        return randElemLocal(open)
    }

    // Returns an index of a TcpSocket that is connected and not closed; creates one if none exist.
    public func randConnectedTcpSocketIndex(): Int64 {
        for (i in 0..tcpClients.size) {
            if (tcpClientConnected[i] && !tcpClientClosed[i]) {
                return i
            }
        }
        let si = randBoundTcpServerIndex()
        let port = tcpServerPortAtIndex(si)
        let clientAddr = IPSocketAddress(IPv4Address.localhost, port)
        let client = TcpSocket(clientAddr)
        client.readTimeout = Some(streamReadTimeout)
        tcpClients.add(client)
        tcpClientConnected.add(false)
        tcpClientClosed.add(false)
        tcpClientServerIndex.add(si)
        tcpClientPeerIndex.add(-1)
        tcpClientHasData.add(false)
        client.connect()
        tcpClientConnected[tcpClientConnected.size - 1] = true
        return tcpClients.size - 1
    }

    // Returns any TcpSocket index we track that is not closed (for connect/read/write/close).
    public func randTcpClientIndex(): Int64 {
        var open = ArrayList<Int64>()
        for (i in 0..tcpClients.size) {
            if (!tcpClientClosed[i]) {
                open.add(i)
            }
        }
        if (open.isEmpty()) {
            let si = randBoundTcpServerIndex()
            let port = tcpServerPortAtIndex(si)
            let clientAddr = IPSocketAddress(IPv4Address.localhost, port)
            let client = TcpSocket(clientAddr)
            client.readTimeout = Some(streamReadTimeout)
            tcpClients.add(client)
            tcpClientConnected.add(false)
            tcpClientClosed.add(false)
            tcpClientServerIndex.add(si)
            tcpClientPeerIndex.add(-1)
            tcpClientHasData.add(false)
            return tcpClients.size - 1
        }
        return randElemLocal(open)
    }

    // Non-empty byte array for read/write buffers. Size in [1, 1024] for TCP.
    public func randSmallByteArray(): Array<Byte> {
        let n = randIntRangeLocal(1, 1025)
        return randSmallBytesLocal(n)
    }

    // Address to connect a client to (localhost:port of a bound server). Ensures server exists.
    public func randTcpClientAddress(): SocketAddress {
        let i = randBoundTcpServerIndex()
        let port = tcpServerPortAtIndex(i)
        return IPSocketAddress(IPv4Address.localhost, port)
    }

    /** Returns a connected TCP socket index that has data to read (so read won't block). Ensures one by writing from peer if needed. */
    public func randConnectedTcpSocketIndexWithData(): Int64 {
        for (i in 0..tcpClients.size) {
            if (tcpClientConnected[i] && !tcpClientClosed[i] && tcpClientHasData[i]) {
                return i
            }
        }
        for (i in 0..tcpClients.size) {
            let j = tcpClientPeerIndex[i]
            if (j >= 0 && tcpClientPeerIndex[j] == i && tcpClientConnected[j] && !tcpClientClosed[j]) {
                let payload = randSmallByteArray()
                tcpSocketWriteIndex(j, payload)
                return i
            }
        }
        let si = randBoundTcpServerIndex()
        let port = tcpServerPortAtIndex(si)
        let clientAddr = IPSocketAddress(IPv4Address.localhost, port)
        let client = TcpSocket(clientAddr)
        client.readTimeout = Some(streamReadTimeout)
        tcpClients.add(client)
        tcpClientConnected.add(false)
        tcpClientClosed.add(false)
        tcpClientServerIndex.add(si)
        tcpClientPeerIndex.add(-1)
        tcpClientHasData.add(false)
        client.connect()
        tcpClientConnected[tcpClientConnected.size - 1] = true
        let clientIdx = tcpClients.size - 1
        let _ = tcpServerAccept(si)
        let acceptedIdx = tcpClients.size - 1
        let payload = randSmallByteArray()
        tcpSocketWriteIndex(clientIdx, payload)
        return acceptedIdx
    }

    // --- TCP wrapper methods (call std.net and update state; index-based)

    /** Pre: none. Post: new TcpServerSocket(0) created and recorded; not bound, not closed. */
    public func tcpServerCreateUnit(): Unit {
        let server = TcpServerSocket(bindAt: 0u16)
        tcpServers.add(server)
        tcpServerBound.add(false)
        tcpServerClosed.add(false)
    }

    /** Pre: i valid index; server not closed; not already bound. Post: server bound and listening; state updated. */
    public func tcpServerBindIndex(i: Int64): Unit {
        if (i < 0 || i >= tcpServers.size || tcpServerClosed[i] || tcpServerBound[i]) {
            return
        }
        tcpServers[i].bind()
        tcpServerBound[i] = true
    }

    private static let acceptShortTimeout: Duration = 20 * Duration.millisecond
    private static let streamReadTimeout: Duration = 150 * Duration.millisecond

    /** Pre: i is randBoundTcpServerIndex (bound and not closed). Post: returns connected TcpSocket; optionally record in state. May throw SocketTimeoutException. */
    public func tcpServerAccept(i: Int64): TcpSocket {
        if (i < 0 || i >= tcpServers.size || tcpServerClosed[i] || !tcpServerBound[i]) {
            throw Exception("tcpServerAccept precondition violated: server must be bound and not closed")
        }
        let client = tcpServers[i].accept(timeout: Some(acceptShortTimeout))
        client.readTimeout = Some(streamReadTimeout)
        let newIdx = tcpClients.size
        tcpClients.add(client)
        tcpClientConnected.add(true)
        tcpClientClosed.add(false)
        tcpClientServerIndex.add(i)
        var peerK: Int64 = -1
        var unpairedCount: Int64 = 0
        for (k in 0..tcpClients.size - 1) {
            if (tcpClientServerIndex[k] == i && tcpClientConnected[k] && tcpClientPeerIndex[k] == -1) {
                unpairedCount += 1
                peerK = k
            }
        }
        if (unpairedCount != 1) {
            peerK = -1
        }
        tcpClientPeerIndex.add(peerK)
        tcpClientHasData.add(false)
        if (peerK >= 0) {
            tcpClientPeerIndex[peerK] = newIdx
        }
        return client
    }

    /** Unit version for RunRandomly. Not registered in random pool (accept only used inside generators). */
    public func tcpServerAcceptUnitIndex(i: Int64): Unit {
        let _ = tcpServerAccept(i)
    }

    /** Pre: i valid index. Post: server closed; state marks closed; all clients connected to this server marked disconnected. */
    public func tcpServerCloseIndex(i: Int64): Unit {
        if (i < 0 || i >= tcpServers.size || tcpServerClosed[i]) {
            return
        }
        tcpServers[i].close()
        tcpServerClosed[i] = true
        for (j in 0..tcpClients.size) {
            if (tcpClientServerIndex[j] == i) {
                tcpClientConnected[j] = false
            }
        }
    }

    /** Pre: address is IPv4 or IPv6. Post: new TcpSocket created and recorded; not connected. */
    public func tcpClientCreateUnit(address: SocketAddress): Unit {
        let client = TcpSocket(address)
        client.readTimeout = Some(streamReadTimeout)
        tcpClients.add(client)
        tcpClientConnected.add(false)
        tcpClientClosed.add(false)
        let portOpt: Option<IPSocketAddress> = address as IPSocketAddress
        let si: Int64 = if (portOpt.isSome()) { tcpServerIndexByPort(portOpt.getOrThrow().port) } else { -1 }
        tcpClientServerIndex.add(si)
        tcpClientPeerIndex.add(-1)
        tcpClientHasData.add(false)
    }

    private static let connectShortTimeout: Duration = 200 * Duration.millisecond

    /** Pre: i valid index; socket not closed; server listening. Post: socket connected; state updated. Skips connect if server closed. Uses short timeout to avoid long wait; on timeout or failure does not mark connected. */
    public func tcpClientConnectIndex(i: Int64): Unit {
        if (i < 0 || i >= tcpClients.size || tcpClientClosed[i] || tcpClientConnected[i]) {
            return
        }
        let si = tcpClientServerIndex[i]
        if (si >= 0 && (si >= tcpServers.size || tcpServerClosed[si] || !tcpServerBound[si])) {
            return
        }
        try {
            tcpClients[i].connect(timeout: Some(connectShortTimeout))
            tcpClientConnected[i] = true
        } catch (_: SocketTimeoutException) {
            ()
        }
    }

    /** Pre: i valid index; socket connected and not closed; buffer non-empty. On timeout gives up quickly without long wait; state updated. */
    public func tcpSocketReadIndex(i: Int64, buffer: Array<Byte>): Unit {
        if (buffer.isEmpty()) {
            return
        }
        if (i < 0 || i >= tcpClients.size || tcpClientClosed[i] || !tcpClientConnected[i]) {
            return
        }
        try {
            let _ = tcpClients[i].read(buffer)
            tcpClientHasData[i] = false
        } catch (_: SocketTimeoutException) {
            tcpClientHasData[i] = false
        }
    }

    /** Pre: i valid index; socket connected and not closed; payload non-empty; peer (if any) not closed. Post: peer's hasData set. */
    public func tcpSocketWriteIndex(i: Int64, payload: Array<Byte>): Unit {
        if (payload.isEmpty()) {
            return
        }
        if (i < 0 || i >= tcpClients.size || tcpClientClosed[i] || !tcpClientConnected[i]) {
            return
        }
        let peer = tcpClientPeerIndex[i]
        if (peer >= 0 && tcpClientClosed[peer]) {
            return
        }
        tcpClients[i].write(payload)
        if (peer >= 0) {
            tcpClientHasData[peer] = true
        }
    }

    /** Pre: i valid index. Post: socket closed; state marks closed; peer (if any) marked disconnected so no read/write on broken connection. */
    public func tcpSocketCloseIndex(i: Int64): Unit {
        if (i < 0 || i >= tcpClients.size || tcpClientClosed[i]) {
            return
        }
        let peer = tcpClientPeerIndex[i]
        tcpClients[i].close()
        tcpClientClosed[i] = true
        if (peer >= 0 && peer < tcpClients.size) {
            tcpClientConnected[peer] = false
        }
    }

    public func initialiseContext(): Unit {
        if (!exists(Path(tmpRoot))) {
            Directory.create(Path(tmpRoot), recursive: true)
        }
        let _ = randBoundTcpServerIndex()
        let _ = randConnectedTcpSocketIndex()
    }

    private func unixPathInUse(p: String): Bool {
        for (i in 0..unixPathsInUse.size) {
            if (unixPathsInUse[i] == p) {
                return true
            }
        }
        return false
    }

    private func unixPathReservedByServer(p: String): Bool {
        for (i in 0..unixServerPath.size) {
            if (unixServerPath[i] == p) {
                return true
            }
        }
        return false
    }

    private func unixPathReservedByDgram(p: String): Bool {
        for (i in 0..unixDgramPath.size) {
            if (unixDgramPath[i] == p) {
                return true
            }
        }
        return false
    }

    private func indexOfUnixDgramByPath(path: String): Option<Int64> {
        for (i in 0..unixDgramPath.size) {
            if (unixDgramPath[i] == path) {
                return Some(i)
            }
        }
        return None
    }

    private func indexOfUnixServerByPath(path: String): Option<Int64> {
        for (i in 0..unixServerPath.size) {
            if (unixServerPath[i] == path) {
                return Some(i)
            }
        }
        return None
    }

    /** Fresh path under tmpRoot not in use and not existing on disk. Pre: tmpRoot exists (e.g. create with std.fs). */
    public func randFreshUnixPath(): String {
        var path: String
        var loops: Int64 = 1
        do {
            let n = Int64(loops % 10) + 1
            path = tmpRoot + "/uds_" + randShortStringLocal(n)
            loops += 1
        } while (unixPathInUse(path) || unixPathReservedByServer(path) || unixPathReservedByDgram(path) || exists(Path(path)))
        return path
    }

    /** Returns index of a bound Unix server; creates one if none exist. Path is unixServerPath[i], server is unixServers[i]. */
    public func randBoundUnixServerIndex(): Int64 {
        for (i in 0..unixServers.size) {
            if (unixServerBound[i] && !unixServerClosed[i]) {
                return i
            }
        }
        let path = randFreshUnixPath()
        let server = UnixServerSocket(bindAt: path)
        unixServerPath.add(path)
        unixServers.add(server)
        unixServerBound.add(false)
        unixServerClosed.add(false)
        server.bind()
        unixServerBound[unixServerBound.size - 1] = true
        unixPathsInUse.add(path)
        return unixServers.size - 1
    }

    /** Returns a Unix server that is bound and not closed; creates one if none exist. */
    public func randBoundUnixServer(): UnixServerSocket {
        return unixServers[randBoundUnixServerIndex()]
    }

    /** Returns a path for a Unix server we created but not yet bound (for unixServerBind). */
    public func randUnixServerPathForBind(): String {
        for (i in 0..unixServers.size) {
            if (!unixServerBound[i] && !unixServerClosed[i]) {
                return unixServerPath[i]
            }
        }
        let path = randFreshUnixPath()
        let server = UnixServerSocket(bindAt: path)
        unixServerPath.add(path)
        unixServers.add(server)
        unixServerBound.add(false)
        unixServerClosed.add(false)
        return path
    }

    /** Returns any Unix server we track by path (for close). */
    public func randUnixServerPath(): String {
        var open = ArrayList<Int64>()
        for (i in 0..unixServers.size) {
            if (!unixServerClosed[i]) {
                open.add(i)
            }
        }
        if (open.isEmpty()) {
            return randUnixServerPathForBind()
        }
        let i = randElemLocal(open)
        return unixServerPath[i]
    }

    /** Returns index of a UnixSocket that is connected and not closed; creates one if none exist. */
    public func randConnectedUnixSocketIndex(): Int64 {
        for (i in 0..unixClients.size) {
            if (unixClientConnected[i] && !unixClientClosed[i]) {
                return i
            }
        }
        let si = randBoundUnixServerIndex()
        let path = unixServerPath[si]
        let client = UnixSocket(path)
        client.readTimeout = Some(streamReadTimeout)
        unixClients.add(client)
        unixClientServerPath.add(path)
        unixClientConnected.add(false)
        unixClientClosed.add(false)
        unixClientPeerIndex.add(-1)
        unixClientHasData.add(false)
        client.connect()
        unixClientConnected[unixClientConnected.size - 1] = true
        return unixClients.size - 1
    }

    /** Returns index of any UnixSocket we track that is not closed. */
    public func randUnixClientIndex(): Int64 {
        var open = ArrayList<Int64>()
        for (i in 0..unixClients.size) {
            if (!unixClientClosed[i]) {
                open.add(i)
            }
        }
        if (open.isEmpty()) {
            let si = randBoundUnixServerIndex()
            let path = unixServerPath[si]
            let client = UnixSocket(path)
            client.readTimeout = Some(streamReadTimeout)
            unixClients.add(client)
            unixClientServerPath.add(path)
            unixClientConnected.add(false)
            unixClientClosed.add(false)
            unixClientPeerIndex.add(-1)
            unixClientHasData.add(false)
            return unixClients.size - 1
        }
        return randElemLocal(open)
    }

    /** Returns a connected Unix socket index that has data to read (so read won't block). Ensures one by writing from peer if needed. */
    public func randConnectedUnixSocketIndexWithData(): Int64 {
        for (i in 0..unixClients.size) {
            if (unixClientConnected[i] && !unixClientClosed[i] && unixClientHasData[i]) {
                return i
            }
        }
        for (i in 0..unixClients.size) {
            let j = unixClientPeerIndex[i]
            if (j >= 0 && unixClientPeerIndex[j] == i && unixClientConnected[j] && !unixClientClosed[j]) {
                let payload = randSmallByteArray()
                unixSocketWriteIndex(j, payload)
                return i
            }
        }
        let si = randBoundUnixServerIndex()
        let path = unixServerPath[si]
        let client = UnixSocket(path)
        client.readTimeout = Some(streamReadTimeout)
        unixClients.add(client)
        unixClientServerPath.add(path)
        unixClientConnected.add(false)
        unixClientClosed.add(false)
        unixClientPeerIndex.add(-1)
        unixClientHasData.add(false)
        client.connect()
        unixClientConnected[unixClientConnected.size - 1] = true
        let clientIdx = unixClients.size - 1
        if (!unixServerClosed[si] && unixServerBound[si]) {
            let accepted = unixServers[si].accept(timeout: Some(unixAcceptShortTimeout))
            accepted.readTimeout = Some(streamReadTimeout)
            unixClients.add(accepted)
            unixClientServerPath.add(path)
            unixClientConnected.add(true)
            unixClientClosed.add(false)
            unixClientPeerIndex[clientIdx] = unixClients.size - 1
            unixClientPeerIndex.add(clientIdx)
            unixClientHasData.add(false)
            let payload = randSmallByteArray()
            unixSocketWriteIndex(clientIdx, payload)
            return unixClients.size - 1
        }
        throw Exception("randConnectedUnixSocketIndexWithData: server path not found")
    }

    /** Pre: path valid and not in use, does not exist. Post: server created and recorded. */
    public func unixServerCreate(path: String): UnixServerSocket {
        let server = UnixServerSocket(bindAt: path)
        unixServerPath.add(path)
        unixServers.add(server)
        unixServerBound.add(false)
        unixServerClosed.add(false)
        return server
    }

    public func unixServerCreateUnit(path: String): Unit {
        let _ = unixServerCreate(path)
    }

    /** Pre: server not closed; path not in use and does not exist (path is the one we stored at create). Post: server bound; path in use. */
    public func unixServerBind(serverPath: String): Unit {
        match (indexOfUnixServerByPath(serverPath)) {
            case Some(i) =>
                if (unixServerClosed[i] || unixServerBound[i]) {
                    return
                }
                unixServers[i].bind()
                unixServerBound[i] = true
                unixPathsInUse.add(serverPath)
            case None => return
        }
    }

    private static let unixAcceptShortTimeout: Duration = 20 * Duration.millisecond

    public func unixServerAcceptUnit(serverPath: String): Unit {
        match (indexOfUnixServerByPath(serverPath)) {
            case Some(i) =>
                if (unixServerClosed[i] || !unixServerBound[i]) {
                    return
                }
                let client = unixServers[i].accept(timeout: Some(unixAcceptShortTimeout))
                client.readTimeout = Some(streamReadTimeout)
                let newIdx = unixClients.size
                unixClients.add(client)
                unixClientServerPath.add(serverPath)
                unixClientConnected.add(true)
                unixClientClosed.add(false)
                var peerK: Int64 = -1
                var unpairedCount: Int64 = 0
                for (k in 0..unixClients.size - 1) {
                    if (unixClientServerPath[k] == serverPath && unixClientConnected[k] && unixClientPeerIndex[k] == -1) {
                        unpairedCount += 1
                        peerK = k
                    }
                }
                if (unpairedCount != 1) {
                    peerK = -1
                }
                unixClientPeerIndex.add(peerK)
                unixClientHasData.add(false)
                if (peerK >= 0) {
                    unixClientPeerIndex[peerK] = newIdx
                }
            case None => return
        }
    }

    public func unixServerClose(serverPath: String): Unit {
        match (indexOfUnixServerByPath(serverPath)) {
            case Some(i) =>
                if (!unixServerClosed[i]) {
                    unixServers[i].close()
                    unixServerClosed[i] = true
                    for (j in 0..unixClients.size) {
                        if (unixClientServerPath[j] == serverPath) {
                            unixClientConnected[j] = false
                        }
                    }
                }
            case None => return
        }
    }

    /** Pre: path valid (server must be bound at path for connect to succeed). Post: client created and recorded. */
    public func unixSocketCreate(path: String): UnixSocket {
        let client = UnixSocket(path)
        client.readTimeout = Some(streamReadTimeout)
        unixClients.add(client)
        unixClientServerPath.add(path)
        unixClientConnected.add(false)
        unixClientClosed.add(false)
        unixClientPeerIndex.add(-1)
        unixClientHasData.add(false)
        return client
    }

    public func unixSocketCreateUnit(path: String): Unit {
        let _ = unixSocketCreate(path)
    }

    /** Connect client at index to server (path stored at create). Skips if server no longer bound. On connection refused does not mark connected (avoids long wait). */
    public func unixSocketConnectIndex(i: Int64): Unit {
        if (i < 0 || i >= unixClients.size || unixClientClosed[i] || unixClientConnected[i]) {
            return
        }
        let serverPath = unixClientServerPath[i]
        match (indexOfUnixServerByPath(serverPath)) {
            case Some(si) =>
                if (unixServerClosed[si] || !unixServerBound[si]) {
                    return
                }
            case None => return
        }
        unixClients[i].connect()
        unixClientConnected[i] = true
    }

    /** Pre: i valid; socket connected and not closed; buffer non-empty. On timeout gives up quickly; state updated. */
    public func unixSocketReadIndex(i: Int64, buffer: Array<Byte>): Unit {
        if (buffer.isEmpty()) {
            return
        }
        if (i < 0 || i >= unixClients.size || unixClientClosed[i] || !unixClientConnected[i]) {
            return
        }
        try {
            let _ = unixClients[i].read(buffer)
            unixClientHasData[i] = false
        } catch (_: SocketTimeoutException) {
            unixClientHasData[i] = false
        }
    }

    /** Pre: i valid; socket connected and not closed; payload non-empty. Post: peer's hasData set. */
    public func unixSocketWriteIndex(i: Int64, payload: Array<Byte>): Unit {
        if (payload.isEmpty()) {
            return
        }
        if (i < 0 || i >= unixClients.size || unixClientClosed[i] || !unixClientConnected[i]) {
            return
        }
        let peer = unixClientPeerIndex[i]
        if (peer >= 0 && unixClientClosed[peer]) {
            return
        }
        unixClients[i].write(payload)
        if (peer >= 0) {
            unixClientHasData[peer] = true
        }
    }

    public func unixSocketCloseIndex(i: Int64): Unit {
        if (i < 0 || i >= unixClients.size || unixClientClosed[i]) {
            return
        }
        let peer = unixClientPeerIndex[i]
        unixClients[i].close()
        unixClientClosed[i] = true
        if (peer >= 0 && peer < unixClients.size) {
            unixClientConnected[peer] = false
        }
    }

    /** Optional: validate every path in unixPathsInUse exists as a socket file (like FsContext.validateStateMatchesFilesystem). */
    public func validateStateMatchesReality(): Unit {
        for (i in 0..unixPathsInUse.size) {
            let p = Path(unixPathsInUse[i])
            if (!exists(p)) {
                throw Exception("NetContext: path ${p} in unixPathsInUse does not exist.")
            }
        }
    }

    /** Path for a bound Unix server (so connect will succeed). */
    public func randUnixServerPathBound(): String {
        return unixServerPath[randBoundUnixServerIndex()]
    }

    // --- Unix datagram
    public func randBoundUnixDgramPath(): String {
        for (i in 0..unixDgramSockets.size) {
            if (unixDgramBound[i] && !unixDgramClosed[i]) {
                return unixDgramPath[i]
            }
        }
        let path = randFreshUnixPath()
        let socket = UnixDatagramSocket(bindAt: path)
        unixDgramPath.add(path)
        unixDgramSockets.add(socket)
        unixDgramBound.add(false)
        unixDgramConnected.add(false)
        unixDgramClosed.add(false)
        unixDgramHasData.add(false)
        unixDgramRemotePath.add("")
        socket.bind()
        unixDgramBound[unixDgramBound.size - 1] = true
        unixPathsInUse.add(path)
        unixDgramSockets[unixDgramSockets.size - 1].receiveTimeout = Some(100 * Duration.millisecond)
        return path
    }

    public func randUnixDgramPathForBind(): String {
        for (i in 0..unixDgramSockets.size) {
            if (!unixDgramBound[i] && !unixDgramClosed[i]) {
                return unixDgramPath[i]
            }
        }
        let path = randFreshUnixPath()
        let socket = UnixDatagramSocket(bindAt: path)
        unixDgramPath.add(path)
        unixDgramSockets.add(socket)
        unixDgramBound.add(false)
        unixDgramConnected.add(false)
        unixDgramClosed.add(false)
        unixDgramHasData.add(false)
        unixDgramRemotePath.add("")
        return path
    }

    public func randUnixDgramPath(): String {
        var open = ArrayList<Int64>()
        for (i in 0..unixDgramSockets.size) {
            if (!unixDgramClosed[i]) {
                open.add(i)
            }
        }
        if (open.isEmpty()) {
            return randUnixDgramPathForBind()
        }
        let i = randElemLocal(open)
        return unixDgramPath[i]
    }

    /** Bound Unix dgram path that has data to receive (for receiveFrom). Ensures one by sending to it if needed. */
    public func randBoundUnixDgramPathWithData(): String {
        for (i in 0..unixDgramSockets.size) {
            if (unixDgramBound[i] && !unixDgramClosed[i] && unixDgramHasData[i]) {
                return unixDgramPath[i]
            }
        }
        for (i in 0..unixDgramSockets.size) {
            if (unixDgramBound[i] && !unixDgramClosed[i]) {
                let recipientPath = unixDgramPath[i]
                let senderPath = randBoundUnixDgramPath()
                if (senderPath != recipientPath) {
                    let payload = randSmallByteArray()
                    unixDgramSendTo(senderPath, recipientPath, payload)
                    return recipientPath
                }
            }
        }
        let receiverPath = randBoundUnixDgramPath()
        var senderPath = randBoundUnixDgramPath()
        if (senderPath == receiverPath) {
            let _ = randUnixDgramPathForBind()
            let senderIdx = unixDgramPath.size - 1
            unixDgramBind(unixDgramPath[senderIdx])
            senderPath = unixDgramPath[senderIdx]
        }
        let payload = randSmallByteArray()
        unixDgramSendTo(senderPath, receiverPath, payload)
        return receiverPath
    }

    /** Connected Unix dgram path that has data to receive (for receive). Ensures one by having peer send. */
    public func randConnectedUnixDgramPathWithData(): String {
        for (i in 0..unixDgramSockets.size) {
            if (unixDgramBound[i] && unixDgramConnected[i] && !unixDgramClosed[i] && unixDgramHasData[i]) {
                return unixDgramPath[i]
            }
        }
        let path1 = randConnectedUnixDgramPath()
        match (indexOfUnixDgramByPath(path1)) {
            case Some(i) =>
                let remotePath = unixDgramRemotePath[i]
                if (remotePath != "" && remotePath != path1) {
                    match (indexOfUnixDgramByPath(remotePath)) {
                        case Some(_) =>
                            let payload = randSmallByteArray()
                            unixDgramSendTo(remotePath, path1, payload)
                            return path1
                        case None => ()
                    }
                }
            case None => ()
        }
        let path2 = randBoundUnixDgramPath()
        var path3 = randBoundUnixDgramPath()
        var loops: Int64 = 0
        while (path3 == path2 && loops < 10) {
            path3 = randBoundUnixDgramPath()
            loops += 1
        }
        if (path3 != path2) {
            match (indexOfUnixDgramByPath(path2)) {
                case Some(i) =>
                    if (!unixDgramConnected[i]) {
                        unixDgramConnect(path2, path3)
                        let payload = randSmallByteArray()
                        unixDgramSendTo(path3, path2, payload)
                        return path2
                    }
                case None => ()
            }
        }
        return randBoundUnixDgramPathWithData()
    }

    /** A path we can use as recipient for sendTo (bound Unix socket - dgram or stream server). */
    public func randUnixRecipientPath(): String {
        if (randBool(0.50) && !unixDgramPath.isEmpty()) {
            return randBoundUnixDgramPath()
        }
        return randUnixServerPathBound()
    }

    public func randConnectedUnixDgramPath(): String {
        for (i in 0..unixDgramSockets.size) {
            if (unixDgramBound[i] && unixDgramConnected[i] && !unixDgramClosed[i]) {
                return unixDgramPath[i]
            }
        }
        let path1 = randBoundUnixDgramPath()
        var path2 = randBoundUnixDgramPath()
        var loops: Int64 = 0
        while (path2 == path1 && loops < 10) {
            path2 = randBoundUnixDgramPath()
            loops += 1
        }
        if (path2 == path1) {
            // Only one bound dgram: create and bind a second one so we have two distinct sockets.
            let _ = randUnixDgramPathForBind()
            let senderIdx = unixDgramPath.size - 1
            unixDgramBind(unixDgramPath[senderIdx])
            path2 = unixDgramPath[senderIdx]
        }
        match (indexOfUnixDgramByPath(path1)) {
            case Some(i) =>
                unixDgramSockets[i].connect(path2)
                unixDgramConnected[i] = true
                unixDgramRemotePath[i] = path2
                return path1
            case None => return path1
        }
    }

    public func unixDgramCreate(path: String): Unit {
        let socket = UnixDatagramSocket(bindAt: path)
        unixDgramPath.add(path)
        unixDgramSockets.add(socket)
        unixDgramBound.add(false)
        unixDgramConnected.add(false)
        unixDgramClosed.add(false)
        unixDgramHasData.add(false)
        unixDgramRemotePath.add("")
    }

    public func unixDgramBind(path: String): Unit {
        match (indexOfUnixDgramByPath(path)) {
            case Some(i) =>
                if (unixDgramClosed[i] || unixDgramBound[i]) {
                    return
                }
                unixDgramSockets[i].bind()
                unixDgramBound[i] = true
                unixPathsInUse.add(path)
                unixDgramSockets[i].receiveTimeout = Some(100 * Duration.millisecond)
            case None => return
        }
    }

    public func unixDgramConnect(path: String, remotePath: String): Unit {
        if (path == remotePath) {
            return
        }
        match (indexOfUnixDgramByPath(path)) {
            case Some(i) =>
                if (unixDgramClosed[i] || !unixDgramBound[i] || unixDgramConnected[i]) {
                    return
                }
                unixDgramSockets[i].connect(remotePath)
                unixDgramConnected[i] = true
                unixDgramRemotePath[i] = remotePath
            case None => return
        }
    }

    public func unixDgramDisconnect(path: String): Unit {
        match (indexOfUnixDgramByPath(path)) {
            case Some(i) =>
                if (unixDgramClosed[i] || !unixDgramBound[i]) {
                    return
                }
                unixDgramSockets[i].disconnect()
                unixDgramConnected[i] = false
                unixDgramRemotePath[i] = ""
            case None => return
        }
    }

    public func unixDgramSendTo(path: String, recipientPath: String, payload: Array<Byte>): Unit {
        if (path == recipientPath) {
            return
        }
        match (indexOfUnixDgramByPath(path)) {
            case Some(i) =>
                if (unixDgramClosed[i] || !unixDgramBound[i]) {
                    return
                }
                match (indexOfUnixDgramByPath(recipientPath)) {
                    case Some(j) =>
                        unixDgramSockets[i].sendTo(UnixSocketAddress(recipientPath), payload)
                        unixDgramHasData[j] = true
                    case None => return
                }
            case None => return
        }
    }

    public func unixDgramReceiveFrom(path: String, buffer: Array<Byte>): Unit {
        match (indexOfUnixDgramByPath(path)) {
            case Some(i) =>
                if (unixDgramClosed[i] || !unixDgramBound[i] || buffer.isEmpty()) {
                    return
                }
                try {
                    let _ = unixDgramSockets[i].receiveFrom(buffer)
                    unixDgramHasData[i] = false
                } catch (_: SocketTimeoutException) {
                    unixDgramHasData[i] = false
                }
            case None => return
        }
    }

    public func unixDgramSend(path: String, payload: Array<Byte>): Unit {
        match (indexOfUnixDgramByPath(path)) {
            case Some(i) =>
                if (unixDgramClosed[i] || !unixDgramBound[i] || !unixDgramConnected[i] || payload.isEmpty()) {
                    return
                }
                unixDgramSockets[i].send(payload)
                let remotePath = unixDgramRemotePath[i]
                if (remotePath != "") {
                    match (indexOfUnixDgramByPath(remotePath)) {
                        case Some(j) => unixDgramHasData[j] = true
                        case None => ()
                    }
                }
            case None => return
        }
    }

    public func unixDgramReceive(path: String, buffer: Array<Byte>): Unit {
        match (indexOfUnixDgramByPath(path)) {
            case Some(i) =>
                if (unixDgramClosed[i] || !unixDgramBound[i] || !unixDgramConnected[i] || buffer.isEmpty()) {
                    return
                }
                try {
                    let _ = unixDgramSockets[i].receive(buffer)
                    unixDgramHasData[i] = false
                } catch (_: SocketTimeoutException) {
                    unixDgramHasData[i] = false
                }
            case None => return
        }
    }

    public func unixDgramClose(path: String): Unit {
        match (indexOfUnixDgramByPath(path)) {
            case Some(i) =>
                if (!unixDgramClosed[i]) {
                    unixDgramSockets[i].close()
                    unixDgramClosed[i] = true
                    for (j in 0..unixDgramSockets.size) {
                        if (!unixDgramClosed[j] && unixDgramRemotePath[j] == path) {
                            unixDgramConnected[j] = false
                            unixDgramRemotePath[j] = ""
                        }
                    }
                }
            case None => return
        }
    }

    // --- UDP generators (index-based: UdpSocket has no Equatable)
    private var udpConnectPortCurrent: UInt16 = 54321u16

    private static let udpReceiveTimeout: Duration = 100 * Duration.millisecond

    public func randBoundUdpSocketIndex(): Int64 {
        for (i in 0..udpSockets.size) {
            if (udpBound[i] && !udpClosed[i]) {
                return i
            }
        }
        let socket = UdpSocket(bindAt: 0u16)
        udpSockets.add(socket)
        udpBound.add(false)
        udpConnected.add(false)
        udpClosed.add(false)
        udpBoundPort.add(0u16)
        udpHasData.add(false)
        socket.bind()
        udpBound[udpBound.size - 1] = true
        match (portFromSocketAddress(udpSockets[udpSockets.size - 1].localAddress)) {
            case Some(p) => udpBoundPort[udpBoundPort.size - 1] = p
            case None => ()
        }
        udpSockets[udpSockets.size - 1].receiveTimeout = Some(udpReceiveTimeout)
        return udpSockets.size - 1
    }

    public func randUdpSocketIndex(): Int64 {
        var open = ArrayList<Int64>()
        for (i in 0..udpSockets.size) {
            if (!udpClosed[i]) {
                open.add(i)
            }
        }
        if (open.isEmpty()) {
            let socket = UdpSocket(bindAt: 0u16)
            udpSockets.add(socket)
            udpBound.add(false)
            udpConnected.add(false)
            udpClosed.add(false)
            udpBoundPort.add(0u16)
            udpHasData.add(false)
            return udpSockets.size - 1
        }
        return randElemLocal(open)
    }

    public func randConnectedUdpSocketIndex(): Int64 {
        for (i in 0..udpSockets.size) {
            if (udpBound[i] && udpConnected[i] && !udpClosed[i]) {
                return i
            }
        }
        let i = randBoundUdpSocketIndex()
        let remote = IPSocketAddress(IPv4Address.localhost, udpConnectPortCurrent)
        udpSockets[i].connect(remote)
        udpConnected[i] = true
        return i
    }

    /** Payload size in [1, 512] for UDP to avoid "message too long" on all platforms. */
    public func randSmallByteArrayUdp(): Array<Byte> {
        let n = randIntRangeLocal(1, 513)
        return randSmallBytesLocal(n)
    }

    /** Recipient is a bound, non-closed UDP socket's address so sendTo never targets a closed port. */
    public func randUdpRecipientAddress(): SocketAddress {
        let j = randBoundUdpSocketIndex()
        return IPSocketAddress(IPv4Address.localhost, udpBoundPort[j])
    }

    /** Index of a bound UDP socket that has data to receive (for receiveFrom). Always ensures by sending in this run so receiveFrom never sees a stale or closed sender. */
    public func randBoundUdpSocketIndexWithData(): Int64 {
        let i = randBoundUdpSocketIndex()
        var senderIdx = randBoundUdpSocketIndex()
        if (senderIdx == i) {
            let newIdx = udpSocketCreate()
            udpSocketBind(newIdx)
            senderIdx = newIdx
        }
        let recipient = IPSocketAddress(IPv4Address.localhost, udpBoundPort[i])
        let payload = randSmallByteArrayUdp()
        udpSocketSendTo(senderIdx, recipient, payload)
        return i
    }

    /** Ensures a socket is bound at udpConnectPortCurrent; returns its index. */
    private func ensureBoundUdpSocketAtConnectPort(): Int64 {
        for (i in 0..udpSockets.size) {
            if (udpBound[i] && !udpClosed[i] && udpBoundPort[i] == udpConnectPortCurrent) {
                return i
            }
        }
        let socket = UdpSocket(bindAt: udpConnectPortCurrent)
        udpSockets.add(socket)
        udpBound.add(false)
        udpConnected.add(false)
        udpClosed.add(false)
        udpBoundPort.add(udpConnectPortCurrent)
        udpHasData.add(false)
        socket.bind()
        udpBound[udpBound.size - 1] = true
        udpSockets[udpSockets.size - 1].receiveTimeout = Some(udpReceiveTimeout)
        return udpSockets.size - 1
    }

    /** Index of a connected UDP socket that has data to receive (for receive). Ensures one by having peer at 54321 send to this socket's port. */
    public func randConnectedUdpSocketIndexWithData(): Int64 {
        for (i in 0..udpSockets.size) {
            if (udpBound[i] && udpConnected[i] && !udpClosed[i] && udpHasData[i]) {
                return i
            }
        }
        let clientIdx = randConnectedUdpSocketIndex()
        let clientPort = udpBoundPort[clientIdx]
        let serverIdx = ensureBoundUdpSocketAtConnectPort()
        let recipient = IPSocketAddress(IPv4Address.localhost, clientPort)
        let payload = randSmallByteArrayUdp()
        udpSocketSendTo(serverIdx, recipient, payload)
        return clientIdx
    }

    public func udpSocketCreate(): Int64 {
        let socket = UdpSocket(bindAt: 0u16)
        udpSockets.add(socket)
        udpBound.add(false)
        udpConnected.add(false)
        udpClosed.add(false)
        udpBoundPort.add(0u16)
        udpHasData.add(false)
        return udpSockets.size - 1
    }

    public func udpSocketCreateUnit(): Unit {
        let _ = udpSocketCreate()
    }

    public func udpSocketBind(i: Int64): Unit {
        if (i < 0 || i >= udpSockets.size || udpClosed[i] || udpBound[i]) {
            return
        }
        udpSockets[i].bind()
        udpBound[i] = true
        match (portFromSocketAddress(udpSockets[i].localAddress)) {
            case Some(p) => udpBoundPort[i] = p
            case None => ()
        }
        udpSockets[i].receiveTimeout = Some(udpReceiveTimeout)
    }

    public func udpSocketConnect(i: Int64): Unit {
        if (i < 0 || i >= udpSockets.size || udpClosed[i] || !udpBound[i] || udpConnected[i]) {
            return
        }
        udpSockets[i].connect(IPSocketAddress(IPv4Address.localhost, udpConnectPortCurrent))
        udpConnected[i] = true
    }

    public func udpSocketDisconnect(i: Int64): Unit {
        if (i < 0 || i >= udpSockets.size || udpClosed[i] || !udpBound[i]) {
            return
        }
        udpSockets[i].disconnect()
        udpConnected[i] = false
    }

    public func udpSocketSendTo(i: Int64, recipient: SocketAddress, payload: Array<Byte>): Unit {
        if (i < 0 || i >= udpSockets.size || udpClosed[i] || !udpBound[i]) {
            return
        }
        if (payload.isEmpty()) {
            return
        }
        match (portFromSocketAddress(recipient)) {
            case Some(port) =>
                var recipientLive = false
                for (j in 0..udpSockets.size) {
                    if (udpBound[j] && !udpClosed[j] && udpBoundPort[j] == port) {
                        recipientLive = true
                        break
                    }
                }
                if (!recipientLive) {
                    return
                }
                udpSockets[i].sendTo(recipient, payload)
                for (j in 0..udpSockets.size) {
                    if (udpBound[j] && !udpClosed[j] && udpBoundPort[j] == port) {
                        udpHasData[j] = true
                        break
                    }
                }
            case None => return
        }
    }

    public func udpSocketReceiveFrom(i: Int64, buffer: Array<Byte>): Unit {
        if (i < 0 || i >= udpSockets.size || udpClosed[i] || !udpBound[i] || buffer.isEmpty() || !udpHasData[i]) {
            return
        }
        try {
            let _ = udpSockets[i].receiveFrom(buffer)
            udpHasData[i] = false
        } catch (_: SocketTimeoutException) {
            udpHasData[i] = false
        }
    }

    public func udpSocketSend(i: Int64, payload: Array<Byte>): Unit {
        if (i < 0 || i >= udpSockets.size || udpClosed[i] || !udpBound[i] || !udpConnected[i] || payload.isEmpty()) {
            return
        }
        var peerAtConnectPortExists = false
        for (k in 0..udpSockets.size) {
            if (udpBound[k] && !udpClosed[k] && udpBoundPort[k] == udpConnectPortCurrent) {
                peerAtConnectPortExists = true
                break
            }
        }
        if (!peerAtConnectPortExists) {
            return
        }
        udpSockets[i].send(payload)
        for (j in 0..udpSockets.size) {
            if (udpBound[j] && !udpClosed[j] && udpBoundPort[j] == udpConnectPortCurrent) {
                udpHasData[j] = true
                break
            }
        }
    }

    public func udpSocketReceive(i: Int64, buffer: Array<Byte>): Unit {
        if (i < 0 || i >= udpSockets.size || udpClosed[i] || !udpBound[i] || !udpConnected[i] || buffer.isEmpty()) {
            return
        }
        var peerAtConnectPortExists = false
        for (k in 0..udpSockets.size) {
            if (udpBound[k] && !udpClosed[k] && udpBoundPort[k] == udpConnectPortCurrent) {
                peerAtConnectPortExists = true
                break
            }
        }
        if (!peerAtConnectPortExists) {
            return
        }
        try {
            let _ = udpSockets[i].receive(buffer)
            udpHasData[i] = false
        } catch (_: SocketTimeoutException) {
            udpHasData[i] = false
        }
    }

    public func udpSocketClose(i: Int64): Unit {
        if (i < 0 || i >= udpSockets.size || udpClosed[i]) {
            return
        }
        let wasBoundAtConnectPort = udpBound[i] && udpBoundPort[i] == udpConnectPortCurrent
        udpSockets[i].close()
        udpClosed[i] = true
        udpHasData[i] = false
        if (wasBoundAtConnectPort) {
            for (j in 0..udpSockets.size) {
                udpConnected[j] = false
            }
            udpConnectPortCurrent = if (udpConnectPortCurrent >= 65000u16) { 54321u16 } else { udpConnectPortCurrent + 1u16 }
        }
        for (j in 0..udpSockets.size) {
            udpHasData[j] = false
        }
    }

    public func cleanup(): Unit {
        for (i in 0..tcpClients.size) {
            if (!tcpClientClosed[i]) {
                tcpClients[i].close()
            }
        }
        for (i in 0..tcpServers.size) {
            if (!tcpServerClosed[i]) {
                tcpServers[i].close()
            }
        }
        for (i in 0..unixClients.size) {
            if (!unixClientClosed[i]) {
                unixClients[i].close()
            }
        }
        for (i in 0..unixServers.size) {
            if (!unixServerClosed[i]) {
                unixServers[i].close()
            }
        }
        for (i in 0..udpSockets.size) {
            if (!udpClosed[i]) {
                udpSockets[i].close()
            }
        }
        for (i in 0..unixDgramSockets.size) {
            if (!unixDgramClosed[i]) {
                unixDgramSockets[i].close()
            }
        }
        // Remove Unix socket files so next run (or fresh NetContext) does not see existing paths.
        for (j in 0..unixPathsInUse.size) {
            removeIfExists(Path(unixPathsInUse[j]), recursive: true)
        }
    }
}