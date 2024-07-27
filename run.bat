@echo off
cd /d "%~dp0"
powershell -Command "love .; love . server"