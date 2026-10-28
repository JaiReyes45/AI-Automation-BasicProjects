<#
CareerFlow Windows alerts. Requires the local services and this computer to stay awake.
Pair from the authenticated CareerFlow notification settings; never enter a workspace password here.
  .\scripts\desktop_notifications.ps1 -PairCode 'CODE-FROM-THE-APP' -Install
-Install saves a per-user startup shortcut and launches the paired helper hidden.
-Check validates local Windows support without connecting, pairing, writing files or showing alerts.
Desktop delivery uses the native Windows notification-area balloon API. Windows acceptance is not proof
the user saw it: Focus Assist and notification settings can hide a balloon. A lost acknowledgement
becomes "uncertain" in CareerFlow and requires a deliberate retry.
#>
[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:8087',
    [string]$PairCode,
    [switch]$Install,
    [switch]$Check
)
$ErrorActionPreference = 'Stop'

function Assert-LocalOrigin([string]$Value) {
    $parsed = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$parsed) -or
        $parsed.Scheme -notin @('http', 'https') -or
        $parsed.Host -notin @('localhost', '127.0.0.1', '[::1]', '::1') -or
        $parsed.UserInfo -or $parsed.AbsolutePath -ne '/' -or $parsed.Query -or $parsed.Fragment) {
        throw 'CareerFlow alerts require a localhost origin without a path or embedded credentials.'
    }
    return $parsed.GetLeftPart([UriPartial]::Authority)
}

$BaseUrl = Assert-LocalOrigin $BaseUrl
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if ($Check) {
    Write-Output 'Ready: native Windows alerts and localhost validation are available. No connection or alert was attempted.'
    exit 0
}

$configDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'CareerFlow'
$configPath = Join-Path $configDirectory 'desktop-notifications.json'
$settings = $null
if (Test-Path -LiteralPath $configPath) {
    $settings = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if (-not $PSBoundParameters.ContainsKey('BaseUrl')) {
        $BaseUrl = Assert-LocalOrigin $settings.base_url
    }
}

function Invoke-LocalApi([string]$Path, [hashtable]$Payload, [string]$ScopedToken = '') {
    if ($Path -notin @('/api/notifications/pair', '/api/notifications/claim', '/api/notifications/result')) {
        throw 'Unsupported desktop helper endpoint.'
    }
    $requestHeaders = @{'X-CareerFlow' = 'desktop-notifications'}
    if ($ScopedToken) { $requestHeaders.Authorization = 'Bearer ' + $ScopedToken }
    # Do not follow redirects carrying the scoped token. Never print requests or provider errors.
    return Invoke-RestMethod -Uri ($BaseUrl + $Path) -Method Post -Headers $requestHeaders `
        -ContentType 'application/json' -Body ($Payload | ConvertTo-Json -Compress) `
        -TimeoutSec 10 -MaximumRedirection 0
}

if (-not $PairCode -and -not $settings) {
    $PairCode = Read-Host 'Enter the temporary pairing code from CareerFlow notification settings'
}
if ($PairCode) {
    try {
        $pair = Invoke-LocalApi '/api/notifications/pair' @{code=$PairCode; device_name='Windows desktop'}
    } catch {
        throw 'Pairing failed. Check that CareerFlow is running and create a fresh code in notification settings.'
    }
    $secret = ConvertTo-SecureString ([string]$pair.token) -AsPlainText -Force
    $settings = @{base_url=$BaseUrl; device_id=$pair.device_id; expires_at=$pair.expires_at;
                  encrypted_token=($secret | ConvertFrom-SecureString)}
    New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
    # DPAPI encryption is bound to this Windows user; the directory ACL prevents other users reading it.
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $configDirectory -AclObject $acl
    $settings | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8
    $PairCode = $null
    $pair = $null
}
if (-not $settings -or $settings.base_url -ne $BaseUrl) {
    throw 'Pair this localhost origin before starting the helper.'
}

