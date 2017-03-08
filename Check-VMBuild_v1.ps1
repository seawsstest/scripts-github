#Prompted Variables 
$cmp = Read-Host "Enter short name of server you are checking in lowercase: "
$adm = Read-Host "Enter your cnetID"
#TODO  Add prompt for SA credentials, needed to connect to server to get AV info

#Constructed variables
$ct = $cmp.ToString().Length
$srch = $cmp.ToString().Insert($ct, "*")
$fqdn = $cmp.ToString().Insert($ct,".uchicago.edu")
#TODO Change AV config path to SA user documents folder
$avConfigPath = "C:\Users\_sa-cjhaselton\Documents\avinfo.xml"
$smc = "C:\Program Files (x86)\Symantec\Symantec Endpoint Protection\12.1.7061.6600.105\
Bin\smc.exe -exportconfig C:\Users\_sa-cjhaselton\Documents\avinfo.xml"

# Admin group check
Write-Host ""
Write-Host "Checking for AD local administration group..." -ForegroundColor Yellow
$grp = Get-ADGroup -Filter 'Name -like $srch'
if($grp)
    {
        Write-Host "Check successful. Group $grp.Name exists." -ForegroundColor Green
    }
else
    { Write-Host "Check failed.  Administrative group does not exist." -ForegroundColor Red}

# Get SCCM/SCOM registry key check
Write-Host ""
Write-Host "Checking for SCOM and SCCM registry keys..." -ForegroundColor Yellow
$reg = (Invoke-Command -ComputerName $fqdn -ScriptBlock {Get-Item -Path HKLM:HKEY_LOCAL_MACHINE\SOFTWARE\ITS})
if($reg.Name)
    {
        $mb = Get-ItemProperty $reg.PSPath -Name ManagedBy
        $env = Get-ItemProperty $reg.PSPath -Name WINDOWS
        Write-Host "Check successful" -ForegroundColor Green
        Write-Host "ManagedBy: " -NoNewline -ForegroundColor Green
        Write-Host $mb.ManagedBy
        Write-Host "Environment: " -NoNewline -ForegroundColor Green
        Write-Host $env.WINDOWS
    }
else
    { Write-Host "Check failed. SCCM registry keys not found." -ForegroundColor Red}

#SCOM Install Check
Write-Host ""
Write-Host "Checking for SCOM Agent Install..."
$mgmtsrvr = Read-Host "Enter name of SCOM management host.  Options are 'scomms1 and scomms2'"

New-SCOMManagementGroupConnection -ComputerName $mgmtsrvr -ErrorAction Stop
$cag = get-ScomAgent -SCSession (Get-SCOMManagementGroupConnection) | Where Name -EQ $fqdn

if($cag)
    {
        Write-Host "SCOM agent installed successfully on $fqdn" -ForegroundColor Green
        Write-Host "Health State of agent: " -NoNewline
        Write-Host $cag.HealthState -ForegroundColor Green
        Write-Host "Primary management server for agent: " -NoNewline
        Write-Host  $cag.GetPrimaryManagementServer().DisplayName -ForegroundColor Green
    }
else
    {Write-Host "SCOM agent was not installed on $fqdn." -ForegroundColor Red}


#SCCM Patch Group Check
Write-Host ""
Write-Host "Checking SCCM patch group membership..." -ForegroundColor Yellow

cd CMW:
$ccmp = $cmp.ToUpper()

$dev = @()
$prd = @()

$dev = Get-CMDeviceCollection | ?{$_.name -like "*Dev/Test*"} 
$prd = Get-CMDeviceCollection | ?{$_.name -like "*Production*"}


write-host ""
Write-Host ""
write-host "Select from following options:" -ForegroundColor Magenta
write-host ""
Write-Host "1 - Server is Dev/Test" -ForegroundColor Magenta
Write-Host "2 - Server is Production" -ForegroundColor Magenta
Write-Host ""
$g = Read-Host "Enter option number: "
$col = @()
switch($g)
{
 "1" {foreach ($d in $dev)
        {
        $chk = (Get-CMDeviceCollection -Name $d.name | Get-CMCollectionMember | select -ExpandProperty name)
        $grp = $d.Name
        if($chk -contains $ccmp)
        {
            write-host ""
            Write-Host "$ccmp is a member of $grp" -ForegroundColor Green
            $col += $chk
        }#end if
        else
        {
            $col += $chk
        }#end else
        }#end for
        if($col -notcontains $ccmp)
            {
                 Write-Host "Check failed. $ccmp is not a member of any SCCM test groups." -ForegroundColor Red
            }
        } #end 1

 "2" {foreach ($p in $prd)
        {
        $chk = Get-CMDeviceCollection -Name $p.name | Get-CMCollectionMember | select -ExpandProperty name
        $grp = $p.Name
        if($chk -contains $ccmp)
        {
            write-host ""
            Write-Host "$ccmp is a member of $grp" -ForegroundColor Green
            $col += $chk
        }#end if
        else
        {
            $col += $chk
        }#end else
        }#end for
        if($col -notcontains $ccmp)
            {
                 Write-Host "Check failed. $ccmp is not a member of any SCCM production groups." -ForegroundColor Red
            }
        } #end 2
}# end switch
cd C:


