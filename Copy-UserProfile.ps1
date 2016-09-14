<#
.DESCRIPTION
This script is designed to automate the process of copying a user profile
from one machine to another over the network.
.PARAMETER RemoteComputer
Enter the hostname or IP address of the remote computer were the profile is
stored.
.PARAMETER ProfileName
Enter the LL user name of user whose data you wish to copy.
.EXAMPLE
Copy-MTUserProfile -RemoteComputer GBLSSC0214 -ProfileName terhutch
This will copy the profile data for the user 'terhutch' from the computer GBLSSC0214
to the local computer that the script is run from.
#>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   HelpMessage='Enter the name or IP address of the users current machine')]
        [ValidateScript({Test-Connection $_ -Quiet -Count 1})]
        [ValidateNotNullOrEmpty()]
        [string]$RemoteComputer,

        [Parameter(Mandatory=$true,
                   HelpMessage='Enter the users LL username')]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName
    )

    BEGIN
    {
        $VerbosePreference = 'Continue'
        $UserName = Read-Host -Prompt 'Enter the local administrator username for the remote computer'
        $UserName = Join-Path $RemoteComputer -ChildPath $UserName
        $Password = Read-Host -Prompt 'Enter the local administrator password for the remote computer' -AsSecureString
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $Password
        $LocalProfile = "$env:USERPROFILE\"
        $RemoteUNC = "\\$RemoteComputer\"
        Write-Verbose "Remote UNC path: $RemoteUNC"
    
        $Drives = @('D$', 'C$')

        foreach ($Drive in $Drives)
        {
            try
            {
                Write-Verbose 'Testing for the existence of a dual partitions'
                Test-Path -Path "$RemoteUNC$Drive\Users\$ProfileName" `
                          -ErrorAction Stop | Out-Null
            }
            catch
            {
                $RemoteUNC = "$RemoteUNC$Drive\Users\$ProfileName"
                Write-Verbose "Partition to be used is $Drive"
                break
            }
        }
        
        $Letters = (65..90 | foreach {[char]$_})
        $Letters = $Letters | foreach {$_.ToString()}
        
        Write-Verbose 'Testing for existing mapped drives'
        foreach ($Letter in $Letters)
        {
            $PSDrive = Get-PSDrive
            if (($PSDrive.Name -ne $Letter) -and ($PSDrive.DisplayRoot -ne $RemoteUNC))
            {
                try
                {
                    Write-Verbose "Attempting to map $($Letter.Insert(1,':'))"
                    $DriveMap = New-PSDrive -Name $Letter `
                                            -PSProvider FileSystem `
                                            -Root $RemoteUNC `
                                            -Scope Script `
                                            -Credential $Credential `
                                            -Persist `
                                            -ErrorAction Stop
                }
                catch
                {
                    $Err = $_
                    Write-Warning $Err.Exception.Message
                }
                if ($DriveMap.DisplayRoot -eq $RemoteUNC)
                {
                    Write-Verbose "$($Letter.Insert(1,':')) Drive mapped successfully"
                    $DL = $Letter.Insert(1,':\')
                    break
                }
            elseif ($PSDrive.DisplayRoot -eq $RemoteUNC)
            {
                Write-Verbose 'Drive already mapped'
                $DL = $Letters.Insert(1,':\')
                break
            }
            }
            else
            {
                Write-Output "$Letter drive found. Trying another letter"
            }
        }
    
        $Paths = @{
                        'Desktop'=$DL+"Desktop";
                        'Downloads'=$DL+"Downloads";
                        'Documents'=$DL+"Documents";
                        'Favourites'=$DL+"Favorites";
                        'Links'=$DL+"Links";
                        'Music'=$DL+"Music";
                        'Pictures'=$DL+"Pictures";
                        'Videos'=$DL+"Videos";
                  }

        foreach ($Key in $($Paths.Keys))
        {
            Write-Verbose "Testing for the existence of $Key folder"       
            if (-not (Test-Path -Path $Paths[$Key]))
            {
                Write-Verbose "$Key folder not found. Removing entry from hash table"
                $Paths.Remove($Key)
            }
            else
            {
                Write-Verbose "$Key folder found"
            }
        }
    }
    PROCESS
    {
        Write-Host -ForegroundColor Green "`nStarting ROBOCOPY"
        foreach ($Key in $Paths.Keys)
        {
            Write-Host -ForegroundColor Red "Copying $Key"
            Robocopy $Paths[$Key] $($LocalProfile+$Paths[$Key].Split('\')[1]) /MIR /XA:SH /XJD /R:10 /W:2 /MT:32 /V /NP /LOG+:$($LocalProfile)Desktop\CopyUserProfile.txt
        }
    }
    END
    {
        Write-Host -ForegroundColor Green 'Command ran successfully'
        Write-Warning 'Please view the logfile to verify all data has been successfully transfered'
    }