if ($Install) {
    $installedScript = Join-Path $configDirectory 'desktop_notifications.ps1'
    if ([IO.Path]::GetFullPath($PSCommandPath) -ne [IO.Path]::GetFullPath($installedScript)) {
        Copy-Item -LiteralPath $PSCommandPath -Destination $installedScript -Force
    }
    $startupFolder = [Environment]::GetFolderPath('Startup')
    $shortcutPath = Join-Path $startupFolder 'CareerFlow desktop alerts.lnk'
    $shellLink = New-Object -ComObject WScript.Shell
    $shortcut = $shellLink.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $PSHOME 'powershell.exe'
    $shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $installedScript + '"'
    $shortcut.WorkingDirectory = $configDirectory
    $shortcut.WindowStyle = 7
    $shortcut.Description = 'CareerFlow local desktop alerts'
    $shortcut.Save()
    Start-Process -FilePath $shortcut.TargetPath -ArgumentList $shortcut.Arguments -WindowStyle Hidden | Out-Null
    Write-Output 'CareerFlow alerts paired and started. The helper will start when you sign in to Windows.'
    exit 0
}

$secureToken = ConvertTo-SecureString $settings.encrypted_token
$credential = New-Object System.Management.Automation.PSCredential('desktop', $secureToken)
$token = $credential.GetNetworkCredential().Password
$credential = $null
$settings = $null

# One helper per Windows user prevents competing tray icons on repeated startup.
$mutexCreated = $false
$mutexName = 'Local\CareerFlowDesktopAlerts-' + [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$mutexCreated)
if (-not $mutexCreated) { $mutex.Dispose(); exit 0 }

$script:keepRunning = $true
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = [System.Drawing.SystemIcons]::Information
$tray.Text = 'CareerFlow desktop alerts'
$tray.Visible = $true
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$openItem = $menu.Items.Add('Open CareerFlow')
$openItem.add_Click({ Start-Process $BaseUrl })
$exitItem = $menu.Items.Add('Exit desktop alerts')
$exitItem.add_Click({ $script:keepRunning = $false })
$tray.ContextMenuStrip = $menu
$tray.add_BalloonTipClicked({ Start-Process $BaseUrl })
$tray.add_DoubleClick({ Start-Process $BaseUrl })

try {
    $nextPoll = [DateTime]::UtcNow
    while ($script:keepRunning) {
        [System.Windows.Forms.Application]::DoEvents()
        if ([DateTime]::UtcNow -ge $nextPoll) {
            $nextPoll = [DateTime]::UtcNow.AddSeconds(20)
            try {
                $claim = Invoke-LocalApi '/api/notifications/claim' @{} $token
                $tray.Text = 'CareerFlow alerts connected'
                foreach ($job in $claim.jobs) {
                    $shown = $false
                    try {
                        $tray.BalloonTipTitle = ([string]$job.title).Substring(0, [Math]::Min(63, ([string]$job.title).Length))
                        $tray.BalloonTipText = ([string]$job.body).Substring(0, [Math]::Min(240, ([string]$job.body).Length))
                        $tray.ShowBalloonTip(8000)
                        $shown = $true
                        [System.Windows.Forms.Application]::DoEvents()
                        Invoke-LocalApi '/api/notifications/result' @{id=$job.id; lease=$job.lease; outcome='delivered'} $token | Out-Null
                    } catch {
                        $outcome = if ($shown) { 'uncertain' } else { 'failed' }
                        try { Invoke-LocalApi '/api/notifications/result' @{id=$job.id; lease=$job.lease; outcome=$outcome} $token | Out-Null } catch { }
                        $tray.Text = 'CareerFlow alert needs attention'
                    }
                }
            } catch {
                $tray.Text = 'CareerFlow alerts disconnected'
                # Service restarts and laptop sleep are normal. Reconnect without logging credentials.
                $nextPoll = [DateTime]::UtcNow.AddSeconds(30)
            }
        }
        Start-Sleep -Milliseconds 200
    }
} finally {
    $token = $null
    $tray.Visible = $false
    $tray.Dispose()
    $menu.Dispose()
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
