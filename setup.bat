@echo off
cd /D "%~dp0"
set configPath=%~1
if "%configPath%"=="" set configPath=.tmp\slab-temp-config.json
call PowerShell.exe -ExecutionPolicy ByPass -Command "& './slab.ps1' -ConfigPath '%configPath%'"
