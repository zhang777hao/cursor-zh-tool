@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cursor-zh.ps1" -Action restore %*
