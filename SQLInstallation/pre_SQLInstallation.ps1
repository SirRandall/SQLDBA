<# 20251022 Randy Sheldon

    Used to prepare, install and update SQL Server
#>

#region Parameter Review 
    #Change these as needed
    [String]$ProgressColor    = "Cyan"
    [string]$InformationColor = "White"
    [string]$WarningColor     = "Yellow"
    [string]$ErrorColor       = "Red"
    [string]$PromptColor      = "Green"

    #Connection values
    [string]$SourceName = ""
    [string]$TargetName = hostname

    #Credential values
    [string]$SQLSVCACCOUNT = ""   
    [string]$SAPWD=""  

    #SQL Disk Mapping values
    [string]$AppDrive    = "D"
    [string]$DataDrive   = "F"
    [string]$LogsDrive   = "G"
    [string]$TempDBDrive = "H"
#endregion Parameter Review 


Function New-DirectoryIfMissing {
    [CmdletBinding(SupportsShouldProcess = $true)]

    param(
        [Parameter(Mandatory=$true)]      [string]$Path,
        [Parameter(Mandatory = $false)]   [string]$GrantAccessTo
        )

    # Check if the path exists and is a directory (Container)
    if (-not (Test-Path -Path $Path -PathType Container)) {

        # If it doesn't exist, create it. -Force ensures parent directories are created too.
        if ($PSCmdlet.ShouldProcess("Creating directory '$Path'", "New-Item")) {
            Write-Host "Creating directory: $Path" -ForegroundColor Cyan
            try {
                # Use Out-Null to suppress the object output of New-Item
                $null = New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop
                Write-Host "    Successfully created: $Path" -ForegroundColor Green

                If ($GrantAccessTo){
                    Set-SharePermissions -Folder $Path -Account $GrantAccessTo -Permissions "FullControl"
                    }
            }
            catch {
                Write-Error "Failed to create directory '$Path': $($_.Exception.Message)"
            }
        }

    } else {
        Write-Host "Directory already exists: $Path" -ForegroundColor Yellow
    }
}
Function Set-SharePermissions {
    param(
        [Parameter(Mandatory = $true)]   [string]$Folder,
        [Parameter(Mandatory = $true)]   [string]$Account,
        [Parameter(Mandatory = $true)]   [string]$Permissions
    )

        Write-Host "Granting R/W/X on $Path to $account ..." -ForegroundColor Cyan

            $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $Account,                                 #Identity
                $Permissions ,                            #FilesystemRights
                "ContainerInherit, ObjectInherit",        #Inheritance ('None','ContainerInherit','ObjectInherit')
                "None",                                   #Propagation ('None','NoPropagateInherit','InheritOnly')
                "Allow" )

            # Get the existing Access Control List for the folder
            $ACL = Get-ACL -Path $Folder

            # Add the new Access Rule to the ACL
            $ACL.AddAccessRule($AccessRule)

            # Apply the updated ACL back to the folder
            Set-ACL -Path $Folder -ACLObject $ACL
            Write-Host "    Successfully granted '$Permissions' to '$Account' on folder '$Folder'." -ForegroundColor Green
    }
