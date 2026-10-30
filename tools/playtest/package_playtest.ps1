# Package the playtest build (M7): one zip to send to outside testers.
#
#   Right-click > Run with PowerShell, or:
#   powershell -ExecutionPolicy Bypass -File tools\playtest\package_playtest.ps1
#
# Builds a release version of the game from this project folder, with tools\playtest\playtest.ini
# layered over game.project: the draft dialogue lines still play (drafts = 1) and the developer
# keys are off (F2 sandbox, F3 numbers, F4 dialogue review). A release build also opens no
# network ports, so Windows Firewall doesn't ask testers anything. The tester readme and a
# "find my log" helper go in next to the game, and the lot is zipped to
#   <project>\playtest\Behind the Screen playtest <version> <date>.zip
#
# It uses the same Defold editor as the Play shortcut (tools\launcher\play.ps1), so run
# the shortcut once first if you never have. When the logs come back:
#   python tools\playtest\analyze.py <folder of logs>

$ErrorActionPreference = 'Stop'

$Here = $PSScriptRoot
$Project = (Resolve-Path (Join-Path $Here '..\..')).Path
$BuildOut = Join-Path $Project 'build\playtest'
$Stage = Join-Path $Project 'build\playtest_bundle'
$OutDir = Join-Path $Project 'playtest'
$Log = Join-Path $BuildOut 'package.log'
$DefoldCache = Join-Path $env:LOCALAPPDATA 'BehindTheScreen\defold_path.txt'

function Stop-WithMessage([string]$text) {
    Write-Host ''
    Write-Host $text -ForegroundColor Yellow
    Write-Host ''
    Read-Host 'Press Enter to close' | Out-Null
    exit 1
}

# --- The Defold editor the Play shortcut found --------------------------------------------
if (-not (Test-Path $DefoldCache)) {
    Stop-WithMessage 'Run the "Behind the Screen - Play" shortcut once first, so it can find the Defold editor.'
}
$Defold = (Get-Content $DefoldCache -Raw).Trim()
$packages = Join-Path $Defold 'packages'
$jar = Get-ChildItem -Path $packages -Filter 'defold-*.jar' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
$java = Get-ChildItem -Path $packages -Directory -Filter 'jdk*' -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'bin\java.exe' } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $jar -or -not $java) {
    Stop-WithMessage "The Defold folder at $Defold looks incomplete. Run the Play shortcut again to search for it."
}

$version = '0.0.0'
$match = Select-String -Path (Join-Path $Project 'game.project') -Pattern '^version\s*=\s*(\S+)' | Select-Object -First 1
if ($match) { $version = $match.Matches[0].Groups[1].Value }
$stamp = Get-Date -Format 'yyyy-MM-dd'
$zipName = "Behind the Screen playtest $version $stamp.zip"

# --- Build ----------------------------------------------------------------------------------
Write-Host "Building the playtest version of Behind the Screen ($version)."
Write-Host 'This is a clean build, so it takes a few minutes.'
if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
New-Item -ItemType Directory -Force -Path $BuildOut, $Stage, $OutDir | Out-Null

$settings = Join-Path $Here 'playtest.ini'
$bobArgs = '-Dfile.encoding=UTF-8 -cp "' + $jar.FullName + '" com.dynamo.bob.Bob' +
    ' --root "' + $Project + '" --output build/playtest --platform x86_64-win32 --variant release' +
    ' --settings "' + $settings + '" --archive --bundle-output "' + $Stage + '" distclean build bundle'

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $java
$psi.Arguments = $bobArgs
$psi.WorkingDirectory = $Project
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$proc = [System.Diagnostics.Process]::Start($psi)
$out = $proc.StandardOutput.ReadToEndAsync()
$err = $proc.StandardError.ReadToEndAsync()
while (-not $proc.WaitForExit(1000)) { Write-Host -NoNewline '.' }
$proc.WaitForExit()
Write-Host ''
Set-Content -Path $Log -Value ("java: $java`r`nbob: $bobArgs`r`n`r`n" + $out.Result + "`r`n" + $err.Result)
if ($proc.ExitCode -ne 0) {
    Write-Host 'The build failed. The end of the build log:' -ForegroundColor Yellow
    ($out.Result + "`n" + $err.Result).Trim().Split("`n") | Select-Object -Last 25 | ForEach-Object { Write-Host $_ }
    Stop-WithMessage "Full log: $Log"
}

$game = Get-ChildItem -Path $Stage -Filter '*.exe' -File -Recurse | Select-Object -First 1
if (-not $game) { Stop-WithMessage "The build finished but no game .exe turned up in $Stage. Log: $Log" }
$folder = $game.DirectoryName

# --- What goes in next to the game ----------------------------------------------------------
# (v2: the museum build has its own readme.)
$readme = Join-Path $Here 'README_TESTERS_V2.txt'
if (-not (Test-Path -LiteralPath $readme)) { $readme = Join-Path $Here 'README_TESTERS.txt' }
Copy-Item -Path $readme -Destination (Join-Path $folder 'READ ME FIRST.txt')
Copy-Item -Path (Join-Path $Here 'Open my playtest log folder.bat') -Destination $folder
# The dialogue review mode looks for this; testers don't have it, and shouldn't.
Remove-Item -Path (Join-Path $folder 'project_path.txt') -ErrorAction SilentlyContinue

# --- Zip ------------------------------------------------------------------------------------
$zip = Join-Path $OutDir $zipName
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $folder -DestinationPath $zip
$mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)

Write-Host ''
Write-Host "Ready: $zip ($mb MB)" -ForegroundColor Green
Write-Host ''
Write-Host 'Send it with the tester note from the playtest guide. When logs come back, put them in'
Write-Host 'one folder (one file per tester, named after them) and run:'
Write-Host '  python tools\playtest\analyze.py <that folder>'
Write-Host ''
Start-Process explorer.exe -ArgumentList ('/select,"' + $zip + '"')
Read-Host 'Press Enter to close' | Out-Null
