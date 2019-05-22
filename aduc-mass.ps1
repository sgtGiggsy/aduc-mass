### Language ###
$sysloc = Get-WinSystemLocale
if ($sysloc.Name -eq "hu-HU")
    {
        $lang = Get-Content ".\Languages\hun.lang" | Out-String | ConvertFrom-StringData
    }
else
    {
        $lang = Get-Content ".\Languages\eng.lang" | Out-String | ConvertFrom-StringData
    }
try    
{
    $ErrorActionPreference = "Stop"
    $config = Get-Content ".\config.ini" | Out-String | ConvertFrom-StringData
}
catch
{

}


### Pre-run checks ###

# First check. It doesn't let the user continue, if they doesn't have ActiveDirectory module installed. As the program heavily relies on AD module, it makes no sense to try it without that.
if (!(Get-Module -ListAvailable -Name ActiveDirectory)) 
    {
        try {
            $ErrorActionPreference = "Stop"
            Import-Module .\Microsoft.ActiveDirectory.Management.dll
            Import-Module .\Microsoft.ActiveDirectory.Management.resources.dll
        }
        catch {
            Write-Host "$($lang.ad_module_not_installed)`n$($lang.dlls_missing)`n$($lang.program_exits)" -ForegroundColor Red
            Read-Host
        break
        }
    } 

# Second check. It warns the user if they try to run the program with user level rights. Most functions work without admin rights, but it still worth to notify the user about it.
$admine = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (!($admine.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))
    {
        Clear-Host
        $title = "$($lang.title_user)`n"
        Write-Host $title`n$($lang.warning)`n`n$($lang.warn_not_admin)`n$($lang.wont_have_rights)`n`n$($lang.run_anyway) -ForegroundColor Yellow
        $admin = $false
        Read-Host
    }
else 
    {
        $title = "$($lang.title_admin)`n"
        $admin = $true
        $title
    }

if ($config.savepath)
{
    $script:path = $config.savepath
}
else
{
    $script:path = "D:\AD-Out" # The root of the default save path for csvs.
}

#-#-# ENUMS #-#-#

# Enums to index filters in the filters menu by letters, so it won't get mixed up with attributes.
# There's probably a better way to index them by letters, but it works for now.
# It's only as far as "G" because "H" is used for help menu, and pobably 7 filters are enough.
enum Filterindex
{
    a = 0
    b = 1
    c = 2
    d = 3
    e = 4
    f = 5
    g = 6
}

#-#-# CLASSES #-#-#

# Class to handle CSV functions, like creating the save directory, naming the files,
# and placing the pipeline output into it. It isn't used at the moment, as I haven't rewrite the parts,
# that call for the functions that were fromerly used for the same thing.
class CSV
{
    $csvdir
    $out
    CSV($csvdir)
    {
        $this.csvdir = $csvdir
        $csvpath = "$script:path\$csvdir"
        if(!(Test-Path -Path $csvpath))
        {
            try 
            {
                New-Item -ItemType directory -Path $csvpath | Out-Null    
            }
            catch
            {
                Write-Host $script:lang.directory_cant_be_created -ForegroundColor Red    
            }
        }
    }

    [string]Outfile($csvname)
    {
        $this.out = "$($this.csvdir)\$csvname.csv"
        return $this.out
    }

    Saveto($bemenet, [bool]$noout)
    {
        if ($null -ne $bemenet) # This checks if there is actual output from the pipeline
        {
            try
            {
                $bemenet | export-csv -encoding Unicode -path $this.out -NoTypeInformation
            }
            catch
            {
                if ($noout -eq $false)
                {
                    Write-Host "`n$($script:lang.file_not_created)" -ForegroundColor Red # Warning if the file can't be created
                }        
            }
        }
        else
        {
            $script:lang.object_not_consist | Set-Content $this.out # This writes a default value in created csvs if the pipeline was empty
        }

        if(Test-Path -Path $this.out) # This tests if the file exist, notifies the user about it, and puts the separator part at the first line, in case csvs with comma separators aren't automatically recognized by Excell as spreadheets
        {
            if ($noout -eq $false)
            {
                Write-Host "`n$($script:lang.file_is_created)" $this.out -ForegroundColor Green
            }
            "sep=,`n"+(Get-Content $this.out -Raw) | Set-Content $this.out            
        }
    }
}

class Filterpairs
{
    $trueside
    $truesidename
    $falseside
    $falsesidename
    $state = 0

    Filterpairs($trueside, $truesidename, $falseside, $falsesidename)
        {
            $this.trueside = $trueside
            $this.truesidename = $truesidename
            $this.falseside = $falseside
            $this.falsesidename = $falsesidename
        }

    Out($char)
        {
            $pointer = $null
            switch ($this.state) 
            {
                0 { $pointer = "[ ] [*] [ ]" }
                1 { $pointer = "[*] [ ] [ ]" }
                2 { $pointer = "[ ] [ ] [*]" }
            }
            Write-Host $("({0}) {1, 23} {2} {3}" -f $char, $this.truesidename, $pointer, $this.falsesidename) -NoNewline
        }

    Set($isuser)
        {
            if ($this.state -eq 2)
            {
                $this.state = 0
            }
            else
            {
                $this.state++
            }
        }
    [string]Outmethod()
        {
            if ($this.state -eq 1)
            {
                return $this.trueside
            }
            elseif ($this.state -eq 2)
            {
                return $this.falseside
            }
            else 
            {
                return $null
            }
        }
}

class Attribute
{
    $name
    $attribute
    [bool]$setter

    Attribute($name, $attribute)
        {
            $this.name = $name
            $this.attribute = $attribute
        }
    $outmethod = "@{n='$name'; e='$attribute'}"

    Out($sorsz)
        {
            $sorsz = ++$sorsz
            if ($this.setter)
            {
                Write-Host "`r[*] " -NoNewline
            }
            else 
            {
                Write-Host "`r[ ] " -NoNewline
            }
            Write-Host $("{0, 4} {1, -47}" -f "($sorsz)", $this.name) -NoNewline
        }
    Set()
        {
            if ($this.setter)
            {
                $this.setter = $false
            }
            else
            {
                $this.setter = $true
            }
        }
}

class OUfilter
{
    [bool]$state
    $ou
    Out($char)
    {
        if ($this.state)
        {
            Write-Host $("({0}) Choosen OU: {1}" -f $char, $Script:ounev) -NoNewline
        }
        else 
        {
            Write-Host $("({0}) OU is not set" -f $char) -NoNewline
        }
    }

