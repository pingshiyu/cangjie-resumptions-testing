# Net testing bug report: segfault and related failures

## Summary

Running `main_net_testing()` (1000 iterations via `./cjpm-run.sh`) can trigger:

1. **Segfault** (occasional) – in the runtime GC thread.
2. **SocketException: "The socket is already connected"** – UDP path; state inconsistency.
3. **SocketException: "Failed to write data 1: Operation not permitted"** – Unix datagram send.

---

## 1. Segfault (SIGSEGV)

### When it happens

- **Frequency**: Occasional; often after hundreds of iterations (e.g. 262–330, 329, 667+ in different runs).
- **Thread**: `Thread 3 "gc-main-thread"` (garbage collector).
- **Location**: Inside runtime/generated code, not in user Cangjie code. Example:
  - `0x0000723e93218762` (JIT/runtime-style address).
  - GDB: “Backtrace stopped: Cannot access memory at address 0x723e6ed3aa50”.

### Likely cause

- Crash is in the **GC thread**, not in the main test loop.
- Possible causes:
  - **Use-after-free**: Main thread closes/frees sockets or collections while GC is scanning.
  - **Bad object graph**: Certain combinations of socket/collection state leading to invalid references during GC.
  - **Race**: Main thread and GC accessing the same structures (e.g. `NetContext` or std.net internals) without synchronisation.

### How to reproduce

```bash
./cjpm-run.sh
# Or run repeatedly until segfault:
./run-until-error.sh
# Or under GDB to get a backtrace:
gdb -batch -ex "run" -ex "bt full" -ex "quit" --args ./target/release/bin/main
```

### Code path (user side)

- Entry: `main_net_testing()` → `withSeed` → loop 1000 × (`NetContext` create → `initialiseContext` → `executeUntilDone(lib, 25, dummyNetTester)` → `cleanup`).
- `executeUntilDone` randomly runs lib functions (TCP/Unix/UDP ops) or resumes `dummyNetTester`; any of the net operations can allocate, close sockets, or change shared state that GC may later traverse.

---

## 2. SocketException: "The socket is already connected"

### When it happens

- During a random lib run, when the executor picks **UDP receive** (e.g. `udpSocketReceive`).
- Call chain: `getUdpRunners::lambda.7` → `randConnectedUdpSocketIndexWithData()` → `randConnectedUdpSocketIndex()` → `udpSockets[i].connect(remote)`.

### Where in code

- **Trigger**: `net_testing_generators.cj` – `randConnectedUdpSocketIndex()` (around line 1176).
- **Root cause**: `udpSocketClose(i)` (around 1375–1392). When the closed socket was bound at `udpConnectPortCurrent` (the “server” port), the code sets `udpConnected[j] = false` for **all** `j`, but **does not** call `udpSockets[j].disconnect()`. So:
  - OS-level socket remains connected.
  - Our state says `udpConnected[j] = false`.
  - Later `randConnectedUdpSocketIndex()` does not find any connected socket, picks a bound socket (one of those `j`), and calls `connect()` again → OS throws “socket is already connected”.

### Fix (applied in code)

- In `udpSocketClose`, when clearing `udpConnected[j]`, call `udpSockets[j].disconnect()` for each socket that was actually connected (and still valid) before setting `udpConnected[j] = false`. This keeps OS and bookkeeping in sync and prevents the exception.

---

## 3. SocketException: "Failed to write data 1: Operation not permitted"

### When it happens

- During a random **Unix datagram** action: `unixDgramSendTo` (e.g. from `randBoundUnixDgramPathWithData()` → `getUnixDgramRunners::lambda.6`).

### Where in code

- **Trigger**: `net_testing_generators.cj` – `unixDgramSendTo` (around 1045) → std.net `UnixDatagramSocket::sendTo`.
- Likely causes: target path no longer valid (e.g. socket file removed), or permission/state issue on the receiving socket; less likely a direct cause of the GC segfault but can leave sockets in a bad state.

---

## 4. Functions / actions that stand out

| Area        | Function / action                         | Observed issue                                      |
|------------|--------------------------------------------|-----------------------------------------------------|
| UDP        | `udpSocketClose`                           | Clears `udpConnected` without `disconnect` → later `randConnectedUdpSocketIndex` can call `connect()` on already-connected socket. |
| UDP        | `randConnectedUdpSocketIndex`              | Calls `connect()`; fails with “already connected” when state is out of sync. |
| UDP        | `randConnectedUdpSocketIndexWithData`      | Calls above; used by `udpSocketReceive`.             |
| Unix dgram | `unixDgramSendTo`                          | Can throw “Operation not permitted”.                |
| GC         | Runtime “gc-main-thread”                   | Segfault in GC; may be triggered by net/cleanup pattern. |

---

## 5. Recommendations

1. **UDP state**: Keep the fix that calls `disconnect()` before clearing `udpConnected` when closing the socket at `udpConnectPortCurrent`.
2. **Segfault**: Reproduce with a debug/runtime build (if available) and capture a full GC backtrace; consider running with a single iteration or reduced net activity to see if the crash is allocation/pattern-dependent.
3. **Unix dgram**: Add prechecks (e.g. path/socket still exists and is writable) before `unixDgramSendTo`, or catch and handle “Operation not permitted” so one bad send does not abort the whole run.
