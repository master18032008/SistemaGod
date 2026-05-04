# =====================================================================
# GAME OVER GOD - GESTÃO DE ELITE V4.0
# STATUS: RESET TOTAL EM CADA EXECUÇÃO
# =====================================================================

# ===== CONFIGURAÇÃO DE AMBIENTE E CODIFICAÇÃO =====
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "GameOverGod - Gestão de Elite v4.0"
Clear-Host

if ($host.Name -eq 'ConsoleHost') {
    $mode = Get-ItemProperty -Path "HKCU:\Console" -Name "VirtualTerminalLevel" -ErrorAction SilentlyContinue
    if (-not $mode) {
        New-ItemProperty -Path "HKCU:\Console" -Name "VirtualTerminalLevel" -PropertyType DWord -Value 1 -Force | Out-Null
    }
}

# ===== ACESSO =====
$senhaCorreta = "12345"
Write-Host "----------------------------------------" -ForegroundColor Magenta
$inputSenha = Read-Host " DIGITE A SENHA DE ACESSO "
if ($inputSenha -ne $senhaCorreta) { Write-Host "Acesso negado."; exit }

# ===== DETECÇÃO STEAM =====
$steamReg = Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
$steamExe = $steamReg.SteamExe
if (-not $steamExe) { Write-Host "Steam não localizada."; exit }
$steamDir = [System.IO.Path]::GetDirectoryName($steamExe)
$configDir = Join-Path $steamDir "config"

function Show-Header {
    Clear-Host
    Write-Host "    ____                         ___                 ____           _ " -ForegroundColor Magenta
    Write-Host "   / ___| __ _ _ __ ___   ___   / _ \__   _____ _ __/ ___| ___   __| |" -ForegroundColor Cyan
    Write-Host "  | |  _ / _` | '_ ` _ \ / _ \ | | | \ \ / / _ \ '__| |  _ / _ \ / _` |" -ForegroundColor Magenta
    Write-Host "  | |_| | (_| | | | | | |  __/ | |_| |\ V /  __/ |  | |_| | (_) | (_| |" -ForegroundColor Cyan
    Write-Host "   \____|\__,_|_| |_| |_|\___|  \___/  \_/ \___|_|   \____|\___/ \__,_|" -ForegroundColor Magenta
    Write-Host " ------------------- MODO: SEMPRE PRIMEIRA INSTALAÇÃO ------------------- " -ForegroundColor White
}

function Executar-Instalacao {
    param ($Modo)
    Show-Header
    
    # 1. LIMPEZA PRÉVIA (Força o estado de "Primeira Vez")
    Write-Host "Limpando vestígios de instalações anteriores..." -ForegroundColor Yellow
    $rarFile = "$env:TEMP\GameOverGod_$(Get-Random).rar" # Nome aleatório para evitar cache de arquivo antigo
    $tmp = "$env:TEMP\gameover_clean_tmp"
    
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $tmp | Out-Null

    # 2. FECHAR STEAM
    Write-Host "Fechando processos da Steam..." -ForegroundColor Yellow
    Get-Process steam, steamwebhelper -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2

    # 3. DOWNLOAD (Sempre baixa uma cópia nova)
    Write-Host "Baixando pacote atualizado do servidor..." -ForegroundColor Cyan
    $urlDoRar = "https://cdn.discordapp.com/attachments/1500928090619121826/1500940141643173968/GameOverGod.rar?ex=69fa42ef&is=69f8f16f&hm=9467ea98343ec2c9e19cc24941085ef0485d9b857a0788de97ac1b996a0e0e8f&" 
    try {
        Invoke-WebRequest -Uri $urlDoRar -OutFile $rarFile -ErrorAction Stop
    } catch {
        Write-Host "ERRO de conexão ou link expirado." -ForegroundColor Red
        Pause; return
    }

    # 4. EXTRAÇÃO
    Write-Host "Extraindo arquivos..." -ForegroundColor Cyan
    try {
        if (Test-Path "C:\Program Files\WinRAR\WinRAR.exe") {
            & "C:\Program Files\WinRAR\WinRAR.exe" x -ibck -y $rarFile $tmp
        } elseif (Test-Path "C:\Program Files\7-Zip\7z.exe") {
            & "C:\Program Files\7-Zip\7z.exe" x $rarFile "-o$tmp" -y
        } else {
            Expand-Archive -Path $rarFile -DestinationPath $tmp -Force -ErrorAction SilentlyContinue
        }

        # 5. SINCRONIZAÇÃO DE DLLS E ARQUIVOS (SOBRESCREVER TUDO)
        Write-Host "Aplicando DLLs e configurações..." -ForegroundColor Cyan
        
        # Limpa pastas específicas da Steam antes de copiar
        $pastasLimpar = @("$configDir\depotcache", "$configDir\stplug-in")
        foreach ($folder in $pastasLimpar) {
            if (Test-Path $folder) { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }
        }

        # Copia novos arquivos
        $extraidoConfig = Get-ChildItem -Path $tmp -Filter "Config" -Recurse | Select-Object -First 1
        if ($extraidoConfig) { Copy-Item -Path "$($extraidoConfig.FullName)\*" -Destination "$configDir\" -Recurse -Force }
        
        $extraidoHid = Get-ChildItem -Path $tmp -Filter "Hid.dll" -Recurse | Select-Object -First 1
        if ($extraidoHid) { Copy-Item -Path $extraidoHid.FullName -Destination "$steamDir\" -Force }

        # Limpeza de Cache (Se selecionado Modo Full)
        if ($Modo -eq "Full") {
            foreach ($f in @("cache", "temp", "tmp")) {
                $p = Join-Path $steamDir $f
                if (Test-Path $p) { Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }

        # Limpeza Final do instalador
        Remove-Item $rarFile -Force -ErrorAction SilentlyContinue
        Write-Host "`nGameOverGod INSTALADO COM SUCESSO (ESTADO LIMPO)!" -ForegroundColor Green

    } catch {
        Write-Host "Falha Crítica na Extração." -ForegroundColor Red
    }
}

# ===== MENU =====
Show-Header
Write-Host " 1. Instalação / Atualização (Reset Total)"
Write-Host " 2. Instalação Completa (Full Clean + Cache)"
Write-Host " 3. Desinstalar e Sair"
$opt = Read-Host "`nEscolha uma opção"

switch ($opt) {
    "1" { Executar-Instalacao "Normal" }
    "2" { Executar-Instalacao "Full" }
    "3" { 
        Get-Process steam, steamwebhelper -ErrorAction SilentlyContinue | Stop-Process -Force
        foreach ($f in @("Hid.dll", "xinput1_4.dll", "dwmapi.dll")) {
            $p = Join-Path $steamDir $f
            if (Test-Path $p) { Remove-Item $p -Force }
        }
    }
}

Write-Host "`nReiniciando Steam..." -ForegroundColor Cyan
Start-Process $steamExe
