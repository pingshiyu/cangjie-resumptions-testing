# Net Fuzzer: Structure, Design, and Implementation Guide

This document describes the overall structure of the net fuzzer, the design decisions made during development, and their reasoning. It is intended to inform both humans and agents so that the fuzzer can be maintained, extended, or reimplemented while avoiding known pitfalls.

---

## 1. Overall structure

### 1.1 Components and file roles

| File | Role |
|------|------|
| `src/net_testing_entry.cj` | Entry point: creates `NetContext`, builds the runner list via `getLibNet(netCtx)`, initialises context, runs `executeUntilDone(lib, 25, dummyNetTester)` inside `withSeed(None)` for 1000 iterations, then cleans up. |
| `src/net_testing_lib.cj` | Defines TCP, Unix (stream + dgram), and UDP runner lists. Each runner is `@RunRandomly([args...], netCtx.someMethod)`. Registers which generators feed which wrapper methods. **Do not put business logic here**—only runner registration. |
| `src/net_testing_generators.cj` | Defines `NetContext`: all abstract state (parallel arrays per protocol), all **generators** (e.g. `randBoundTcpServerIndex`, `randUdpRecipientAddress`), and all **wrapper methods** that call std.net and update state. |
| `src/resumptions/exec_loop.cj` | Generic execution loop: handles `Switch`, maintains a list of resumptions, and each “step” either runs a random `UnitFn` from the lib (with probability and fuel) or resumes a random resumption. |
| `src/define/run_random_macro.cj` | Macro `@RunRandomly([x in genA, y in genB], netCtx.foo)` expands to a `UnitFn` that: (1) runs each generator once to get arguments, (2) calls `netCtx.foo(x, y)`. Generators and the call run in one go—no other runner runs in between. |

### 1.2 Execution model

- **Entry** calls `executeUntilDone(lib, maxFuel, dummyNetTester)`.
- `dummyNetTester` performs `Switch()` multiple times (e.g. three times in the current code). Each `Switch` is **handled** by the exec loop: the loop does **not** call `dummyNetTester` again immediately; it either:
  - **Run a random runner**: pick a random index into `lib`, call that `UnitFn`. That `UnitFn` is the expansion of `@RunRandomly(...)`: it runs the generators (which may call other wrappers and modify state), then calls the wrapper (e.g. `tcpSocketWriteIndex(i, payload)`).
  - **Resume a resumption** (if any), or skip if no fuel and no resumptions.
- So “one iteration” of the fuzzer is: run `dummyNetTester` until it completes (all `Switch` performed), where each `Switch` is “resolved” by running a random net action or a resumption. The number of net actions per iteration is bounded by `maxFuel` and the number of `Switch` in the tester.
- **Important**: For a single runner invocation, the sequence is: run generator 1, run generator 2, … , run wrapper. No other runner runs between generator and wrapper. So preconditions checked in the wrapper are still valid relative to the state at generator run time, **provided** generators only observe and update the same `NetContext` and no other thread runs.

### 1.3 Generators vs wrappers

- **Generators** (e.g. `randBoundTcpServerIndex()`, `randUdpRecipientAddress()`) **return** values that will be passed to a wrapper. They may **create** resources (e.g. create and bind a server) and/or **call wrappers** (e.g. send data so that “hasData” is true). They must satisfy the **preconditions** of the wrapper they feed: e.g. a generator for “socket index with data” must ensure that the returned index actually has data (by sending in the same run if necessary).
- **Wrappers** (e.g. `tcpSocketWriteIndex(i, payload)`, `udpSocketSendTo(i, recipient, payload)`) perform the **std.net** call and **update abstract state** so it stays in sync with the concrete state. They should **not** rely on try/catch to hide precondition violations; they should either enforce preconditions at the start (and return without calling the API) or document that only valid inputs are passed (via generators).

---

## 2. Abstract state (NetContext)

State is kept in **parallel arrays** keyed by index. Socket types in std.net may not be `Equatable`, so we identify resources by **index** into these arrays, not by socket identity.

### 2.1 TCP

