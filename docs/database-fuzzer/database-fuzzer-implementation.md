# Database fuzzer – implementation and structure

This document describes how the database fuzzer is implemented so that another agent or human can reimplement or extend it and avoid common mistakes.

## Overview

The fuzzer randomly executes functions from `std.database.sql` so that **calls do not crash** (bugs in the library itself should be rare and documented separately). It follows the same pattern as `fs_testing_*` and `net_testing_*`: a **context** (DbContext) maintains state, **generators** produce valid inputs, and **executors** (UnitFns) perform one library call and update context. The resumption loop picks a random executor, runs its generator(s), then runs the executor.

## File roles

| File | Role |
|------|------|
| `database_testing_entry.cj` | Entry point `main_database_testing()`, `dummyDatabaseTester()` (three `Switch()`), loop 1000 iterations, `withSeed(Option<UInt64>.None)`, `executeUntilDone(lib, 100, dummyDatabaseTester)`. |
| `database_testing_generators.cj` | Mock types (Driver, Datasource, Connection, Statement, QueryResult, UpdateResult, Transaction, ColumnInfo), **DbContext** (state + generators + all executors: DriverManager, Datasource, Connection, Statement, QueryResult, UpdateResult, Transaction, PooledDatasource). |
| `database_testing_lib.cj` | `getLibDb(ctx)` returns `ArrayList<UnitFn>` of `@RunRandomlyQuiet(..., ctx.xxx)` for each executor. |

## Important details

### 1. Naming and overloads

- **dummyTester** is already used in `io_testing_entry.cj` with signature `(): Unit`. The database entry uses **dummyDatabaseTester** to avoid overload conflict; the resumption handler still sees a no-arg Unit function.
- **withSeed** is called as `withSeed(Option<UInt64>.None)` so the type of `None` is unambiguous.

### 2. Mock types and interfaces

- **Resource**: All mocks that implement a DB interface extending `Resource` implement `isClosed(): Bool` and `close(): Unit`.
- **Statement**: Implements both `update()` / `query()` and the deprecated `update(params)` / `query(params)`; also `set<T>(index, value)` for cjnative.
- **QueryResult**: Implements `next()` and deprecated `next(values)`; also `get<T>(index)` and `getOrNull<T>(index)` (mock `get` throws; `getOrNull` returns `None`).
- **ColumnInfo**: One `MockColumnInfoImpl` instance is used to build an empty `Array<ColumnInfo>` as `Array<ColumnInfo>(0, repeat: mockColumnInfo)` for `parameterColumnInfos` / `columnInfos`.

### 3. DriverManager preconditions

- **register(driverName, driver)**: Throws if `driverName` is already registered. So we never register the same name twice: we use a **monotonic counter** in DbContext (`randDriverName()` returns `"mock_" + counter` and increments).
- **deregister(driverName)**: Does not throw if the name is not registered. We only deregister names we have registered: **randRegisteredDriverName()** returns a name from `registeredDriverNames`, or `"none"` when the list is empty; the executor no-ops when the name is `"none"` or not in the list.

### 4. Context lifecycle

- **DbContext** holds seven optional “current” slots: `currentDatasource`, `currentPooledDatasource`, `currentConnection`, `currentStatement`, `currentQueryResult`, `currentUpdateResult`, `currentTransaction`. Executors no-op when the required slot is `None`.
- **clearConnectionDependent()**: Sets `currentStatement`, `currentQueryResult`, `currentUpdateResult`, `currentTransaction` to `None`. Called when setting `currentConnection` (datasourceConnectUnit, pooledDatasourceConnectUnit) and in connectionCloseUnit, and from initialiseContext/cleanup.
- **initialiseContext()**: Clears all seven optionals and DriverManager state; pre-registers one driver.
- **cleanup()**: Clears all seven optionals, then deregisters every name in `registeredDriverNames` and clears the list. Called after each of the 1000 iterations.

### 5. Macro and fuel

- **@RunRandomlyQuiet** is used in `getLibDb` (not `@RunRandomly`) to avoid per-step println and reduce allocation over 1000 iterations.
- **executeUntilDone(lib, 100, dummyDatabaseTester)** uses fuel 100 per iteration; each Switch runs one random executor from `lib`.

