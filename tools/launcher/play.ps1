# Behind the Screen launcher (Windows).
#
# The desktop shortcut runs this. It rebuilds the game from this project folder
# whenever any file has changed since the last build, then starts it, so the
# shortcut always opens the newest version. Nothing changed = it starts at once.
#
# It uses the Defold editor you already have (its Java and its built-in Bob
# builder), so nothing else needs installing. The playable build lands in
# <project>\bundle and the build log in <project>\build\launcher\launcher.log.
#
#   play.ps1                   rebuild if needed, then play
#   play.ps1 -Rebuild          rebuild from scratch, then play
#   play.ps1 -InstallShortcut  (re)create the desktop shortcut, e.g. after moving the project

param(
    [switch]$Rebuild,
    [switch]$InstallShortcut
)

$ErrorActionPreference = 'Stop'
try { $Host.UI.RawUI.WindowTitle = 'Behind the Screen' } catch { }

$Project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$BuildOut = Join-Path $Project 'build\launcher'
$BundleOut = Join-Path $Project 'bundle'
$Log = Join-Path $BuildOut 'launcher.log'
$Stamp = Join-Path $BundleOut 'source.stamp'
$CacheDir = Join-Path $env:LOCALAPPDATA 'BehindTheScreen'
$DefoldCache = Join-Path $CacheDir 'defold_path.txt'

function Stop-WithMessage([string]$text) {
    Write-Host ''
    Write-Host $text -ForegroundColor Yellow
    Write-Host ''
    Read-Host 'Press Enter to close' | Out-Null
    exit 1
}

if ($InstallShortcut) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut((Join-Path $desktop 'Behind the Screen - Play.lnk'))
    $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $lnk.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $PSScriptRoot 'play.ps1') + '"'
    $lnk.WorkingDirectory = $Project
    $lnk.IconLocation = (Join-Path $PSScriptRoot 'behind_the_screen.ico') + ',0'
    $lnk.Description = 'Build and play the latest version of Behind the Screen'
    $lnk.Save()
    Write-Host "Shortcut saved to $desktop"
    exit 0
}

# --- Find the Defold editor ---------------------------------------------------------------
# Remembered after the first search. Picks the newest Defold it can find.
function Find-Defold {
    if (Test-Path $DefoldCache) {
        $dir = (Get-Content $DefoldCache -Raw).Trim()
        if ($dir -and (Test-Path (Join-Path $dir 'packages'))) { return $dir }
    }
    Write-Host 'Looking for the Defold editor (only the first time)...'
    $roots = @(
        (Join-Path $env:USERPROFILE 'Downloads'),
        (Join-Path $env:USERPROFILE 'Documents'),
        (Join-Path $env:USERPROFILE 'OneDrive\Documents'),
        (Join-Path $env:USERPROFILE 'Desktop'),
        (Join-Path $env:USERPROFILE 'OneDrive\Desktop'),
        (Join-Path $env:LOCALAPPDATA 'Programs'),
        $env:ProgramFiles
    ) | Where-Object { $_ -and (Test-Path $_) }
    $best = $null
    $bestVersion = [version]'0.0'
    foreach ($root in $roots) {
        $hits = Get-ChildItem -Path $root -Filter 'Defold.exe' -File -Recurse -Depth 5 -ErrorAction SilentlyContinue
        foreach ($hit in $hits) {
            $config = Join-Path $hit.DirectoryName 'config'
            if (-not (Test-Path $config)) { continue }
            $match = Select-String -Path $config -Pattern '^version\s*=\s*([0-9.]+)' | Select-Object -First 1
            if (-not $match) { continue }
            $version = [version]$match.Matches[0].Groups[1].Value
            if ($version -gt $bestVersion) {
                $bestVersion = $version
                $best = $hit.DirectoryName
            }
        }
    }
    if ($best) {
        New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
        Set-Content -Path $DefoldCache -Value $best
    }
    return $best
}