- **Servers**: `tcpServers`, `tcpServerBound`, `tcpServerClosed`. After `bind()`, `tcpServerBound[i] = true`; port comes from `server.localAddress`.
- **Clients**: `tcpClients`, `tcpClientConnected`, `tcpClientClosed`, `tcpClientServerIndex` (which server this client was created for / accepted from), `tcpClientPeerIndex` (accepted peer index, or -1), `tcpClientHasData` (true when peer has written so we can read without blocking).

Pairing: when a client connects and the server accepts, the accepted socket is appended to `tcpClients` and the two indices are linked via `tcpClientPeerIndex`.

### 2.2 Unix stream (non-Windows)

- **Servers**: path-keyed; `unixServerPath`, `unixServers`, `unixServerBound`, `unixServerClosed`. Paths in use are also in `unixPathsInUse`.
- **Clients**: `unixClients`, `unixClientServerPath`, `unixClientConnected`, `unixClientClosed`, `unixClientPeerIndex`, `unixClientHasData`.

Same idea as TCP: pairing via `unixClientPeerIndex` when a connecting client is accepted.

### 2.3 Unix datagram (non-Windows)

- Per-socket: `unixDgramPath`, `unixDgramSockets`, `unixDgramBound`, `unixDgramConnected`, `unixDgramClosed`, `unixDgramHasData`, `unixDgramRemotePath` (for connected mode).

### 2.4 UDP

- **Sockets**: `udpSockets`, `udpBound`, `udpConnected`, `udpClosed`, `udpBoundPort`, `udpHasData`.
- **Connected mode**: “Connected” means the socket is connected to a fixed **connect port**. That port is tracked in **`udpConnectPortCurrent`** (instance var, starts at 54321). One designated “server” socket is bound at `udpConnectPortCurrent`; other sockets can `connect()` to that port for `send`/`receive`. When the socket at the connect port is closed, we **advance** `udpConnectPortCurrent` (e.g. increment, or wrap) so the next “server” is bound at a **new** port, avoiding reuse of a recently closed port that can cause “Connection refused” on some stacks.

---

## 3. Design decisions and reasoning

### 3.1 Preconditions over try/catch

**Decision**: Do **not** use try/catch to swallow errors. Ensure that only valid inputs are passed into std.net and that after each call the abstract state matches the concrete state.

**Reasoning**: Catching all exceptions hides bugs (e.g. state desync, wrong indices). The fuzzer should fail when preconditions are violated so that generators and state updates can be fixed. Timeouts are a special case: the prompt allows “timeout and give up” to keep runs fast; so a **narrow** catch for `SocketTimeoutException` is acceptable **only** when we **update state** to reflect the outcome (e.g. set `hasData = false` after a read timeout). Do **not** catch broad `SocketException` or similar in connect/send paths.

**Concretely**:

- **TCP connect**: We only catch `SocketTimeoutException`; we do **not** mark connected on timeout. We do **not** catch `SocketException` (e.g. connection refused)—if the server was closed or unreachable, the test should fail so state can be fixed.
- **Unix stream connect**: No try/catch; we already skip if the server is not bound. If connect still throws, state is wrong and we want to see it.
- **Read/receive**: Only catch `SocketTimeoutException` and set `hasData = false` so the model reflects “no data received”. Do not catch other exceptions.

### 3.2 State sync on close (critical)

When a resource is closed, **all** state that depends on it must be updated so no later action assumes it is still valid. Otherwise the next random action may call read/write/send on a broken or closed peer and get “Connection reset by peer” or “Connection refused”.

**TCP**

- **Closing a client** (`tcpSocketCloseIndex(i)`): After closing the socket and setting `tcpClientClosed[i] = true`, set **`tcpClientConnected[peer] = false`** for the peer index `tcpClientPeerIndex[i]`. The peer’s connection is broken; we must not allow write (or read) to be chosen for that peer.
- **Closing a server** (`tcpServerCloseIndex(i)`): After closing the server, set **`tcpClientConnected[j] = false`** for every `j` with `tcpClientServerIndex[j] == i`. Any client that was connected to this server (or created for it) is now invalid for read/write.

**Unix stream**

- Same idea: on **unixSocketCloseIndex(i)** set **`unixClientConnected[peer] = false`** for the peer. On **unixServerClose(serverPath)** set **`unixClientConnected[j] = false`** for all clients with `unixClientServerPath[j] == serverPath`.

**Unix datagram**

