# Inventário read-only do ambiente de edição (Windows).
# Uso (PowerShell):  powershell -ExecutionPolicy Bypass -File .\tools\inventario-windows.ps1
# Gera inventario.md na pasta atual. Não instala, não apaga, não altera nada.

$out = @()
function H($t) { $script:out += ""; $script:out += "## $t" }
function L($t) { $script:out += "- $t" }
function Cmd($name) {
  $c = Get-Command $name -ErrorAction SilentlyContinue
  if ($c) { L "$name : OK  ($($c.Source))" } else { L "$name : FALTA" }
}

$out += "# Inventário do ambiente — $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$out += "Máquina: $env:COMPUTERNAME  Usuário: $env:USERNAME"

H "Drives"
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
  L "$($_.Name): livre $([math]::Round($_.Free/1GB,1)) GB / total $([math]::Round(($_.Used+$_.Free)/1GB,1)) GB"
}

H "Programas de linha de comando"
"node","npm","npx","python","py","pip","ffmpeg","ffprobe","git","claude","code","whisper","whisperx" | ForEach-Object { Cmd $_ }
try { L "node versão: $(node -v 2>$null)" } catch {}
try { L "python versão: $(python --version 2>&1)" } catch {}

H "Pacotes globais npm"
try { (npm ls -g --depth=0 2>$null) | ForEach-Object { L $_ } } catch { L "npm indisponível" }

H "Pacotes Python relevantes"
try {
  (pip list 2>$null) | Select-String -Pattern "whisper|torch|ctranslate|faster|remotion|ffmpeg|numpy" | ForEach-Object { L $_ }
} catch { L "pip indisponível" }

H "Adobe instalado"
Get-ChildItem "C:\Program Files\Adobe" -Directory -ErrorAction SilentlyContinue | ForEach-Object { L $_.Name }

H "Extensões CEP (painéis do Premiere/AE)"
"$env:APPDATA\Adobe\CEP\extensions","C:\Program Files (x86)\Common Files\Adobe\CEP\extensions","C:\Program Files\Common Files\Adobe\CEP\extensions" | ForEach-Object {
  if (Test-Path $_) { Get-ChildItem $_ -Directory | ForEach-Object { L "$($_.FullName)" } }
}

H "Configuração MCP do Claude Code"
$cj = "$env:USERPROFILE\.claude.json"
if (Test-Path $cj) {
  L "encontrado: $cj"
  try {
    $j = Get-Content $cj -Raw | ConvertFrom-Json
    if ($j.mcpServers) { $j.mcpServers.PSObject.Properties | ForEach-Object { L "servidor MCP global: $($_.Name) -> $($_.Value.command) $($_.Value.args -join ' ')" } }
  } catch { L "não consegui ler o JSON" }
} else { L "FALTA: $cj (nenhum MCP registrado no Claude Code)" }
$cd = "$env:APPDATA\Claude\claude_desktop_config.json"
if (Test-Path $cd) { L "Claude Desktop config: $cd" } else { L "Claude Desktop config: não encontrado" }

H "Pasta da ponte MCP do Premiere"
$bridge = "$env:LOCALAPPDATA\Temp\premiere-mcp-bridge"
if (Test-Path $bridge) { L "existe: $bridge ($((Get-ChildItem $bridge -Recurse -File).Count) arquivos)" } else { L "FALTA: $bridge" }

H "Projetos encontrados no D: (até 4 níveis)"
$roots = @("D:\")
$hits = @()
foreach ($r in $roots) {
  if (-not (Test-Path $r)) { L "D:\ não está acessível"; continue }
  Get-ChildItem $r -Recurse -Depth 4 -ErrorAction SilentlyContinue -Include `
    "package.json","requirements.txt","pyproject.toml","*.prproj","*.aep","remotion.config.*","*.mogrt","manifest.xml","CSXS","*.mcp.json",".mcp.json" |
    Where-Object { $_.FullName -notmatch "\\node_modules\\|\\\.venv\\|\\AppData\\" } |
    ForEach-Object { $hits += $_ }
}
$hits | Sort-Object FullName | ForEach-Object { L $_.FullName }
if ($hits.Count -eq 0) { L "nada encontrado" }

H "package.json que citam remotion/whisper/mcp/premiere"
$hits | Where-Object { $_.Name -eq "package.json" } | ForEach-Object {
  $txt = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
  if ($txt -match "remotion|whisper|mcp|premiere|after") {
    L "$($_.FullName)"
    ($txt | ConvertFrom-Json -ErrorAction SilentlyContinue).dependencies.PSObject.Properties | ForEach-Object { L "    $($_.Name) $($_.Value)" }
  }
}

$out -join "`r`n" | Set-Content -Encoding UTF8 .\inventario.md
Write-Host "Pronto: inventario.md gerado em $(Get-Location)"
