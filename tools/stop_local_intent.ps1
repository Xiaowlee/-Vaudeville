$projectPath = Split-Path $PSScriptRoot -Parent
$pidFile = Join-Path $projectPath '.local-speech/intent-server.pid'
if (Test-Path -LiteralPath $pidFile) {
    $serverId = [int](Get-Content -LiteralPath $pidFile)
    $process = Get-Process -Id $serverId -ErrorAction SilentlyContinue
    $expectedPath = Join-Path $projectPath '.local-speech/ollama/ollama.exe'
    if ($process -and $process.Path -eq $expectedPath) { Stop-Process -Id $serverId }
}