- On **unixDgramClose(path)**: For every other socket `j` with `unixDgramRemotePath[j] == path`, set **`unixDgramConnected[j] = false`** and **`unixDgramRemotePath[j] = ""`** so we never send/receive on a “connected” socket whose peer is closed.

**UDP**

- When closing a socket **bound at the connect port** (`udpConnectPortCurrent`):
  - Set **`udpConnected[j] = false`** for all `j` (all “connected” sockets were connected to that port).
  - **Advance** **`udpConnectPortCurrent`** (e.g. increment with wrap) so the next “server” is bound at a **new** port. This avoids “Connection refused” when sending or receiving on a socket that is still logically “connected” to a port that no longer has a live socket.
- On **any** UDP socket close: clear **`udpHasData[j] = false`** for all `j`. We do not track which sender put data in which receiver; after any close, we assume no buffer is safe to rely on for receiveFrom, so we force the next receiveFrom to be driven by a generator that ensures data by sending in the same run.

### 3.3 UDP: sendTo and send preconditions

**sendTo**

- The recipient address is chosen by **`randUdpRecipientAddress()`**, which must return an address whose **port** is currently bound by a **non-closed** socket. Implementation: pick `j = randBoundUdpSocketIndex()` and return `(localhost, udpBoundPort[j])`.
- In **`udpSocketSendTo(i, recipient, payload)`**, before calling `sendTo`, **check** that there exists some `j` with `udpBound[j] && !udpClosed[j] && udpBoundPort[j] == port` (where `port` is from `recipient`). If not, return without calling the API. This guards against any generator/ordering oddity where the recipient socket was closed after the generator ran (e.g. if multiple runners were ever interleaved or state is wrong).

**send (connected UDP)**

- Connected UDP sends to **`udpConnectPortCurrent`**. Before calling **`udpSocketSend(i, payload)`**, check that there exists at least one socket `k` with `udpBound[k] && !udpClosed[k] && udpBoundPort[k] == udpConnectPortCurrent`. If not, return without sending. Same idea: never send to a “peer” that has been closed.

**receive (connected UDP)**

- Before calling **`udpSocketReceive(i, buffer)`**, require the same “peer at connect port exists” check. Otherwise do not call `receive`.

### 3.4 Ensuring “has data” for receive (avoid blocking and stray errors)

Read and receive must only be called when there is actually data (or a short timeout is acceptable). So:

- **Generators** for “socket with data” (e.g. `randConnectedTcpSocketIndexWithData`, `randBoundUdpSocketIndexWithData`) must **ensure** that the returned index has data. If no such socket exists, they should **create** a pair (or use an existing pair), **send** data, then return the receiver index. For UDP **receiveFrom**, we **always** ensure by sending in the **same** generator run (no reuse of “hasData” from a previous run), so we never call receiveFrom on a socket that might have stale or invalid sender state; that avoids “Connection refused” and similar in the underlying stack.
- **Wrappers** for read/receive should check `hasData` (and for UDP connected receive, “peer at connect port exists”) and return without calling the API if the precondition fails. They may use a **short timeout** on the actual read/receive and catch only **SocketTimeoutException** to set `hasData = false`.

### 3.5 Timeouts

To keep runs fast and avoid hanging:

- **TCP**: Short **connect** timeout (e.g. 200 ms), short **accept** timeout (e.g. 20 ms), short **read** timeout (e.g. 150 ms). On connect timeout we simply do not set `tcpClientConnected[i] = true`.
- **Unix**: Short **accept** and **read** timeouts where applicable.
- **UDP / Unix dgram**: Short **receiveTimeout** on sockets so receive does not block indefinitely.

### 3.6 Index-based tracking

Because socket types may not be `Equatable`, we never compare sockets by value. We use **indices** into the context’s arrays. Every wrapper that takes an index must validate `0 <= i < size` and the relevant flags (e.g. `!closed`, `connected`) and return without calling the API if invalid.

---

## 4. Common mistakes to avoid

1. **Using try/catch to hide errors**  
   Do not catch broad exceptions (e.g. `SocketException`) in connect, send, or sendTo. Use preconditions and state updates so that only valid operations are performed. Allow only narrow timeout handling with explicit state update (e.g. `hasData = false`).

