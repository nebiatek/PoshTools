<#
.SYNOPSIS
Crée une tâche planifiée SYSTEM (cachée) qui installe silencieusement l’agent NinjaOne depuis un MSI, avec retries automatiques jusqu’à succès.

.DESCRIPTION
Enregistre une tâche planifiée Windows exécutée en compte SYSTEM (niveau le plus élevé) pour tenter l’installation silencieuse de l’agent NinjaOne à partir d’un fichier MSI.
La tâche démarre à une heure donnée (ou maintenant + 5 minutes), se répète à intervalle fixe pendant une durée définie, et peut aussi se déclencher au démarrage.
Les tentatives et le résultat (ainsi qu’un log MSI détaillé) sont consignés dans un fichier de log local.

.PARAMETER TaskName
Nom de la tâche planifiée à créer/remplacer.
Par défaut : "Nebiatek - Install NinjaOne Agent"

.PARAMETER BaseDir
Répertoire de travail utilisé pour stocker les fichiers nécessaires à l’exécution.
Par défaut : "C:\rmminstaller"

.PARAMETER MsiPath
Chemin complet du fichier MSI de l’agent NinjaOne à installer.
Par défaut : "C:\rmminstaller\NinjaOne-Agent-[ORGANIZATION]-Bureauprincipal-Auto.msi"

.PARAMETER LogPath
Chemin complet du fichier de log (UTF-8) utilisé pour tracer les opérations.
Un fichier additionnel ".msi.log" est généré par msiexec.
Par défaut : "C:\rmminstaller\install.log"

.PARAMETER FirstRun
Date/heure locale de la première exécution.
Si vide, la première exécution est planifiée à maintenant + 5 minutes.
Exemple : "2025-12-16 08:00"

.PARAMETER RepeatMinutes
Intervalle de répétition en minutes (retries).
Par défaut : 60

.PARAMETER RepeatDays
Durée pendant laquelle la répétition reste active (en jours) à partir de la première exécution.
Par défaut : 30

.PARAMETER AlsoAtStartup
Ajoute un déclencheur au démarrage, en plus du time trigger.
Activé par défaut.

.EXAMPLE
.\Install-NinjaOneAgent-ScheduledTask.ps1

Crée la tâche avec les valeurs par défaut (première exécution dans 5 minutes, répétition toutes les 60 minutes pendant 30 jours, déclenchement au démarrage activé).

