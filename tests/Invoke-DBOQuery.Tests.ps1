Param (
    [switch]$Batch
)

if ($PSScriptRoot) { $commandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", ""); $here = $PSScriptRoot }
else { $commandName = "_ManualExecution"; $here = (Get-Item . ).FullName }

if (!$Batch) {
    # Is not a part of the global batch => import module
    #Explicitly import the module for testing
    Import-Module "$here\..\dbops.psd1" -Force; Get-DBOModuleFileList -Type internal | ForEach-Object { . $_.FullName }
}
else {
    # Is a part of a batch, output some eye-catching happiness
    Write-Host "Running $commandName tests" -ForegroundColor Cyan
}

. "$here\constants.ps1"

$workFolder = Join-Path "$here\etc" "$commandName.Tests.dbops"

Describe "Invoke-DBOQuery tests" -Tag $commandName, IntegrationTests {
    BeforeAll {
        if ((Test-Path $workFolder) -and $workFolder -like '*.Tests.dbops') { Remove-Item $workFolder -Recurse }
        $null = New-Item $workFolder -ItemType Directory -Force
    }
    AfterAll {
        if ((Test-Path $workFolder) -and $workFolder -like '*.Tests.dbops') { Remove-Item $workFolder -Recurse }
    }
    Context "Regular tests" {
        It "should run the query" {
            $query = "SELECT 1 AS A, 2 AS B UNION ALL SELECT 3 AS A, 4 AS B"
            $result = Invoke-DBOQuery -Query $query -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential -As DataTable
            $result.A | Should -Be 1, 3
            $result.B | Should -Be 2, 4
        }
        It "should run the query without column names" {
            $query = "SELECT 1, 2 as A, 3"
            $result = Invoke-DBOQuery -Query $query -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential -As DataTable
            $result.Column1 | Should -Be 1
            $result.A | Should -Be 2
            $result.Column3 | Should -Be 3
        }
        It "should run the query with GO" {
            $query = "SELECT 1 AS A, 2 AS B
            GO
            SELECT 3 AS A, 4 AS B"
            $result = Invoke-DBOQuery -Query $query -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential -As DataTable
            $result[0].A | Should -Be 1
            $result[0].B | Should -Be 2
            $result[1].A | Should -Be 3
            $result[1].B | Should -Be 4
        }
        It "should run the query with GO as a dataset" {
            $query = "SELECT 1 AS A, 2 AS B
            GO
            SELECT 3 AS A, 4 AS B"
            $result = Invoke-DBOQuery -Query $query -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential -As Dataset
            $result.Tables[0].A | Should -Be 1
            $result.Tables[0].B | Should -Be 2
            $result.Tables[1].A | Should -Be 3
            $result.Tables[1].B | Should -Be 4
        }
        It "should run the query as a PSObject" {
            $query = "SELECT 1 AS A, 2 AS B UNION ALL SELECT NULL AS A, 4 AS B"
            $result = Invoke-DBOQuery -Query $query -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential -As PSObject
            $result.A | Should -Be 1, $null
            $result.B | Should -Be 2, 4
        }
        It "should run the query as a SingleValue" {
            $query = "SELECT 1 AS A"
            $result = Invoke-DBOQuery -Query $query -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential -As SingleValue
            $result | Should -Be 1
        }
        It "should run the query from InputFile" {
            $file1 = Join-Path $workFolder 1.sql
            $file2 = Join-Path $workFolder 2.sql
            "SELECT 1 AS A, 2 AS B" | Out-File $file1 -Force
            "SELECT 3 AS A, 4 AS B" | Out-File $file2 -Force -Encoding bigendianunicode
            $result = Invoke-DBOQuery -InputFile $file1, $file2 -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential -As DataTable
            $result[0].A | Should -Be 1
            $result[0].B | Should -Be 2
            $result[1].A | Should -Be 3
            $result[1].B | Should -Be 4
        }
        It "should run the query from InputObject" {
            $file1 = Join-Path $workFolder 1.sql
            $file2 = Join-Path $workFolder 2.sql
            "SELECT 1 AS A, 2 AS B" | Out-File $file1 -Force
            "SELECT 3 AS A, 4 AS B" | Out-File $file2 -Force -Encoding bigendianunicode
            $result = Get-Item $file1, $file2 | Invoke-DBOQuery -SqlInstance $script:mssqlInstance -Silent -Credential $script:mssqlCredential -As DataTable
            $result[0].A | Should -Be 1
            $result[0].B | Should -Be 2
            $result[1].A | Should -Be 3
            $result[1].B | Should -Be 4
            $result = $file1, $file2 | Invoke-DBOQuery -SqlInstance $script:mssqlInstance -Silent -Credential $script:mssqlCredential -As DataTable
            $result[0].A | Should -Be 1
            $result[0].B | Should -Be 2
            $result[1].A | Should -Be 3
            $result[1].B | Should -Be 4
        }
        It "should run the query with custom variables" {
            $query = "SELECT '#{Test}' AS A, '#{Test2}' AS B UNION ALL SELECT '3' AS A, '4' AS B"
            $result = Invoke-DBOQuery -Query $query -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential -As DataTable -Variables @{ Test = '1'; Test2 = '2'}
            $result.A | Should -Be '1', '3'
            $result.B | Should -Be '2', '4'
        }
        It "should connect to the server from a custom variable" {
            $query = "SELECT 1 AS A, 2 AS B UNION ALL SELECT 3 AS A, 4 AS B"
            $result = Invoke-DBOQuery -Query $query -SqlInstance '#{srv}' -Credential $script:mssqlCredential -As DataTable -Variables @{ Srv = $script:mssqlInstance }
            $result.A | Should -Be '1', '3'
            $result.B | Should -Be '2', '4'
        }
        It "should run the query with custom parameters" {
            $query = "SELECT @p1 AS A, @p2 AS B"
            $result = Invoke-DBOQuery -Query $query -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential -Parameter @{ p1 = '1'; p2 = 'string'}
            $result.A | Should -Be 1
            $result.B | Should -Be string
        }
        It "should connect to a specific database" {
            $query = "SELECT db_name(), 1, 2"
            $result = Invoke-DBOQuery -Query $query -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential -Database tempdb -As SingleValue
            $result | Should -Be tempdb
        }
    }
    Context "Negative tests" {
        It "should fail when query is erroneous" {
            { Invoke-DBOQuery -Query 'SELECT 1/0'  -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential } | Should throw 'Divide by zero'
        }
        It "should fail when parameters are of a wrong type" {
            { Invoke-DBOQuery -Query 'SELECT 1/@foo' -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential -Parameter @{ foo = 'bar' } } | Should throw 'Conversion failed'
            { Invoke-DBOQuery -Query 'SELECT ''bar'' + @foo' -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential -Parameter @{ foo = 10 } } | Should throw 'Conversion failed'
            { Invoke-DBOQuery -Query 'SELECT ''bar'' + @foo' -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential -Parameter @{ foo = Get-Date } } | Should throw 'Conversion failed'
        }
        It "should fail when credentials are wrong" {
            { Invoke-DBOQuery -Query 'SELECT 1' -SqlInstance $script:mssqlInstance -Credential ([pscredential]::new('nontexistent', ([securestring]::new()))) } | Should throw 'Login failed'
        }
        It "should fail when input file is not found" {
            { Invoke-DBOQuery -InputFile '.\nonexistent' -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential } | Should throw 'Cannot find path'
            { '.\nonexistent' | Invoke-DBOQuery -SqlInstance $script:mssqlInstance -Credential $script:mssqlCredential } | Should throw 'Cannot find path'
        }
    }
}