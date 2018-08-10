$VerbosePreference = "SilentlyContinue"
$searchForGoods = $false
$shares = $null
$results = $null
$computers = $null

# Choose One Below
# Use AD Requires Active Directory Module Installed
#$computers = (Get-ADComputer -Filter{name -like '*'}).Name 

# Use Net View Discovery
$computers = (net view | Select-String -Pattern '(?<=^\\\\)\w+').Matches.Value

#Targeted Computers, Cifs Servers, NAS etc
$computers = ""

cls


function Write-ToScreen{
[cmdletbinding()]
Param
(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Prefix','Title','Main')]
        $Type,
        
        
        [Parameter(Mandatory=$false)]
        [string]
        $Message,

        		[Parameter(Mandatory=$false)]
        [INT]
        $IndentCount
        
)    
    # Needed for [Parameter(ValueFromPipeline = $true,Mandatory=$true)]
    PROCESS
    {
        if(!$IndentCount){$IndentCount = 0}
		#Make sure you change this to match the [ValidateSet('Option1','Option2')] $Param3 above
        switch ($Type)
        {
            'Prefix' 
            {
                for ($i = 0; $i -lt $IndentCount; $i++)
                { 
                    $indent += "`t"
                }
                write-host -NoNewline -ForegroundColor Cyan "$($indent)["
                write-host -NoNewline -ForegroundColor Yellow '*' 
                write-host -NoNewline -ForegroundColor cyan '] - ' 
            }
            'Title' 
            {
                write-host -ForegroundColor Yellow "$message"
            }
            'Main' 
            {
                write-host $message
            }
            Default 
            {
                #Set Default
            }
        }					
    }    
}




Write-ToScreen -Type Title -Message "Searching with Net view"


$results = @()

foreach($computer in $computers)
{     
    Write-ToScreen -Type Prefix
    Write-ToScreen -Type Main -Message $computer    
    
    try{
        #computer accessible
        if (Test-Connection $computer -Count 1 -Quiet)
        {
            # get shares
            $shares = (net view $computer | Select-String -Pattern '.*(?=\s*Disk)').Matches.Value

            # If shares returned
            If($shares){
                # Enumerate shares and test for access
                Write-ToScreen -Type Prefix -IndentCount 1
                Write-ToScreen -Type Main -Message "Enumerating Shares"
                
                foreach ($share in $shares) 
                {                
                    $share = $share.trim()
                    $result = "" | Select-Object Computer, Share, Path, AccessResult
                    $result.Computer = $computer
                    $result.Share = $share
                    $result.AccessResult =(Test-Path \\$computer\$share\*)
                    $result.Path = $("\\$computer\$share")
                    
                    $results += $result
                    #$result
                    if($result.AccessResult){
                        Write-ToScreen -IndentCount 1 -Type Prefix                
                        Write-ToScreen -Type Main -Message $result.Path
                    }
                }
            }            
        }
    }
    catch{
        #swallow errors for now
        $_.exception
    }
}

#search for passwords in .Config files
if($results -and $searchForGoods)
{

    Write-Host "`n`n"
    Write-ToScreen -Type Title -Message "Searching for Intresting Data"
    foreach ($item in $results)
    {       
        $theGoods = Get-ChildItem $item.path -recurse -Include "*.Config","*.txt","*.settings" | select-string "password=||pw=||pass="
        if($theGoods){
            foreach ($pw in $theGoods)
            {
                Write-ToScreen -Type Main -Message $pw           
            }        
        }
    }

    $results.ForEach( { Get-ChildItem $item.path -recurse -Include "*.Config","*.txt","*.settings" | select-string "password=||pw=||pass=" } )

    #$results | Where-Object{$_.AccessResult -eq "True"} |  Out-GridView

}
else{
    Write-Host "`n`n"
    Write-ToScreen -Type Title "Recon Results"
    Write-ToScreen -Type Prefix 
    Write-ToScreen -Type Main -Message "Recon Completed"
    Write-ToScreen -Type Prefix -IndentCount 1
    Write-ToScreen -Type Main -Message "Computers Found: $($Computers.Count)" -IndentCount 1
    Write-ToScreen -Type Prefix -IndentCount 1
    Write-ToScreen -Type Main -Message "Shares Found: $($results.Count)"  -IndentCount 1
    Write-ToScreen -Type Prefix -IndentCount 1
    Write-ToScreen -Type Main -Message "Accessable Shares Found: $(($results | where{$_.AccessResult}).Count)"  -IndentCount 1
}
