// DbContext and mock Driver/Datasource/Connection/Statement/QueryResult/UpdateResult/Transaction
// for std.database.sql PBT. Mocks allow fuzzing the API without a real database.
package cangjie_experiments.side_effects.database

import std.collection.*
import std.math.*
import std.random.*
import std.database.sql.*
import std.core.*
import cangjie_experiments.generators.*

// --- Mock implementations (no real DB) ---

private class MockColumnInfoImpl <: ColumnInfo {
    public prop name: String { get() { "c" } }
    public prop typeName: String { get() { "Int64" } }
    public prop length: Int64 { get() { 0 } }
    public prop scale: Int64 { get() { 0 } }
    public prop nullable: Bool { get() { true } }
    public prop displaySize: Int64 { get() { 0 } }
}

private let mockColumnInfo: ColumnInfo = MockColumnInfoImpl()
private let emptyColumnInfoArray: Array<ColumnInfo> = Array<ColumnInfo>(0, repeat: mockColumnInfo)

private class MockUpdateResultImpl <: UpdateResult {
    public prop rowCount: Int64 { get() { 0 } }
    public prop lastInsertId: Int64 { get() { 0 } }
}

private class MockQueryResultImpl <: QueryResult {
    var closed: Bool = false
    public prop columnInfos: Array<ColumnInfo> { get() { emptyColumnInfoArray } }
    public func next(values: Array<SqlDbType>): Bool { false }
    public func next(): Bool { false }
    public func get<T>(index: Int64): T { throw Exception("mock get") }
    public func getOrNull<T>(index: Int64): ?T { None }
    public func isClosed(): Bool { closed }
    public func close(): Unit { closed = true }
}

private class MockStatementImpl <: Statement {
    var closed: Bool = false
    public prop parameterColumnInfos: Array<ColumnInfo> { get() { emptyColumnInfoArray } }
    public func setOption(key: String, value: String): Unit { () }
    public func setNull(index: Int64): Unit { () }
    public func set<T>(index: Int64, value: T): Unit { () }
    public func update(params: Array<SqlDbType>): UpdateResult { MockUpdateResultImpl() }
    public func query(params: Array<SqlDbType>): QueryResult { MockQueryResultImpl() }
    public func update(): UpdateResult { MockUpdateResultImpl() }
    public func query(): QueryResult { MockQueryResultImpl() }
    public func isClosed(): Bool { closed }
    public func close(): Unit { closed = true }
}

private class MockTransactionImpl <: Transaction {
    var _isoLevel: TransactionIsoLevel = TransactionIsoLevel.Unspecified
    var _accessMode: TransactionAccessMode = TransactionAccessMode.Unspecified
    var _deferrableMode: TransactionDeferrableMode = TransactionDeferrableMode.Unspecified
    public mut prop isoLevel: TransactionIsoLevel { get() { _isoLevel } set(v) { _isoLevel = v } }
    public mut prop accessMode: TransactionAccessMode { get() { _accessMode } set(v) { _accessMode = v } }
    public mut prop deferrableMode: TransactionDeferrableMode { get() { _deferrableMode } set(v) { _deferrableMode = v } }
    public func begin(): Unit { () }
    public func commit(): Unit { () }
    public func rollback(): Unit { () }
    public func rollback(savePointName: String): Unit { () }
    public func save(savePointName: String): Unit { () }
    public func release(savePointName: String): Unit { () }
}

private class MockConnectionImpl <: Connection {
    var closed: Bool = false
    public prop state: ConnectionState { get() { ConnectionState.Connected } }
    public func getMetaData(): Map<String, String> { HashMap<String, String>() }
    public func prepareStatement(sql: String): Statement { MockStatementImpl() }
    public func createTransaction(): Transaction { MockTransactionImpl() }
    public func isClosed(): Bool { closed }
    public func close(): Unit { closed = true }
}

private class MockDatasourceImpl <: Datasource {
    var closed: Bool = false
    public func setOption(key: String, value: String): Unit { () }
    public func connect(): Connection { MockConnectionImpl() }
    public func isClosed(): Bool { closed }
    public func close(): Unit { closed = true }
}

