Look into the `std/net` library in cangjie_runtime. Please summarise the public-facing APIs, and design a testing system that:
1. simulates necessary states for the library using a class. The states should provide sufficient information to design generators that can always satisfy the preconditions of each function.
2. provide generators that satisfies the preconditions of the calls in the library
3. update the state after each calls to keep the simulation up to date
4. if possible, design internal checks that validates the abstract state kept follows the concrete state.

Explicitly record down the pre/postcondition specification you infer from the code, and record them down in your design.

The calls, the concrete state and the abstract state should be consistent with each other: they should eliminate the need of try/catch statements surrounding any calls, by ensuring that the generated value always satisfies the preconditions of the function calls.

An existing example for filesystems exist for the files with prefix `fs_...cj`. Please design a similar system following the structure of those files. The files `net_...cj` have already beeen created.

---

## Design / Pre-Postcondition spec (recorded)

- **State class**: `NetContext` in `net_testing_lib.cj` holds abstract state (TCP servers/clients and their bound/connected/closed flags; Unix paths and sockets when Phase 2+ are in place).
- **Generators** ensure preconditions: e.g. `randBoundTcpServer` returns a bound, non-closed server (or creates one); `randConnectedTcpSocket` returns a connected, non-closed client (or creates one); `randSmallByteArray` returns non-empty buffers; `randTcpClientAddress` returns an address of a bound server so `connect` succeeds.
- **Wrappers** in `NetContext` perform the std.net call and then update state (e.g. after `bind()` set `tcpServerBound[i] = true`; after `close()` set `tcpServerClosed[i] = true`). See method comments in `net_testing_lib.cj` for per-call pre/post.
- **Consistency**: Calls use only these wrappers and generators, so no try/catch is needed around the generated calls; the only internal try/catch is in `tcpServerAcceptUnit` for `SocketTimeoutException` when accept times out with no connecting client.
- Full API summary and pre/post table are in the plan (`.cursor/plans/` or attached plan file).