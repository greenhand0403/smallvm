# 由于window上git bash找不到emcc，所以用powershell去执行构建脚本了
# 注意安装 4.0.10 版本 .\emsdk install 4.0.10 (最新的是 5.0.4)
# 并切换到该版本 .\emsdk activate 4.0.10
$ErrorActionPreference = "Stop"

function Copy-IfExists {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePattern,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $items = Get-ChildItem -Path $SourcePattern -ErrorAction SilentlyContinue
    if ($items) {
        Copy-Item $SourcePattern $Destination -Force
    }
}

function Remove-IfExists {
    param(
        [Parameter(Mandatory = $true)][string]$PathToRemove
    )

    if (Test-Path $PathToRemove) {
        Remove-Item $PathToRemove -Recurse -Force
    }
}

Write-Host "== Preparing build assets =="

# Clean any leftovers from previous runs
Remove-IfExists "Examples"
Remove-IfExists "Libraries"
Remove-IfExists "precompiled"
Remove-IfExists "esp32"
Remove-IfExists "runtime"
Remove-IfExists "translations"
Remove-IfExists "img"

# Copy folders to be included in embedded file system
Copy-Item "..\..\gp\Examples" -Destination "." -Recurse -Force
Copy-Item "..\..\gp\Libraries" -Destination "." -Recurse -Force

New-Item -ItemType Directory -Force -Path "precompiled" | Out-Null
Copy-IfExists "..\..\precompiled\*.hex" "precompiled"
Copy-IfExists "..\..\precompiled\*.uf2" "precompiled"
Copy-IfExists "..\..\precompiled\*.bin" "precompiled"

New-Item -ItemType Directory -Force -Path "esp32" | Out-Null
Copy-IfExists "..\..\esp32\*.bin" "esp32"

Copy-Item "..\..\gp\runtime" -Destination "." -Recurse -Force
Copy-Item "..\..\ide\*" "runtime\lib" -Force

if (Test-Path "runtime\lib\MicroBlocksPatches.gp") {
    Move-Item "runtime\lib\MicroBlocksPatches.gp" "runtime\lib\zzzMicroBlocksPatches.gp" -Force
}

Copy-Item "..\..\translations" -Destination "." -Recurse -Force
Copy-Item "..\..\img" -Destination "." -Recurse -Force

Write-Host "== Running emcc =="

emcc `
  -std=gnu99 `
  -Wall `
  -O3 `
  -Wno-macro-redefined `
  -D EMSCRIPTEN `
  -D NO_JPEG `
  -D NO_SDL `
  -D NO_SOCKETS `
  -D SHA2_USE_INTTYPES_H `
  -s USE_ZLIB=1 `
  -s FETCH=1 `
  -s TOTAL_MEMORY=268435456 `
  -s ALLOW_MEMORY_GROWTH=0 `
  -s WASM=1 `
  browserPrims.c `
  cache.c `
  dict.c `
  embeddedFS.c `
  events.c `
  gp.c `
  httpPrims.c `
  interp.c `
  mem.c `
  memGC.c `
  oop.c `
  parse.c `
  pathPrims.c `
  prims.c `
  serialPortPrims.c `
  sha1.c `
  sha2.c `
  soundPrims.c `
  textAndFontPrims.c `
  vectorPrims.c `
  --preload-file Examples `
  --preload-file Libraries `
  --preload-file precompiled `
  --preload-file esp32 `
  --preload-file runtime `
  --preload-file translations `
  --preload-file img `
  -o gp_wasm.html

if ($LASTEXITCODE -ne 0) {
    throw "emcc failed with exit code $LASTEXITCODE"
}

Write-Host "== Checking outputs =="

$requiredOutputs = @("gp_wasm.js", "gp_wasm.wasm", "gp_wasm.data")
foreach ($file in $requiredOutputs) {
    if (-not (Test-Path $file)) {
        throw "Expected output file not found: $file"
    }
}

Write-Host "== Copying outputs to webapp =="

New-Item -ItemType Directory -Force -Path "..\webapp" | Out-Null
Copy-Item "gp_wasm.js" "..\webapp" -Force
Copy-Item "gp_wasm.wasm" "..\webapp" -Force
Copy-Item "gp_wasm.data" "..\webapp" -Force

Write-Host "== Moving outputs to MicroBlocks =="

New-Item -ItemType Directory -Force -Path "..\MicroBlocks" | Out-Null
Move-Item "gp_wasm.js" "..\MicroBlocks" -Force
Move-Item "gp_wasm.wasm" "..\MicroBlocks" -Force
Move-Item "gp_wasm.data" "..\MicroBlocks" -Force

if (Test-Path "gp_wasm.html") {
    Remove-Item "gp_wasm.html" -Force
}

Write-Host "== Cleaning temporary folders =="

Remove-IfExists "Examples"
Remove-IfExists "Libraries"
Remove-IfExists "precompiled"
Remove-IfExists "esp32"
Remove-IfExists "runtime"
Remove-IfExists "translations"
Remove-IfExists "img"

Write-Host "Build completed successfully."