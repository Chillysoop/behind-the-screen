# Behind the Screen launcher (Windows).
#
# The desktop shortcut runs this. It rebuilds the game from this project folder
# whenever any file has changed since the last build, then starts it, so the
# shortcut always opens the newest version. Nothing changed = it starts at once.
#
# It uses the Defold editor you already have (its Java and its built-in Bob
# builder), so nothing else needs installing. The playable build lands in
# <project>\bundle and the build log in <project>\build\launcher\launcher.log.
# Every run also writes what it did to <project>\build\launcher\last_run.txt,
# so a run that stops early can be looked into afterwards.
#
#   play.ps1                   rebuild if needed, then play
#   play.ps1 -Rebuild          rebuild from scratch, then play
#   play.ps1 -InstallShortcut  (re)create the desktop shortcut, e.g. after moving the project
#
# (October 29: the first run used to search whole drives for Defold before saying anything,
# which could look like nothing was happening. It now checks the usual places first, says
# what it's doing, and any error stays on screen instead of closing the window.)

param(
    [switch]$Rebuild,
    [switch]$InstallShortcut
)

$ErrorActionPreference = 'Stop'
try { $Host.UI.RawUI.WindowTitle = 'Behind the Screen' } catch { }

$Project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$BuildOut = Join-Path $Project 'build\launcher'
$BundleOut = Join-Path $Project 'bundle'
$Log = Join-Path $BuildOut 'launcher.log'
$RunLog = Join-Path $BuildOut 'last_run.txt'
$Stamp = Join-Path $BundleOut 'source.stamp'
$CacheDir = Join-Path $env:LOCALAPPDATA 'BehindTheScreen'
$DefoldCache = Join-Path $CacheDir 'defold_path.txt'

New-Item -ItemType Directory -Force -Path $BuildOut | Out-Null
$transcript = $false
try { Start-Transcript -LiteralPath $RunLog -Force | Out-Null; $transcript = $true } catch { }

function Close-Run {
    if ($script:transcript) {
        try { Stop-Transcript | Out-Null } catch { }
        $script:transcript = $false
    }
}

function Stop-WithMessage([string]$text) {
    Write-Host ''
    Write-Host $text -ForegroundColor Yellow
    Write-Host ''
    Close-Run
    Read-Host 'Press Enter to close' | Out-Null
    exit 1
}

# Anything unexpected: say what and where, and keep the window open.
trap {
    Write-Host ''
    Write-Host ('Something went wrong: ' + $_.Exception.Message) -ForegroundColor Yellow
    if ($_.InvocationInfo) { Write-Host $_.InvocationInfo.PositionMessage }
    Write-Host ''
    Write-Host "What happened is saved in $RunLog"
    Close-Run
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
    Close-Run
    exit 0
}

Write-Host "Behind the Screen: $Project"

# --- Find the Defold editor ---------------------------------------------------------------
# Remembered after the first time. The usual places are checked first, which is instant;
# only if Defold isn't in any of them does it search the user's folders.

# A Defold editor folder: Defold.exe beside a packages folder holding the editor jar.
function Test-DefoldDir([string]$dir) {
    if (-not $dir) { return $false }
    if (-not (Test-Path -LiteralPath (Join-Path $dir 'Defold.exe'))) { return $false }
    $pk = Join-Path $dir 'packages'
    if (-not (Test-Path -LiteralPath $pk)) { return $false }
    $jar = Get-ChildItem -LiteralPath $pk -Filter 'defold-*.jar' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    return [bool]$jar
}

function Get-DefoldVersion([string]$dir) {
    $config = Join-Path $dir 'config'
    if (Test-Path -LiteralPath $config) {
        $match = Select-String -LiteralPath $config -Pattern '^version\s*=\s*([0-9.]+)' | Select-Object -First 1
        if ($match) {
            try { return [version]$match.Matches[0].Groups[1].Value } catch { }
        }
    }
    return [version]'0.0'
}