### 6. Executor list

All executors are defined on DbContext and registered in `getLibDb`: DriverManager (driverManagerRegisterUnit, driverManagerDeregisterUnit, driverManagerGetDriverUnit, driverManagerDriversUnit); Datasource (datasourceFromDriverOpenUnit, datasourceSetOptionUnit, datasourceConnectUnit); Connection (connectionGetMetaDataUnit, connectionPrepareStatementUnit, connectionCreateTransactionUnit, connectionCloseUnit); Statement (statementSetOptionUnit, statementSetNullUnit, statementUpdateUnit, statementQueryUnit, statementCloseUnit); QueryResult (queryResultNextUnit, queryResultGetOrNullUnit); UpdateResult (updateResultReadUnit); Transaction (transactionSetIsoLevelUnit, transactionSetAccessModeUnit, transactionSetDeferrableModeUnit, transactionBeginUnit, transactionCommitUnit, transactionRollbackUnit, transactionRollbackSavepointUnit, transactionSaveUnit, transactionReleaseUnit); PooledDatasource (pooledDatasourceCreateUnit, pooledDatasourceSetOptionUnit, pooledDatasourceConnectUnit, pooledDatasourceCloseUnit).

## How to add more executors

1. **Add a generator** on DbContext in `database_testing_generators.cj` that returns `() -> T` for each argument (e.g. `randOptionKey()`, `randSql()`).
2. **Add an executor** on DbContext that performs one library call and updates context if needed (e.g. store current Connection after `connect()`).
3. **Register it** in `getLibDb` in `database_testing_lib.cj` with `@RunRandomlyQuiet([arg1 in ctx.gen1, ...], ctx.executorMethod)`.

Ensure preconditions are satisfied by the generator (e.g. only call `prepareStatement` when we have a Connection). If an executor can fail when the context is not ready, either make the executor no-op in that case (like net/fs) or add a generator that only returns valid indices/handles (e.g. “current connection if non-null”).

## Common mistakes to avoid

1. **Registering the same driver name twice** – use a strictly increasing name (e.g. counter) or track and skip.
2. **dummyTester name clash** – use a distinct name (e.g. `dummyDatabaseTester`) when another entry also defines `dummyTester(): Unit`.
3. **withSeed(None)** – use `Option<UInt64>.None` (or the appropriate Option type) so the compiler can resolve the generic.
4. **Missing interface members** – implement all non-conditional interface methods (including deprecated overloads and, when required, cjnative `set`/`get`/`getOrNull`) in mocks.
5. **Empty Array<ColumnInfo>** – use `Array<ColumnInfo>(0, repeat: someColumnInfoInstance)`; the repeat value is needed for type even when size is 0.
6. **Using try/catch to absorb errors** – the requirement is to generate valid inputs and satisfy preconditions; avoid swallowing exceptions in executors except where documenting a known bug and skipping the trigger.
7. **Transaction rollback/save/release** – call with positional argument, e.g. `rollback(savePointName)` not `rollback(savePointName: savePointName)` (named-arg syntax may not be accepted at call site).
8. **QueryResult.get(index)** – not fuzzed; the mock throws. Use **getOrNull** only.
9. **PooledDatasource mut props** – idleTimeout, maxLifeTime, keepaliveTime, maxSize, maxIdleSize, connectionTimeout are optional; can add executors with bounded generators in a later iteration.

## Running the fuzzer

- Use **`./cjpm-run.sh`** so that `CANGJIE_STDX_PATH` and the environment are set; this runs the binary that calls `main()` in `main.cj`.
- In `main.cj`, call **`main_database_testing()`** to run the database fuzzer (1000 iterations).
- Success criterion: 1000 iterations complete without errors (exit code 0 and “Database iteration 1000 completed” in the output).

## If you find a bug in the library

Record it in a separate `.md` file with: trigger (steps or seed), expected behaviour, observed behaviour. Temporarily skip that trigger in the fuzzer (e.g. by not registering the offending executor or by making the generator avoid the bad input) so the 1000-iteration run still passes.
