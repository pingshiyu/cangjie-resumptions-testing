# Database Fuzzer Plan

## Library under test

`std.database.sql` (from `/home/pings/projects/cangjie-resumptions/cangjie_runtime/stdlib/libs/std/database`).

## Public API summary

- **DriverManager** (static): `register(driverName, driver)`, `deregister(driverName)`, `getDriver(driverName)`, `drivers()`
- **Driver** (interface): `name`, `version`, `preferredPooling`, `open(connectionString, opts) -> Datasource`
- **Datasource** (interface): `setOption(key, value)`, `connect() -> Connection`
- **Connection** (interface): `state`, `getMetaData() -> Map<String,String>`, `prepareStatement(sql) -> Statement`, `createTransaction() -> Transaction`
- **Statement** (interface): `parameterColumnInfos`, `setOption`, `setNull`, `set` (cjnative), `update()/update(params)`, `query()/query(params)`
- **QueryResult** (interface): `columnInfos`, `next()/next(values)`, `get`/`getOrNull` (cjnative)
- **UpdateResult** (interface): `rowCount`, `lastInsertId`
- **Transaction** (interface): `isoLevel`, `accessMode`, `deferrableMode`, `begin`, `commit`, `rollback`, `save`, `release`
- **SqlOption**: constants for option keys
- **TransactionIsoLevel**, **TransactionAccessMode**, **TransactionDeferrableMode**: enums
- **ConnectionState**: enum
- **ColumnInfo** (interface): `name`, `typeName`, `length`, `scale`, `nullable`, `displaySize`

## Context design

- **DbContext** holds:
  - `registeredDriverNames: ArrayList<String>` – names currently registered with DriverManager
  - `driverNameCounter` – used to generate unique driver names for register
  - `mockDriver: Driver` – single mock Driver used for all register calls
  - `currentDatasource: Option<Datasource>` – from Driver.open or unused
  - `currentPooledDatasource: Option<PooledDatasource>` – from PooledDatasource(datasource)
  - `currentConnection: Option<Connection>` – from Datasource.connect or PooledDatasource.connect
  - `currentStatement: Option<Statement>` – from Connection.prepareStatement
  - `currentQueryResult: Option<QueryResult>` – from Statement.query()
  - `currentUpdateResult: Option<UpdateResult>` – from Statement.update()
  - `currentTransaction: Option<Transaction>` – from Connection.createTransaction

- When `currentConnection` is set, `currentStatement`, `currentQueryResult`, `currentUpdateResult`, `currentTransaction` are cleared (they refer to the previous connection). When `currentStatement` is set, `currentQueryResult` and `currentUpdateResult` are cleared.

- No real database: all usage goes through **mock implementations** (MockDriverImpl → MockDatasourceImpl → MockConnectionImpl → MockStatementImpl, MockQueryResultImpl, MockUpdateResultImpl, MockTransactionImpl). PooledDatasource is real but wraps the mock Datasource.

## Generators (per executor)

