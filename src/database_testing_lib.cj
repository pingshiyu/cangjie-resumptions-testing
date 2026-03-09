// getLibDb: list of UnitFns for std.database.sql PBT. Uses DbContext for generators and executors.
package cangjie_experiments

import std.collection.*
import stdx.effect.*
import cangjie_experiments.define.*
import cangjie_experiments.resumptions.*
import cangjie_experiments.generators.*

// Builds libDb: DriverManager + Datasource/Connection/Statement/QueryResult/UpdateResult/Transaction/PooledDatasource executors.
// All executors use context so that generated inputs satisfy preconditions; no-op when required context slot is None.
public func getLibDb(ctx: DbContext): ArrayList<UnitFn> {
    ArrayList([
        @RunRandomly([driverName in ctx.randDriverName(), driver in ctx.getMockDriver()], ctx.driverManagerRegisterUnit),
        @RunRandomly([driverName in ctx.randRegisteredDriverName()], ctx.driverManagerDeregisterUnit),
        @RunRandomly([driverName in ctx.randRegisteredDriverName()], ctx.driverManagerGetDriverUnit),
        @RunRandomly([], ctx.driverManagerDriversUnit),
        @RunRandomly([driverName in ctx.randRegisteredDriverName(), connectionString in ctx.randConnectionString(), opts in ctx.randOpts()], ctx.datasourceFromDriverOpenUnit),
        @RunRandomly([key in ctx.randOptionKey(), value in ctx.randOptionValue()], ctx.datasourceSetOptionUnit),
        @RunRandomly([], ctx.datasourceConnectUnit),
        @RunRandomly([], ctx.connectionGetMetaDataUnit),
        @RunRandomly([sql in ctx.randSql()], ctx.connectionPrepareStatementUnit),
        @RunRandomly([], ctx.connectionCreateTransactionUnit),
        @RunRandomly([], ctx.connectionCloseUnit),
        @RunRandomly([key in ctx.randOptionKey(), value in ctx.randOptionValue()], ctx.statementSetOptionUnit),
        @RunRandomly([index in ctx.randParamIndex()], ctx.statementSetNullUnit),
        @RunRandomly([], ctx.statementUpdateUnit),
        @RunRandomly([], ctx.statementQueryUnit),
        @RunRandomly([], ctx.statementCloseUnit),
        @RunRandomly([], ctx.queryResultNextUnit),
        @RunRandomly([index in ctx.randParamIndex()], ctx.queryResultGetOrNullUnit),
        @RunRandomly([], ctx.updateResultReadUnit),
        @RunRandomly([level in ctx.randTransactionIsoLevel()], ctx.transactionSetIsoLevelUnit),
        @RunRandomly([mode in ctx.randTransactionAccessMode()], ctx.transactionSetAccessModeUnit),
        @RunRandomly([mode in ctx.randTransactionDeferrableMode()], ctx.transactionSetDeferrableModeUnit),
        @RunRandomly([], ctx.transactionBeginUnit),
        @RunRandomly([], ctx.transactionCommitUnit),
        @RunRandomly([], ctx.transactionRollbackUnit),
        @RunRandomly([savePointName in ctx.randSavepointName()], ctx.transactionRollbackSavepointUnit),
        @RunRandomly([savePointName in ctx.randSavepointName()], ctx.transactionSaveUnit),
        @RunRandomly([savePointName in ctx.randSavepointName()], ctx.transactionReleaseUnit),
        @RunRandomly([], ctx.pooledDatasourceCreateUnit),
        @RunRandomly([key in ctx.randOptionKey(), value in ctx.randOptionValue()], ctx.pooledDatasourceSetOptionUnit),
        @RunRandomly([], ctx.pooledDatasourceConnectUnit),
        @RunRandomly([], ctx.pooledDatasourceCloseUnit),
    ])
}
