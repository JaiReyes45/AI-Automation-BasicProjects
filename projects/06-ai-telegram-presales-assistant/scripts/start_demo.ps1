param(
    [Parameter(Mandatory=$true)][string]$LinuxProjectPath,
    [string]$Distribution='Ubuntu'
)
$ErrorActionPreference='Stop'
$tunnelExe=(Get-Command cloudflared -ErrorAction Stop).Source
$privateLogDir=Join-Path ([System.IO.Path]::GetTempPath()) ('chatterbox-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $privateLogDir | Out-Null
Write-Host 'Keep this supervisor running during your demo. Ctrl+C ends its tunnel.'
while ($true) {
    $stderr=Join-Path $privateLogDir 'tunnel.stderr.log'
    $stdout=Join-Path $privateLogDir 'tunnel.stdout.log'
    $tunnel=Start-Process -FilePath $tunnelExe -ArgumentList @('tunnel','--url','http://localhost:5686','--no-autoupdate') -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    try {
        $ready=$false
        for($attempt=0;$attempt -lt 60;$attempt++) {
            if($tunnel.HasExited){break}
            if((Test-Path -LiteralPath $stderr) -and (Select-String -LiteralPath $stderr -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -Quiet)){$ready=$true;break}
            Start-Sleep -Seconds 1
        }
        if(-not $ready){throw 'Cloudflare did not create a tunnel. Inspect the private log locally.'}
        $linuxLog=(& wsl.exe -d $Distribution -- wslpath -u $stderr).Trim()
        & wsl.exe -d $Distribution --cd $LinuxProjectPath -- python3 scripts/refresh_tunnel.py --log $linuxLog
        if($LASTEXITCODE -ne 0){throw 'Webhook refresh failed; private logs retained.'}
        Write-Host 'Tunnel and webhook address refreshed. Monitoring tunnel process.'
        while(-not $tunnel.HasExited){Start-Sleep -Seconds 5}
        Write-Host 'Tunnel ended; creating a replacement.'
    } finally {
        if(-not $tunnel.HasExited){Stop-Process -Id $tunnel.Id}
    }
}
