@echo off
setlocal
set ownpath=%~dp0%
texlua "%ownpath%mtxrun.lua" --usekpse --execute runtools.rb %*
endlocal
