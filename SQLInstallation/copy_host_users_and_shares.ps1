## TO BE RUN ON THE TARGET HOST

cls
function Get-HostnameFromFQDN {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FQDN
    )

    # Split on the first dot and return the first part
    return ($FQDN -split '\.')[0]
}

#region SourceHostname
    [string]$sourceFQDN
    [string]$SourceShortName = "" 
    [string]$tempSource = ""

    $tempSource= Read-Host "Enter the FQDN name of the SOURCE server...
    [ENTER] = continue using [$sourceFQDN]
    [XX]    = CANCEL
    "


    If (($tempSource -eq "") -and ([string]::IsNullOrwhiteSpace($sourceFQDN))) {
        Write-Host "MISSING SOURCE HOST" -ForegroundColor RED
        break
        }
    elseif ($tempSource -eq "XX")
        { write-host "Cancelled." -ForegroundColor Red
        break}

    elseif (($tempSource -eq "") -and (!([string]::IsNullOrwhiteSpace($sourceFQDN)))) 
        {write-host $sourceFQDN}

    elseif ($tempSource -ne "") 
        {$sourceFQDN = $tempSource}

    $sourceShortName = Get-HostnameFromFQDN -FQDN $sourceFQDN


    write-host "    Source Host Name: $sourceFQDN   (aka: $sourceShortName)
" -ForegroundColor Yellow

#endregion SourceHostname

#region targetHostname
    [string]$strThisHost = hostname
    [string]$targetFQDN = [system.net.DNS]::GetHostEntry($strthisHost).hostname
    [string]$targetShortName = "" 

    [string]$temp = Read-Host "Confirm the FQDN name of the target server (currently set to: $targetFQDN)"

    If ($temp -ne ""){
        $targetFQDN = $temp
        }

    $TargetShortName = Get-HostnameFromFQDN -FQDN $targetFQDN


    If ($targetFQDN -eq "") 
        {
            Write-Host "MISSING target HOST" -ForegroundColor RED
            BREAK
         }

    write-host "    target Host Name: $targetFQDN   (aka: $targetShortName)
" -ForegroundColor Yellow

#endregion targetHostname

#region GetCredentials
    $YourCreds = Get-Credential -Message "Please enter network credentials to connect to $sourceFQDN"

    write-host "checking credentials..." -ForegroundColor DarkYellow
    try {
        [string]$x = Invoke-Command -ComputerName $sourceFQDN -Credential $YourCreds -ScriptBlock { hostname }
        Write-Host "    Credentials are valid!" -ForegroundColor Yellow
    } catch {
        Write-Host "    Invalid credentials or connection failed." -ForegroundColor Red
        break
    }
#endregion GetCredentials

#region Collect Source LocalAccounts
[datetime]$dt = get-date

[string]$strOutput = "REM -- Values copied from " + $sourceFQDN + "
REM -- " + $dt + "
"
#Get Local host Users and Groups from the Source
[string]$sourceValues=  Invoke-Command -ComputerName $sourceFQDN -Credential $YourCreds  -ScriptBlock {

    Write-Output "REM Local accounts:
"
    $users = Get-LocalUser |  Where-Object Enabled -EQ True
    foreach ($user in $users) {
        If($User.Enabled -eq $TRUE) {
            write-output "   net.exe user $user <password> /add
"
                }
        }

    write-Output "
"

    Write-Output "REM Groups with DOMAIN accounts:
"
    $groups = get-localgroup  

    foreach ($group in $groups) {
        $members = Get-LocalGroupMember -Group $group.name
        foreach ($member in $members) {
            If(($member.name -like "*\*") -and ($member.name -notlike "NT*")) {
            write-output "   net.exe localgroup ""{0}"" ""{1}"" /add" -f   $group.name ,$member.name  "
 " 

            }
        }
    }

    write-Output "
"
    write-Output "REM Groups with LOCAL accounts:
"
    foreach ($group in $groups) {
        $members = Get-LocalGroupMember -Group $group.name
        foreach ($member in $members) {
            If ($member.name -notlike "NHA*"){
            write-output "   net.exe localgroup ""{0}"" ""{1}"" /add" -f   $group.name ,$member.name  "
"
            }
        }
    }

}

    $strOutput = $strOutput + $sourceValues

