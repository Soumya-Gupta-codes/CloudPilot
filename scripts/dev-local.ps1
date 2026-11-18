param (
    [int]$ApiPort = 8000,
    [int]$WorkloadPort = 8001,
    [string]$HostName = "127.0.0.1"
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot
$PythonCmd = "$ProjectDir\.venv\Scripts\python.exe"

if (-not (Test-Path $PythonCmd)) {
    Write-Error "Python virtual environment missing at $PythonCmd. Please create .venv first."
    exit 1
}

Write-Host "Starting CloudPilot locally..." -ForegroundColor Cyan
Write-Host "  Workload API:      http://${HostName}:${WorkloadPort}" -ForegroundColor Green
Write-Host "  Control Plane API: http://${HostName}:${ApiPort}" -ForegroundColor Green
Write-Host "  Frontend UI:       http://${HostName}:5173" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop all services." -ForegroundColor Yellow

$env:PYTHONPATH = "$ProjectDir;$ProjectDir\backend;$ProjectDir\workload"
$env:CLOUDPILOT_MODE = "simulation"
$env:CLOUDPILOT_DATABASE = "$ProjectDir\cloudpilot.db"
$env:CLOUDPILOT_WORKLOAD_URL = "http://${HostName}:${WorkloadPort}"
$env:CLOUDPILOT_PROMETHEUS_URL = "http://${HostName}:9090"
$env:CLOUDPILOT_ALLOWED_ORIGINS = "http://localhost:5173,http://${HostName}:5173,http://localhost:8080"
$env:VITE_API_PROXY = "http://${HostName}:${ApiPort}"

$WorkloadProc = Start-Process -FilePath $PythonCmd -ArgumentList "-m", "uvicorn", "workload.app.main:app", "--host", $HostName, "--port", "$WorkloadPort" -PassThru -NoNewWindow
$BackendProc  = Start-Process -FilePath $PythonCmd -ArgumentList "-m", "uvicorn", "backend.app.main:app", "--host", $HostName, "--port", "$ApiPort" -PassThru -NoNewWindow

Set-Location "$ProjectDir\frontend"
try {
    & npm run dev -- --host $HostName
}
finally {
    Write-Host "`nStopping background services..." -ForegroundColor Cyan
    if ($WorkloadProc -and -not $WorkloadProc.HasExited) { Stop-Process -Id $WorkloadProc.Id -Force -ErrorAction SilentlyContinue }
    if ($BackendProc -and -not $BackendProc.HasExited) { Stop-Process -Id $BackendProc.Id -Force -ErrorAction SilentlyContinue }
    Write-Host "CloudPilot stopped." -ForegroundColor Green
}