private class MockDriverImpl <: Driver {
    public prop name: String { get() { "mock" } }
    public prop version: String { get() { "1.0" } }
    public prop preferredPooling: Bool { get() { false } }
    public func open(connectionString: String, opts: Array<(String, String)>): Datasource { MockDatasourceImpl() }
}

// --- DbContext: state and generators for database fuzzer ---

public class DbContext {
    let registeredDriverNames: ArrayList<String> = ArrayList()
    var driverNameCounter: Int64 = 0
    let mockDriver: Driver = MockDriverImpl()

    var currentDatasource: Option<Datasource> = None
    var currentPooledDatasource: Option<PooledDatasource> = None
    var currentConnection: Option<Connection> = None
    var currentStatement: Option<Statement> = None
    var currentQueryResult: Option<QueryResult> = None
    var currentUpdateResult: Option<UpdateResult> = None
    var currentTransaction: Option<Transaction> = None

    public init() {}

    private func randIntRangeLocal(begin: Int64, end: Int64): Int64 {
        randomIntInRange(begin, end)
    }

    private func clearConnectionDependent(): Unit {
        currentStatement = None
        currentQueryResult = None
        currentUpdateResult = None
        currentTransaction = None
    }

    public func initialiseContext(): Unit {
        registeredDriverNames.clear()
        driverNameCounter = 0
        currentDatasource = None
        currentPooledDatasource = None
        currentConnection = None
        clearConnectionDependent()
        // Optionally pre-register one driver so we have something to deregister/get
        let name = "mock_" + driverNameCounter.toString()
        driverNameCounter += 1
        if (!DriverManager.getDriver(name).isSome()) {
            DriverManager.register(name, mockDriver)
            registeredDriverNames.add(name)
        }
    }

    public func cleanup(): Unit {
        currentDatasource = None
        currentPooledDatasource = None
        currentConnection = None
        clearConnectionDependent()
        for (i in 0..registeredDriverNames.size) {
            let n = registeredDriverNames[i]
            DriverManager.deregister(n)
        }
        registeredDriverNames.clear()
    }

    // Generators: return () -> T for @RunRandomly

    /** Fresh driver name (unique per call) so register never sees duplicate. */
    public func randDriverName(): () -> String {{ =>
        let n = driverNameCounter
        driverNameCounter += 1
        "mock_" + n.toString()
    }}

    /** A registered driver name (for deregister / getDriver); if none, returns a placeholder and executor must no-op. */
    public func randRegisteredDriverName(): () -> String {{ =>
        if (registeredDriverNames.isEmpty()) {
            "none"
        } else {
            let i = randIntRangeLocal(0, registeredDriverNames.size)
            registeredDriverNames[i]
        }
    }}

    /** Returns the single mock Driver for register. */
    public func getMockDriver(): () -> Driver {{ =>
        mockDriver
    }}

    /** Short string for option keys/values. */
    public func randOptionKey(): () -> String {{ =>
        let keys = ArrayList([SqlOption.URL, SqlOption.Host, SqlOption.Username, SqlOption.Password, SqlOption.Database, SqlOption.Driver])
        let i = randIntRangeLocal(0, keys.size)
        keys[i]
    }}

    public func randOptionValue(): () -> String {{ =>
        randShortString(n: randIntRangeLocal(0, 5))()
    }}

    /** Simple SQL string for prepareStatement (mock ignores it). */
    public func randSql(): () -> String {{ =>
        "SELECT 1"
    }}

    /** Statement parameter index (mock accepts any). */
    public func randParamIndex(): () -> Int64 {{ =>
        randIntRangeLocal(0, 4)
    }}

    /** Transaction isolation level. */
    public func randTransactionIsoLevel(): () -> TransactionIsoLevel {{ =>
        let levels = ArrayList([TransactionIsoLevel.Unspecified, TransactionIsoLevel.ReadCommitted, TransactionIsoLevel.ReadUncommitted, TransactionIsoLevel.RepeatableRead, TransactionIsoLevel.Serializable])
        let i = randIntRangeLocal(0, levels.size)
        levels[i]
    }}

    /** Transaction access mode. */
    public func randTransactionAccessMode(): () -> TransactionAccessMode {{ =>
        let modes = ArrayList([TransactionAccessMode.Unspecified, TransactionAccessMode.ReadWrite, TransactionAccessMode.ReadOnly])
        let i = randIntRangeLocal(0, modes.size)
        modes[i]
    }}

