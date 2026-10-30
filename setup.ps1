param([switch]$IncludeTests)

$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $venvPython = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
    $uvCommand = Get-Command uv -ErrorAction SilentlyContinue
    if (-not (Test-Path -LiteralPath $venvPython)) {
        if ($uvCommand) {
            & $uvCommand.Source venv .venv
        } else {
            $pythonCommand = $null
            foreach ($candidate in @('py', 'python3.15', 'python')) {
                $pythonCommand = Get-Command $candidate -ErrorAction SilentlyContinue
                if ($pythonCommand) { break }
            }
            if (-not $pythonCommand) { throw 'Install Python 3.10+ or uv first.' }
            & $pythonCommand.Source -m venv .venv
        }
        if ($LASTEXITCODE -ne 0) { throw 'Virtual environment creation failed.' }
    }

    $requirementsFile = 'requirements.txt'
    if ($IncludeTests) { $requirementsFile = 'requirements-dev.txt' }
    if ($uvCommand) {
        & $uvCommand.Source pip install --python $venvPython -r $requirementsFile
    } else {
        & $venvPython -m pip install -r $requirementsFile
    }
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }

    Write-Host 'Dependencies installed in .venv.'
    Write-Host 'Start: .\.venv\Scripts\python.exe -m uvicorn main:app --reload'
} finally {
    Pop-Location
}