function Ensure-ModuleImported {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
        Write-Error "Module '$ModuleName' is not installed."
        return
    }

    if (-not (Get-Module -Name $ModuleName)) {
        Import-Module -Name $ModuleName -ErrorAction Stop
        Write-Host "Module '$ModuleName' imported successfully." -ForegroundColor Green
    } else {
        Write-Host "Module '$ModuleName' is already imported." -ForegroundColor Yellow
    }
}
function Ensure-ModuleInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [string]$Repository = "PSGallery",

        [switch]$Force
    )

    # Check if module is available locally
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "Module '$ModuleName' not found. Installing from $Repository..." -ForegroundColor Red
        try {
            Install-Module -Name $ModuleName -Repository $Repository -AllowClobber -Force -ErrorAction Stop
            Write-Host "Module '$ModuleName' installed successfully." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to install module '$ModuleName': $_" 
        }
    }
    else {
        If ($Force) {
            try {
                Install-Module -Name $ModuleName -Repository $Repository -AllowClobber -Force -ErrorAction Stop
                Write-Host "Module '$ModuleName' installed successfully." -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to install module '$ModuleName': $_" 
            }
        }
        else {
        Write-Host "Module '$ModuleName' is already installed." -ForegroundColor Yellow
        }
    }
}
function Read-Continue {
    param(
        [Parameter(Mandatory=$false)]      [string]$prompt = "Continue",
        [Parameter(Mandatory=$false)]      [string]$message,
        [Parameter(Mandatory=$false)]      [string]$color = "White"
        )

    while ($true) {
        If ($message) {
            Write-host $message -ForegroundColor $color
            write-host ""
            }
        $response = Read-Host "$prompt (Y/N)"

        if ($response -match '^[Yy]$') {
            return "Y"
        }
        elseif ($response -match '^[Nn]$') {
            return "N"
        }
        else {
            Write-Host "Please enter Y or N." -ForegroundColor Yellow
        }
    }
}



<#
#write-host "Black" -ForegroundColor Black
#write-host "Blue" -ForegroundColor Blue
write-host "Cyan" -ForegroundColor Cyan
#write-host "DarkBlue" -ForegroundColor DarkBlue
write-host "DarkCyan" -ForegroundColor DarkCyan
write-host "DarkGray" -ForegroundColor DarkGray
write-host "DarkGreen" -ForegroundColor DarkGreen
#write-host "DarkMagenta" -ForegroundColor DarkMagenta
#write-host "DarkRed" -ForegroundColor DarkRed
write-host "DarkYellow" -ForegroundColor DarkYellow
write-host "Gray" -ForegroundColor Gray
write-host "Green" -ForegroundColor Green
write-host "Magenta" -ForegroundColor Magenta
write-host "Red" -ForegroundColor Red
write-host "White" -ForegroundColor White
write-host "Yellow" -ForegroundColor Yellow
#>

cls
write-host "Prepping orchestrated SQL Server installation..." -foregroundColor $ProgressColor

#region Setup
    #Install/confirm sqlServer powershell module
        Ensure-ModuleInstalled -moduleName sqlserver
        Ensure-ModuleInstalled -moduleName dbatools #-Force

        Ensure-ModuleImported  -ModuleName dbaTools
        Ensure-Moduleimported  -ModuleName sqlserver
#endregion Setup

#region Define Connections
        #region Source
        While (!($SourceName)){
            write-host ""
            write-host "Setting the SOURCE SQL Server Name" -ForegroundColor $PromptColor
            $SourceName = read-host "     Verify the SOURCE SQL Server name" 

            If ($SourceName -eq $TargetName){
                write-host "The Source server cannot be the same as the target server.
You are running this script on the target server [$TargetName]." -ForegroundColor $ErrorColor
                $SourceName = ""
                }
            }

        Try {
            $SourceServer = Connect-DbaInstance -SqlInstance $SourceName      -TrustServerCertificate -ErrorAction stop -WarningAction Continue
            write-host ""
            write-host "     Source Server set to: "$SourceServer.ComputerName  $SourceServer.DomainName $SourceServer.Version $SourceServer.ProductLevel -ForegroundColor $InformationColor
            }
        Catch {
            Write-host $_
            }
        #endregion Source

        #region Target
        $TargetName = ""

        While ($TargetName -eq ""){
            $TargetName = hostname
            write-host ""
            write-host "Setting the TARGET SQL Server Name" -ForegroundColor $PromptColor
            $ask1 = read-host "     Verify the TARGET SQL Server hostname (press enter to continue with [$TargetName])"
            
            If (!($ask1)) {
                $TargetName = hostname
                }
            elseIf ($ask1 -eq $SourceName)  {

                write-host "The Target server cannot be the same as the source server. Please try again." -ForegroundColor $ErrorColor
                $TargetName = ""
                $ask1 = ""
                }
            }
            write-host ""
            write-host "     Target Server set to: $TargetName" -ForegroundColor $InformationColor
        #endregion Target

        #region ServiceAccount
        While (!($SQLSVCACCOUNT)){
            write-host ""
            write-host "Setting the TARGET SQL Server SERVICE ACCOUNT Username" -ForegroundColor $PromptColor

            $ask2 = read-host "     Enter the SQL Service credential user name (including domain-name)"
            If (($ask2 -ne $SQLSVCACCOUNT) -and ($ask2)){
              $SQLSVCACCOUNT = $Ask2
               }
            }
            write-host ""
            write-host "     Target SQLServiceAccount username set to : $SQLSVCACCOUNT" -ForegroundColor $InformationColor
        #endregion ServiceAccount

        #region SA Password
        While (!($SAPWD)){
            write-host ""
            write-host "Setting the TARGET SA password" -ForegroundColor $PromptColor

            $SAPWD = read-host "    Enter the SA password you'd like to use"
            }
            write-host ""
            write-host "    SA password for $TargetServer will be: $SAPWD" -ForegroundColor $InformationColor
        #endregion  SA Password

        #region DiskMapping
            write-host ""
            write-host "The following disk mapping settings have been entered. Please confirm." -ForegroundColor $PromptColor
            write-host "    Application Drive: $AppDrive
    Data Drive:        $DataDrive
    Logfile Drive:     $LogsDrive
    TempDB Drive:      $TempDBDrive
