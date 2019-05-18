$lang = Get-Content ".\Languages\hun.lang" | Out-String | ConvertFrom-StringData
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

function Createcustom {
    param ($attribfilter)
# Create custom attributes
    Clear-Host
    if ($attribfilter -eq $lang.attribute)
    {
        do
        {
            Write-Host $lang.create_custom_attrib
            Write-Host $lang.create_custom_attrib_expl
            $customname = Read-Host -Prompt $lang.custom_attr_dispname
            if($customname -eq $lang.custom_finish)
            {
                Break
            }
            if($customname -eq "H")
            {
                $lang.custom_attr_dispname_help
            }
            $customattribute = Read-Host -Prompt $lang.custom_attr_msname
            if($customattribute -eq $lang.custom_finish)
            {
                Break
            }
            if($customname -eq "H")
            {
                $lang.custom_attr_msname_help
            }
            $attributes.Add(($customattribute = [Attribute]::new($customname, $customattribute))) > $null
        }while ($customname -ne $lang.custom_finish)
    }
    if ($attribfilter -eq $lang.attribute)
    {
        do
        {

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
            Write-Host "($char)" $this.truesidename $pointer $this.falsesidename -NoNewline
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
            Write-Host "($sorsz) $($this.name)`t`t`t`t" -NoNewline
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

    #$ment = Get-ADComputer -Filter $activity -SearchBase $ou -Properties $properties | select @{n=$lang.computername; e='name'}, @{n=$lang.last_logon;e='LastLogonDate'}, @{n=$lang.OS; e='OperatingSystem'}
### Filters
$filters = New-Object System.Collections.ArrayList($null)
$filters.Add(($lastlogonfilter = [Filterpairs]::new(($active = "{LastLogonTimeStamp -gt $($time)}"),$lang.active_ones,($inactive = "{LastLogonTimeStamp -lt $($time)}"),$lang.inactive_ones))) > $null
$filters.Add(($isenabled = [Filterpairs]::new(("{Enabled -eq True}"),$lang.enabled,($isdisabled = "{Enabled -eq False}"),$lang.disabled))) > $null

## Attributes
$attributes = New-Object System.Collections.ArrayList($null)
$attributes.Add(($lastlogon = [Attribute]::new($lang.last_logon, "LastLogonDate"))) > $null
$attributes.Add(($os = [Attribute]::new($lang.os, "OperatingSystem"))) > $null
$attributes.Add(($telnumber = [Attribute]::new($lang.telephoneNumber, "telephoneNumber"))) > $null
$attributes.Add(($enabled = [Attribute]::new($lang.enabled, "enabled"))) > $null
$attributes.Add(($company = [Attribute]::new($lang.Company, "Company"))) > $null
$attributes.Add(($department = [Attribute]::new($lang.department, "Department"))) > $null
$attributes.Add(($name = [Attribute]::new($lang.name, "Name"))) > $null
$attributes.Add(($computername = [Attribute]::new($lang.computername, "Name"))) > $null
$attributes.Add(($description = [Attribute]::new($lang.description, "Description"))) > $null
$attributes.Add(($logonWorkstation = [Attribute]::new($lang.logonWorkstation, "logonWorkstation"))) > $null
$attributes.Add(($mail = [Attribute]::new($lang.mail, "mail"))) > $null
$attributes.Add(($title = [Attribute]::new($lang.title, "title"))) > $null


## For later use
$unfiltered = "*"


do
    {
    #Clear-Host
    Write-Host "A kimenetben megjelenítendő attribútumok kiválasztása, eredmények szűrése`n"
    Write-Host "Választható attribútumok`t`t`t`tVálasztható filterek"
    [array]$opciok = $null
    [array]$functionexpl = ($lang.funcexptitle, $lang.custom_attrib_title, $lang.custom_filter_title, $lang.funchelp, $lang.funcfinish)
    $j = 0
    for ($i = 0; $i -lt $attributes.Count; $i++)
    {
        if($i -lt $filters.Count)
        {
            Write-Host $attributes[$i].Out($i) $filters[$i].Out([Filterindex]$i)
            $opciok += ($i +1)
            $opciok += [Filterindex]$i
        }
        elseif($i -gt $attributes.Count-6)
        {
            Write-Host $attributes[$i].Out($i) -nonewline
            Write-Host "`t"$functionexpl[$j] -ForegroundColor Gray
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
    <# For debug purposes. We can see the contents of allowed input with it
    for($i = 0; $i -lt $opciok.Length; $i++)
    {
        Write-Host $opciok[$i] "`t" -nonewline
    }#>

    $setter = Valaszt($opciok)
    switch ($setter)
        {
            K { }
            H { }
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
    
if ($lastlogonfilter.state -ne 0)
{
    $time = "Placeholder" 
    $lastlogonfilter.Outmethod()
}