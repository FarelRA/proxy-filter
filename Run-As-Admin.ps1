param (
    [string]$command
)

# Define the function to run commands as an administrator
function Invoke-AsAdmin {
    param (
        [string]$command
    )
    
    $scriptBlock = {
        param ($cmd)
        Start-Process powershell -ArgumentList @("-NoProfile", "-ExecutionPolicy Bypass", "-Command", $cmd) -Verb RunAs -Wait
    }

    # Check if running in PowerShell Core (pwsh)
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        Start-Process pwsh -ArgumentList @("-NoProfile", "-ExecutionPolicy Bypass", "-Command", $command) -Verb RunAs -Wait
    } else {
        # Use PowerShell if in Windows PowerShell
        & $scriptBlock -cmd $command
    }
}

# Call the function with the provided command
Invoke-AsAdmin -command $command
