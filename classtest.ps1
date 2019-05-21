$lang = Get-Content ".\Languages\hun.lang" | Out-String | ConvertFrom-StringData
#. .\aduc-mass.ps1


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
function Createcustom {
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
            Write-Host $("({0, 2}) {1, -47}" -f $sorsz, $this.name) -NoNewline
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
            <#$vane = $true
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
            } while ($vane -eq $false)#>
            $this.state = $true
        }
    }
    Out($char)
    {
        if ($this.state)
        {
            Write-Host $("({0}) Choosen OU: {1}" -f $char, $char <#$Script:ounev#>) -NoNewline
            #Write-Host "Choosen OU: " <#$Script:ounev#> -NoNewline
        }
        else 
        {
            Write-Host $("({0}) OU is not set" -f $char) -NoNewline
        }
    }
    [string]Outmethod()
    {
        return $this.ou
    }
}

### Filters
#function Queryfiltering {
 #   param ($isuser, $issingle, $title, $objname)

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
            "Meghivattam"
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
            #Clear-Host
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
        $this.Output()
    }

    Output()
    {
        [string]$properties = "samAccountname"
        [string]$select = "@{n='$($script:lang.username)'; e='samAccountName'}"
        [string]$filter = $null | Out-Null
        [string]$searchbase = $null
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
                $properties += ", $($this.attributes[$i].attribute)"
                $select += ", $($this.attributes[$i].outmethod)"
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
                    $filter += "$($this.filters[$i].Outmethod())"
                }
                else
                {
                    $filter += ", $($this.filters[$i].Outmethod())"
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
            Write-Host "Get-ADUser $this.objname -Properties $properties | Select-Object $select"
        }
        elseif (!($isoufiltered))
        {            
            Write-Host "Get-ADUser -Filter $filter -Properties $properties | Select-Object $select"
        }
        else 
        {
            Write-Host "Get-ADUser -Filter $filter -SearchBase '$($searchbase)' -Properties $properties | Select-Object $select"
            
        }

    }
    else 
    {
        if ($this.issingle)
        {
            Write-Host "$this.objname -Properties $properties | Select-Object $select"
        }
        elseif (!($isoufiltered))
        {
            Write-Host "Get-ADComputer -Filter $filter -Properties $properties | Select-Object $select"
        }
        else 
        {
            Write-Host "Get-ADComputer -Filter $filter -SearchBase $searchbase -Properties $properties | Select-Object $select"
        }
    }
    }
}

<### Attributes
    $attributes = New-Object System.Collections.ArrayList($null)
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
}

# Filters. We need them only if we want to query more users, so they won't show up when querying one user
    if (!($issingle))
    {        
        $filters = New-Object System.Collections.ArrayList($null)
        $filters.Add(($lastlogonfilter = [Filterpairs]::new(($active = "{LastLogonTimeStamp -gt $($time)}"),$lang.active_ones,($inactive = "{LastLogonTimeStamp -lt $($time)}"),$lang.inactive_ones))) > $null
        $filters.Add(($isenabled = [Filterpairs]::new(("{Enabled -eq True}"),$lang.enabled,($isdisabled = "{Enabled -eq False}"),$lang.disabled))) > $null
        $filters.Add(($oufilter = [OUfilter]::new())) > $null
    }

## Attributes
    $attributes = New-Object System.Collections.ArrayList($null)
    $attributes.Add(($lastlogon = [Attribute]::new($lang.last_logon, "LastLogonDate"))) > $null
    $attributes.Add(($enabled = [Attribute]::new($lang.enabled, "enabled"))) > $null
    $attributes.Add(($description = [Attribute]::new($lang.description, "Description"))) > $null
    $attributes.Add(($created = [Attribute]::new($lang.created, "created"))) > $null
    if(!($isuser))
    {
        $attributes.Add(($os = [Attribute]::new($lang.os, "OperatingSystem"))) > $null
        $attributes.Add(($computername = [Attribute]::new($lang.computername, "Name"))) > $null
        $attributes.Add(($IPv4Address = [Attribute]::new($lang.IPv4Address, "IPv4Address"))) > $null
        $attributes.Add(($logoncount = [Attribute]::new($lang.logoncount, "logoncount"))) > $null
    }
    else
    {
        $attributes.Add(($telnumber = [Attribute]::new($lang.telephoneNumber, "telephoneNumber"))) > $null
        $attributes.Add(($company = [Attribute]::new($lang.Company, "Company"))) > $null
        $attributes.Add(($department = [Attribute]::new($lang.department, "Department"))) > $null
        $attributes.Add(($name = [Attribute]::new($lang.name, "Name"))) > $null
        $attributes.Add(($logonWorkstation = [Attribute]::new($lang.logonWorkstation, "logonWorkstation"))) > $null
        $attributes.Add(($mail = [Attribute]::new($lang.mail, "mail"))) > $null
        $attributes.Add(($title = [Attribute]::new($lang.title, "title"))) > $null
    }




