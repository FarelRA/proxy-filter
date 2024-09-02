param(
    [Parameter(Mandatory=$false)]
    [string]$Action
)

function Get-CurrentIP {
    $ip = & C:\Windows\System32\curl.exe --ipv4 ip.me
    return $ip.Trim()
}

function Start-WireGuard {
    Write-Host "Starting WireGuard Warp..."
    gsudo wireguard /installtunnelservice .\wgcf-profile.conf
}

function Stop-WireGuard {
    Write-Host "Stopping WireGuard Warp..."
    gsudo wireguard /uninstalltunnelservice wgcf-profile
}

function Check-IPDifference {
    param(
        [Parameter(Mandatory=$true)]
        [string]$previousIP
    )

    while ($true) {
        Start-Sleep -Seconds 1  # Wait for 1 seconds
        $currentIP = Get-CurrentIP
        Write-Host "Current IP: $currentIP"

        if ($currentIP -ne $previousIP) {
            Write-Host "IP address has changed!"
            return
        }

        Write-Host "IP address hasn't changed. Checking again..."
    }
}

function Start-Warp {
    $initialIP = Get-CurrentIP
    Write-Host "Initial IP: $initialIP"

    Start-WireGuard
    Check-IPDifference -previousIP $initialIP
    exit
}

function Stop-Warp {
    $initialIP = Get-CurrentIP
    Write-Host "Initial IP: $initialIP"

    Stop-WireGuard
    Check-IPDifference -previousIP $initialIP
    exit
}

switch ($Action) {
    "start" { Start-Warp }
    "stop" { Stop-Warp }
    default { Write-Host "Usage: manage-warp.ps1 -Action [start|stop]" }
}
