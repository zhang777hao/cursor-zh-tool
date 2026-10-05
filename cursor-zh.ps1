# cursor-zh permanent installer (Windows PowerShell 5.1+)
# 把翻译引擎 + 词典永久嵌入 Cursor 的 workbench.html，无需每次开启注入窗口。
param(
  [ValidateSet('install', 'restore', 'status')][string]$Action = 'install',
  [string]$CursorPath = '',
  [switch]$NoPause
)
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Marker = '<!-- cursor-zh -->'
$Tag = "`r`n`t<script src=`"./zh-inject.js`"></script>$Marker"
$Utf8 = New-Object System.Text.UTF8Encoding($false)

function Pause-End { if (-not $NoPause) { Read-Host '按回车键退出' | Out-Null } }

function Find-Cursor {
  $cands = @()
  if ($CursorPath) { $cands += $CursorPath }
  $p = Get-Process -Name Cursor -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
  if ($p) { $cands += (Split-Path -Parent $p.Path) }
  $cands += "$env:LOCALAPPDATA\Programs\cursor"
  $cands += "$env:ProgramFiles\cursor"
  if (${env:ProgramFiles(x86)}) { $cands += "${env:ProgramFiles(x86)}\cursor" }
  foreach ($c in $cands) {
    if ($c -and (Test-Path (Join-Path $c 'resources\app\product.json'))) { return (Resolve-Path $c).Path }
  }
  return $null
}

function Get-Hash([string]$file) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $b = $sha.ComputeHash([System.IO.File]::ReadAllBytes($file))
  return ([Convert]::ToBase64String($b)).TrimEnd('=')
}

function Can-Write([string]$file) {
  try { $fs = [System.IO.File]::Open($file, 'Open', 'ReadWrite', 'ReadWrite'); $fs.Close(); return $true } catch { return $false }
}

function Set-Checksum([string]$productPath, [string]$hash) {
  $text = [System.IO.File]::ReadAllText($productPath)
  $re = [regex]'("vs/code/electron-sandbox/workbench/workbench\.html"\s*:\s*")[^"]+(")'
  if (-not $re.IsMatch($text)) { throw 'product.json 中找不到 workbench.html 校验和，此版本 Cursor 可能不兼容。' }
  $new = $re.Replace($text, { param($m) $m.Groups[1].Value + $hash + $m.Groups[2].Value }, 1)
  [System.IO.File]::WriteAllText($productPath, $new, $Utf8)
}

try {
  $root = Find-Cursor
  if (-not $root) { throw '找不到 Cursor 安装目录。请用 -CursorPath "D:\路径\cursor" 指定（该目录下应有 Cursor.exe 和 resources 文件夹）。' }
  $app = Join-Path $root 'resources\app'
  $wbDir = Join-Path $app 'out\vs\code\electron-sandbox\workbench'
  $htmlPath = Join-Path $wbDir 'workbench.html'
  $injPath = Join-Path $wbDir 'zh-inject.js'
  $productPath = Join-Path $app 'product.json'
  $bakDir = Join-Path $app 'zh-backup'
  $bakHtml = Join-Path $bakDir 'workbench.html'
  if (-not (Test-Path $htmlPath)) { throw "找不到 $htmlPath" }

  $ver = ''
  try { $ver = (Get-Content $productPath -Raw | ConvertFrom-Json).version } catch {}
  Write-Host "Cursor 目录: $root  (版本 $ver)"

  if ($Action -eq 'status') {
    $html = [System.IO.File]::ReadAllText($htmlPath)
    $injected = $html.Contains($Marker) -and (Test-Path $injPath)
    $okSum = (Get-Content $productPath -Raw) -match [regex]::Escape((Get-Hash $htmlPath))
    Write-Host ("汉化状态: " + $(if ($injected) { '已安装' } else { '未安装（可能被 Cursor 更新覆盖）' }))
    Write-Host ("校验和一致: " + $okSum)
    Write-Host ("备份存在: " + (Test-Path $bakHtml))
    Pause-End; exit 0
  }

  # 需要写权限，否则以管理员重新启动自己
  if (-not (Can-Write $productPath)) {
    Write-Host '需要管理员权限，正在请求提升...'
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -Action $Action -CursorPath `"$root`""
    Start-Process powershell -Verb RunAs -ArgumentList $argList
    exit 0
  }

  if ($Action -eq 'restore') {
    $html = [System.IO.File]::ReadAllText($htmlPath)
    if ($html.Contains($Marker)) {
      if (Test-Path $bakHtml) { Copy-Item $bakHtml $htmlPath -Force }
      else { [System.IO.File]::WriteAllText($htmlPath, ([regex]::Replace($html, '\r?\n\t<script src="\./zh-inject\.js"></script><!-- cursor-zh -->', '')), $Utf8) }
    }
    if (Test-Path $injPath) { Remove-Item $injPath -Force }
    Set-Checksum $productPath (Get-Hash $htmlPath)
    Write-Host '已还原为英文原版。重启 Cursor 生效。'
    Pause-End; exit 0
  }

  # ---- install ----
  $translator = Join-Path $Here 'assets\translator.js'
  $dictFile = Join-Path $Here 'assets\zh-CN.json'
  if (-not (Test-Path $translator) -or -not (Test-Path $dictFile)) { throw 'assets 文件夹缺少 translator.js 或 zh-CN.json。' }
  $dictText = [System.IO.File]::ReadAllText($dictFile)
  # 注意：不用 ConvertFrom-Json 校验——PowerShell 5.1 不允许仅大小写不同的键，而词典里有很多。
  $t = $dictText.Trim()
  if (-not ($t.StartsWith('{') -and $t.EndsWith('}'))) { throw '词典 zh-CN.json 格式不正确。' }

  $html = [System.IO.File]::ReadAllText($htmlPath)
  New-Item -ItemType Directory -Force $bakDir | Out-Null
  if ($html.Contains($Marker)) {
    if (-not (Test-Path $bakHtml)) { throw '已安装过但缺少备份，无法安全重装。请先重装/修复 Cursor 后再运行。' }
    $orig = [System.IO.File]::ReadAllText($bakHtml)
  } else {
    # 干净文件（首次安装，或 Cursor 更新后）：刷新备份
    Copy-Item $htmlPath $bakHtml -Force
    $orig = $html
  }

  $boot = "`n;(function(){var d=" + $dictText + ";`nfunction go(){try{window.__cursorZh&&window.__cursorZh.setDictionary(d);}catch(e){console.warn('[cursor-zh]',e);}}`nif(document.readyState==='loading')document.addEventListener('DOMContentLoaded',go);else go();})();`n"
  [System.IO.File]::WriteAllText($injPath, ([System.IO.File]::ReadAllText($translator) + $boot), $Utf8)

  $newHtml = $orig -replace '</body>', ('</body>' + $Tag)
  [System.IO.File]::WriteAllText($htmlPath, $newHtml, $Utf8)
  Set-Checksum $productPath (Get-Hash $htmlPath)
  Write-Host '安装完成。请完全退出并重新打开 Cursor。'
  Write-Host '提示: Cursor 更新后汉化会失效，重新运行本工具即可。'
  Pause-End
}
catch {
  Write-Host ("出错: " + $_.Exception.Message) -ForegroundColor Red
  Pause-End; exit 1
}
