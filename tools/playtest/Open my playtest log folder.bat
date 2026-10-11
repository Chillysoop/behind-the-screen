@echo off
rem Opens the folder where Behind the Screen keeps the playtest log.
if exist "%APPDATA%\behind_the_screen\playtest_log.jsonl" (
    explorer /select,"%APPDATA%\behind_the_screen\playtest_log.jsonl"
) else if exist "%APPDATA%\behind_the_screen" (
    explorer "%APPDATA%\behind_the_screen"
) else (
    echo There's no playtest log yet. Play at least one session first.
    pause
)
