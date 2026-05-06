param(
    [Parameter(Mandatory = $true)]
    [string] $SourceDir,

    [Parameter(Mandatory = $true)]
    [string] $VcpkgRoot,

    [string] $MySqlVersion = "5.7.44"
)

$ErrorActionPreference = "Stop"

function New-CleanDirectory {
    param([Parameter(Mandatory = $true)][string] $Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Copy-FirstFile {
    param(
        [Parameter(Mandatory = $true)][string] $Root,
        [Parameter(Mandatory = $true)][string] $Filter,
        [Parameter(Mandatory = $true)][string] $Destination
    )

    $file = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $Filter | Select-Object -First 1
    if (-not $file) {
        throw "Cannot find $Filter under $Root"
    }
    Copy-Item -LiteralPath $file.FullName -Destination $Destination -Force
}

$tempRoot = $env:RUNNER_TEMP
if (-not $tempRoot) {
    $tempRoot = [System.IO.Path]::GetTempPath()
}
$thirdPartyDir = Join-Path $tempRoot "wyturtle-thirdparty"
New-CleanDirectory -Path $thirdPartyDir

$windowsDepDir = Join-Path $SourceDir "dep\windows"
$includeDir = Join-Path $windowsDepDir "include"
$releaseLibDir = Join-Path $windowsDepDir "lib\x64_release"
New-Item -ItemType Directory -Force -Path $releaseLibDir | Out-Null

$mysqlZip = Join-Path $thirdPartyDir "mysql-$MySqlVersion-winx64.zip"
$mysqlUrl = "https://cdn.mysql.com/Downloads/MySQL-5.7/mysql-$MySqlVersion-winx64.zip"
Invoke-WebRequest -Uri $mysqlUrl -OutFile $mysqlZip

$mysqlExtractDir = Join-Path $thirdPartyDir "mysql"
Expand-Archive -LiteralPath $mysqlZip -DestinationPath $mysqlExtractDir -Force
$mysqlRoot = Get-ChildItem -LiteralPath $mysqlExtractDir -Directory | Select-Object -First 1
if (-not $mysqlRoot) {
    throw "Cannot find extracted MySQL directory"
}

$mysqlIncludeDst = Join-Path $includeDir "mysql"
New-CleanDirectory -Path $mysqlIncludeDst
Copy-Item -Path (Join-Path $mysqlRoot.FullName "include\*") -Destination $mysqlIncludeDst -Recurse -Force
Copy-FirstFile -Root $mysqlRoot.FullName -Filter "libmysql.lib" -Destination (Join-Path $releaseLibDir "libmySQL.lib")
Copy-FirstFile -Root $mysqlRoot.FullName -Filter "libmysql.dll" -Destination (Join-Path $releaseLibDir "libmySQL.dll")

Get-ChildItem -LiteralPath $mysqlRoot.FullName -Recurse -File -Filter "*.dll" |
    Where-Object { $_.Name -like "libssl*.dll" -or $_.Name -like "libcrypto*.dll" -or $_.Name -ieq "libmysql.dll" } |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $releaseLibDir -Force }

$vcpkgInstalledDir = Join-Path $VcpkgRoot "installed\x64-windows"
$opensslSourceIncludeDir = Join-Path $vcpkgInstalledDir "include\openssl"
$opensslSourceLibDir = Join-Path $vcpkgInstalledDir "lib"
$vcpkgBinDir = Join-Path $VcpkgRoot "installed\x64-windows\bin"

if (-not (Test-Path -LiteralPath (Join-Path $opensslSourceIncludeDir "ssl.h"))) {
    throw "Cannot find vcpkg OpenSSL headers. Make sure openssl:x64-windows is installed."
}

$opensslIncludeDst = Join-Path $includeDir "openssl"
New-CleanDirectory -Path $opensslIncludeDst
Copy-Item -Path (Join-Path $opensslSourceIncludeDir "*") -Destination $opensslIncludeDst -Recurse -Force

$opensslNestedIncludeDst = Join-Path $opensslIncludeDst "openssl"
New-Item -ItemType Directory -Force -Path $opensslNestedIncludeDst | Out-Null
Copy-Item -Path (Join-Path $opensslSourceIncludeDir "*") -Destination $opensslNestedIncludeDst -Recurse -Force

Copy-Item -LiteralPath (Join-Path $opensslSourceLibDir "libssl.lib") -Destination (Join-Path $releaseLibDir "libssl.lib") -Force
Copy-Item -LiteralPath (Join-Path $opensslSourceLibDir "libcrypto.lib") -Destination (Join-Path $releaseLibDir "libcrypto.lib") -Force

if (Test-Path -LiteralPath $vcpkgBinDir) {
    Get-ChildItem -LiteralPath $vcpkgBinDir -File -Filter "*.dll" |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $releaseLibDir -Force }
}

$requiredFiles = @(
    "libmySQL.lib",
    "libmySQL.dll",
    "libssl.lib",
    "libcrypto.lib"
)

foreach ($file in $requiredFiles) {
    $path = Join-Path $releaseLibDir $file
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required dependency file is missing: $path"
    }
}

Write-Host "Prepared Windows dependencies in $releaseLibDir"
