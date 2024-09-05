# Nebiatest = 42515d96-ba8a-4788-93a7-0f9385312fe0 @nebiatest.onmicrosoft.com
# Nebiatek = 1eae22f0-5728-4559-b5fa-bec04a2763cd @nebiatek.onmicrosoft.com
# Polara = ad66fed9-87fe-4d46-af62-9fc57caa2c0f @polaraenergy.onmicrosoft.com
# Hi5CPA = c194c4b2-a8eb-4e7c-a4e3-ee5e0653917a @hicpa.onmicrosoft.com
# theoreme = 2dbf1c31-b883-4ed2-bc27-25838e1bad46 @theoremecpa.onmicrosoft.com
# OPAConseil = 2c8bc25a-6731-4e2b-863b-9106f392354d @opaconseil.onmicrosoft.com

# !TODO create SSPR group to require only them to register info for SSPR on first login (instead of registration asked, then "done" message without doing anything)

#sharpoint
# Connect-SPOService -Url https://nebiatest-admin.sharepoint.com
# Get-SPOTenant | select *B2B*
# Set-SPOTenant -EnableAzureADB2BIntegration $true
# Set-SPOTenant -SyncAadB2BManagementPolicy $true

d8v+b68c
$tenantId = "42515d96-ba8a-4788-93a7-0f9385312fe0"
$password01 = 'Recoil5-Uneasy-Enable-Dividend-Anemia-Strongman-Astride-Removal-Heroics-Agreeable' # admin.global01
$password02 = 'Overbook-Playtime-Cannon2-Problem-Remedy-Smokeless-Elated-Bagel-Alarm-Mutt' # admin.global02

Connect-MgGraph -Scopes Directory.Read.All, User.ReadWrite.All, Policy.Read.All, Policy.ReadWrite.Authorization, Policy.ReadWrite.ConditionalAccess, RoleManagement.ReadWrite.Directory -NoWelcome -TenantId $tenantId
$onmicrosoftdomain = (Get-MgOrganization | select -ExpandProperty VerifiedDomains | ? IsInitial).Name
$adminAccounts = @()

# Disable SSPR for administators
Update-MgPolicyAuthorizationPolicy -AllowedToUseSspr:$false

# Create first admin account
$params = @{
    AccountEnabled    = $true
    GivenName         = "Admin"
    Surname           = "Microsoft 01"
    DisplayName       = "Admin Microsoft 01"
    JobTitle          = "Admin Account"
    MailNickname      = "admin.global01"
    UserPrincipalName = "admin.global01@$onmicrosoftdomain"
    UserType          = "Member"
    PasswordPolicies  = "DisablePasswordExpiration"
    PasswordProfile   = @{
        password                             = $password01
        forceChangePasswordNextSignIn        = $false
        forceChangePasswordNextSignInWithMfa = $false
    }
}
$adminAccounts += New-MgUser @params

# Create second admin account
$params = @{
    AccountEnabled    = $true
    GivenName         = "Admin"
    Surname           = "Microsoft 02"
    DisplayName       = "Admin Microsoft 02"
    JobTitle          = "Admin Account"
    MailNickname      = "admin.global02"
    UserPrincipalName = "admin.global02@$onmicrosoftdomain"
    UserType          = "Member"
    PasswordPolicies  = "DisablePasswordExpiration"
    PasswordProfile   = @{
        password                             = $password02
        forceChangePasswordNextSignIn        = $false
        forceChangePasswordNextSignInWithMfa = $false
    }
}
$adminAccounts += New-MgUser @params

$globaladminrole = Get-MgDirectoryRole | ? DisplayName -EQ "Global Administrator"

foreach ($adminAccount in $adminAccounts) {

    #$globaladminrolemembers = Get-MgDirectoryRoleMember -DirectoryRoleId $globaladminrole.Id
    Write-Host "Adding $($adminAccount.DisplayName) ($($adminAccount.Id)) to $($globaladminrole.DisplayName) ($($globaladminrole.Id))"
    New-MgDirectoryRoleMemberByRef -DirectoryRoleId $globaladminrole.Id -OdataId "https://graph.microsoft.com/v1.0/directoryObjects/$($adminAccount.Id)"

    $capolicies = (Get-MgIdentityConditionalAccessPolicy | Sort-Object DisplayName)

    foreach ($capolicy in $capolicies) {
        Write-Verbose ("Checking conditional access policy {0}" -f $capolicy.displayName)

        # Get already excluded users
        [array]$excludedUsers = $capolicy.Conditions.Users.ExcludeUsers

        if ($adminAccount.Id -notin $excludedUsers) {
            $excludedUsers += $adminAccount.Id
    
            # Parameters needed to update the CA policy
            $bodyParam = @{
                Conditions = @{
                    users = @{  
                        ExcludeUsers = $excludedUsers
                    }
                }
            }
    
            Write-Host ("Excluding '{0}' ({1}) from policy '{2}'" -f $adminAccount.DisplayName, $adminAccount.Id, $capolicy.DisplayName) -ForegroundColor Yellow
            Update-MgIdentityConditionalAccessPolicy -BodyParameter $bodyParam -ConditionalAccessPolicyId $capolicy.Id
        }
    }
}
