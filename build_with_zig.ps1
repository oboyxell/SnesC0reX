param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

function Get-RelativeProjectPath([string]$Root, [string]$FullPath) {
    $rootNorm = [System.IO.Path]::GetFullPath($Root)
    $fullNorm = [System.IO.Path]::GetFullPath($FullPath)
    if ($fullNorm.StartsWith($rootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $fullNorm.Substring($rootNorm.Length)
        if ($rel.StartsWith("\") -or $rel.StartsWith("/")) {
            $rel = $rel.Substring(1)
        }
        return $rel
    }
    return [System.IO.Path]::GetFileName($FullPath)
}

function Find-Tool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Find-Zig {
    $zig = Find-Tool "zig"
    if ($zig) { return $zig }
    throw "zig.exe not found in PATH. Install Zig and add it to PATH first."
}

function Find-Lld([string]$zigPath) {
    $cmd = Find-Tool "ld.lld"
    if ($cmd) { return $cmd }

    $zigDir = Split-Path $zigPath -Parent
    $candidates = @(
        (Join-Path $zigDir "ld.lld.exe"),
        (Join-Path $zigDir "ld.lld")
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    throw "ld.lld not found. Install LLVM or use a Zig package that includes ld.lld."
}

function Find-Objcopy([string]$zigPath) {
    $cmd = Find-Tool "llvm-objcopy"
    if ($cmd) { return $cmd }

    $zigDir = Split-Path $zigPath -Parent
    $candidates = @(
        (Join-Path $zigDir "llvm-objcopy.exe"),
        (Join-Path $zigDir "llvm-objcopy")
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    throw "llvm-objcopy not found. Install LLVM or use a Zig package that includes llvm-objcopy."
}

$ProjectRoot = (Resolve-Path $ProjectRoot).Path
Set-Location $ProjectRoot

$BuildDir = Join-Path $ProjectRoot "compiled"
$ObjDir   = Join-Path $BuildDir "obj"

$CFlags = @(
    "-target", "x86_64-freestanding-none",
    "-Os",
    "-ffreestanding",
    "-fno-stack-protector",
    "-fno-builtin",
    "-fpie",
    "-mno-red-zone",
    "-mstackrealign",
    "-fomit-frame-pointer",
    "-fcf-protection=none",
    "-fno-exceptions",
    "-fno-unwind-tables",
    "-fno-asynchronous-unwind-tables",
    "-Wall",
    "-Wno-unused-function",
    "-Isrc"
)

$zigPath = Find-Zig
$lld     = Find-Lld $zigPath
$objcopy = Find-Objcopy $zigPath

if (Test-Path $ObjDir) {
    Remove-Item $ObjDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ObjDir | Out-Null
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

$srcRoot = Join-Path $ProjectRoot "src"
$coreSources = Get-ChildItem (Join-Path $srcRoot "snes") -Filter *.c | Sort-Object Name | ForEach-Object { $_.FullName }
$mainSources = @(
    (Join-Path $srcRoot "snes_main.c"),
    (Join-Path $srcRoot "snes_runtime.c"),
    (Join-Path $srcRoot "ftp.c")
)
$sources = $mainSources + $coreSources

$objects = @()

foreach ($src in $sources) {
    $relative = Get-RelativeProjectPath $ProjectRoot $src
    $obj = Join-Path $ObjDir (($relative -replace '\\','/') + ".o")
    $objDir = Split-Path $obj -Parent
    New-Item -ItemType Directory -Force -Path $objDir | Out-Null

    Write-Host "Compiling $relative"
    & $zigPath cc @CFlags -c $src -o $obj
    if ($LASTEXITCODE -ne 0) {
        throw "Compilation failed for $relative"
    }
    $objects += $obj
}

$elf = Join-Path $BuildDir "snes_emu.elf"
$bin = Join-Path $BuildDir "snes_emu.bin"

Write-Host "Linking compiled\snes_emu.elf"
$linkArgs = @(
    "-m", "elf_x86_64",
    "-pie",
    "--script", "linker.ld",
    "-e", "_start",
    "-o", $elf
) + $objects

& $lld @linkArgs
if ($LASTEXITCODE -ne 0) {
    throw "Link failed"
}

Write-Host "Writing compiled\snes_emu.bin"
& $objcopy -O binary $elf $bin
if ($LASTEXITCODE -ne 0) {
    throw "objcopy failed"
}

$size = (Get-Item $bin).Length
Write-Host "Built: $bin ($size bytes)"
