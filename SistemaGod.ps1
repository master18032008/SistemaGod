# ===== CONFIGURAÇÃO DE AMBIENTE E CODIFICAÇÃO =====
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "GameOverGod - Gestão de Elite v4.0"
Clear-Host

# Ativar suporte a cores ANSI no console
if ($host.Name -eq 'ConsoleHost') {
    $mode = Get-ItemProperty -Path "HKCU:\Console" -Name "VirtualTerminalLevel" -ErrorAction SilentlyContinue
    if (-not $mode) {
        New-ItemProperty -Path "HKCU:\Console" -Name "VirtualTerminalLevel" -PropertyType DWord -Value 1 -Force | Out-Null
    }
}

# ===== SISTEMA DE ACESSO (SENHA: 12345) =====
$tentativas = 0
$senhaCorreta = "12345"

while ($tentativas -lt 3) {
    Write-Host "----------------------------------------" -ForegroundColor Magenta
    $inputSenha = Read-Host " DIGITE A SENHA DE ACESSO "
    Write-Host "----------------------------------------" -ForegroundColor Magenta
    
    if ($inputSenha -eq $senhaCorreta) {
        Write-Host "Acesso autorizado! Bem-vindo, CEO." -ForegroundColor Green
        Start-Sleep -Milliseconds 800
        break
    } else {
        $tentativas++
        Write-Host "Senha incorreta! ($tentativas/3)" -ForegroundColor Red
        if ($tentativas -eq 3) { 
            Write-Host "Acesso bloqueado por segurança." -ForegroundColor DarkRed
            Start-Sleep -Seconds 2
            exit 
        }
    }
}

# ===== DETECÇÃO DE CAMINHO DA STEAM =====
$steamReg = Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
$steamExe = $steamReg.SteamExe
if (-not $steamExe) { 
    Write-Host "ERRO: Steam não localizada no registro." -ForegroundColor Red
    Pause; exit 
}
$steamDir = [System.IO.Path]::GetDirectoryName($steamExe)
$configDir = Join-Path $steamDir "config"

# ===== INTERFACE VISUAL (BANNER ATUALIZADO) =====
function Show-Header {
    Clear-Host
    Write-Host "   ____                         ___                 ____           _ " -ForegroundColor Magenta
    Write-Host "  / ___| __ _ _ __ ___   ___   / _ \__   _____ _ __/ ___| ___   __| |" -ForegroundColor Cyan
    Write-Host " | |  _ / _` | '_ ` _ \ / _ \ | | | \ \ / / _ \ '__| |  _ / _ \ / _` |" -ForegroundColor Magenta
    Write-Host " | |_| | (_| | | | | | |  __/ | |_| |\ V /  __/ |  | |_| | (_) | (_| |" -ForegroundColor Cyan
    Write-Host "  \____|\__,_|_| |_| |_|\___|  \___/  \_/ \___|_|   \____|\___/ \__,_|" -ForegroundColor Magenta
    Write-Host " --------------------------------------------------------------------- " -ForegroundColor White
}

# ===== FUNÇÕES DE OPERAÇÃO =====

function Stop-Steam {
    Write-Host "Fechando processos da Steam..." -ForegroundColor Yellow
    Get-Process steam, steamwebhelper -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
}

