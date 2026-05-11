$ErrorActionPreference = "Stop"

$envFile = Join-Path $PSScriptRoot "env\dev.json"
$config = Get-Content $envFile -Raw | ConvertFrom-Json
$webPort = if ($config.FLUTTER_WEB_PORT) { [string]$config.FLUTTER_WEB_PORT } else { "5005" }

flutter run -d chrome --web-port $webPort --dart-define-from-file $envFile
