@echo off
cd /D "%~dp0"
if exist "dist\slab.exe" (
    "dist\slab.exe" %*
) else (
    node dist/index.js %*
)
