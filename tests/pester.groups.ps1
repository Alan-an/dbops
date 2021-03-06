# this files describes which tests to run on which environment of the build matrix

$TestsRunGroups = @{
    # run on scenario MSSQL
    "all"        = @(
        "$ModuleBase\tests\*"
        "$ModuleBase\tests\mysql\*"
        "$ModuleBase\tests\postgresql\*"
    )
    "default"    = @(
        "$ModuleBase\tests\*"
    )
    "mysql"      = @(
        "$ModuleBase\tests\mysql\*"
    )
    "postgresql" = @(
        "$ModuleBase\tests\postgresql\*"
    )
    # do not run everywhere
    "disabled"   = @()
}