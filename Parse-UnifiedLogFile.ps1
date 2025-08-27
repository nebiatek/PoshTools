Add-Type -AssemblyName System.Windows.Forms

$FileDialog = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    InitialDirectory = [Environment]::GetFolderPath('Desktop') 
    Filter           = 'CSV Files (*.csv)|*.csv'
    Title            = 'Select a unified log file'
}

$FileDialog.ShowDialog() | Out-Null

if ($FileDialog.FileName -ne '') {
    $csvContent = Get-Content -Path $FileDialog.FileName
    ($csvContent | ConvertFrom-Csv).AuditData | ConvertFrom-Json | Export-Csv -Path ($FileDialog.FileName -replace '\.csv$', ' - Arranged.csv') -NoTypeInformation
}
