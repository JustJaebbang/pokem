#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$PythonCommand = "python",
    [switch]$SkipFlutter
)
$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot

function Invoke-Checked {
    param([string]$Program, [string[]]$CommandArgs)
    & $Program @CommandArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed (exit $LASTEXITCODE): $Program"
    }
}

Push-Location -LiteralPath $projectRoot
try {
    if (-not (Get-Command $PythonCommand -ErrorAction SilentlyContinue)) {
        throw "Install Python 3.14 and add it to PATH, or use -PythonCommand with its full path."
    }
    if (-not $SkipFlutter -and -not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw "Install Flutter 3.47.2 and add flutter/bin to PATH. For backend only, use -SkipFlutter."
    }
    Invoke-Checked -Program $PythonCommand -CommandArgs @("-c", "import sys; assert sys.version_info[:2] == (3,14), 'Python 3.14 is required (verified: 3.14.6)'")
    $venvPython = Join-Path $projectRoot ".venv/Scripts/python.exe"
    if (-not (Test-Path -LiteralPath $venvPython)) {
        Invoke-Checked -Program $PythonCommand -CommandArgs @("-m", "venv", ".venv")
    }
    Invoke-Checked -Program $venvPython -CommandArgs @("-c", "import sys; assert sys.version_info[:2] == (3,14), 'Existing .venv uses a different Python version; recreate it with Python 3.14'")
    Invoke-Checked -Program $venvPython -CommandArgs @("-m", "pip", "install", "--disable-pip-version-check", "-r", "requirements.txt")
    Invoke-Checked -Program $venvPython -CommandArgs @("-m", "pip", "check")
    if (-not (Test-Path -LiteralPath ".env")) {
        # Create only when missing. Never overwrite an existing developer's settings.
        Invoke-Checked -Program $venvPython -CommandArgs @("-c", "from pathlib import Path; import secrets; p=Path('.env'); content=Path('.env.example').read_text(encoding='utf-8'); content=content.replace('JWT_SECRET_KEY=', 'JWT_SECRET_KEY='+secrets.token_hex(32), 1); p.open('x', encoding='utf-8').write(content)")
        Write-Host "Created local .env with a random JWT key. Fill in your MySQL settings."
    } else {
        Write-Host "Existing .env preserved."
    }
    Invoke-Checked -Program $venvPython -CommandArgs @("-c", "from main import app; from zoneinfo import ZoneInfo; ZoneInfo('Asia/Seoul'); print('FastAPI imports and timezone: OK')")
    if (-not $SkipFlutter) {
        $flutterInfo = & flutter --version --machine
        if ($LASTEXITCODE -ne 0) { throw "Cannot read Flutter SDK version." }
        $flutterVersion = ($flutterInfo | ConvertFrom-Json).frameworkVersion
        if ($flutterVersion -ne "3.47.2") {
            Write-Warning "Verified Flutter version is 3.47.2; installed: $flutterVersion. See flutter_app/.fvmrc."
        }
        Push-Location -LiteralPath (Join-Path $projectRoot "flutter_app")
        try {
            Invoke-Checked -Program "flutter" -CommandArgs @("pub", "get", "--enforce-lockfile")
        } finally {
            Pop-Location
        }
    }
    Write-Host "Dependencies installed. See docs/setup.md for database and run instructions."
} finally {
    Pop-Location
}