| Executor | Generators | Notes |
|----------|------------|--------|
| driverManagerRegisterUnit | randDriverName(), getMockDriver() | Unique name so register never duplicates |
| driverManagerDeregisterUnit | randRegisteredDriverName() | Only registered names; no-op if empty |
| driverManagerGetDriverUnit | randRegisteredDriverName() | Any name is safe; getDriver returns Option |
| driverManagerDriversUnit | (none) | No arguments |
| datasourceFromDriverOpenUnit | randRegisteredDriverName(), randConnectionString(), randOpts() | No-op if driverName "none" or not registered |
| datasourceSetOptionUnit | randOptionKey(), randOptionValue() | No-op if currentDatasource is None |
| datasourceConnectUnit | (none) | Sets currentConnection; clears connection-dependent state |
| connectionGetMetaDataUnit | (none) | No-op if currentConnection is None |
| connectionPrepareStatementUnit | randSql() | Sets currentStatement; clears currentQueryResult/currentUpdateResult |
| connectionCreateTransactionUnit | (none) | Sets currentTransaction |
| connectionCloseUnit | (none) | Closes connection; clears currentConnection and connection-dependent state |
| statementSetOptionUnit | randOptionKey(), randOptionValue() | No-op if currentStatement is None |
| statementSetNullUnit | randParamIndex() | No-op if currentStatement is None |
| statementUpdateUnit | (none) | Sets currentUpdateResult |
| statementQueryUnit | (none) | Sets currentQueryResult |
| statementCloseUnit | (none) | Clears currentStatement |
| queryResultNextUnit | (none) | No-op if currentQueryResult is None |
| queryResultGetOrNullUnit | randParamIndex() | No-op if currentQueryResult is None; mock returns None |
| updateResultReadUnit | (none) | Reads rowCount, lastInsertId; no-op if currentUpdateResult is None |
| transactionSetIsoLevelUnit | randTransactionIsoLevel() | No-op if currentTransaction is None |
| transactionSetAccessModeUnit | randTransactionAccessMode() | No-op if currentTransaction is None |
| transactionSetDeferrableModeUnit | randTransactionDeferrableMode() | No-op if currentTransaction is None |
| transactionBeginUnit, transactionCommitUnit, transactionRollbackUnit | (none) | No-op if currentTransaction is None |
| transactionRollbackSavepointUnit, transactionSaveUnit, transactionReleaseUnit | randSavepointName() | No-op if currentTransaction is None |
| pooledDatasourceCreateUnit | (none) | No-op if currentDatasource is None |
| pooledDatasourceSetOptionUnit | randOptionKey(), randOptionValue() | No-op if currentPooledDatasource is None |
| pooledDatasourceConnectUnit | (none) | Sets currentConnection; clears connection-dependent state |
| pooledDatasourceCloseUnit | (none) | Clears currentPooledDatasource |

## Executors

- **DriverManager**: driverManagerRegisterUnit, driverManagerDeregisterUnit, driverManagerGetDriverUnit, driverManagerDriversUnit (as before).
- **Datasource**: datasourceFromDriverOpenUnit (get Driver by name, open(connectionString, opts), set currentDatasource); datasourceSetOptionUnit; datasourceConnectUnit (connect(), set currentConnection, clear connection-dependent).
- **Connection**: connectionGetMetaDataUnit; connectionPrepareStatementUnit (set currentStatement); connectionCreateTransactionUnit (set currentTransaction); connectionCloseUnit (close(), clear currentConnection and connection-dependent).
- **Statement**: statementSetOptionUnit; statementSetNullUnit; statementUpdateUnit (set currentUpdateResult); statementQueryUnit (set currentQueryResult); statementCloseUnit.
- **QueryResult**: queryResultNextUnit; queryResultGetOrNullUnit (mock returns None). **QueryResult.get(index)** is not fuzzed (mock throws).
- **UpdateResult**: updateResultReadUnit (read rowCount, lastInsertId).
- **Transaction**: transactionSetIsoLevelUnit, transactionSetAccessModeUnit, transactionSetDeferrableModeUnit; transactionBeginUnit, transactionCommitUnit, transactionRollbackUnit; transactionRollbackSavepointUnit, transactionSaveUnit, transactionReleaseUnit.
- **PooledDatasource**: pooledDatasourceCreateUnit (PooledDatasource(currentDatasource)); pooledDatasourceSetOptionUnit; pooledDatasourceConnectUnit; pooledDatasourceCloseUnit. Mut props (idleTimeout, maxLifeTime, etc.) are optional for a later iteration.

## Design choices

1. **No try/catch**: Correct inputs only; executors no-op when required context slot is None.
2. **Single mock Driver**: One MockDriverImpl shared by all register calls; only the driver *name* varies.
3. **Mock chain wired**: Datasource/Connection/Statement/QueryResult/UpdateResult/Transaction are exercised via executors that guard on current* Option slots.
4. **RunRandomlyQuiet**: Used in getLibDb for all executors to avoid per-step println and reduce allocation for 1000 iterations.
