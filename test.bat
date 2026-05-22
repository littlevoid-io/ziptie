@echo off
cd /D "%~dp0"
powershell -ExecutionPolicy Bypass -NoProfile -File "test\run-sandbox-tests.ps1"