#replace hostnames to use the Target names

    $strOutput = $strOutput -replace $SourceShortName, $targetShortName

#prepare the file output
    [string]$filename = "d:\temp\installers\" + $SourceShortName + "_Modified_localAccounts.bat"

    #Drop the file if it already exists
    If (test-path $fileName){
        remove-item $filename
        }

    #write the file
    Set-content -Path $filename -Value $strOutput


    write-host "Local host accounts from $sourceShortName have been scripted to file:
    $filename" -ForegroundColor green


#endregion Collect Source LocalAccounts

#region Copy FileShares
    #Collect all Manually created shares from SOURCE
        write-host "Collecting FileShare information from $SourceFQDN..."
    
        $sourceShares = Invoke-Command -ComputerName $sourceFQDN -Credential $YourCreds  -ScriptBlock {
            # All shares?
                # $shares = Get-SmbShare | Where-Object { $_.Name -notmatch '^(C\$|ADMIN\$|IPC\$|PRINT\$)' -notlike '*$' }

            #Manually created shares only
            $shares = Get-SmbShare | Where-Object { $_.Name -notlike "*$"}

            $shareConfigs = $shares | ForEach-Object {
                $shareName = $_.Name
                $path = $_.Path
                $description = $_.Description

            $sharePermissions = Get-SmbShareAccess -Name $shareName | Select-Object AccountName, AccessRight, AccessControlType

            $acl = Get-Acl -Path $path
            $ntfsPermissions = $acl.Access | Select-Object IdentityReference, FileSystemRights, AccessControlType, InheritanceFlags, PropagationFlags

            [PSCustomObject]@{
                ShareName = $shareName
                Path = $path
                Description = $description
                SharePermissions = $sharePermissions
                NTFS = $ntfsPermissions
                }


            }
            #return collected configs
            $shareconfigs
        }

        #Export JSON of collected SourceShares
            [string]$filename = "D:\temp\installers\" + $SourceShortName + "_manual_shares.xml"
            $sourceShares | Export-CliXML -path $filename 

        write-host "FileShare information collected and stored at...
            $filename" -ForegroundColor Green


#endregion Copy FileShares

#region Replicate FileShares
    #Sourcefile:
    rv shareconfigs -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    $shareConfigs = Import-CliXML -Path $filename

    #Drive replacements, if any
#    $shareconfigs = $shareConfigs -replace "E:", "F:"


    #Create file shares
        Foreach ($share in $shareConfigs){

            #Replace drive letter if needed
                [string]$sharePath = $share.Path -replace "E:", "F:"

            # Create the folder if it doesn't exist
                if (-not (Test-Path $sharePath)) {
                    New-Item -ItemType Directory -Path $sharePath -Force
                }

            # Create the share
                New-SmbShare -Name $share.ShareName -Path $sharePath -Description $share.Description

            # Apply share-level permissions
                foreach ($perm in $share.SharePermissions) {
                    Grant-SmbShareAccess -Name $share.ShareName -AccountName $perm.AccountName -AccessRight $perm.AccessRight -Force
                }

            # Apply NTFS permissions
                $acl = Get-Acl $sharePath

                foreach ($ntfs in $share.NTFS) {

                    # Convert from deserialized to real NTAccount
                    #Importing Identities from another machine, "Deserializes" the NT account.
                    #the solution is to recreate the NTAccount object locally.

                    $identity = New-Object System.Security.Principal.NTAccount($ntfs.IdentityReference.Value)

                    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        $identity,
                        $ntfs.FileSystemRights,
                        $ntfs.InheritanceFlags,
                        $ntfs.PropagationFlags,
                        $ntfs.AccessControlType
                        )
                    $acl.SetAccessRule($rule)
                    }

                   #apply permissions to the share
                Set-Acl -Path $sharePath -AclObject $acl
            }



#endregion Replicate FileShares