    Set($isuser)
    {
        Write-Host
        if ($this.state)
        {
            Write-Host $script:lang.unset_ou
            $yousure = Read-Host -Prompt $script:lang.choose
            if ($yousure -eq $script:lang.yes_char)
            {
                $this.state = $false
            }
        }
        else
        {
            $vane = $true
            do
            {
                $this.ou = OUcheck
                $ounev = $Script:ounev                

                if ($isuser)
                {
                    $teszt = Get-ADUser -Filter * -SearchBase $this.ou
            
                    if($teszt.Length -eq 0)
                    {
                        Write-Host $script:lang.no_users_in_ou "`n" -ForegroundColor Red
                        $vane = $false                        
                    }
                }
                else 
                {
                    $teszt = Get-ADComputer -Filter * -SearchBase $this.ou
            
                    if($teszt.Length -eq 0)
                    {
                        Write-Host $script:lang.no_computers_in_ou "`n" -ForegroundColor Red
                        $vane = $false                        
                    }
                }                    
            } while ($vane -eq $false)
            $this.state = $true
        }
    }

    [string]Outmethod()
    {
        return $this.ou
    }
}

class QueryFiltering
{
    $isuser
    $issingle
    $menutitle
    $objname
    $setter
    $filters
    $attributes
    QueryFiltering($isuser, $issingle, $menutitle, $objname)
    {
        $this.isuser = $isuser
        $this.issingle = $issingle
        $this.menutitle = $menutitle
        $this.objname = $objname
        $this.filters = New-Object System.Collections.ArrayList($null)
        $this.attributes = New-Object System.Collections.ArrayList($null)
        $this.Paramlist($this.filters, $this.attributes)        
    }

    Paramlist($filters, $attributes)
    {        
        # Filters. We need them only if we want to query more users, so they won't show up when querying one user
        if (!($this.issingle))
        {        
            $filters.Add(($script:lastlogonfilter = [Filterpairs]::new(($active = "{LastLogonTimeStamp -gt $($this.time)}"),$script:lang.active_ones,($inactive = "{LastLogonTimeStamp -lt $($this.time)}"),$script:lang.inactive_ones))) > $null
            $filters.Add(($isenabled = [Filterpairs]::new(("{Enabled -eq True}"),$script:lang.enabled,($isdisabled = "{Enabled -eq False}"),$script:lang.disabled))) > $null
            $filters.Add(($oufilter = [OUfilter]::new())) > $null
        }
        $attributes.Add(($lastlogon = [Attribute]::new($script:lang.last_logon, "LastLogonDate"))) > $null
        $attributes.Add(($enabled = [Attribute]::new($script:lang.enabled, "enabled"))) > $null
        $attributes.Add(($description = [Attribute]::new($script:lang.description, "Description"))) > $null
        $attributes.Add(($created = [Attribute]::new($script:lang.created, "created"))) > $null
        if(!($this.isuser))
        {
            $attributes.Add(($os = [Attribute]::new($script:lang.os, "OperatingSystem"))) > $null
            $attributes.Add(($computername = [Attribute]::new($script:lang.computername, "Name"))) > $null
            $attributes.Add(($IPv4Address = [Attribute]::new($script:lang.IPv4Address, "IPv4Address"))) > $null
            $attributes.Add(($logoncount = [Attribute]::new($script:lang.logoncount, "logoncount"))) > $null
        }
        else
        {
            $attributes.Add(($telnumber = [Attribute]::new($script:lang.telephoneNumber, "telephoneNumber"))) > $null
            $attributes.Add(($company = [Attribute]::new($script:lang.Company, "Company"))) > $null
            $attributes.Add(($department = [Attribute]::new($script:lang.department, "Department"))) > $null
            $attributes.Add(($name = [Attribute]::new($script:lang.name, "Name"))) > $null
            $attributes.Add(($logonWorkstation = [Attribute]::new($script:lang.logonWorkstation, "logonWorkstation"))) > $null
            $attributes.Add(($mail = [Attribute]::new($script:lang.mail, "mail"))) > $null
            $attributes.Add(($title = [Attribute]::new($script:lang.title, "title"))) > $null
        }
    }