" -ForegroundColor $promptcolor


        $Ask1 = Read-Continue -message "" -prompt "Would you like to proceed?"
        If (($ask1 -eq "") -or ($ask1 -eq "N")) {
        break
        }



        #endregion DiskMapping

#endregion Define Connections

#region Create Directories
write-host "Creating required directories..." -ForegroundColor $ProgressColor

    New-DirectoryIfMissing $AppDrive":\MSSQL\Backups"   -ErrorAction Continue -WarningAction Continue     #Backups
                                                                
    New-DirectoryIfMissing $AppDrive":\MSSQL\Data"      -ErrorAction Continue -WarningAction Continue     #System DB
                                                                
    New-DirectoryIfMissing $AppDrive":\MSSQL\Logs"      -ErrorAction Continue -WarningAction Continue     #System Logs
                                                                                                                                
    New-DirectoryIfMissing $DataDrive":\MSSQL\Data"      -ErrorAction Continue -WarningAction Continue     #User DB
                                                                
    New-DirectoryIfMissing $LogsDrive":\MSSQL\Logs"      -ErrorAction Continue -WarningAction Continue     #User Logs
                                                                
    New-DirectoryIfMissing $TempDBDrive":\MSSQL\tempDB"       -ErrorAction Continue -WarningAction Continue     #TempDB

    New-DirectoryIfMissing $AppDrive":\temp\for_restore" -ErrorAction SilentlyContinue -WarningAction Continue -GrantAccessTo $SQLSVCACCOUNT    #for database moves

    New-DirectoryIfMissing $AppDrive":\login_audit"       -ErrorAction SilentlyContinue -WarningAction Continue -GrantAccessTo $SQLSVCACCOUNT    #for login_auditing 

#endregion Create Directories


#break


