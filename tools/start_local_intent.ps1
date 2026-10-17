$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$runtimePath = Join-Path $projectPath '.local-speech/ollama/ollama.exe'
try {
    $existing = Invoke-RestMethod 'http://127.0.0.1:11435/api/version' -TimeoutSec 2
    if ($existing.version) { exit 0 }
} catch {}
if (-not (Test-Path -LiteralPath $runtimePath)) { throw 'Portable Ollama is missing.' }
$env:OLLAMA_HOST = '127.0.0.1:11435'
$env:OLLAMA_MODELS = Join-Path $projectPath '.local-speech/intent-models'
$env:OLLAMA_NO_CLOUD = '1'
$env:OLLAMA_KEEP_ALIVE = '10m'
$server = Start-Process -FilePath $runtimePath -ArgumentList 'serve' -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $projectPath '.local-speech/intent-server.log') -RedirectStandardError (Join-Path $projectPath '.local-speech/intent-server-error.log')
$server.Id | Set-Content (Join-Path $projectPath '.local-speech/intent-server.pid')
