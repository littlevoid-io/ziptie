@echo off
cd /D "%~dp0"
if exist "slab.exe" (
    "slab.exe" %*
) else if exist "dist\slab.exe" (
    "dist\slab.exe" %*
) else (
    node dist/index.js %*
)
