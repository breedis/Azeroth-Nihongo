<#
Builds the release of Azeroth Nihongo.

  publish\AzerothNihongo\            exactly what goes in the zip
  publish\AzerothNihongo-<ver>.zip   upload this to CurseForge

Usage (from this folder):
  powershell -ExecutionPolicy Bypass -File build.ps1
  powershell -ExecutionPolicy Bypass -File build.ps1 -Install "C:\Program Files (x86)\World of Warcraft\_retail_"

-Install also copies the built addon into <game>\Interface\AddOns\AzerothNihongo.
#>
param([string]$Install)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$name = 'AzerothNihongo'

# Version from the .toc
$toc = Join-Path $root "$name.toc"
$version = (Select-String -Path $toc -Pattern '^## Version:\s*(\S+)').Matches[0].Groups[1].Value
if (-not $version) { throw "No '## Version:' line in $toc" }

# Files that ship. Everything else (build script, CurseForge text, tests...) stays out.
$files = @("$name.toc", 'Bindings.xml', 'LICENSE.txt', 'README.md', 'CHANGELOG.md')
$tocText = Get-Content $toc -Encoding UTF8
foreach ($line in $tocText) {
  $l = $line.Trim()
  if ($l -and -not $l.StartsWith('#')) { $files += $l }   # the .lua files the .toc loads
}
$files += @('Fonts\japanese.ttf', 'Fonts\IPA_Font_License_Agreement_v1.0.txt', 'Fonts\README.txt')

$publish = Join-Path $root 'publish'
$out = Join-Path $publish $name
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $out 'Fonts') | Out-Null

foreach ($f in $files) {
  $src = Join-Path $root $f
  if (-not (Test-Path $src)) { throw "Missing file: $f" }
  Copy-Item $src (Join-Path $out $f)
}

# Zip with forward slashes and a top-level AzerothNihongo folder (Compress-Archive in
# Windows PowerShell writes backslashes, which some addon managers cannot unpack).
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = Join-Path $publish "$name-$version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
  Get-ChildItem $out -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($out.Length + 1).Replace('\', '/')
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
      $zip, $_.FullName, "$name/$rel", [System.IO.Compression.CompressionLevel]::Optimal)
  }
} finally {
  $zip.Dispose()
}

$count = (Get-ChildItem $out -Recurse -File).Count
$size = [math]::Round((Get-Item $zipPath).Length / 1KB)
Write-Output "Built $name $version : $count files, $size KB"
Write-Output "  $zipPath"

if ($Install) {
  $dest = Join-Path $Install "Interface\AddOns\$name"
  if (-not (Test-Path (Join-Path $Install 'Interface\AddOns'))) { throw "No Interface\AddOns in $Install" }
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  Copy-Item $out $dest -Recurse
  Write-Output "Installed to $dest"
}