    /** Transaction deferrable mode. */
    public func randTransactionDeferrableMode(): () -> TransactionDeferrableMode {{ =>
        let modes = ArrayList([TransactionDeferrableMode.Unspecified, TransactionDeferrableMode.Deferrable, TransactionDeferrableMode.NotDeferrable])
        let i = randIntRangeLocal(0, modes.size)
        modes[i]
    }}

    public func randSavepointName(): () -> String {{ =>
        "sp_" + randShortString(n: 2)()
    }}

    /** Connection string for Driver.open (mock ignores it). */
    public func randConnectionString(): () -> String {{ =>
        "mem:" + randShortString(n: 2)()
    }}

    /** Small opts array for Driver.open. */
    public func randOpts(): () -> Array<(String, String)> {{ =>
        let n = randIntRangeLocal(0, 4)
        let arr = ArrayList<(String, String)>()
        for (_ in 0..n) {
            arr.add((randOptionKey()(), randOptionValue()()))
        }
        arr.toArray()
    }}

    // --- Executors (DriverManager + mock chain); update context so preconditions hold ---

    /** Register a driver with a fresh name; adds name to registeredDriverNames. Skips if name already registered to avoid SqlException. */
    public func driverManagerRegisterUnit(driverName: String, driver: Driver): Unit {
        if (DriverManager.getDriver(driverName).isSome()) {
            return
        }
        DriverManager.register(driverName, driver)
        registeredDriverNames.add(driverName)
    }

    /** Deregister by name; removes from registeredDriverNames. No-op if name not in list. */
    public func driverManagerDeregisterUnit(driverName: String): Unit {
        if (driverName == "none") {
            return
        }
        var i: Int64 = 0
        while (i < registeredDriverNames.size) {
            if (registeredDriverNames[i] == driverName) {
                DriverManager.deregister(driverName)
                registeredDriverNames.remove(at: i)
                return
            }
            i += 1
        }
    }

    /** Just call getDriver(name); no state change. */
    public func driverManagerGetDriverUnit(driverName: String): Unit {
        let _ = DriverManager.getDriver(driverName)
    }

    /** Call drivers(); no state change. */
    public func driverManagerDriversUnit(): Unit {
        let _ = DriverManager.drivers()
    }

    // --- Obtain Datasource (Driver.open) ---
    public func datasourceFromDriverOpenUnit(driverName: String, connectionString: String, opts: Array<(String, String)>): Unit {
        if (driverName == "none") {
            return
        }
        match (DriverManager.getDriver(driverName)) {
            case Some(driver) =>
                currentDatasource = Some(driver.open(connectionString, opts))
            case None => ()
        }
    }

    // --- Datasource ---
    public func datasourceSetOptionUnit(key: String, value: String): Unit {
        if (currentDatasource.isNone()) {
            return
        }
        currentDatasource.getOrThrow().setOption(key, value)
    }

    public func datasourceConnectUnit(): Unit {
        if (currentDatasource.isNone()) {
            return
        }
        currentConnection = Some(currentDatasource.getOrThrow().connect())
        clearConnectionDependent()
    }

    // --- Connection ---
    public func connectionGetMetaDataUnit(): Unit {
        if (currentConnection.isNone()) {
            return
        }
        let _ = currentConnection.getOrThrow().getMetaData()
    }

    public func connectionPrepareStatementUnit(sql: String): Unit {
        if (currentConnection.isNone()) {
            return
        }
        currentStatement = Some(currentConnection.getOrThrow().prepareStatement(sql))
        currentQueryResult = None
        currentUpdateResult = None
    }

    public func connectionCreateTransactionUnit(): Unit {
        if (currentConnection.isNone()) {
            return
        }
        currentTransaction = Some(currentConnection.getOrThrow().createTransaction())
    }

    public func connectionCloseUnit(): Unit {
        if (currentConnection.isNone()) {
            return
        }
        currentConnection.getOrThrow().close()
        currentConnection = None
        clearConnectionDependent()
    }

