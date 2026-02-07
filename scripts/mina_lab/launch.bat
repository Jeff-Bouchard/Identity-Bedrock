@echo off
REM Nano-Mina Chain Launcher for Windows

REM Start node
start "Nano-Mina Node" python nanomina.py node --words "%1" --supply %2

REM Wait for node to initialize
timeout /t 2 >nul

REM Open browser
start "" "http://localhost:61234/unified.html"

REM Show node output
type "chain_data\node.log"
