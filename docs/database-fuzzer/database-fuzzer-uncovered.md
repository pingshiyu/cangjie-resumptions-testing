# Database fuzzer – uncovered / infeasible functions

Functions in `std.database.sql` that are **not** currently exercised by the fuzzer, and why.

## Currently covered

- **DriverManager**: `register`, `deregister`, `getDriver`, `drivers` – all covered.
- **Driver.open**: Obtaining a Datasource via `getDriver(name).open(connectionString, opts)` – covered by datasourceFromDriverOpenUnit.
- **Datasource**: `setOption`, `connect` – covered.
- **Connection**: `getMetaData`, `prepareStatement`, `createTransaction`, and close – covered. `state` is read indirectly when using the connection.
- **Statement**: `setOption`, `setNull`, `set`, `update()`, `query()`, and close – covered. `parameterColumnInfos` is read indirectly.
- **QueryResult**: `columnInfos`, `next()`, `getOrNull` – covered. **`get(index)`** is not fuzzed (mock throws; would require try/catch).
- **UpdateResult**: `rowCount`, `lastInsertId` – covered via updateResultReadUnit.
- **Transaction**: `isoLevel`, `accessMode`, `deferrableMode`, `begin`, `commit`, `rollback`, `save`, `release` – covered.
- **PooledDatasource**: `init(datasource)`, `setOption`, `connect`, `close` – covered. Mut props (`idleTimeout`, `maxLifeTime`, `keepaliveTime`, `maxSize`, `maxIdleSize`, `connectionTimeout`) are optional for a later iteration.

## Not covered (and reasons)

### 1. QueryResult.get(index)

- **Reason:** The mock’s `get<T>(index)` throws; fuzzing it would require try/catch. We fuzz `getOrNull` only.

### 2. Pool / ResourcePool / ProxyConnection (direct)

- **Pool** is an interface; **ResourcePool** and **ProxyConnection** are not public. They are exercised **indirectly** via PooledDatasource (connect returns a Connection that may be a ProxyConnection).

### 3. Statement / QueryResult deprecated overloads (Array<SqlDbType>)

- **Statement**: `update(params: Array<SqlDbType>)`, `query(params: Array<SqlDbType>)`
- **QueryResult**: `next(values: Array<SqlDbType>)`
- **SqlDbType** and all deprecated concrete types (SqlChar, SqlVarchar, etc.)

**Reason:** Building valid random `Array<SqlDbType>` is heavy and the API is deprecated. Mocks implement these for interface compliance only; we do not fuzz them.

### 4. PooledDatasource mut props (optional)

- **idleTimeout**, **maxLifeTime**, **keepaliveTime**, **maxSize**, **maxIdleSize**, **connectionTimeout** – can be added in a later iteration with bounded Duration/Int32 generators if desired.

### 5. Driver.name / version / preferredPooling

- Read-only props; covered indirectly when we use a Driver from getDriver. No dedicated executor.

## Summary

- **Fully covered:** DriverManager; Driver.open; Datasource (setOption, connect); Connection (getMetaData, prepareStatement, createTransaction, close); Statement (setOption, setNull, set, update, query, close); QueryResult (next, getOrNull; not get); UpdateResult (rowCount, lastInsertId); Transaction (all); PooledDatasource (create, setOption, connect, close).
- **Not fuzzed:** QueryResult.get (mock throws); deprecated SqlDbType overloads; Pool/ResourcePool/ProxyConnection direct API; PooledDatasource mut props (optional).
