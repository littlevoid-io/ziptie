@echo off
cd /D "%~dp0"
if exist "ziptie.exe" (
    "ziptie.exe" %*
) else if exist "dist\ziptie.exe" (
    "dist\ziptie.exe" %*
) else (
    node dist/index.js %*
)
