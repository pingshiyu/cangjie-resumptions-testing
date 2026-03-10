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
        @RunRandomlyQuiet([driverName in ctx.randDriverName(), driver in ctx.getMockDriver()], ctx.driverManagerRegisterUnit),
        @RunRandomlyQuiet([driverName in ctx.randRegisteredDriverName()], ctx.driverManagerDeregisterUnit),
        @RunRandomlyQuiet([driverName in ctx.randRegisteredDriverName()], ctx.driverManagerGetDriverUnit),
        @RunRandomlyQuiet([], ctx.driverManagerDriversUnit),
        @RunRandomlyQuiet([driverName in ctx.randRegisteredDriverName(), connectionString in ctx.randConnectionString(), opts in ctx.randOpts()], ctx.datasourceFromDriverOpenUnit),
        @RunRandomlyQuiet([key in ctx.randOptionKey(), value in ctx.randOptionValue()], ctx.datasourceSetOptionUnit),
        @RunRandomlyQuiet([], ctx.datasourceConnectUnit),
        @RunRandomlyQuiet([], ctx.connectionGetMetaDataUnit),
        @RunRandomlyQuiet([sql in ctx.randSql()], ctx.connectionPrepareStatementUnit),
        @RunRandomlyQuiet([], ctx.connectionCreateTransactionUnit),
        @RunRandomlyQuiet([], ctx.connectionCloseUnit),
        @RunRandomlyQuiet([key in ctx.randOptionKey(), value in ctx.randOptionValue()], ctx.statementSetOptionUnit),
        @RunRandomlyQuiet([index in ctx.randParamIndex()], ctx.statementSetNullUnit),
        @RunRandomlyQuiet([], ctx.statementUpdateUnit),
        @RunRandomlyQuiet([], ctx.statementQueryUnit),
        @RunRandomlyQuiet([], ctx.statementCloseUnit),
        @RunRandomlyQuiet([], ctx.queryResultNextUnit),
        @RunRandomlyQuiet([index in ctx.randParamIndex()], ctx.queryResultGetOrNullUnit),
        @RunRandomlyQuiet([], ctx.updateResultReadUnit),
        @RunRandomlyQuiet([level in ctx.randTransactionIsoLevel()], ctx.transactionSetIsoLevelUnit),
        @RunRandomlyQuiet([mode in ctx.randTransactionAccessMode()], ctx.transactionSetAccessModeUnit),
        @RunRandomlyQuiet([mode in ctx.randTransactionDeferrableMode()], ctx.transactionSetDeferrableModeUnit),
        @RunRandomlyQuiet([], ctx.transactionBeginUnit),
        @RunRandomlyQuiet([], ctx.transactionCommitUnit),
        @RunRandomlyQuiet([], ctx.transactionRollbackUnit),
        @RunRandomlyQuiet([savePointName in ctx.randSavepointName()], ctx.transactionRollbackSavepointUnit),
        @RunRandomlyQuiet([savePointName in ctx.randSavepointName()], ctx.transactionSaveUnit),
        @RunRandomlyQuiet([savePointName in ctx.randSavepointName()], ctx.transactionReleaseUnit),
        @RunRandomlyQuiet([], ctx.pooledDatasourceCreateUnit),
        @RunRandomlyQuiet([key in ctx.randOptionKey(), value in ctx.randOptionValue()], ctx.pooledDatasourceSetOptionUnit),
        @RunRandomlyQuiet([], ctx.pooledDatasourceConnectUnit),
        @RunRandomlyQuiet([], ctx.pooledDatasourceCloseUnit),
    ])
}
