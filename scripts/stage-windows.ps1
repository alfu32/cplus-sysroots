param(
    [Parameter(Mandatory = $true)][string]$Reference,
    [Parameter(Mandatory = $true)][string]$Output
)

$ErrorActionPreference = "Stop"

if ($Reference -notmatch '^(x86_64|arm64)-w64-mingw32-(dev|rt)$') {
    throw "unsupported Windows reference: $Reference"
}

$kind = $Reference.Substring($Reference.LastIndexOf('-') + 1)
$prefix = if ($Reference.StartsWith('arm64-')) { 'C:\msys64\clangarm64' } else { 'C:\msys64\ucrt64' }
$bash = 'C:\msys64\usr\bin\bash.exe'

if (-not (Test-Path $bash)) {
    throw "MSYS2 is not available at C:\msys64"
}

if ($Reference.StartsWith('arm64-')) {
    $packages = 'mingw-w64-clang-aarch64-gcc mingw-w64-clang-aarch64-headers mingw-w64-clang-aarch64-crt'
} else {
    $packages = 'mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-headers mingw-w64-ucrt-x86_64-crt'
}

& $bash -lc "pacman --noconfirm -Sy $packages"
if ($LASTEXITCODE -ne 0) { throw "MSYS2 package installation failed" }

if (Test-Path $Output) { Remove-Item -Recurse -Force $Output }
New-Item -ItemType Directory -Path $Output | Out-Null

$include = Join-Path $prefix 'include'
$lib = Join-Path $prefix 'lib'
$bin = Join-Path $prefix 'bin'
if ($kind -eq 'dev') {
    Copy-Item -Recurse -Force $include (Join-Path $Output 'include')
}
Copy-Item -Recurse -Force $lib (Join-Path $Output 'lib')
if ($kind -eq 'rt' -and (Test-Path $bin)) {
    New-Item -ItemType Directory -Path (Join-Path $Output 'bin') | Out-Null
    Get-ChildItem $bin -Filter '*.dll' | Copy-Item -Destination (Join-Path $Output 'bin') -Force
}

$packageList = & $bash -lc "pacman -Q"
$manifest = [ordered]@{
    reference = $Reference
    target = $Reference.Substring(0, $Reference.LastIndexOf('-'))
    kind = $kind
    family = 'mingw-ucrt'
    crt = 'ucrt'
    source = 'github-windows-2025-msys2'
    prefix = $prefix
    packages = @($packageList)
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Output 'MANIFEST.json')