    // --- Statement ---
    public func statementSetOptionUnit(key: String, value: String): Unit {
        if (currentStatement.isNone()) {
            return
        }
        currentStatement.getOrThrow().setOption(key, value)
    }

    public func statementSetNullUnit(index: Int64): Unit {
        if (currentStatement.isNone()) {
            return
        }
        currentStatement.getOrThrow().setNull(index)
    }

    public func statementUpdateUnit(): Unit {
        if (currentStatement.isNone()) {
            return
        }
        currentUpdateResult = Some(currentStatement.getOrThrow().update())
    }

    public func statementQueryUnit(): Unit {
        if (currentStatement.isNone()) {
            return
        }
        currentQueryResult = Some(currentStatement.getOrThrow().query())
    }

    public func statementCloseUnit(): Unit {
        if (currentStatement.isNone()) {
            return
        }
        currentStatement.getOrThrow().close()
        currentStatement = None
    }

    // --- QueryResult ---
    public func queryResultNextUnit(): Unit {
        if (currentQueryResult.isNone()) {
            return
        }
        let _ = currentQueryResult.getOrThrow().next()
    }

    public func queryResultGetOrNullUnit(index: Int64): Unit {
        if (currentQueryResult.isNone()) {
            return
        }
        let _ = currentQueryResult.getOrThrow().getOrNull<Int64>(index)
    }

    // --- UpdateResult ---
    public func updateResultReadUnit(): Unit {
        if (currentUpdateResult.isNone()) {
            return
        }
        let r = currentUpdateResult.getOrThrow()
        let _ = r.rowCount
        let _ = r.lastInsertId
    }

    // --- Transaction ---
    public func transactionSetIsoLevelUnit(level: TransactionIsoLevel): Unit {
        if (currentTransaction.isNone()) {
            return
        }
        currentTransaction.getOrThrow().isoLevel = level
    }

    public func transactionSetAccessModeUnit(mode: TransactionAccessMode): Unit {
        if (currentTransaction.isNone()) {
            return
        }
        currentTransaction.getOrThrow().accessMode = mode
    }

    public func transactionSetDeferrableModeUnit(mode: TransactionDeferrableMode): Unit {
        if (currentTransaction.isNone()) {
            return
        }
        currentTransaction.getOrThrow().deferrableMode = mode
    }

    public func transactionBeginUnit(): Unit {
        if (currentTransaction.isNone()) {
            return
        }
        currentTransaction.getOrThrow().begin()
    }

    public func transactionCommitUnit(): Unit {
        if (currentTransaction.isNone()) {
            return
        }
        currentTransaction.getOrThrow().commit()
    }

    public func transactionRollbackUnit(): Unit {
        if (currentTransaction.isNone()) {
            return
        }
        currentTransaction.getOrThrow().rollback()
    }

    public func transactionRollbackSavepointUnit(savePointName: String): Unit {
        if (currentTransaction.isNone()) {
            return
        }
        currentTransaction.getOrThrow().rollback(savePointName)
    }

    public func transactionSaveUnit(savePointName: String): Unit {
        if (currentTransaction.isNone()) {
            return
        }
        currentTransaction.getOrThrow().save(savePointName)
    }

    public func transactionReleaseUnit(savePointName: String): Unit {
        if (currentTransaction.isNone()) {
            return
        }
        currentTransaction.getOrThrow().release(savePointName)
    }

    // --- PooledDatasource ---
    public func pooledDatasourceCreateUnit(): Unit {
        if (currentDatasource.isNone()) {
            return
        }
        currentPooledDatasource = Some(PooledDatasource(currentDatasource.getOrThrow()))
    }

    public func pooledDatasourceSetOptionUnit(key: String, value: String): Unit {
        if (currentPooledDatasource.isNone()) {
            return
        }
        currentPooledDatasource.getOrThrow().setOption(key, value)
    }

    public func pooledDatasourceConnectUnit(): Unit {
        if (currentPooledDatasource.isNone()) {
            return
        }
        currentConnection = Some(currentPooledDatasource.getOrThrow().connect())
        clearConnectionDependent()
    }

    public func pooledDatasourceCloseUnit(): Unit {
        if (currentPooledDatasource.isNone()) {
            return
        }
        currentPooledDatasource.getOrThrow().close()
        currentPooledDatasource = None
    }
}