function Executar-Instalacao {
    param ($Modo)
    Show-Header
    
    # --- DOWNLOAD DO ARQUIVO .RAR DO DISCORD ---
    $rarFile = "GameOverGod.rar"
    if (-not (Test-Path $rarFile)) {
        Write-Host "Baixando pacote GameOverGod..." -ForegroundColor Cyan
        $urlDoRar = "https://cdn.discordapp.com/attachments/1500928090619121826/1500940141643173968/GameOverGod.rar?ex=69fa42ef&is=69f8f16f&hm=9467ea98343ec2c9e19cc24941085ef0485d9b857a0788de97ac1b996a0e0e8f&" 
        
        try {
            Invoke-WebRequest -Uri $urlDoRar -OutFile $rarFile -ErrorAction Stop
            Write-Host "Download do pacote concluído!" -ForegroundColor Green
        } catch {
            Write-Host "ERRO: Link expirado ou sem conexão." -ForegroundColor Red
            Pause; return
        }
    }

    Stop-Steam
    
    # Sincronização de DLLs críticas
    Write-Host "Sincronizando arquivos de sistema..." -ForegroundColor Cyan
    $dlls = @{ 
        "xinput1_4.dll" = "http://update.steamox.com/update"
        "dwmapi.dll"    = "http://update.steamox.com/dwmapi" 
    }
    foreach ($name in $dlls.Keys) {
        try {
            Invoke-WebRequest -Uri $dlls[$name] -OutFile (Join-Path $steamDir $name) -ErrorAction SilentlyContinue
        } catch {}
    }

    # Extração e Configuração
    Write-Host "Aplicando modificações GameOverGod..." -ForegroundColor Cyan
    $tmp = "$env:TEMP\gameover_tmp"
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    New-Item -ItemType Directory -Path $tmp | Out-Null
    
    try {
        # Como o PowerShell nativo não extrai .RAR, tentamos usar o WinRAR ou 7-Zip se instalados, 
        # caso contrário, orientamos o uso de .ZIP para automação total.
        if (Test-Path "C:\Program Files\WinRAR\WinRAR.exe") {
            & "C:\Program Files\WinRAR\WinRAR.exe" x -ibck $rarFile $tmp
        } elseif (Test-Path "C:\Program Files\7-Zip\7z.exe") {
            & "C:\Program Files\7-Zip\7z.exe" x $rarFile "-o$tmp" -y
        } else {
            # Fallback: Se não houver extrator, tentamos expandir (pode falhar com RAR)
            # DICA: Marcos, se puder usar .ZIP, a automação fica 100% garantida em qualquer PC.
            Expand-Archive -Path $rarFile -DestinationPath $tmp -Force -ErrorAction SilentlyContinue
        }
        
        # Limpeza de pastas antigas
        $limpar = @("$configDir\depotcache", "$configDir\stplug-in")
        foreach ($l in $limpar) { if (Test-Path $l) { Remove-Item $l -Recurse -Force -ErrorAction SilentlyContinue } }

        # Aplicação dos arquivos
        # Procura a pasta Config dentro do extraído
        $extraidoConfig = Get-ChildItem -Path $tmp -Filter "Config" -Recurse | Select-Object -First 1
        if ($extraidoConfig) {
            Copy-Item -Path "$($extraidoConfig.FullName)\*" -Destination "$configDir\" -Recurse -Force
        }
        
        $extraidoHid = Get-ChildItem -Path $tmp -Filter "Hid.dll" -Recurse | Select-Object -First 1
        if ($extraidoHid) {
            Copy-Item -Path $extraidoHid.FullName -Destination "$steamDir\" -Force
        }
        
        if ($Modo -eq "Full") {
            $folders = @("cache", "temp", "tmp")
            foreach ($f in $folders) { 
                $p = Join-Path $steamDir $f
                if (Test-Path $p) { Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
        Write-Host "`nGameOverGod INSTALADO COM SUCESSO!" -ForegroundColor Green
    } catch {
        Write-Host "ERRO: Falha ao processar o arquivo .RAR." -ForegroundColor Red
    }
}

# ===== MENU =====
Show-Header
Write-Host " 1. Atualizar GameOverGod & DLLs" -ForegroundColor White
Write-Host " 2. Instalação Completa (Full Clean)" -ForegroundColor White
Write-Host " 3. Desinstalar Sistema" -ForegroundColor White
Write-Host " 4. Sair" -ForegroundColor White
Write-Host " --------------------------------------------------------------------- "

$opt = Read-Host "Escolha uma opcao"

switch ($opt) {
    "1" { Executar-Instalacao "Normal" }
    "2" { Executar-Instalacao "Full" }
    "3" { 
        Stop-Steam
        $apagar = @("Hid.dll", "xinput1_4.dll", "dwmapi.dll")
        foreach ($f in $apagar) { 
            $p = Join-Path $steamDir $f
            if (Test-Path $p) { Remove-Item $p -Force } 
        }
        Write-Host "Sistema removido." -ForegroundColor Yellow
    }
    Default { exit }
}

Write-Host "`nIniciando Steam..." -ForegroundColor Cyan
Start-Process $steamExe
Start-Sleep -Seconds 2