function Find-Defold {
    if (Test-Path -LiteralPath $DefoldCache) {
        $dir = (Get-Content -LiteralPath $DefoldCache -Raw).Trim()
        if (Test-DefoldDir $dir) { return $dir }
    }
    $bases = @(
        (Join-Path $env:USERPROFILE 'Downloads'),
        (Join-Path $env:USERPROFILE 'Desktop'),
        (Join-Path $env:USERPROFILE 'OneDrive\Desktop'),
        (Join-Path $env:USERPROFILE 'Documents'),
        (Join-Path $env:USERPROFILE 'OneDrive\Documents'),
        (Join-Path $env:LOCALAPPDATA 'Programs'),
        $env:ProgramFiles,
        $env:SystemDrive + '\'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    # The usual spots: <base>\Defold, <base>\Defold*\ and <base>\Defold*\Defold
    # (the download unzips to Defold-x86_64-win32\Defold).
    $candidates = @()
    foreach ($base in $bases) {
        $candidates += (Join-Path $base 'Defold')
        foreach ($d in (Get-ChildItem -LiteralPath $base -Directory -Filter 'Defold*' -ErrorAction SilentlyContinue)) {
            $candidates += $d.FullName
            $candidates += (Join-Path $d.FullName 'Defold')
        }
    }
    $best = $null
    $bestVersion = [version]'0.0'
    foreach ($dir in $candidates) {
        if (Test-DefoldDir $dir) {
            $version = Get-DefoldVersion $dir
            if (-not $best -or $version -gt $bestVersion) {
                $best = $dir
                $bestVersion = $version
            }
        }
    }
    if (-not $best) {
        Write-Host 'Looking for the Defold editor in your folders (only the first time; this can take a few minutes)...'
        foreach ($root in $bases) {
            if ($root -eq $env:ProgramFiles -or $root -eq ($env:SystemDrive + '\')) { continue }
            Write-Host "  $root"
            $hits = Get-ChildItem -LiteralPath $root -Filter 'Defold.exe' -File -Recurse -Depth 4 -ErrorAction SilentlyContinue
            foreach ($hit in $hits) {
                if (Test-DefoldDir $hit.DirectoryName) {
                    $version = Get-DefoldVersion $hit.DirectoryName
                    if (-not $best -or $version -gt $bestVersion) {
                        $best = $hit.DirectoryName
                        $bestVersion = $version
                    }
                }
            }
        }
    }
    if ($best) {
        New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
        Set-Content -LiteralPath $DefoldCache -Value $best
    }
    return $best
}

$Defold = Find-Defold
if (-not $Defold) {
    Stop-WithMessage ("Couldn't find the Defold editor (Defold.exe). Put its folder in Downloads " +
        "or Documents, or write its folder path into $DefoldCache.")
}
Write-Host "Defold: $Defold"
$packages = Join-Path $Defold 'packages'
$jar = Get-ChildItem -LiteralPath $packages -Filter 'defold-*.jar' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$java = Get-ChildItem -LiteralPath $packages -Directory -Filter 'jdk*' |
    ForEach-Object { Join-Path $_.FullName 'bin\java.exe' } |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $jar -or -not $java) {
    Remove-Item -LiteralPath $DefoldCache -ErrorAction SilentlyContinue
    Stop-WithMessage "The Defold folder at $Defold looks incomplete (no editor jar or Java). Try again to search for another copy."
}

# --- Has anything changed since the last build? --------------------------------------------
$skip = @('build', 'bundle', '.internal', '.git', 'tools', 'playtest')
$newest = [long]0
$count = 0
foreach ($file in (Get-ChildItem -LiteralPath $Project -File -Recurse -Force -ErrorAction SilentlyContinue)) {
    $rel = $file.FullName.Substring($Project.Length).TrimStart('\')
    $top = $rel.Split('\')[0]
    if ($skip -contains $top -or $rel -eq 'log.txt') { continue }
    $count++
    if ($file.LastWriteTimeUtc.Ticks -gt $newest) { $newest = $file.LastWriteTimeUtc.Ticks }
}
$sourceStamp = "$newest|$count|$($jar.Name)"

function Find-Game {
    if (-not (Test-Path -LiteralPath $BundleOut)) { return $null }
    Get-ChildItem -LiteralPath $BundleOut -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$game = Find-Game
$upToDate = $false
if ((-not $Rebuild) -and $game -and (Test-Path -LiteralPath $Stamp)) {
    $upToDate = ((Get-Content -LiteralPath $Stamp -Raw).Trim() -eq $sourceStamp)
}

if (-not $upToDate) {
    if ($game) {
        # (By name: reading other processes' paths can be refused.)
        $open = Get-Process -Name $game.BaseName -ErrorAction SilentlyContinue
        if ($open) {
            Stop-WithMessage 'Behind the Screen is already open. Close it, then use the shortcut again to load the newest version.'
        }
    }
    Write-Host 'Building the newest version of Behind the Screen.'
    Write-Host 'The first build takes a minute or two; after that only changes are rebuilt.'
    $commands = 'build bundle'
    if ($Rebuild) { $commands = 'distclean build bundle' }
    # (A project-relative root, run from the project folder: Bob 1.13.2 can mount an absolute
    # root twice. The bundle output is absolute.)
    $bobArgs = '-Dfile.encoding=UTF-8 -cp "' + $jar.FullName + '" com.dynamo.bob.Bob' +
        ' --root . --output build/launcher --platform x86_64-win32 --variant debug' +
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
    Set-Content -LiteralPath $Log -Value $text
    if ($proc.ExitCode -ne 0) {
        Write-Host ''
        Write-Host 'The build failed. The end of the build log:' -ForegroundColor Yellow
        ($out.Result + "`n" + $err.Result).Trim().Split("`n") | Select-Object -Last 25 | ForEach-Object { Write-Host $_ }
        Stop-WithMessage "Full log: $Log"
    }
    $game = Find-Game
    if (-not $game) { Stop-WithMessage "The build finished but no game .exe turned up in $BundleOut. Log: $Log" }
    Set-Content -LiteralPath $Stamp -Value $sourceStamp
    Write-Host ('Built in {0:N0} seconds.' -f ((Get-Date) - $started).TotalSeconds)
}

# The dialogue review mode (F4) saves straight into the project's lines.json; tell the game where that is.
Set-Content -LiteralPath (Join-Path $game.DirectoryName 'project_path.txt') -Value $Project -Encoding ASCII

Write-Host 'Starting Behind the Screen...'
Start-Process -FilePath $game.FullName -WorkingDirectory $game.DirectoryName
Close-Run