Read-Host
    do
    {
        #Clear-Host
        if($isuser -and $issingle)
        {
            Write-Host $objname.Name $lang.user_is_being_queried
        }
        Write-Host $lang.attributes_and_filters"`n"
        if (!($issingle))
        {
            Write-Host $("{0, -55} {1}" -f $lang.available_attribs, $lang.available_filters)
        }
        else
        {
            Write-Host $lang.available_attribs
        }
        [array]$opciok = $null
        [array]$functionexplanation = ($lang.funcexptitle, $lang.custom_attrib_title, $lang.custom_filter_title, $lang.funchelp, $lang.funcfinish)
        $j = 0
        for ($i = 0; $i -lt $attributes.Count; $i++)
        {
            if($i -lt $filters.Count)
            {
                Write-Host $attributes[$i].Out($i) $filters[$i].Out([Filterindex]$i)
                $opciok += ($i +1)
                $opciok += [Filterindex]$i
            }
            elseif($i -gt ($attributes.Count-$functionexplanation.count-1))
            {
                Write-Host $attributes[$i].Out($i) -nonewline
                Write-Host $functionexplanation[$j] -ForegroundColor Gray
                $j++
                $opciok += ($i +1)
            }
            else
            {
                Write-Host $attributes[$i].Out($i)
                $opciok += ($i +1)
            }
        }
        $opciok += "K"
        $opciok += "H"
        $opciok += $lang.attribute
        $opciok += $lang.filter

        $setter = Valaszt($opciok)
        switch ($setter)
            {
                K { }
                H { Read-Host $lang.attribselectmain_help }
                $lang.attribute { Createcustom($setter) }
                $lang.filter { Createcustom($setter) }
                Default 
                {
                    try
                    {
                        [int32]$setter
                        $attributes[$setter-1].Set()
                    }
                    catch
                    {
                        $filters[[Filterindex]::$setter.value__].Set($isuser)
                    }
                }
            }    
    }while($setter -ne "K")
  



    if ($lastlogonfilter.state -ne 0 -and $issingle -eq $false)
    {
        Write-Host $lang.youset_day_filter
        do
        {   
            try
            {
                [int32]$time = Read-Host -Prompt $lang.youset_daynumber
            }
            catch
            {
                Write-Host $lang.non_numeric_value -ForegroundColor Red
            }
        } while(!($time -is [int32]))
        $lastlogonfilter.trueside = "{LastLogonTimeStamp -gt $time}"
        $lastlogonfilter.falseside = "{LastLogonTimeStamp -lt $time}"
    }

    [string]$properties = "samAccountname"
    [string]$select = "@{n=$($lang.username); e='samAccountName'}"
    [string]$filter | Out-Null
    [string]$searchbase

    for($i = 0; $i -lt $attributes.Count; $i++)
        {
            if($attributes[$i].setter)
            {
                $properties += ", $($attributes[$i].attribute)"
                $select += ", $($attributes[$i].outmethod)"
            }
        }
    $filtercount = 0
    $isoufiltered = $false
    for($i = 0; $i -lt $filters.Count; $i++)
    {
        if($filters[$i].state -ne 0 -and $filters[$i].state -ne $false)
        {
            if ($filters[$i] -isnot "OUfilter")
            {
                if($filtercount -eq 0)
                {
                    $filter += "$($filters[$i].Outmethod())"
                }
                else
                {
                    $filter += ", $($filters[$i].Outmethod())"
                }
            }
            elseif($filters[$i].state -eq $true)
            {
                $searchbase = "$($filters[$i].Outmethod())"
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


    if ($isuser)
    {
        if ($issingle)
        {
            $query = Get-ADUser $objname -Properties $properties | Select-Object $select
        }
        elseif (!($isoufiltered))
        {            
            $query = Get-ADUser -Filter $filter -Properties $properties | Select-Object $select
        }
        else 
        {
            $query = Get-ADUser -Filter $filter -SearchBase '$($searchbase)' -Properties $properties | Select-Object $select
            Get-ADUser -Filter * -SearchBase 'OU=KTIK,OU=Users,OU=KCSK59,OU=KIT_Users_Groups,DC=stn,DC=hunmil,DC=local' -Properties samAccountname | Select-Object @{n="Felhasználónév"; e='samAccountName'}
            $query
        }

    }
    else 
    {
        if ($issingle)
        {
            Get-ADComputer $objname -Properties $properties | Select-Object $select
        }
        elseif (!($isoufiltered))
        {
            $query = Get-ADComputer -Filter $filter -Properties $properties | Select-Object $select
        }
        else 
        {
            $query = Get-ADComputer -Filter $filter -SearchBase $searchbase -Properties $properties | Select-Object $select
        }
    }
    #>

    $menu = [QueryFiltering]::new($true, $false, "valami", "valami")
$menu.Menu()

#Write-Host $query
Read-Host
<#$csvout = "$csvdir\$ounev-$($lang.last)-$napja-$($lang.days_active_pc).csv"
CSVfunkciok $ment $csvout
            Write-Host $lang.ou_whats_next
            $kilep = Valaszt ("N", "Q", "R")#>
#}

class QueryType
{
    User()
    {

    }
}
function Userfunction
{    
    param($title, $functionname, $querytype)
    $kilep
    do # The main loop of this menu #
    {
        MenuTitle($title)
        Write-Host $functionname
        $objname = Read-Host -Prompt $lang.id
       # $username = Letezike $username # It calls the function to check if the entered username exist
            
        $simpledetailed = Valaszt("1", "2")

        if ($simpledetailed -eq "1")
        {
            $kilep = GroupsOfUser
        }
        else
        {
            $kilep = Queryfiltering $true $true $objname
        }
    } while ($kilep -eq "U")
    return $kilep
}


class test
{
    [System.Object]micsoda()
    {
        return "visszatér"
    }
}

$grgr = [test]::new()
$a = $grgr.micsoda()

Write-Host $a

$csvinpath = "D:\TelHFKP.csv"
        $incsv = Get-Content $csvinpath