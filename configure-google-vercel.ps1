$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:APPDATA = Join-Path $root '.tools\appdata'
$env:LOCALAPPDATA = Join-Path $root '.tools\appdata'
$env:npm_config_cache = Join-Path $root '.tools\npm-cache'

Write-Host 'Linking backend Vercel project (choose/create the backend project when prompted)...' -ForegroundColor Cyan
npx.cmd --yes vercel@50.14.0 link --cwd (Join-Path $root 'backend')

$oauthFile = Join-Path $root '.google-oauth.local'
$oauth = @{}
if (Test-Path -LiteralPath $oauthFile) {
  foreach ($line in Get-Content -LiteralPath $oauthFile) {
    if ($line -match '^([A-Z0-9_]+)=(.*)$') { $oauth[$Matches[1]] = $Matches[2] }
  }
}
$clientId = if ($oauth['GOOGLE_CLIENT_ID']) { $oauth['GOOGLE_CLIENT_ID'] } else { '349745349873-7hgica51fjerubocs9p5g14heutci66h.apps.googleusercontent.com' }
$secretPlain = $oauth['GOOGLE_CLIENT_SECRET']
if ([string]::IsNullOrWhiteSpace($secretPlain)) {
  $secret = Read-Host 'Paste a NEW rotated Google client secret (input is hidden)' -AsSecureString
  $secretPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret))
}
try {
  $vars = @{
    GOOGLE_CLIENT_ID = $clientId
    GOOGLE_CLIENT_SECRET = $secretPlain
    GOOGLE_REDIRECT_URI = if ($oauth['GOOGLE_REDIRECT_URI']) { $oauth['GOOGLE_REDIRECT_URI'] } else { 'https://lab3-godot-cardano-bridge.vercel.app/api/auth/callback/google' }
    GOOGLE_FRONTEND_URL = if ($oauth['GOOGLE_FRONTEND_URL']) { $oauth['GOOGLE_FRONTEND_URL'] } else { 'https://vercel-game-alpha.vercel.app' }
  }
  foreach ($name in $vars.Keys) {
    Write-Host "Setting $name..." -ForegroundColor DarkCyan
    $tmp = Join-Path $root ('.tools\' + $name + '.value')
    [System.IO.File]::WriteAllText($tmp, [string]$vars[$name], [System.Text.UTF8Encoding]::new($false))
    try {
      cmd.exe /d /c "type `"$tmp`" | npx.cmd --yes vercel@50.14.0 env add $name production --cwd `"$(Join-Path $root 'backend')`" --force --yes"
      if ($LASTEXITCODE -ne 0) { throw "Failed to set $name" }
    } finally {
      Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
  }
} finally {
  $secretPlain = $null
}

Push-Location (Join-Path $root 'backend')
try {
  npx.cmd --yes vercel@50.14.0 deploy --prod --yes
  if ($LASTEXITCODE -ne 0) { throw 'Backend deploy failed' }
} finally {
  Pop-Location
}
Write-Host 'Google OAuth backend deployed.' -ForegroundColor Green
