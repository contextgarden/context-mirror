@echo off
setlocal
set ownpath=%~dp0%
texlua "%ownpath%luatools.lua" %*
endlocal
