#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
#-#-#                                      SETTINGS                                           #-#-#
#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

# Language. It checks the system language of the OS, then sets the language to Hungarian,
# if it's Hungarian, and sets to English, if it's any other language
$sysloc = Get-WinSystemLocale
if ($sysloc.Name -eq "hu-HU")
    {
        try
        {
            $ErrorActionPreference = "Stop"
            $lang = Get-Content ".\Languages\hun.lang" | Out-String | ConvertFrom-StringData
        }
        catch
        {
            Write-Host "A nyelvi fájl hiányzik!`nKérlek ellenőrizd, hogy a 'hun.lang' fájl megtalálható-e a program Language könyvtárában!" -ForegroundColor Red
        }
    }
else
    {
        try
        {
            $ErrorActionPreference = "Stop"
            $lang = Get-Content ".\Languages\eng.lang" | Out-String | ConvertFrom-StringData
        }
        catch
        {
            Write-Host "The Language file is missing!`nCheck if 'eng.lang' file is in the Language folder of the program" -ForegroundColor Red
        }
    }

# Configuration. It's very basic at the moment, it has only the default save path in it.
try
{
    $ErrorActionPreference = "Stop"
    $config = Get-Content ".\config.ini" | Out-String | ConvertFrom-StringData
}
catch
{
}

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
#-#-#                                   PRE-RUN CHECKS                                        #-#-#
#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

# First check. It doesn't let the user continue, if they doesn't have
# ActiveDirectory module installed. As the program heavily relies on AD module,
# it makes no sense to go further than this without it.
if (!(Get-Module -ListAvailable -Name ActiveDirectory)) 
{
    try
    {
        $ErrorActionPreference = "Stop"
        Import-Module .\Microsoft.ActiveDirectory.Management.dll
        Import-Module .\Microsoft.ActiveDirectory.Management.resources.dll
    }
    catch
    {
        Write-Host "$($lang.ad_module_not_installed)`n$($lang.dlls_missing)`n$($lang.program_exits)" -ForegroundColor Red
        Read-Host
        break
    }
} 

# Second check. It warns the user if they try to run the program with user level rights.
# Most functions work without admin rights, but it still worth to notify the user about it.
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

# Third check. It doesn't do anything else, than setting the save path to the one in the config.ini.
if ($config.savepath)
{
    $script:path = $config.savepath
}
else
{
    $script:path = "D:\AD-Out" # The root of the default save path for csvs.
}

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
#-#-#                                       ENUMS                                             #-#-#
#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

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

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
#-#-#                                      CLASSES                                            #-#-#
#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

# Class to handle CSV functions, like creating the save directory, naming the files,
# and placing the pipeline output into it. It has two constructors, one for the cases,
# when creating the directory, and naming the file can be done at the same time, and
# one other, when the filename is generated in a loop, so we can avoid doing the
# directory related actions when they aren't needed.
class CSV
{
    $csvdir
    $outfile
    $out
    $csvpath
    CSV($csvdir, $outfile)
    {
        $this.csvdir = $csvdir
        $this.outfile = $outfile
        $this.DirectoryFunctions()        
    }
    CSV($csvdir)
    {
        $this.csvdir = $csvdir
        $this.DirectoryFunctions()
    }

    DirectoryFunctions()
    {
        $this.csvpath = "$script:path\$($this.csvdir)"
        if(!(Test-Path -Path $this.csvpath))
        {
            try 
            {
                New-Item -ItemType directory -Path $this.csvpath | Out-Null    
            }
            catch
            {
                Write-Host $script:lang.directory_cant_be_created -ForegroundColor Red    
            }
        }
        if ($this.outfile)
        {
            $this.out = "$($this.csvpath)\$($this.outfile).csv"
        }
    }

    File($outfile)
    {
        $this.outfile = $outfile
        $this.out = "$($this.csvpath)\$($this.outfile).csv"
    }

