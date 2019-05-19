﻿$lang = Get-Content ".\Languages\hun.lang" | Out-String | ConvertFrom-StringData
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

    Set()
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
    [bool]$setter = $true
    $ou
    Set()
    {
        Write-Host
        if ($this.setter)
        {
            Write-Host $script:lang.unset_ou
            $yousure = Read-Host -Prompt $script:lang.choose
            if ($yousure -eq $script:lang.yes_char)
            {
                $this.setter = $false
            }
        }
        else
        {
            $this.ou = OUcheck
            $this.setter = $true
        }
    }
    Out($char)
    {
        if ($this.setter)
        {
            Write-Host $("({0}) Choosen OU: {1}" -f $char, $char) -NoNewline
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
function Queryfiltering {
    param ($isuser, $issingle)

    $isuser = $true
    $issingle = $false

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
    if($isuser)
    {
        $attributes.Add(($telnumber = [Attribute]::new($lang.telephoneNumber, "telephoneNumber"))) > $null
        $attributes.Add(($company = [Attribute]::new($lang.Company, "Company"))) > $null
        $attributes.Add(($department = [Attribute]::new($lang.department, "Department"))) > $null
        $attributes.Add(($name = [Attribute]::new($lang.name, "Name"))) > $null
        $attributes.Add(($logonWorkstation = [Attribute]::new($lang.logonWorkstation, "logonWorkstation"))) > $null
        $attributes.Add(($mail = [Attribute]::new($lang.mail, "mail"))) > $null
        $attributes.Add(($title = [Attribute]::new($lang.title, "title"))) > $null
    }


    do
    {
        Clear-Host
        Write-Host "A kimenetben megjelenítendő attribútumok kiválasztása, eredmények szűrése`n"
        if (!($issingle))
        {
            Write-Host "Választható attribútumok`t`t`t`tVálasztható filterek"
        }
        else
        {
            Write-Host "Választható attribútumok"
        }
        [array]$opciok = $null
        [array]$functionexpl = ($lang.funcexptitle, <#$lang.custom_attrib_title, $lang.custom_filter_title,#> $lang.funchelp, $lang.funcfinish)
        $j = 0
        for ($i = 0; $i -lt $attributes.Count; $i++)
        {
            if($i -lt $filters.Count)
            {
                Write-Host $attributes[$i].Out($i) $filters[$i].Out([Filterindex]$i)
                $opciok += ($i +1)
                $opciok += [Filterindex]$i
            }
            elseif($i -gt ($attributes.Count-$functionexpl.count-1))
            {
                Write-Host $attributes[$i].Out($i) -nonewline
                Write-Host $functionexpl[$j] -ForegroundColor Gray
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
                        $filters[[Filterindex]::$setter.value__].Set()
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
    [string]$filter
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
    for($i = 0; $i -lt $filters.Count; $i++)
    {
        if($filters[$i].state -ne 0)
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
            elseif($filters[$i].setter -eq $true)
            {
                $searchbase = "$($filters[$i].Outmethod())"
                $filtercount--
            }
            $filtercount++
        }
    }
    if($filtercount -eq 0)
    {
        $filter = "*"
    }

Write-Host "-Filter $filter -SearchBase $searchbase -Properties $properties | Select-Object $select"
    Read-Host
}