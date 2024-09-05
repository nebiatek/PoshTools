Connect-MgGraph -NoWelcome -Scopes Policy.ReadWrite.ConditionalAccess

# Define app id for the Microsoft Rights Management Services app
$accountIds = @('76b169b3-3c4e-478e-8da4-341f28356b4b', '69d1d8fd-2ec4-4a36-9336-f6e6b844a615')

foreach ($Policy in (Get-MgIdentityConditionalAccessPolicy | Sort-Object DisplayName)) {
    Write-Host ("Checking conditional access policy {0}" -f $Policy.displayName)

    # Get already excluded users
    [array]$ExcludedUsers = $Policy.Conditions.Users.ExcludeUsers

    foreach ($accountId in $accountIds) {

        
        if ($accountId -notin $ExcludedUsers) {
            $ExcludedUsers += $accountId

            # Parameters needed to update the CA policy
            $bodyParam = @{
                Conditions = @{
                    users = @{  
                        ExcludeUsers = $ExcludedUsers
                    }
                }
            }

            Write-Host ("Updating policy {0} with exclusion" -f $Policy.DisplayName) -ForegroundColor Yellow
            Update-MgIdentityConditionalAccessPolicy -BodyParameter $bodyParam -ConditionalAccessPolicyId $Policy.Id
        }
    }
}