    Create($bemenet, [bool]$noout)
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
            $this.Separator()
        }
    }
    Append($bemenet)
    {
        $bemenet | export-csv -encoding unicode -path $this.out -NoTypeInformation -Append
    }

    Separator()
    {
        "sep=,`n"+(Get-Content $this.out -Raw) | Set-Content $this.out
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
            Write-Host $("({0}) $($script:lang.chosen_ou): {1}" -f $char, $Script:ounev) -NoNewline -ForegroundColor Green
        }
        else 
        {
            Write-Host $("({0}) $($script:lang.ou_is_not_set)" -f $char) -NoNewline -ForegroundColor Red
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
# This class is responsible for selective querying. We can select which attributes we want to show in the output,
# and which OU we want to query. It's rather detailed, and mostly works, but there is some problem with the
# result filtering at the moment. I'm working on it.
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
# This method creates the arrays with the selectable attributes as objects in it.
    {        
        # Filters. We need them only if we want to query more users, so they won't show up when querying one user
        if (!($this.issingle))
        {        
            $filters.Add(($script:lastlogonfilter = [Filterpairs]::new(($active = "{LastLogonTimeStamp -gt $($this.time)}"),$script:lang.active_ones,($inactive = "{LastLogonTimeStamp -lt $($this.time)}"),$script:lang.inactive_ones))) > $null
            $filters.Add(($isenabled = [Filterpairs]::new(('Enabled -eq "True"'),$script:lang.enabled,($isdisabled = 'Enabled -eq "False"'),$script:lang.disabled))) > $null
            $filters.Add(($script:oufilter = [OUfilter]::new())) > $null
        }
        $attributes.Add(($lastlogon = [Attribute]::new($script:lang.last_logon, "LastLogonDate"))) > $null
        $attributes.Add(($enabled = [Attribute]::new($script:lang.enabled, "enabled"))) > $null
        $attributes.Add(($description = [Attribute]::new($script:lang.description, "Description"))) > $null
        $attributes.Add(($created = [Attribute]::new($script:lang.created, "created"))) > $null
        if(!($this.isuser))
        {
            $attributes.Add(($os = [Attribute]::new($script:lang.os, "OperatingSystem"))) > $null
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
# This method is responsible for showing the attribute, and filter slection menu, and also it calls the methods
# the other classes on the attribute and filter objects.
    {
        $ouisset = $true
        do
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
                $opciok += $script:lang.char_finalize
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
            }while($this.setter -ne $script:lang.char_finalize)
# This stops us from continue if we didn't set the OU filter. On larger Active Directories
# a query on all AD objects can take long, so this confirmation makes sure, if we really
# want to query the whole AD.
            if (!($script:oufilter.state) -and !($this.issingle))
            {
                Write-Host $script:lang.confirm_without_ou -ForegroundColor DarkYellow
                Write-Host $script:lang.search_will_be_on_whole_ad -ForegroundColor DarkYellow
                Write-Host "($($script:lang.char_yes)) $($script:lang.yes)`n($($script:lang.char_no)) $($script:lang.no)"
                $confirm = Valaszt ("$($script:lang.char_yes)", "$($script:lang.char_no)")
                if($confirm -eq $script:lang.char_yes)
                {
                    $ouisset = $true
                }
                else
                {
                    $ouisset = $false
                }
            }
        }while(!($ouisset))
    }

    [string]Output()
# This method is responsible for creating the query string.
    {
        if ($this.isuser)
        {
            $properties = "samAccountname"
            $select = "@{n='$($script:lang.username)'; e='samAccountName'}"
        }
        else
        {
            $properties = "Name"
            $select = "@{n='$($script:lang.computername)'; e='Name'}"
        }
        $filter = $null
        $searchbase = $null
        $napja = $null
        $time = $null

# In case we selected a filter about activity, this part asks how many days we want to query.
        if ($script:lastlogonfilter.state -ne 0 -and $this.issingle -eq $false)
        {
            Write-Host $script:lang.youset_day_filter
            do
            {   
                try
                {
                    [int32]$napja = Read-Host -Prompt $script:lang.youset_daynumber
                }
                catch
                {
                    Write-Host $script:lang.non_numeric_value -ForegroundColor Red
                }
            } while(!($napja -is [int32]))
            $time = (Get-Date).Adddays(-($napja))
            $script:time = $time
            $script:lastlogonfilter.trueside = "LastLogonTimeStamp -gt `$time"
            $script:lastlogonfilter.falseside = "LastLogonTimeStamp -lt `$time"
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
                        $filter = $filter + " -and " + $this.filters[$i].Outmethod()
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

# Now we create the query string from the collected attributes and filters.
        if ($this.isuser)
        {
            if ($this.issingle)
            {
                $script:query = "Get-ADUser $($this.objname) -Properties $properties | Select-Object $select"
            }
            elseif (!($isoufiltered))
            {
                $script:query = "Get-ADUser -Filter '$filter' -Properties $properties | Select-Object $select"
            }
            else 
            {
                $script:query = "Get-ADUser -Filter '$filter' -SearchBase '$($searchbase)' -Properties $properties | Select-Object $select"
            }
        }
        else 
        {
            if ($this.issingle)
            {
                $script:query = "Get-ADComputer $this.objname -Properties $properties | Select-Object $select"
            }
            elseif (!($isoufiltered))
            {
                $script:query = "Get-ADComputer -Filter '$filter' -Properties $properties | Select-Object $select"
            }
            else 
            {
                $script:query = "Get-ADComputer -Filter '$filter' -SearchBase '$($searchbase)' -Properties $properties | Select-Object $select"
            }
        }
        return $script:query # | Out-String # | export-csv -Encoding Unicode -path D:\file.csv -NoTypeInformation
    }
}

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
#-#-#                                    FUNCTIONS                                            #-#-#
#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#


#-#-#                              FUNCTIONS OF MINOR TASKS                                #-#-#
#-#-#                                                                                      #-#-#
#-#-# Because one can never be lazy enough. The one(s) that got here are almost ponitless. #-#-#
function Timestamp
{
    return Get-Date -Format FileDateTime   
}

#-#-#                                  ACTION FUNCTIONS                                    #-#-#
#-#-#                                                                                      #-#-#
#-#-#       These are the functions that check, or modify the objects we work with.        #-#-#

function OUnevfordito
{
# Function to translate the traditional Domain/Organizational Unit form into the DistinguishedName
# that's needed to filter queries on a certain OU.
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

function OUcheck
{
# This function checks if the OU the user entered, exist.
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

function Letezike 
{
## This function checks if the identifier, the user entered is exist, and asks them to enter it again, if not.
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

function Createcustom
{
# This will be used to create custom attributes and filters to query.
# Currently nonfunctional, therefore doesn't show up in any menu
    param ($attribfilter)

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


#-#-#                                NAVIGATIONAL FUNCTIONS                                   #-#-#
#-#-#                                                                                         #-#-#
#-#-# These make it easier to navigate through the menus, show elements, select options, etc. #-#-#

function MenuTitle
{
# This function clears the console, than shows the program title, and menu title in every menu.
    param ($menuname)
    Clear-Host
    Write-Host "$($title)$($menuname)`n"    
}


function Valaszt
{
## This function is responsible to check if users entered one of the allowed choices
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

function AfterProcess
{
# This function brings up the selection menu after a task is finished.
    param($copy)

    Write-Host "$($lang.after_process)"
    if ($copy)
    {
        Write-Host "($($lang.char_repeat)) $($lang.repeat)"
    }
    Write-Host "($($lang.char_new_proc)) $($lang.new_process)"
    Write-Host "($($lang.char_mainmenu)) $($lang.return_to_main_menu)"
    Write-Host "($($lang.char_quit)) $($lang.to_quit)"
    if ($copy)
    {
        $kilep = Valaszt ("$($lang.char_repeat)", "$($lang.char_new_proc)", "$($lang.char_mainmenu)", "$($lang.char_quit)")
    }
    else
    {
        $kilep = Valaszt ("$($lang.char_new_proc)", "$($lang.char_mainmenu)", "$($lang.char_quit)")
    }
    return $kilep
}

function Outhelp
{
# This function is here to show help messages throughout the program.
# It works, but the help messages aren't written yet.
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


#-#-#                                   MAIN MENU ENTRIES                                     #-#-#
#-#-#                                                                                         #-#-#
#-#-# They don't need to be in separate functions, but it makes the code more readable to me. #-#-#

function UsersOfGroup 
{
# This menu is for collecting all users of a group, and outputting them on console,
# saving them in a csv, or copying them to another group.
# Parts of it need minor rewriting to be more efficient, and less cluttered.
    do
    {
        MenuTitle($lang.users_of_group) 
        Write-Host $lang.enter_group_name
        $csopnev = Read-Host -Prompt $lang.id
        $csopnev = Letezike $csopnev # It calls the function to check if the entered groupname exist

        # We get here if we want to do different tasks with the group #
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

            $result = Get-ADGroupMember -identity $csopnev | Get-ADObject -Properties description, samAccountName | select @{n=$lang.name; e='name'}, @{n=$lang.description; e='description'}, @{n=$lang.username; e='samAccountName'}
            switch ($kiir)
            {
                1 # Write users of the group on console #
                    {
                        $kiirat = $result | Out-String
                        Write-Host $kiirat
                        $kilep = AfterProcess $true
                    }
                2 # Save users of the group in a csv #
                    {
                        $csvout = [CSV]::new($lang.groups, $csopnev)
                        $csvout.Create($result, $false)
                        $kilep = AfterProcess $true
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
                            $kilep = AfterProcess $true
                        } while ($kilep -eq $lang.char_repeat)                    
                    }
            }
        } while ($kilep -eq $lang.char_repeat)
    } while ($kilep -eq $lang.char_new_proc)
    return $kilep
}

function SingleUser
{
# This menu is querying a user. We can get their group memberships, or a detailed table about their
# attributes. In either case, we can show the output on console, or save it to a csv.
# In case of group memberships, we can also copy them to another user.
    do # Second loop in this program. We get here if we want to do different tasks with the user #
    {
        MenuTitle($lang.memberships_of_user)
        $result = $null
        $username = Read-Host -Prompt $lang.id
        $username = Letezike $username # It calls the function to check if the entered username exist
        do
        {
            MenuTitle($lang.memberships_of_user)
            $kitol = Get-ADUser $username 
            Write-Host $lang.i_found $username $lang.the_user $kitol.name"`n" -ForegroundColor Green
            Write-Host $lang.what_kind_of_query
            Write-Host $lang.simple_with_groupmemberships
            Write-Host $lang.detailed_with_attribute_selection
            $mit = Valaszt("1", "2")

            if($mit -eq "1")
            {
                $result = Get-ADPrincipalGroupMembership $username | select  @{n=$lang.group_name; e='name'} #| Out-String
            }
            else
            {
                $menu = [QueryFiltering]::new($true, $true, $lang.memberships_of_user, $username)
                $menu.Menu()
                $result = invoke-expression $menu.Output() -Verbose
            }

            Write-Host "`n$($lang.what_do_you_want_with_results)"
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
            switch($kiir)
            {
                1 
                    { 
                        $kiirat = $result | Out-String
                        Write-Host $kiirat
                        $kilep = AfterProcess $true
                    }
                2
                    {
                        $csvout = [CSV]::new($lang.users, "$username-$($lang.s_rights)")
                        $csvout.Create($result, $false)
                        $kilep = AfterProcess $true
                    }
                3 
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
                                $kilep = AfterProcess $true
                        } while ($kilep -eq $lang.char_repeat)
                    }
            }
        } while ($kilep -eq $lang.char_repeat)
    } while ($kilep -eq $lang.char_new_proc)
    return $kilep
}

function GroupsOfOU 
{
# This menu is for collecting all users of all groups from an OU, and saving them into separate CSVs.
# Right now I'm not planning to extend the functions of this menu.
# Parts of it need minor rewriting to be more efficient, and less cluttered.
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
        
        $csvout = [CSV]::new("$($lang.groups)\$ounev")
        $elemszam = $csopnevek.Count

        $progressbar = 100 / $elemszam # To count one item means how much in percentage of the whole process
        Write-Host $lang.progress "`n"

        for ($i=0; $i -lt $elemszam; $i++)
        {            
            $csopnev = Get-ADGroup $csopnevek[$i].samAccountName
            $result = Get-ADGroupMember -identity $csopnev | Get-ADObject -Properties description, samAccountName | select @{n=$lang.name; e='name'}, @{n=$lang.description; e='description'}, @{n=$lang.username; e='samAccountName'}
            $csvout.File($csopnev.name)
            $csvout.Create($result, $true)
            $percentage = [math]::Round($progressbar * ($i+1)) # To count the current percentage
            Write-Host "`r$Percentage%" -NoNewline # To show the current percentage to the user, without putting it into a new line
        }
        $kilep = AfterProcess
    } while ($kilep -eq $lang.char_repeat)
    return $kilep
}

function AllUsersFromOU 
{
# This menu is for collecting all group memberships of all users from an OU, and saving them
# into separate CSVs. Right now I'm not planning to extend the functions of this menu.
# Parts of it need minor rewriting to be more efficient, and less cluttered.
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

        $csvout = [CSV]::new("$($lang.users)\$ounev")
        $elemszam = $userek.Count

        $progressbar = 100 / $elemszam
        Write-Host $lang.progress

        for ($i=0; $i -lt $elemszam; $i++)
        {
            $username = Get-ADUser $userek[$i].samAccountName
            $result = Get-ADPrincipalGroupMembership $username | select @{n=$lang.group_name; e='name'}
            $csvout.File($username.samAccountName)
            $csvout.Create($result, $true)

            $percentage = [math]::Round($progressbar * ($i+1))
            Write-Host "`r$Percentage%" -NoNewline
        }                    
        $kilep = AfterProcess
    } while ($kilep -eq $lang.char_repeat)
    return $kilep
}

function OUUsersComputers
{
# This function is to mass query all users or all computers from an OU. It doesn't show their
# group memberships, but it gives a detailed set of attributes and filters we can query them by.
    param($title, $isuser, $csvdir, $csvname)
    MenuTitle($title)
    $menu = [QueryFiltering]::new($isuser, $false, $title, $false)
    $result = $null
    do
    {
        $menu.Menu()
        $result = invoke-expression $menu.Output()
        Write-Host "`n$($lang.what_do_you_want_with_results)"
        Write-Host "(1) $($lang.whats_next_outconsole)"
        Write-Host "(2) $($lang.whats_next_savecsv)"
        $kiir = Valaszt ("1", "2")
        switch($kiir)
        {
            1 
                { 
                    $kiirat = $result | Out-String
                    Write-Host $kiirat
                }
            2
                {
                    $csvout = [CSV]::new($csvdir, "$($Script:ounev)-$($csvname)")
                    $csvout.Create($result, $false)
                }
        }
        $kilep = AfterProcess
    } while($kilep -eq $lang.char_new_proc)
    return $kilep
}

function MassModify
{
# Without a doubt the most dangerous part of the program at the moment. It must be used with extreme caution, as it can change
# the attributes of every single user we have authority over in a few seconds. To make the changes reversable,
# I implemented a save feature, that saves the old attributes into a csv file before making the changes. To make it even more secure,
# the changes are saved line by line, so even if the script stops running at one point, there will be a backup about the already
# applied changes. As far as I can tell, it's as secure as it possibly can be.
#
# It also creates a logfile about the changes it couldn't make for some reason. It works a little less precisely at the moment,
# but it gives an overview about the unsuccesful tasks.
# Maybe it could still be optimized a bit, but it works as efficiently, as I could write it now
    do
    {
        # Warnings
        Clear-Host
        Write-Host $lang.warning -ForegroundColor Red
        Write-Host $lang.mm_prewarn_line1 -ForegroundColor Red
        Write-Host $lang.mm_prewarn_line2 -ForegroundColor Red
        Write-Host $lang.mm_prewarn_line3 -ForegroundColor Red
        Write-Host $lang.mm_prewarn_line4 "`n" -ForegroundColor Red
        Write-Host $lang.are_you_sure -ForegroundColor DarkYellow
        Write-Host "($($script:lang.char_yes)) $($script:lang.yes)`n($($script:lang.char_no)) $($script:lang.no)"
        $confirm = Valaszt ("$($script:lang.char_yes)", "$($script:lang.char_no)")
        if($confirm -eq $script:lang.char_no)
        {
            break
        }

        # Getting the OU path
        $ounev
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
                $nextmove = $true
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
        $timestamp = Timestamp
        $csvout = [CSV]::new("$($lang.users)\$ounev\$($lang.backup)", $timestamp)
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
                    $backup | add-member -membertype NoteProperty -name "$($attribute[0])" -Value "$($ADUser)"
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
                    $csvout.Append($backup)
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
        $csvout.Separator()
        $csvout.File("$timestamp-$($lang.failed)")
        $csvout.Create($hiba, $true)
        $kilep = AfterProcess
    } while ($kilep -eq $lang.char_new_proc)
    return $kilep
}

function SavePath
{
# This function is to change the default save path of the program. Right now it changes it
# only temporarely, the permanent change can be made by manually changing the attribute in
# the ini, but I plan to improve the function to do that for us.
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

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
#-#-#                               PROGRAM ENTRY POINT                                       #-#-#
#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

# The main loop of the program. This is where we call the functions and classes from.
do
{ 
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
        1 { $kilep = UsersOfGroup }
        2 { $kilep = SingleUser }
        3 { $kilep = GroupsOfOU }
        4 { $kilep = AllUsersFromOU }
        5 { $kilep = OUUsersComputers $lang.all_computers_of_ou $false $lang.computers $lang.s_computers }
        6 { $kilep = OUUsersComputers $lang.all_users_of_ou $true $lang.users $lang.s_users }
        7 { $kilep = MassModify }
        S { SavePath }
    }    
} while ($kilep -ne $lang.char_quit)