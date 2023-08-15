#Requires -RunAsAdministrator
function Backup-LocalData {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        
    }
    
    process {
        
    }
    
    end {
        
    }
}

function Create-AutopilotInfoFile {
    [CmdletBinding()]
    param (
        
    )
    
    process {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        New-Item -Type Directory -Path "$env:HOMEDRIVE\HWID" && Set-Location -Path "$env:HOMEDRIVE\HWID"

        $env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

        $filename = (get-date -Format yy-MM-dd_HH-mm)+"_"+$env:COMPUTERNAME+"_"+$env:USERNAME+".csv"

        Install-Script -Name Get-WindowsAutopilotInfo
        Get-WindowsAutopilotInfo -OutputFile $filename
    }
}