    Menu()
    {
        do
        {
            Clear-Host
            if($this.isuser -and $this.issingle)
            {
                Write-Host $this.objname.Name $script:lang.user_is_being_queried
            }
            Write-Host $script:lang.attributes_and_filters"`n"
            if (!($this.issingle))
            {
                Write-Host $("{0, -55} {1}" -f $script:lang.available_attribs, $script:lang.available_filters)
            }
            else
            {
                Write-Host $script:lang.available_attribs
            }
            [array]$opciok = $null
            [array]$functionexplanation = ($script:lang.funcexptitle, <#$lang.custom_attrib_title, $lang.custom_filter_title,#> $script:lang.funchelp, $script:lang.funcfinish)
            $j = 0
            for ($i = 0; $i -lt $this.attributes.Count; $i++)
            {
                if($i -lt $this.filters.Count)
                {
                    Write-Host $this.attributes[$i].Out($i) $this.filters[$i].Out([Filterindex]$i)
                    $opciok += ($i +1)
                    $opciok += [Filterindex]$i
                }
                elseif($i -gt ($this.attributes.Count-$functionexplanation.count-1))
                {
                    Write-Host $this.attributes[$i].Out($i) -nonewline
                    Write-Host $functionexplanation[$j] -ForegroundColor Gray
                    $j++
                    $opciok += ($i +1)
                }
                else
                {
                    Write-Host $this.attributes[$i].Out($i)
                    $opciok += ($i +1)
                }
            }
            $opciok += "K"
            $opciok += "H"
            $opciok += $script:lang.attribute
            $opciok += $script:lang.filter

            $this.setter = Valaszt($opciok)
            switch ($this.setter)
                {
                    K { }
                    H { Read-Host $script:lang.attribselectmain_help }
                    $script:lang.attribute { Createcustom($this.setter) }
                    $script:lang.filter { Createcustom($this.setter) }
                    Default 
                    {
                        try
                        {
                            [int32]$this.setter
                            $this.attributes[$this.setter-1].Set()
                        }
                        catch
                        {
                            $this.filters[[Filterindex]::($this.setter).value__].Set($this.isuser)
                        }
                    }
                }    
        }while($this.setter -ne "K")
    }

    Output()
    {
        $properties = "samAccountname"
        $select = "@{n='$($script:lang.username)'; e='samAccountName'}"
        $filter = $null | Out-Null
        $searchbase = $null
        $time = $null
        
        if ($script:lastlogonfilter.state -ne 0 -and $this.issingle -eq $false)
        {
            Write-Host $script:lang.youset_day_filter
            do
            {   
                try
                {
                    [int32]$time = Read-Host -Prompt $script:lang.youset_daynumber
                }
                catch
                {
                    Write-Host $script:lang.non_numeric_value -ForegroundColor Red
                }
            } while(!($time -is [int32]))
            $script:lastlogonfilter.trueside = "{LastLogonTimeStamp -gt $time}"
            $script:lastlogonfilter.falseside = "{LastLogonTimeStamp -lt $time}"
        }

        for($i = 0; $i -lt $this.attributes.Count; $i++)
        {
            if($this.attributes[$i].setter)
            {
                $properties = $properties + ", " + $this.attributes[$i].attribute
                $select = $select + ", " + $this.attributes[$i].outmethod
            }
        }

        $filtercount = 0
        $isoufiltered = $false
        for($i = 0; $i -lt $this.filters.Count; $i++)
        {
            if($this.filters[$i].state -ne 0 -and $this.filters[$i].state -ne $false)
            {
                if ($this.filters[$i] -isnot "OUfilter")
                {
                    if($filtercount -eq 0)
                    {
                        $filter = $filter + $this.filters[$i].Outmethod()
                    }
                    else
                    {
                        $filter = $filter + "-and " + $this.filters[$i].Outmethod()
                    }
                }
                elseif($this.filters[$i].state -eq $true)
                {
                    $searchbase = "$($this.filters[$i].Outmethod())"
                    $isoufiltered = $true
                    $filtercount--
                }
                $filtercount++
            }
        }
        if($filtercount -eq 0)
        {
            $filter = "*"
        }

        if ($this.isuser)
        {
            if ($this.issingle)
            {
                $script:query = "Get-ADUser $($this.objname) -Properties $properties | Select-Object $select"
            }
            elseif (!($isoufiltered))
            {
                $script:query = "Get-ADUser -Filter $filter -Properties $properties | Select-Object $select"
            }
            else 
            {
                $script:query = "Get-ADUser -Filter $filter -SearchBase '$($searchbase)' -Properties $properties | Select-Object $select"
            }
        }
        else 
        {
            if ($this.issingle)
            {
                $script:query = "$this.objname -Properties $properties | Select-Object $select"
            }
            elseif (!($isoufiltered))
            {
                $script:query = "Get-ADComputer -Filter $filter -Properties $properties | Select-Object $select"
            }
            else 
            {
                $script:query = "Get-ADComputer -Filter $filter -SearchBase $searchbase -Properties $properties | Select-Object $select"
            }
        }
        Write-Host $script:query
        Invoke-Expression  $script:query | export-csv -Encoding Unicode -path D:\file.csv -NoTypeInformation
    }
}

#-#-# Functions #-#-#

## Function to translate the traditional Domain/Organizational Unit form into the DistinguishedName that's needed to filter queries on a certain OU
#OU related functions
function OUnevfordito # Creates Distinguished names from OU path
{
    param($bemenet) #OU name in the form you can find it in ADUC
    $kimenet = $bemenet.Split("/") #Splitting the OU name by slash characters
    
    for ($i = $kimenet.Length-1; $i -gt -1; $i--) #Loop starts from the last section of the string array to put them to the front
    {
        if ($i -ne 0) #Do the conversion until we get to the DC part
        {
            if ($i -eq $kimenet.Length-1) # This conditional is used to get the OU name from the whole path, so we can use it as as folder, or filename
            {
                $Script:ounev = $kimenet[$i]
            }
            $forditott += "OU="+ $kimenet[$i]+","
        }
        else #Here's where we turn DC name into DistinguishedName format too
        {
            $dcnevold = $kimenet[$i]
            $dcnevtemp = $dcnevold.Split(".")
            for ($j = 0; $j -lt $dcnevtemp.Length; $j++)
            {
                if ($j -lt $dcnevtemp.Length-1) #It's needed so there won't be a comma at the end of the output
                    {
                        $dcnev += "DC="+$dcnevtemp[$j]+","
                    }
                else 
                    {
                        $dcnev += "DC="+$dcnevtemp[$j]
                    }    
            }
            $forditott += $dcnev
        }
    }    
    return $forditott #OU name in DistinguishedName form
}

# This function checks if the OU the user entered, exist.
function OUcheck
{
    $ouletezik = $false
    do 
    {
        try # It gets the value from the main part of the program, sends it to the ou-distinguishedname interpreter, then checks if it exist. If not, it asks the user to enter the value again
        {            
            Write-Host $lang.enter_ou
            $eredetiou = Read-Host -Prompt $lang.path
            $ou = OUnevfordito $eredetiou 
            Get-ADOrganizationalUnit -Identity $ou | Out-Null
            $ouletezik = $true
        }
        catch
        {
            Write-Host $lang.non_existent_ou "`n" -ForegroundColor Red
            $ouletezik = $false
        }
    } while ($ouletezik -eq $false)
    return $ou
}

## This function is responsible to check if users entered one of the allowed choices
function Valaszt
{
    param($choice) # It receives an array of the possible choices, it's not fixed, so it doesn't matter if we have 2 allowed choices, or 30
    $probalkozottmar = $false
    do
    {        
        if ($probalkozottmar -eq $false) # Here the user enters their choice, if it's their first try
        {
            $valasztas = Read-Host -Prompt $lang.choose
        }
        else
        {
            Write-Host "`n`n$($lang.choose_err)" -ForegroundColor Yellow # This is the error message, the user gets here after every single bad entry
            $valasztas = Read-Host -Prompt $lang.choose
        }
        $teszt = $false
        for ($i=0; $i -lt $choice.Length; $i++) # This loop checks if the user entered an allowed value
        {
            if ($valasztas -eq $choice[$i])
            {
                $teszt = $true
                break # To get out of the loop if there's a match
            }
            $probalkozottmar = $true
        }
    } while ($teszt -ne $true)
    return $valasztas
}

# This will be used to create custom attributes and filters to query.
# Currently nonfunctional, therefore doesn't show up in any menu
function Createcustom
{
    param ($attribfilter)
# Create custom attributes    
    if ($attribfilter -eq $lang.attribute)
    {
        do
        {
            Clear-Host
            Write-Host $lang.create_custom_attrib
            Write-Host $lang.create_custom_attrib_expl "`n"
            $customname = Outhelp $lang.custom_attr_dispname $lang.custom_attr_dispname_help
            if($customname -eq $lang.custom_finish)
            {
                Break
            }
            $customattribute = Outhelp $lang.custom_attr_msname $lang.custom_attr_msname_help
            if($customattribute -eq $lang.custom_finish)
            {
                Break
            }
            $attributes.Add(($customattribute = [Attribute]::new($customname, $customattribute))) > $null
            if($customattribute.outmethod)
            {
                Write-Host $lang.custom_attrib_successful -ForegroundColor Green
            }
            else
            {
                Write-Host $lang.custom_attrib_unsuccesful -ForegroundColor Red
            }
            Write-Host "`n"
            Read-Host
        }while ($customname -ne $lang.custom_finish)
    }
    if ($attribfilter -eq $lang.filter)
    {
        do
        {
            Clear-Host
            Write-Host $lang.create_custom_filter
            Write-Host $lang.create_custom_filter_expl "`n"
            $customtruesidename = Outhelp $lang.custom_filter_dispname $lang.custom_filter_dispname_help
            if($customtruesidename -eq $lang.custom_finish)
            {
                Break
            }
            $customtrueside = Outhelp $lang.custom_filter_msname $lang.custom_filter_msname_help
            if($customtrueside -eq $lang.custom_finish)
            {
                Break
            }
            $customfalsesidename = Outhelp $lang.custom_filter_dispname $lang.custom_filter_dispname_help
            if($customfalsesidename -eq $lang.custom_finish)
            {
                Break
            }
            $customfalseside = Outhelp $lang.custom_filter_msname $lang.custom_filter_msname_help
            if($customfalseside -eq $lang.custom_finish)
            {
                Break
            }
            $filters.Add(($customfilter = [Filterpairs]::new($customtrueside, $customtruesidename, $customfalseside, $customfalsesidename))) > $null
            if($customfilter.outmethod)
            {
                Write-Host $lang.custom_attrib_successful -ForegroundColor Green
            }
            else
            {
                Write-Host $lang.custom_attrib_unsuccesful -ForegroundColor Red
            }
            Write-Host "`n"
            Read-Host
        }while ($customname -ne $lang.custom_finish)
    }
    Break
}

# This function is here to show help messages throughout the program.
# It works, but the help messages aren't written yet.
function Outhelp
{
    param($prompt, $help)
        
        $parameter
        do
        {
            $parameter = Read-Host -Prompt $prompt
            if($parameter -eq "H")
            {
                Write-Host $help
                Read-Host
            }
        }while($parameter -eq "H")
        return $parameter    
}

## This function handles the saving into csv. While save into csv is a basic function in PowerShell, it adds a little more functionality to it
function CSVfunkciok
{
    param ($bemenet, $csvout, [bool]$noout) # The first variable is the output from the pipeline, the second is the path and name we want to save our csv as, and the third is a boolean argument, that we have to set to true, if we don't want output on the console

    if ($null -ne $bemenet) # This checks if there is actual output from the pipeline
    {
        try
        {
            $bemenet | export-csv -encoding Unicode -path $csvout -NoTypeInformation
        }
        catch
        {
            if ($noout -eq $false)
            {
                Write-Host "`n$($lang.file_not_created)" -ForegroundColor Red # Warning if the file can't be created
            }        
        }
    }
    else
    {
        $lang.object_not_consist | Set-Content $csvout # This writes a default value in created csvs if the pipeline was empty
    }

    if(Test-Path -Path $csvout) # This tests if the file exist, notifies the user about it, and puts the separator part at the first line, in case csvs with comma separators aren't automatically recognized by Excell as spreadheets
        {
            if ($noout -eq $false)
            {
                Write-Host "`n$($lang.file_is_created)" $csvout -ForegroundColor Green
            }
            "sep=,`n"+(Get-Content $csvout -Raw) | Set-Content $csvout            
        }
}

## This function checks if the identifier, the user entered is exist, and asks them to enter it again, if not.
function Letezike 
{
    param ($obj)
    do
    {
        if (@(Get-ADObject -Filter { SamAccountName -eq $obj }).Count -eq 0)
            {                
                Write-Host "`n$($lang.id_not_exist)" "`n" -ForegroundColor Red
                Write-Host $lang.reenter_id
                $obj = Read-Host -Prompt $lang.id
            }
    } while (@(Get-ADObject -Filter { SamAccountName -eq $obj }).Count -eq 0)
    return $obj
}

## This function is responsible of creating the directories where we'll save csv files.
## First it checks if the directory exist, then if it's not, it creates it. If it's not possible, it notifies the user about it.
function CSVdir
{
    param ($csvdir)
   
    $csvpath = "$script:path\$csvdir"
    if(!(Test-Path -Path $csvpath))
    {
        try 
        {
            New-Item -ItemType directory -Path $csvpath | Out-Null    
        }
        catch
        {
            Write-Host $lang.directory_cant_be_created -ForegroundColor Red    
        }
    }
    return $csvpath
}
function MenuTitle 
{
    param ($menuname)
    Clear-Host
    Write-Host "$($title)$($menuname)`n"
    
}
function AfterQueryCopy
{
    param($queryORcopy)

    Write-Host "$($lang.after_process)"
    if ($queryORcopy -eq "C")
    {
        Write-Host "(R) $($lang.repeat_with_source)"
    }
    Write-Host "(M) $($lang.another_process_with_the_id)"
    Write-Host "(N) $($lang.query_another_id)"
    Write-Host "(U) $($lang.return_to_main_menu)"
    Write-Host "(Q) $($lang.to_quit)"
    if ($queryORcopy -eq "C")
    {
        $kilep = Valaszt ("R", "M", "N", "U", "Q")
    }
    else
    {
        $kilep = Valaszt ("M", "N", "U", "Q")
    }
    return $kilep
}

function AfterProcess
{
    Write-Host "$($lang.after_process)"
    Write-Host "(R) $($lang.new_process)"
    Write-Host "(U) $($lang.return_to_main_menu)"
    Write-Host "(Q) $($lang.to_quit)"
    $kilep = Valaszt ("R", "U", "Q")
    return $kilep
}

# This one shouldn't really be a function, I just made it one,
# so the Main part of program be more readable.
function UsersOfGroup 
{
    do # The main loop of this menu #
    {
    MenuTitle($lang.users_of_group) 
    Write-Host $lang.enter_group_name
    $csopnev = Read-Host -Prompt $lang.id
    $csopnev = Letezike $csopnev # It calls the function to check if the entered groupname exist

        # Second loop in this program. We get here if we want to do different tasks with the group #
        do
        {                       
            MenuTitle($lang.users_of_group)
            Write-Host $lang.i_found $csopnev $lang.the_group "`n" -ForegroundColor Green
            Write-Host $lang.whats_next
            Write-Host "(1) $($lang.whats_next_outconsole)"
            Write-Host "(2) $($lang.whats_next_savecsv)"
            if ($admin)
            {
                Write-Host "(3) $($lang.whats_next_group_copy_users)"
                $kiir = Valaszt ("1", "2", "3")
            }
            else
            {
                $kiir = Valaszt ("1", "2")
            }

            switch ($kiir)
                {
                    1 # Write users of the group on console #
                        {
                            Get-ADGroupMember -identity $csopnev | Get-ADObject -Properties description, samAccountName | select @{n=$lang.name; e='name'}, @{n=$lang.description; e='description'}, @{n=$lang.username; e='samAccountName'} | Out-String
                            $kilep = AfterQueryCopy ("Q")
                        }
                    2 # Save users of the group in a csv #
                        {
                            $csvdir = $lang.groups
                            $csvdir = CSVdir $csvdir

                            $csvout = "$csvdir\$csopnev.csv"
                            $ment = Get-ADGroupMember -identity $csopnev | Get-ADObject -Properties description, samAccountName | select @{n=$lang.name; e='name'}, @{n=$lang.description; e='description'}, @{n=$lang.username; e='samAccountName'}
                            CSVfunkciok $ment $csvout
                            
                            $kilep = AfterQueryCopy ("Q")
                        }
                    3 # Add users to another group #
                        {
                            # Inner loop. We repeat this, if we want to add the contents of the group to another group #
                            do
                            {
                                $kitol = Get-ADGroup $csopnev                                        
                                MenuTitle($lang.users_of_group)
                                Write-Host $lang.group_members_copy_the $kitol.name $lang.group_members_copy "`n"
                                Write-Host $lang.enter_target_group
                                $newgroup = Read-Host -Prompt $lang.group_name
                                $newgroup = Letezike $newgroup

                                # The process of adding the members to the other group #
                                [array]$members = Get-ADGroupMember $csopnev;
                                $kihez = Get-ADGroup $newgroup                    
                                MenuTitle($lang.users_of_group)
                                Write-Host $kitol.Name $lang.group_members_copying $kihez.Name $lang.to_group

                                $elemszam = $members.Count

                                for ($i=0; $i -lt $elemszam; $i++)
                                    {
                                        # Catch exceptions #
                                        try
                                        {
                                            Add-ADGroupMember -Identity $newgroup -Members $members[$i]
                                            Write-Host "`r$i/"$elemszam $lang.copy_of -NoNewline
                                        }
                                        catch
                                        {                                    
                                            $hiba = $true
                                            break # If we can't add people to the group, it makes no sense trying with all of them, so we jump out of the loop
                                        }
                                    }
                                    # After the process is finished, notify the user of the unsuccesful task.
                                    # As we tried to modify only one group, we were able to either add all users, or none
                                    # Output in the case of an unsuccesful task #                                    
                                    MenuTitle($lang.users_of_group)
                                    if ($hiba -eq $true)
                                    {
                                        Write-Host "`n$($lang.task_unsuccesful)`n" -ForegroundColor Red
                                        Write-Host $lang.you_have_no_rights $kihez.Name $lang.to_modify_group -ForegroundColor Red
                                    }
                                    else
                                    {
                                        Write-Host $lang.task_fully_succesful -ForegroundColor Green
                                    }
                                    $kilep = AfterQueryCopy ("C")
                            } while ($kilep -eq "R")                    
                        }
                }
        } while ($kilep -eq "M")
    } while ($kilep -eq "U")
    return $kilep
}
function GroupsOfUser
{
    
    MenuTitle($lang.memberships_of_user)
    Write-Host $username
    Write-Host 
    $username = Read-Host -Prompt $lang.id
   # $username = Letezike $username # It calls the function to check if the entered username exist

        do # Second loop in this program. We get here if we want to do different tasks with the user #
        {          
            MenuTitle($lang.memberships_of_user)
            $kitol = Get-ADUser $username 
            Write-Host $lang.i_found $username $lang.the_user $kitol.name"`n" -ForegroundColor Green
            Write-Host "(1) $($lang.whats_next_outconsole)"
            Write-Host "(2) $($lang.whats_next_savecsv)"
            if ($admin) # As we probably don't want users to modify groups, most likely they don't even have rights to do so, we won't even show the option to them
            {
                Write-Host "(3) $($lang.whats_next_users_copy_memberships)"
                $kiir = Valaszt ("1", "2", "3")
            }
            else
            {
                $kiir = Valaszt ("1", "2")
            }

            switch ($kiir)
            {
                1 # Write group memberships on the console #
                    {
                        MenuTitle($lang.memberships_of_user)
                        Get-ADPrincipalGroupMembership $username | select  @{n=$lang.group_name; e='name'}  | Out-String
                        $kilep = AfterQueryCopy ("Q")
                    }
                2 # Saving group memberships in a file #
                    {
                        $csvdir = $lang.users
                        $csvdir = CSVdir $csvdir

                        $csvout = "$csvdir\$username-$($lang.s_rights).csv"
                        $ment = Get-ADPrincipalGroupMembership $username | select @{n=$lang.group_name; e='name'}
                        CSVfunkciok $ment $csvout                                

                        $kilep = AfterQueryCopy ("Q")
                    }
                3 # Copying group memberships to another user #
                    {
                        # Inner loop. We get back here if the user of the program wants to copy source user's memberships to another user #
                        do 
                        {
                            MenuTitle($lang.memberships_of_user)         
                            Write-Host $kitol.Name $lang.users_groups_copy
                            Write-Host $lang.enter_target_user
                            $newuser = Read-Host -Prompt $lang.id
                            $newuser = Letezike $newuser
                            
                            # A The process of copying memberships #
                            [array]$csopnevek = Get-ADPrincipalGroupMembership $username;
                            $kihez = Get-ADUser $newuser
                            $elemszam = $csopnevek.Count

                            MenuTitle($lang.memberships_of_user)
                            Write-Host $kitol.Name $lang.users_groups_copying $kihez.Name $lang.to_user
                            for ($i=0; $i -lt $elemszam; $i++)
                                {
                                    # Catch exceptions. It won't show them here, but collected at the end of the process #
                                    try
                                        {
                                            Add-ADGroupMember -Identity $csopnevek[$i] -Members $newuser
                                            Write-Host "`r$i/"$elemszam $lang.copy_of -NoNewline
                                        }
                                    catch
                                        {                                    
                                            $hiba += @($csopnevek[$i].SamAccountName)
                                        }
                                }

                                # After the task is finished notifying the user of the results.
                                # As here we tried to modify several groups, the result can be unsuccesful, partially succesful, and fully succesful.
                                # We handle all these in the following conditionals
                                if ($hiba.Count -gt 0)
                                {
                                    if ($hiba.Count -eq $elemszam) # In case of an unsuccesful task
                                    {
                                        MenuTitle($lang.memberships_of_user)
                                        Write-Host $lang.have_no_rights_to_modify_groups -ForegroundColor Red
                                    }
                                    else  # In case of a partially succesful task. We'll write the collected unsuccesful processes here
                                    {
                                        MenuTitle($lang.memberships_of_user)

                                        $sikeres = $elemszam-$hiba.Count                                                
                                        Write-Host $lang.task_ended_with_errors "`n" -ForegroundColor Yellow
                                        for ($j=0; $j -lt $hiba.Count; $j++)
                                            {
                                                Write-Host $lang.you_have_no_rights $hiba[$j] $lang.to_modify_group -ForegroundColor Yellow                                                    
                                            }
                                        # A notification about the number of succesful copies
                                        Write-Host $kihez.Name $lang.user_added $sikeres $lang.to_group_of $elemszam $lang.of_groups "`n" -ForegroundColor Yellow
                                    }
                                }
                                # Best case scenario, notification in case of a fully succesful task #
                                else
                                {
                                    MenuTitle($lang.memberships_of_user)
                                    Write-Host $lang.task_fully_succesful -ForegroundColor Green
                                }
                                $kilep = AfterQueryCopy ("C")                                                                               
                        } while ($kilep -eq "R")                                
                    }
            }
        } while ($kilep -eq "M")
    
}

function GroupsOfOU 
{
    do
    {
        MenuTitle($lang.users_of_all_groups_ou)
        do
        {                      
            $ou = OUcheck # It calls the function to enter the OU name, and check if it exist
            $ounev = $Script:ounev # It calls the $script:ounev variable from OUcheck function, so we could create separate folders by OUs
                
            $vane = $true
            [array]$csopnevek = Get-ADGroup -SearchBase $ou -Filter *

            if($csopnevek.Length -eq 0) # This conditional checks if there are groups in the OU, and doesn't let the user continue until they enter an OU that has groups in it
            {
                Write-Host $lang.no_groups_in_ou "`n" -ForegroundColor Red
                $vane = $false                        
            }                    
        } while ($vane -eq $false)

        $elemszam = $csopnevek.Count

        $csvdir = "$($lang.groups)\$ounev"
                $csvdir = CSVdir $csvdir

                    $progressbar = 100 / $elemszam # To count one item means how much in percentage of the whole process
                    Write-Host $lang.progress "`n"

                    for ($i=0; $i -lt $elemszam; $i++)
                    {
                        $csvname = $csopnevek[$i].name
                        $csvout = "$csvdir\$csvname.csv"
                        
                        $csopnev = Get-ADGroup $csopnevek[$i].samAccountName
                        $ment = Get-ADGroupMember -identity $csopnev | Get-ADObject -Properties description, samAccountName | select @{n=$lang.name; e='name'}, @{n=$lang.description; e='description'}, @{n=$lang.username; e='samAccountName'}
                        CSVfunkciok $ment $csvout $true
                        $percentage = [math]::Round($progressbar * ($i+1)) # To count the current percentage
                        Write-Host "`r$Percentage%" -NoNewline # To show the current percentage to the user, without putting it into a new line
                    }
                $kilep = AfterProcess
            } while ($kilep -eq "R")
            return $kilep
}

function ADUserFunctions
{    
    param($title, $functionname)

    $kilep
    do # The main loop of this menu #
    {
                   
        Write-Host "1 groupsofuser`n2 AllusersfromOU`n3 Queryfilter"
        $simpledetailed = Valaszt("1", "2", "3")

        switch($simpledetailed)
        {
            1 { $kilep = GroupsOfUser }
            2 { $kilep = AllUsersFromOU }
            3 { $menu = [QueryFiltering]::new($true, $true, $lang.all_computers_of_ou, "kb158a7h")
                do
                {
                    $menu.Menu()
                    $menu.Output()
                    $kilep = AfterProcess
                } while($kilep -eq "R") }
        }
    } while ($kilep -eq "U")
    return $kilep
}

function AllUsersFromOU 
{
    do
    {
        MenuTitle($lang.memberships_of_all_users_ou)
        # Loop that gets the OU, checks if there are users in it, then continues
        do
        {
            $ou = OUcheck
            $ounev = $Script:ounev
                
            $vane = $true
            [array]$userek = Get-ADUser -SearchBase $ou -Filter *

            if($userek.Length -eq 0) 
            {
                Write-Host $lang.no_users_in_ou "`n" -ForegroundColor Red
                $vane = $false                        
            }                    
        } while ($vane -eq $false)

        $elemszam = $userek.Count

        $csvdir = "$($lang.users)\$ounev"
        $csvdir = CSVdir $csvdir

        $progressbar = 100 / $elemszam
        Write-Host $lang.progress

        for ($i=0; $i -lt $elemszam; $i++)
        {
            $csvname = $userek[$i].samAccountName
            $csvout = "$csvdir\$csvname.csv"
                        
            $username = Get-ADUser $userek[$i].samAccountName
            $ment = Get-ADPrincipalGroupMembership $username | select @{n=$lang.group_name; e='name'}
            CSVfunkciok $ment $csvout $true
            $percentage = [math]::Round($progressbar * ($i+1))
            Write-Host "`r$Percentage%" -NoNewline
        }                    
        $kilep = AfterProcess
    } while ($kilep -eq "R")
}

# Without a doubt the most dangerous part of the program at the moment. It must be used with extreme caution, as it can change
# the attributes of every single user we have authority over in a few seconds. To make the changes reversable,
# I implemented a save feature, that saves the old attributes into a csv file before making the changes. To make it even more secure,
# the changes are saved line by line, so even if the script stops running at one point, there will be a backup about the already
# applied changes. As far as I can tell, it's as secure as it possibly can be.
#
# It also creates a logfile about the changes it couldn't make for some reason. It works a little less precisely at the moment,
# but it gives an overview about the unsuccesful tasks.
function MassModify
{
    # Maybe it could still be optimized a bit, but it works as efficiently, as I could write it now
    do
    {
        # Warnings
        Clear-Host
        Write-Host $lang.warning -ForegroundColor Red
        Write-Host $lang.mm_prewarn_line1 -ForegroundColor Red
        Write-Host $lang.mm_prewarn_line2 -ForegroundColor Red
        Write-Host $lang.mm_prewarn_line3 -ForegroundColor Red
        Write-Host $lang.mm_prewarn_line4 -ForegroundColor Red

        # Getting the OU path
        do
        {
            Write-Host $lang_all_users_of_ou
            $ou = OUcheck # It calls the function to check if the entered OU exist
            $ounev = $Script:ounev # It calls the $script:ounev variable from OUcheck function, so we could create separate folders by OUs
                
            $vane = $true
            [array]$userek = Get-ADUser -SearchBase $ou -Filter *

            if($userek.Length -eq 0) # This conditional checks if there are groups in the OU, and doesn't let the user continue until they enter an OU that has groups in it
            {
                Write-Host $lang_no_users_in_ou -ForegroundColor Red
                $vane = $false                        
            }                    
        } while ($vane -eq $false)

        # Getting the CSV path
        Write-Host $lang.enter_modifycsv_path
        do
        {
            $csvinpath = Read-Host -Prompt $lang.path
            $script:nextmove = $true
            try
            {
                $incsv = Get-Content $csvinpath
            }
            catch
            {
                Write-Host $lang.file_doesnt_exist -ForegroundColor Red
                $nextmove = $false
            }            
        } while($nextmove -ne $true)

# Delete
        # $cvcsdcsd | ForEach-Object {Remove-ADUser -Identity $_.samAccountName -Confirm:$false}

# Modify 

        # Last confirmation about the process, after this, the program will run
        Write-Host $lang.last_warning "`n" -ForegroundColor Red
        Write-Host $lang.the $csvinpath $lang.will_be_used_to_modify $eredetiou $lang.modify_all_users_of_ou "`n" -ForegroundColor Red
        Write-Host $lang.enter_yes -ForegroundColor Red
        $confirm = Read-Host -Prompt $lang.enter_string
        if ($confirm -ne $lang.yes) # The program won't go further, unless the users types "yes" in their language.
        {
            Break
        }

        # The actual process
        ## First step, getting the number of columns. It probably can be done a little more sophisticated. 
        for ($i = 0; $i -lt 1; $i++)
        {
            $oszlopok = $incsv[$i].Split("$($lang.delimiter)")
        }

        ## Here we create the array that will store the attribute names
        $attribute = New-Object string[] $oszlopok.Length
        $progressbar = 100 / $incsv.Length ## Progressbar, so the user knows how far they are in the process.
        Write-Host $lang_progress
        
        $hiba = @() ## Array to store the errors, instead of outputting them realtime on the console
        $firstuser = $true ## We will need this variable for saving the backup CSV
        $random = Get-Random ## This random number is used in naming the CSVs, to avoid accidental overwrites.
        for ($i = 0; $i -lt $incsv.Length; $i++)
        {
            $value = $incsv[$i].Split("$($lang.delimiter)") # We split the rows by the delimiter we set in the language file
            $backup = New-Object PsObject ## This array will store the old values from before we make the change on them
            
            # This loop is to get the attribute names from the header of the CSV
            if($i -eq 0)
            {
                for ($j = 0; $j -lt $value.Length; $j++)
                {
                    $attribute[$j] = $value[$j]
                }
            }
            else
            {
                $ADUser = $value[0] # For now, the program works only, if samAccountName is the first column of the table.
                # As a security measure, we change users only from the chosen Organizational Unit, and from nowhere else,
                # even if the user exist in another OU.
                if ($ADUser -and (Get-ADUser -SearchBase $ou -Filter "samAccountName -eq '$ADUser'"))
                {
                    for ($j = 1; $j -lt $oszlopok.Length; $j++) # We step through the columns one by one
                    {
                        try
                        {
                            $attribbackup = Get-ADUser -identity $ADUser -Properties $attribute[$j] | Select-Object $attribute[$j] # Backup step 1: getting the value of the attribute
                            $backup | add-member -membertype NoteProperty -name "$($attribute[$j])" -Value "$($attribbackup.($attribute[$j]))" # Backup step 2: Putting the value in the backup array object
                            Set-ADUser -identity $ADUser -Replace @{$attribute[$j]=$value[$j]} # The main part of the whole function. This changes the value of the chosen attribute.
                        }
                        catch
                        {
                            #$hiba += @("$($lang.the_given_csv) $attribute[$j] $($lang.the_attribute) $ADUser $($lang.for_the_user)") 
                            # Exception catch 2: It tells the user if an attribute is cannot be changed for some reason. As for now it doesn't differenciate
                            # if the user doesn't have sufficient right to change the value, or the CSV file didn't have value for the attribute.
                            $hiba += New-Object PsObject -property @{"$($lang.error_description)" = ("$($lang.the_given_csv) $attribute $($lang.the_attribute) $ADUser $($lang.for_the_user)")}
                        }
                    }
                    if($firstuser) # We need separate command for the first time, when we create the CSV file
                    {
                        $backup | export-csv -encoding unicode -path "$script:path\backup-$random.csv" -NoTypeInformation
                        $firstuser = $false # We don't need this branch of the if-else anymore, so set the variable false.
                    }
                    else
                    {
                        $backup | export-csv -encoding unicode -path "$script:path\backup-$random.csv" -NoTypeInformation -Append
                    }

                    $percentage = [math]::Round($progressbar * ($i+1)) # To count the current percentage, it doesn't work properly, at the moment, and there are way more important things to fix than this.
                    Write-Host "`r$Percentage%" -NoNewline # To show the current percentage to the user, without putting it into a new line
                }
            
                else
                {
                    #$hiba += @("$($lang.the) $ADUser $($lang.user_doesnt_exist) $ounev $($lang.not_in_the_ou)")
                    # Exception catch 1: It tells the user if the user they want to change doesn't exist, or isn't in the chosen OU
                    $hiba += New-Object PsObject -property @{"$($lang.error_description)" = ("$($lang.the) $ADUser $($lang.user_doesnt_exist) $ounev $($lang.not_in_the_ou)")}
                }
            }
        }

        $hiba | export-csv -encoding unicode -path "$script:path\hibajegy-$random.csv" -NoTypeInformation

        $kilep = AfterProcess
    } while ($kilep -eq "R")
}

###### Program entry point ########

# The main loop of the program. This is where we call the functions and classes from.
do
{ 
    # Choose from the given options #
    MenuTitle($lang.main_menu)
    Write-Host "(1) $($lang.users_of_group)"
    Write-Host "(2) $($lang.memberships_of_user)"
    Write-Host "(3) $($lang.users_of_all_groups_ou)"
    Write-Host "(4) $($lang.memberships_of_all_users_ou)"
    Write-Host "(5) $($lang.all_computers_of_ou)"
    Write-Host "(6) $($lang.all_users_of_ou)"
    Write-Host "(7) $($lang.dangerzone)" -ForegroundColor Red
    Write-Host "(S) $($lang.change_save_root)"
    Write-Host "`n$($lang.old_path) $script:path"
    $mit = Valaszt ("1", "2", "3", "4", "5", "6", "7", "S")

    switch ($mit)
    {
    1 # Actions on a single group. Get users, write them on the host, save them into a csv, or copy its users to another group #
        {
            $kilep = UsersOfGroup
        }

    2 # Actions on a single user. Get ugroup memberships, write them on the host, save them into a csv, or copy them to another user #
        {            
            $kilep = ADUserFunctions $lang.memberships_of_user $lang.enter_username $true $true
        }

    3 # All members of all groups from a certain OU, collected in separate csvs #
        {
            $kilep = GroupsOfOU
        }

    4
        {
            
        }

    5 # All PCs of a certain OU, filtered or not filtered by recent activity #
        {
            MenuTitle($lang.all_computers_of_ou)
            $menu = [QueryFiltering]::new($true, $false, $lang.all_computers_of_ou, $false)
            do
            {
                $menu.Menu()
                $menu.Output()
                $kilep = AfterProcess
            } while($kilep -eq "R")
        }

    6 # All Users of an OU, filtered or not filtered by their activity #
        {
            MenuTitle($lang.users_of_ou)
            # Loop that gets the OU, checks if there are users in it, then continues
            do
            {
                $eredetiou = Read-Host -Prompt $lang.enter_ou
                $ou = OUcheck $eredetiou
                $ounev = $Script:ounev

                $vane = $true
                $teszt = Get-ADUser -Filter * -SearchBase $ou

                if($teszt.Length -eq 0)
                    {
                        Write-Host $lang.no_users_in_ou -ForegroundColor Red
                        $vane = $false
                    }                    
            } while ($vane -eq $false)

            $csvdir = $lang.users
            $csvdir = CSVdir $csvdir

            MenuTitle($lang.users_of_ou)
            Write-Host $lang.ou_exist -ForegroundColor Green
            Write-Host $lang.generic_or_activity_filtered
            $szurt = Valaszt ("1", "2") # Decide what kind of list we'd like to recieve

            if ($szurt -eq 2) # In case we'd like a filtered list
                {
                    MenuTitle($lang.users_of_ou)
                    Write-Host $lang.the $eredetiou $lang.ou_users                
                    $napja = Read-Host -Prompt $lang.how_many_days
                    $time = (Get-Date).Adddays(-($napja))

                    MenuTitle($lang.users_of_ou)
                    Write-Host $lang.the $eredetiou $lang.users_last $napja $lang.days_of_activity
                    Write-Host $lang.active_or_inactive # Decide if we'd like a list about the active, or inactive users 
                    $avi = Valaszt ("1", "2")

                    if ($avi -eq "1")
                        {
                            $csvout = "$csvdir\$ounev-$($lang.last)-$napja-$($lang.days_active_users).csv"
                            $ment = Get-ADUser -Filter {LastLogonTimeStamp -gt $time} -SearchBase $ou -Properties name, SamAccountName, description, LastLogonDate | select @{n=$lang.name; e='name'}, @{n=$lang.description; e='description'}, @{n=$lang.username; e='samAccountName'}, @{n=$lang.last_logon;e='LastLogonDate'}
                        }
                    else
                        {
                            $csvout = "$csvdir\$ounev-$($lang.last)-$napja-$($lang.days_inactive_users).csv"
                            $ment = Get-ADUser -Filter {LastLogonTimeStamp -lt $time} -SearchBase $ou -Properties name, SamAccountName, description, LastLogonDate | select @{n=$lang.name; e='name'}, @{n=$lang.description; e='description'}, @{n=$lang.username; e='samAccountName'}, @{n=$lang.last_logon;e='LastLogonDate'}
                        }
                }
            else
                {
                    MenuTitle($lang.users_of_ou)
                    $csvout = "$csvdir\$ounev-OU-$($lang.users_of).csv"
                    $ment = Get-ADUser -Filter * -SearchBase $ou -Properties name, SamAccountName, description, LastLogonDate | select @{n=$lang.name; e='name'}, @{n=$lang.description; e='description'}, @{n=$lang.username; e='samAccountName'}, @{n=$lang.last_logon;e='LastLogonDate'}
                }
            CSVfunkciok $ment $csvout
            Write-Host $lang.ou_whats_next
            $kilep = Valaszt ("N", "Q", "R")
        }
    7
        {
            MassModify
        }
    S # Modify the save path of csvs
        {
            MenuTitle($lang.change_save_root)
            Write-Host $lang.old_path $script:path "`n"                            
            $newpath = Read-Host -Prompt $lang.new_path

            if(!(Test-Path -Path $newpath))
            {
                Write-Host $lang.folder_not_exist
                $fold = Valaszt ("1", "2")
                
                do
                {    
                    if ($fold -eq "1")
                    {
                        try
                        {
                            $ErrorActionPreference = "Stop" # To throw an exception when the user tries to use an invalid path. Without it, the program gets into an infinite loop
                            New-Item -ItemType directory -Path $newpath | Out-Null
                        }
                        catch
                        {
                            Write-Host "`n$($lang.directory_cant_be_created)" -ForegroundColor Red
                            Write-Host $lang.new_or_exit
                            $neworold = Valaszt ("1", "2")
                            
                            if ($neworold -eq "2")
                            {
                                $newpath = $script:path
                            }
                            else
                            {
                                $newpath = Read-Host -Prompt $lang.new_path
                            }
                        }
                    } 
                } while (!(Test-Path -Path $newpath) -and $fold -eq "1" -and $neworold -ne "2")
            }

            $script:path = $newpath
        }
    }
    
} while ($kilep -ne "Q")