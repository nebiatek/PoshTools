<#
.SYNOPSIS
    Disable Microsoft 365 account of shared mailboxes

.DESCRIPTION
    This function helps IT administrators to disable all or specificed shared mailbox accounts in a Microsoft 365 tenant.
    It helps keep disabled the accounts which are not supposed to login (as shared mailboxes are using delegated permissions directly from Exchange)

.INPUTS
    String

.OUTPUTS
    Array

.EXAMPLE
    Disable-SharedMailboxUserAccount

.EXAMPLE
    Disable-SharedMailboxUserAccount -Identity test.shared@contoso.com

.NOTES
    Website: https://github.com/nebiatek
#>

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users, ExchangeOnlineManagement

function Disable-SharedMailboxUserAccount {

    [CmdletBinding(DefaultParameterSetName = 'AllMailboxes')]
    
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [string]
        $TenantId,

        [Parameter(Mandatory = $false,
            ParameterSetName = 'AllSharedMailboxes')]
        [switch]
        $All,

        # TODO: Allow to call this function providing an array of one or more userprincipalname of sharedmailbox to disable
        [Parameter(Mandatory = $true,
            ParameterSetName = 'TargetedSharedMailboxes')]
        [string[]]
        $Identity,

        # TODO: Require manual confirmation before each "disable account" action
        [Parameter(Mandatory = $false)]
        [switch]
        $Confirm
    )
    
    begin {
        Connect-MgGraph -TenantId $TenantId -Scopes Directory.ReadWrite.All
        Connect-ExchangeOnline -ShowBanner:$false
        $disabledaccounts = @()
    }
    
    process {
        $sharedmailboxes = Get-EXOMailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited

        for ($i = 0; $i -lt $sharedmailboxes.Count; $i++) {

            try {
                $user = Get-MgUser -Filter "UserPrincipalName eq '$($($sharedmailboxes[$i].UserPrincipalName))'"
            }
            catch {
                Write-Error $_.Exception.Message
            }
            
            Write-Verbose "Disabling $($user.UserPrincipalName) with object id $($user.Id)"
            Update-MgUser -UserId $user.Id -BodyParameter @{AccountEnabled = "false"}

            $disabledaccounts += ($user | Select-Object Id,UserPrincipalName)
        }
    }
    
    end {
        return $disabledaccounts
        Disconnect-MgGraph | Out-Null
        Disconnect-ExchangeOnline | Out-Null
    }
}