$Defold = Find-Defold
if (-not $Defold) {
    Stop-WithMessage ("Couldn't find the Defold editor (Defold.exe). Put its folder somewhere under Downloads " +
        "or Documents, or write its folder path into $DefoldCache.")
}
$packages = Join-Path $Defold 'packages'
$jar = Get-ChildItem -Path $packages -Filter 'defold-*.jar' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$java = Get-ChildItem -Path $packages -Directory -Filter 'jdk*' |
    ForEach-Object { Join-Path $_.FullName 'bin\java.exe' } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $jar -or -not $java) {
    Remove-Item -Path $DefoldCache -ErrorAction SilentlyContinue
    Stop-WithMessage "The Defold folder at $Defold looks incomplete (no editor jar or Java). Try again to search for another copy."
}

# --- Has anything changed since the last build? --------------------------------------------
$skip = @('build', 'bundle', '.internal', '.git', 'tools', 'playtest')
$newest = [long]0
$count = 0
foreach ($file in (Get-ChildItem -Path $Project -File -Recurse -Force -ErrorAction SilentlyContinue)) {
    $rel = $file.FullName.Substring($Project.Length).TrimStart('\')
    $top = $rel.Split('\')[0]
    if ($skip -contains $top -or $rel -eq 'log.txt') { continue }
    $count++
    if ($file.LastWriteTimeUtc.Ticks -gt $newest) { $newest = $file.LastWriteTimeUtc.Ticks }
}
$sourceStamp = "$newest|$count|$($jar.Name)"

function Find-Game {
    Get-ChildItem -Path $BundleOut -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$game = Find-Game
$upToDate = (-not $Rebuild) -and $game -and (Test-Path $Stamp) -and ((Get-Content $Stamp -Raw).Trim() -eq $sourceStamp)

if (-not $upToDate) {
    if ($game) {
        $open = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $game.FullName }
        if ($open) {
            Stop-WithMessage 'Behind the Screen is already open. Close it, then use the shortcut again to load the newest version.'
        }
    }
    Write-Host 'Building the newest version of Behind the Screen.'
    Write-Host 'The first build takes a minute or two; after that only changes are rebuilt.'
    New-Item -ItemType Directory -Force -Path $BuildOut | Out-Null
    $commands = 'build bundle'
    if ($Rebuild) { $commands = 'distclean build bundle' }
    $bobArgs = '-Dfile.encoding=UTF-8 -cp "' + $jar.FullName + '" com.dynamo.bob.Bob' +
        ' --root "' + $Project + '" --output build/launcher --platform x86_64-win32 --variant debug' +
        ' --archive --bundle-output "' + $BundleOut + '" ' + $commands

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
    $started = Get-Date
    while (-not $proc.WaitForExit(1000)) { Write-Host -NoNewline '.' }
    $proc.WaitForExit()
    Write-Host ''
    $text = "java: $java`r`nbob: $bobArgs`r`n`r`n" + $out.Result + "`r`n" + $err.Result
    Set-Content -Path $Log -Value $text
    if ($proc.ExitCode -ne 0) {
        Write-Host ''
        Write-Host 'The build failed. The end of the build log:' -ForegroundColor Yellow
        ($out.Result + "`n" + $err.Result).Trim().Split("`n") | Select-Object -Last 25 | ForEach-Object { Write-Host $_ }
        Stop-WithMessage "Full log: $Log"
    }
    $game = Find-Game
    if (-not $game) { Stop-WithMessage "The build finished but no game .exe turned up in $BundleOut. Log: $Log" }
    Set-Content -Path $Stamp -Value $sourceStamp
    Write-Host ('Built in {0:N0} seconds.' -f ((Get-Date) - $started).TotalSeconds)
}

# The dialogue review mode (F4) saves straight into the project's lines.json; tell the game where that is.
Set-Content -Path (Join-Path $game.DirectoryName 'project_path.txt') -Value $Project -Encoding ASCII

Write-Host 'Starting Behind the Screen...'
Start-Process -FilePath $game.FullName -WorkingDirectory $game.DirectoryName
