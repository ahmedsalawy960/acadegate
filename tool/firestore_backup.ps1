#Requires -Version 5.1
<#
.SYNOPSIS
  Export Cloud Firestore to a GCS bucket (manual / drill backup).

.EXAMPLE
  .\tool\firestore_backup.ps1 -Bucket "gs://acadegate-new-firestore-backups"
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$Bucket,

  [string]$ProjectId = "acadegate-new"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
  Write-Error "gcloud CLI not found. Install Google Cloud SDK first."
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$dest = "$Bucket/$stamp".TrimEnd("/")

Write-Host "Exporting Firestore ($ProjectId) -> $dest"
gcloud firestore export $dest --project=$ProjectId
Write-Host "Done. Record a restore drill in docs/BACKUP_RESTORE_AR.md"