2. **Forgetting to mark the peer disconnected when closing one end**  
   If you close a TCP/Unix client, set `tcpClientConnected[peer] = false` (and similarly for Unix). Otherwise the fuzzer may later choose “write” for that peer and get “Connection reset by peer”.

3. **Forgetting to mark clients disconnected when closing a server**  
   When closing a TCP or Unix server, set `tcpClientConnected[j] = false` (or Unix equivalent) for all clients that were associated with that server. Otherwise writes to those clients can fail with connection reset.

4. **Sending to a closed or non-existent recipient (UDP)**  
   Always ensure the recipient port has a live bound socket: in the generator (e.g. `randUdpRecipientAddress` → bound socket’s address) and again in the wrapper (check that some socket is still bound and not closed at that port before calling `sendTo`).

5. **Using a fixed UDP “connect port” that gets reused after close**  
   When the socket bound at the connect port is closed, advance the connect port (e.g. `udpConnectPortCurrent += 1` with wrap) and mark all UDP sockets as not connected. Otherwise connected send/receive can hit “Connection refused” on some stacks.

6. **Assuming “hasData” stays true across closes**  
   When any UDP socket is closed, clear `udpHasData` for all sockets so that receiveFrom is only used when the generator has just ensured data in the same run. For Unix dgram, similar care: ensure data or have a clear notion of when it’s safe to receive.

7. **Letting receiveFrom/receive run without ensuring data**  
   Use “with data” generators that **create and send in the same run** where possible (e.g. UDP receiveFrom). For TCP/Unix stream, ensure hasData by writing from the peer in the generator so read is not called on a connection with no data (avoid long blocks or timeouts).

8. **Exposing connect as a random action without ensuring accept**  
   Connect can block until timeout if no one calls accept. We keep a short timeout and only catch `SocketTimeoutException`; we do not mark connected on failure. If the test fails often on connect, consider ensuring in the test harness or generators that a server is ready to accept (e.g. by having “connect” only used from generators that also drive accept, or by accepting that some random runs will timeout and not connect).

---

## 5. Runner registration pattern

In `net_testing_lib.cj`, each runner is:

```text
@RunRandomly([arg1 in netCtx.gen1, arg2 in netCtx.gen2, ...], netCtx.wrapperMethod)
```

- **gen1, gen2, ...** are called **once per invocation** of this runner, in order; their return values are passed to **wrapperMethod**.
- Generators must return values that satisfy the wrapper’s preconditions. The wrapper can still do defensive checks and return without calling the API if state has changed (e.g. recipient port no longer live).

Adding a new net operation:

1. Add any new state in `NetContext` if needed.
2. Add generators that produce valid inputs for the new wrapper.
3. Add a wrapper that calls std.net and updates state (and enforces preconditions at entry).
4. Register a new runner in `getTcpRunners` / `getUnixRunners` / `getUnixDgramRunners` / `getUdpRunners` with `@RunRandomly([...], netCtx.newWrapper)`.

---

## 6. Initialisation and cleanup

- **initialiseContext()**: Create `tmpRoot` directory if needed; ensure at least one bound TCP server and one connected TCP client exist (e.g. by calling `randBoundTcpServerIndex()` and `randConnectedTcpSocketIndex()`) so the first random actions have something to work with.
- **cleanup()**: Close all non-closed sockets in every list (TCP clients/servers, Unix clients/servers, UDP, Unix dgram), then remove Unix socket files under `unixPathsInUse` so the next run or a fresh context does not see leftover paths.

---

## 7. Summary

The net fuzzer is a **random testing** harness: it repeatedly runs random sequences of std.net operations (TCP, Unix stream, Unix dgram, UDP) driven by **generators** that are supposed to produce valid inputs, and **wrappers** that perform the call and keep **abstract state** in sync with the real process state. Success depends on:

- **Strict preconditions** in wrappers and generators (no broad try/catch).
- **Complete state updates on close** (peer disconnected, server’s clients disconnected, UDP connect port advanced, hasData cleared where needed).
- **Preconditions on send/sendTo** (recipient port or connect-port peer must be live).
- **“With data” generators** that ensure data in the same run for receive paths, and short timeouts everywhere to keep runs fast and avoid trivial “all timeout” behaviour.

Following this design and avoiding the listed mistakes should allow another implementation (by a human or agent) to reproduce a robust net fuzzer that runs without spurious runtime errors.
