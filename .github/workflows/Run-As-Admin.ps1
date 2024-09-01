param([string]$command)
$bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
$encodedCommand = [Convert]::ToBase64String($bytes)
$arguments = "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"
Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait
