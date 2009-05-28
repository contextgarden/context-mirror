@echo off
setlocal
set ownpath=%~dp0%
texlua "%ownpath%mtxrun.lua" --usekpse --execute texexec.rb %*
endlocal
