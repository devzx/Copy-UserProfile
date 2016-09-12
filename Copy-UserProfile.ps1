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
        [string]$RemoteComputer,

        [Parameter(Mandatory=$true,
                   HelpMessage='Enter the users LL username')]
        [string]$ProfileName
    )

    BEGIN
    {
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
                Test-Path -Path "$RemoteUNC$Drive\Users\$ProfileName"  -ErrorAction Stop
            }
            catch
            {
                $RemoteUNC = "$RemoteUNC$Drive\Users\$ProfileName"
                Write-Verbose "Partition to be used is $Drive"
                break
            }
        }
        Write-Debug 'Test REMOTEUNC VARIABLE'
        
        $Letters = (65..90 | foreach {[char]$_})
        $Letters = $Letters | foreach {$_.ToString()}
            
        foreach ($Letter in $Letters)
        {
            $PSDrive = Get-PSDrive
            if ($PSDrive.Name -ne $Letter)
            {
                try
                {
                    Write-Debug 'Try to create new PSDrive'
                    New-PSDrive -Name $Letter `
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
                
                $DL = $Letter.Insert(1,':\')
                $DL
                break
            }
        }
        Write-Verbose 'Drive mapping succesfully created'
        Write-Debug 'Drive Successfully Mapped'
    
        $Paths = @{
                        'Desktop'=$DL+"Desktop";
                        'Downloads'=$DL+"Downloads";
                        'Documents'=$DL+"Documents";
                        'Favourites'=$DL+"Favorites";
                        'Links'=$DL+"Links";
                        'Music'=$DL+"Music";
                        'Pictures'=$DL+"Pictures";
                        'Videos'=$DL+"Videos";
                        'StickyNotes'=$DL+"AppData\Roaming\Microsoft\Sticky Notes"
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
                Write-Verbose "$Key folder found."
            }
        }
    }
    PROCESS
    {
        Write-Debug 'Pre Robocopy'
        
        foreach ($Key in $Paths.Keys)
        {
            Robocopy $Paths[$Key] $($LocalProfile+$Paths[$Key].Split('\')[1]) /MIR /XA:SH /XJD /R:10 /W:2 /MT:32 /V /NP /LOG+:$($env:USERPROFILE)\Desktop\CopyUserProfile.txt
        }
        Write-Debug 'Post Robocopy'
    }
    END
    {
        Write-Output 'Command ran successfully.'
        Write-Output "Please view the logfile to verify data has been successfully transfered"
    }