#SCCM ManagedBy Group check
Write-Host ""
Write-Host "Checking membership in SCCM ManagedBy group..." -ForegroundColor Yellow
{
    cd CMW:

    $ccmp = $cmp.ToUpper()
    $mb = Get-CMDeviceCollection | ?{$_.name -like "*ManagedBy*"}
    $col = @()
    foreach($m in $mb)
        {
            $chk = Get-CMDeviceCollection -Name $m.name | Get-CMCollectionMember | Select -ExpandProperty name
            $grp = $m.name
            if($chk -contains $ccmp)
            {
                Write-Host "Check succeeded.  $ccmp is a member of $grp" -ForegroundColor Green
                $col += $chk
            }
            else
            {
                $col += $chk
            }
        }# end for
        if($col -notcontains $chk)
        {
            Write-Host "Check failed.  $ccmp is not a member of any ManagedBy groups." -ForegroundColor Red
        }

}


#Local Administrator account rename and password change check
Write-Host ""
Write-Host "Checking local administrator name and password change" -ForegroundColor Yellow
{
Add-Type -AssemblyName System.DirectoryServices.AccountManagement

$un="$cmp\pmccrackin"
$pw = Read-Host -Prompt "Enter local administrator password for $cmp" -AsSecureString
$crds = New-Object System.Management.Automation.PSCredential -ArgumentList $un, $pw
$np = $crds.GetNetworkCredential().Password

$pc = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$cmp)
$rst = $pc.ValidateCredentials($un,$np)
if($rst)
    { Write-Host "Credentials for $cmp were validated successfully" -ForegroundColor Yellow}
else
    { Write-Host "Either the username, password or both are incorrect for $cmp." -ForegroundColor Red}
}

# Installed patches check
Write-Host ""
Write-Host "Checking for patches waiting to be installed..." -ForegroundColor Yellow


Write-Verbose "Computer: $($fqdn)" 
        If (Test-Connection -ComputerName $fqdn -Count 1 -Quiet) 
        { 
            Try { 
            #Create Session COM object 
                Write-Verbose "Creating COM object for WSUS Session" 
                $updatesession =  [activator]::CreateInstance([type]::GetTypeFromProgID("Microsoft.Update.Session",$c)) 
                } 
            Catch { 
                Write-Warning "$($Error[0])" 
                Break 
                }
        }

        #Configure Session COM Object 
         $updatesearcher = $updatesession.CreateUpdateSearcher() 
         #Configure Searcher object to look for Updates awaiting installation 
         Write-Host "Searching for WSUS updates on client" -ForegroundColor Yellow
         $searchresult = $updatesearcher.Search("IsInstalled=0")
         If ($searchresult.Updates.Count -gt 0) 
         { 
          #Updates are waiting to be installed
          Write-Host "Check failed.  $($searchresult.Updates.Count) updates need to be installed." -ForegroundColor Red
         }  
         else
         {
            Write-Host "Check succeeded. $($searchresult.Updates.Count) patches waiting to be installed" -ForegroundColor Green   
         }  

Write-Host ""
Write-Host "Checking for 2012/2012 R2 WSUS scheduling reboot fix..." -ForegroundColor Yellow
cd 
$WSUSreg = (Invoke-Command -ComputerName $fqdn -ScriptBlock {Get-ItemProperty -Path HKLM:HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU})
if($WSUSreg.UseWUServer -eq 1)
    {
        Write-Host "Check successful.  UseWUServer key exists and has value of 1" -ForegroundColor Green
    }
else
    { Write-Host "Check failed. WSUS scheduling registry key not found." -ForegroundColor Red}


# Symantec install/configure check