.EXAMPLE
.\Install-NinjaOneAgent-ScheduledTask.ps1 `
  -MsiPath "C:\Temp\NinjaOne-Agent-Contoso-HQ.msi" `
  -LogPath "C:\Temp\NinjaOneInstall\install.log" `
  -FirstRun "2026-03-02 19:30" `
  -RepeatMinutes 30 `
  -RepeatDays 7

Planifie une première tentative à une date précise, puis retente toutes les 30 minutes pendant 7 jours, en loggant dans un répertoire personnalisé.

.EXAMPLE
.\Install-NinjaOneAgent-ScheduledTask.ps1 -AlsoAtStartup:$false

Crée la tâche sans déclenchement au démarrage (uniquement via la planification).

.NOTES
- Exécuter en contexte administrateur est recommandé pour créer/remplacer une tâche planifiée et écrire dans certains chemins.
- Si le MSI est absent au moment d’un déclenchement, la tâche ne “fail” pas définitivement : elle retentera au prochain trigger.
- La tâche est créée en mode caché (Hidden=true) et s’exécute sous SYSTEM avec privilèges élevés.
- Pour diagnostiquer : consulter -LogPath et le fichier MSI détaillé (même chemin, extension .msi.log).

#>

[CmdletBinding()]
param(
  [string]$TaskName      = "Nebiatek - Install NinjaOne Agent",
  [string]$BaseDir       = "C:\rmminstaller",
  [string]$MsiPath       = "C:\rmminstaller\NinjaOne-Agent-[ORGANIZATION]-Bureauprincipal-Auto.msi",
  [string]$LogPath       = "C:\rmminstaller\install.log",
  [string]$FirstRun      = "",     # "2025-12-16 08:00" sinon now + 5 min
  [int]   $RepeatMinutes = 60,
  [int]   $RepeatDays    = 30,
  [switch]$AlsoAtStartup = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
  param([string]$Message)
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null
  Add-Content -Path $LogPath -Value "[$ts] $Message" -Encoding UTF8
}

# --- Ensure base directory exists
New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null

# --- Compute first run time (local)
[datetime]$AtTime =
  if ([string]::IsNullOrWhiteSpace($FirstRun)) { (Get-Date).AddMinutes(5) }
  else { [datetime]::Parse($FirstRun) }

$StartBoundary = $AtTime.ToString("yyyy-MM-ddTHH:mm:ss")

$WorkerPath = Join-Path $BaseDir "Install-NinjaOneAgent.ps1"

# --- Worker script (NO expansion)
$worker = @'
[CmdletBinding()]
param(
  [string]$TaskName,
  [string]$MsiPath,
  [string]$LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log([string]$m) {
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null
  Add-Content -Path $LogPath -Value "[$ts] $m" -Encoding UTF8
}

function Test-NinjaInstalled {
  # Heuristique: service + uninstall keys
  if (Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue) { return $true }

  $uninstallRoots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )

  foreach ($root in $uninstallRoots) {
    try {
      $hit = Get-ItemProperty $root -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match "NinjaRMM|NinjaOne|NinjaRMMAgent" } |
        Select-Object -First 1
      if ($hit) { return $true }
    } catch {}
  }
  return $false
}

try {
  if (Test-NinjaInstalled) {
    Write-Log "Agent détecté. Suppression de la tache '$TaskName'."
    # Cette partie est commenté pour éviter les probleme lors des transfert de MSP (detection du NinjaOne de l'ancien MSP par exemple)
    # Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    exit 0
  }

  if (-not (Test-Path -LiteralPath $MsiPath)) {
    Write-Log "MSI introuvable: $MsiPath (retry au prochain trigger)."
    exit 2
  }

  Write-Log "Installation silencieuse: msiexec /i '$MsiPath' /qn /norestart"
  $msiLog = [System.IO.Path]::ChangeExtension($LogPath, ".msi.log")

  $p = Start-Process -FilePath "msiexec.exe" -ArgumentList @(
    "/i", "`"$MsiPath`"",
    "/qn",
    "/norestart",
    "/L*v", "`"$msiLog`""
  ) -Wait -PassThru

  Write-Log ("msiexec exit code: {0}" -f [int]$p.ExitCode)

  # 0 = OK, 3010 = OK mais reboot requis
  if ($p.ExitCode -in 0, 3010) {
    Write-Log "Installation reussie. Suppression de la tache '$TaskName'."
    # Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    exit 0
  } else {
    Write-Log ("Installation echouee (code {0}). Retry au prochain trigger." -f [int]$p.ExitCode)
    exit 1
  }
}
catch {
  Write-Log ("Exception: {0}" -f $_.Exception.Message)
  exit 99
}
'@

Set-Content -Path $WorkerPath -Value $worker -Encoding UTF8 -Force
Write-Log "Worker script ecrit: $WorkerPath"

# --- Action PowerShell (arguments)
$Arg = "-NoProfile -ExecutionPolicy Bypass -File `"$WorkerPath`" -TaskName `"$TaskName`" -MsiPath `"$MsiPath`" -LogPath `"$LogPath`""

# Escape XML special chars just in case (rare but safe)
$ArgEscaped = [System.Security.SecurityElement]::Escape($Arg)

# --- Repetition ISO 8601
$IntervalIso = "PT${RepeatMinutes}M"  # ex: PT60M
$DurationIso = "P${RepeatDays}D"      # ex: P30D

# --- Boot trigger XML (optional)
$BootTriggerXml = if ($AlsoAtStartup) {
@"
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
"@
} else { "" }

# --- Task XML
$TaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>Nebiatek</Author>
    <Description>Installe l'agent NinjaOne Nebiatek en silencieux avec retry.</Description>
  </RegistrationInfo>

  <Triggers>
    <TimeTrigger>
      <StartBoundary>$StartBoundary</StartBoundary>
      <Enabled>true</Enabled>
      <Repetition>
        <Interval>$IntervalIso</Interval>
        <Duration>$DurationIso</Duration>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
    </TimeTrigger>
$BootTriggerXml
  </Triggers>
  
  <Principals>
    <Principal id="Author">
      <UserId>SYSTEM</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>

  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>

    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>

    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <ExecutionTimeLimit>PT30M</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>

  <Actions Context="Author">
    <Exec>
      <Command>PowerShell.exe</Command>
      <Arguments>$ArgEscaped</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# --- Create / Replace task
try {
  if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
    Write-Log "Ancienne tâche supprimée: $TaskName"
  }
} catch {}

Register-ScheduledTask -TaskName $TaskName -Xml $TaskXml -Force | Out-Null
Write-Log "Tâche créée (XML): $TaskName | Start=$StartBoundary | Interval=$IntervalIso | Duration=$DurationIso | Startup=$AlsoAtStartup"

Write-Output "OK - Scheduled Task '$TaskName' created. Log: $LogPath"