#region Installations
    write-host ""
    write-host "Beginning SQL Server Installation..." -ForegroundColor $progressColor

    #region Define Install Arguments
        #Path to Source files
        [string]$iso_diskImagePath = Get-ChildItem -path "D:\temp\Installers" -Filter "*.iso" | Select-Object -ExpandProperty FullName
        [string]$cu_updatePath = Get-ChildItem -path "D:\temp\Installers" -Filter "SQL*KB*.exe" -file | Select-Object -ExpandProperty FullName
        [string]$DN = $env:USERDNSDOMAIN

            write-host ""
            Write-Host "    ISO Installer path: $iso_diskImagePath" -ForegroundColor $informationColor
            write-host ""
            Write-Host "    EXE CU path       : $cu_updatePath" -ForegroundColor $informationColor
            Write-host ""
            Write-Host "    Current Domain    : $DN" -ForegroundColor $informationColor
        #Installation Arguments


        #SQLInstall SPECIFIC
        [string]$AGTSVCACCOUNT= $SQLSVCACCOUNT     #SQL Agent Accont

        If ($dn -like '*nhacentral.com'){

            $SQLSVCACCOUNT       = $SQLSVCACCOUNT.Replace('NHATEST\','NHA\')
            $SQLSVCACCOUNT       = $SQLSVCACCOUNT.Replace('.UAT','2')

            $AGTSVCACCOUNT       = $AGTSVCACCOUNT.Replace('NHATEST\','NHA\')
            $AGTSVCACCOUNT       = $AGTSVCACCOUNT.Replace('.UAT','2')
            }

        [string]$ACTION="Install"
        [string]$FEATURES="SQLENGINE"
        [string]$INSTANCENAME="MSSQLSERVER"
        [string]$SECURITYMODE="SQL"
        [string]$USEMICROSOFTUPDATE="False"
        [string]$ADDCURRENTUSERASSQLADMIN="False"
        [string]$AGTSVCSTARTUPTYPE='Automatic'      #Automatic | Manual | Disabled

        [string]$INSTANCEDIR=$AppDrive + ":\Program Files\Microsoft SQL Server"
        [string]$INSTALLSQLDATADIR=$AppDrive + ":\Program Files"

        [string]$INSTALLSHAREDDIR='C:\Program Files\Microsoft SQL Server'
        [string]$SQLCOLLATION='SQL_Latin1_General_CP1_CI_AS'
        [string]$SQLSVCINSTANTFILEINIT="True"
        [string]$SQLUSERDBDIR=$DataDrive + ":\MSSQL\Data"


        [string]$SQLUSERDBLOGDIR=$LogsDrive + ":\MSSQL\Logs"

        [string]$SQLBACKUPDIR=$AppDrive + ":\MSSQL\Backups"
        [string]$SQLTEMPDBDIR=$TempDBDrive + ":\MSSQL\TempDB"
        [string]$SQLTEMPDBLOGDIR=$TempDBDrive + ":\MSSQL\TempDB"
        [string]$SQLTEMPDBFILECOUNT=2
        [string]$SQLTEMPDBFILESIZE=32
        [string]$SQLTEMPDBFILEGROWTH=32
        [string]$TCPENABLED=1
        [string]$NPENABLED=1
        [string]$BROWSERSVCSTARTUPTYPE='Disabled'
        [string]$INDICATEPROGRESS

        $arguments = @(
            "/IACCEPTSQLSERVERLICENSETERMS"
            "/ACTION=" +$ACTION
            "/FEATURES=" + $FEATURES 
            "/INSTANCENAME=$INSTANCENAME"
            "/SECURITYMODE=$SECURITYMODE"

            "/USEMICROSOFTUPDATE=$USEMICROSOFTUPDATE"
            '/SAPWD=' + $SAPWD
            '/SQLSYSADMINACCOUNTS=' + $SQLSYSADMINACCOUNTS
            '/SQLSVCACCOUNT=' + $SQLSVCACCOUNT

            '/ADDCURRENTUSERASSQLADMIN="' + $ADDCURRENTUSERASSQLADMIN + '"'
            '/AGTSVCACCOUNT=' + $AGTSVCACCOUNT
            '/AGTSVCSTARTUPTYPE=' + $AGTSVCSTARTUPTYPE 
            '/INSTANCEDIR="' + $INSTANCEDIR + '"'
            '/INSTALLSQLDATADIR="' + $INSTALLSQLDATADIR +'"'

            '/INSTALLSHAREDDIR="' + $INSTALLSHAREDDIR + '"'
            '/SQLCOLLATION="' + $SQLCOLLATION + '"'
            '/SQLSVCINSTANTFILEINIT="' + $SQLSVCINSTANTFILEINIT + '"'
            '/SQLUSERDBDIR="' + $SQLUSERDBDIR + '"'
            '/SQLUSERDBLOGDIR="' + $SQLUSERDBLOGDIR + '"'

            '/SQLBACKUPDIR="' + $SQLBACKUPDIR + '"'
            '/SQLTEMPDBDIR="' + $SQLTEMPDBDIR + '"'
            '/SQLTEMPDBLOGDIR="' + $SQLTEMPDBLOGDIR + '"'
            '/SQLTEMPDBFILECOUNT=' + $SQLTEMPDBFILECOUNT
            '/SQLTEMPDBFILESIZE=' + $SQLTEMPDBFILESIZE

            '/SQLTEMPDBFILEGROWTH=' + $SQLTEMPDBFILEGROWTH
            '/TCPENABLED=' + $TCPENABLED
            '/NPENABLED=' + $NPENABLED
            '/BROWSERSVCSTARTUPTYPE=' + $BROWSERSVCSTARTUPTYPE 
            '/INDICATEPROGRESS'
        )

        $arguments
    #endregion Define Install Arguments


    write-host ""
    write-host "↑↑↑Please review ↑↑↑" -ForegroundColor $PromptColor
    write-host ""

    $Ask1 = Read-Continue -message "We're now ready to install SQL Server using the previous arguments !" -prompt "Would you like to proceed?" -Color $progressColor
    If (($ask1 -eq "") -or ($ask1 -eq "N")) {
        break
        }

    #region Install SQL Server
        write-host ""
        write-host ""
        write-host "Beginning SQL Server Install from:
    $iso_diskImagePath" -ForegroundColor $ProgressColor

        #Mount Disk Image and capture the output object using -PassThru
            $mountedDisk = Mount-DiskImage -ImagePath $iso_diskImagePath -PassThru

            $mountedDriveLetter = ($mountedDisk | Get-Volume).DriveLetter + ":"

        #Path to Setup.exe
            $PathTosetupExe = Join-path $mountedDriveLetter "Setup.exe"

        #Run the setup.exe with arguments
            Try {
                Start-Process -FilePath $PathTosetupExe -ArgumentList $arguments -wait -PassThru
                }
            Catch {
                write-host "SQL Server was NOT installed."-ForegroundColor $ErrorColor
                write-host $_
                }

        Try {
        #Dismount the Disk image
            Dismount-DiskImage -ImagePath $iso_diskImagePath

        #Cleanup
        rv mountedDisk
        rv mountedDriveLetter
        rv PathTosetupExe
        rv arguments
            }
        Catch {
            $_
            }

        Write-host "SQL Server Installation is complete, or cancelled." -foregroundcolor $ProgressColor
        write-host ""
#        write-host "We're now ready to install the downloaded CU path for SQL Server!" -ForegroundColor $progressColor
#        write-host ""

    #endregion Install SQL Server


    $ask1 = Read-Continue -message "We're now ready to install the downloaded CU path for SQL Server!" -prompt "Would you like to proceed?" -color $Progresscolor
    If (($ask1 -eq "") -or ($ask1 -eq "N")) {
        break
        }


    #region Install CU
        write-host ""
        write-host ""
        write-host "Beginning SQL Server CU Install from:
    $cu_updatePath" -ForegroundColor $ProgressColor

        $arguments = @(
            "/ACTION=Patch"
            "/AllInstances"
            "/qs"
            "/IAcceptSQLServerLicenseTerms"
            )

        Try {
            Start-Process $cu_updatePath -ArgumentList $arguments -Wait -PassThru
            }
        Catch {
            write-host "SQL CU was NOT installed correctly." -ForegroundColor $ErrorColor
            write-host $_ -ForegroundColor $errorcolor
            }

        Write-host "SQL Server CU Installation is complete, or cancelled." -foregroundcolor $ProgressColor
    #endregion Install CU

#endregion Installations


$ask1 = Read-Continue -message "

SQL Server installers have completed their work.

You should confirm the instance is running before continuing." -prompt "Would you like to proceed?" -color $ProgressColor
       If (($ask1 -eq "") -or ($ask1 -eq "N")) {
        break
        }


##
##
##  20251205 Tested to here!
##
##



#region Configure SQL Server
    $TargetServer = Connect-DbaInstance -SqlInstance $TargetName -TrustServerCertificate

    #Source enable remote admin
        #Some commands require DAC (dedicated access control) on the Source 
            Invoke-Sqlcmd -ServerInstance $SourceServer.name -Database master -Query "EXEC sp_configure 'remote admin connections', 1" -TrustServerCertificate
            Invoke-Sqlcmd -ServerInstance $SourceServer.name -Database master -Query "RECONFIGURE" -TrustServerCertificate

    #Allow Ole Automation
            Invoke-Sqlcmd -ServerInstance $targetserver.name -Database master -Query "EXEC sp_configure 'show advanced options', 1" -TrustServerCertificate
            Invoke-Sqlcmd -ServerInstance $TargetServer.name -Database master -Query "RECONFIGURE" -TrustServerCertificate
            Invoke-Sqlcmd -ServerInstance $targetserver.name -Database master -Query "EXEC sp_configure 'Ole Automation Procedures', 1" -TrustServerCertificate
            Invoke-Sqlcmd -ServerInstance $TargetServer.name -Database master -Query "RECONFIGURE" -TrustServerCertificate


    #region SQL Config

        #region Copy SQL Server Logins
            # Copy Enabled, non-system Logins
            $sourceLogins = Get-DbaLogin -SqlInstance $SourceServer -ExcludeSystemLogin -ExcludeFilter "NT *" | Where-Object IsDisabled -Like "False" 
            $Sourcelogins | Copy-DbaLogin -Destination $TargetServer #-WhatIf
         #endregion Copy SQL Server Logins

        #region Copy Credentials
            Copy-DbaCredential -Source $sourceServer -Destination $targetServer
        #endregion Copy Credentials

        #region Linked Servers

            # Requires SQL Browser service?

                #Start SQL Browser service
                #Start-DbaService -ComputerName $SourceServer,$TargetServer -Type Browser  -ErrorAction stop -WarningAction Continue -InformationAction Continue

                #Copy linked Servers
                Copy-DbaLinkedServer -Source $sourceServer -Destination $TargetServer -UpgradeSqlClient

                #Stop SQL browser service
                #Stop-DbaService -ComputerName $sourceServer, $TargetServer -Type Browser -ErrorAction stop -WarningAction Continue -InformationAction Continue

        #endregion Linked Servers

        #region SQL Agent Objects
            # https://docs.dbatools.io/Copy-DbaAgentServer
            # Copies all SQL Server Agent objects and server properties between instances.
            # Incl: Jobs, Opoerators, Alerts, Schedules, Job Categories, Proxies, and SQL Agent Properties
        
            Copy-DbaAgentServer -Source $sourceServer -Destination $TargetServer
        #endregion SQL Agent Objects

    #endregion SQL Config

#endregion Configure SQL Server


break


#region Copy Databases
    [string]$sharedPath = '\\' + $TargetServer.name + '\D$\temp\for_restore'
    write-host "Copying databases using local share:" $sharedPath -ForegroundColor $ProgressColor

    $p1 = get-date
    write-host $p1 " - Starting database migrations..." -ForegroundColor $ProgressColor
     
    Copy-DbaDatabase -Source $SourceServer `
                -Destination $TargetServer `
                -AllDatabases -ExcludeDatabase Login_Audit `
                -BackupRestore `
                -SharedPath $sharedPath


   Copy-DbaDatabase -Source $SourceServer `
                -Destination $TargetServer `
                -database _DBAAdmin, Login_audit `
                -BackupRestore `
                -SharedPath $sharedPath

    $p2 = get-date
    write-host $p2 " - Database migration completed..." -ForegroundColor $ProgressColor
    write-host ($p2 - $p1).Minutes " minute(s) total time." -ForegroundColor $ProgressColor


    Set-DbaDbCompatibility -SqlInstance $TargetServer -ErrorAction Continue -WarningAction Continue

    
#    Remove-DbaDatabase -SqlInstance $targetServer -Database Test_StudentProcessingcI -Confirm


#endregion Copy Databases




