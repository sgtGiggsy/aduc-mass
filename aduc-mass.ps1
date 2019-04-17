function OUnevfordito
{
    param($bemenet)
    $kimenet = $bemenet.Split("/")
    
    for ($i = $kimenet.Length-1; $i -gt -1; $i--)
    {
        if ($i -ne 0)
        {
            if ($i -eq $kimenet.Length-1)
            {
                $ounev = $kimenet[$i]
            }
            $forditott += "OU="+ $kimenet[$i]+","
        }
        else 
        {
            $dcnevold = $kimenet[$i]
            $dcnevtemp = $dcnevold.Split(".")
          #  $dcnevtemp
            for ($j = 0; $j -lt $dcnevtemp.Length; $j++)
            {
                if ($j -lt $dcnevtemp.Length-1)
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
    return $forditott
}

function OUment
{
    param($bemenet)
    $kimenet = $bemenet.Split(",OU=")
    return $kimenet[3]
}

function Valaszt
{
    param($choice)
    $probalkozottmar = $false
    do
    {        
        if ($probalkozottmar -eq $false)
        {
            $valasztas = Read-Host -Prompt "Válassz"
        }
        else
        {
            Write-Host "`n`nKérlek csak a megadott lehetőségek közül válassz!"  -ForegroundColor Yellow
            $valasztas = Read-Host -Prompt "Válassz"
        }
        $teszt = $false
        for ($i=0; $i -lt $choice.Length; $i++)
        {
            if ($valasztas -eq $choice[$i])
            {
                $teszt = $true
                break
            }
            $probalkozottmar = $true
        }
    } while ($teszt -ne $true)
    return $valasztas
}

function CSVfunkciok
{
    param ($bemenet, $csvout, [bool]$noout)

    if ($null -ne $bemenet)
    {
        try
        {
            $bemenet | export-csv -encoding Unicode -path $csvout -NoTypeInformation
        }
        catch
        {
            if ($noout -eq $false)
            {
                Write-Host "`nValami hiba történt, a fájl nem jött létre!" -ForegroundColor Red
            }        
        }
    }
    else
    {
        #Out-String "A csoport nem tartalmaz tagokat" | export-csv -encoding Unicode -path $csvout -NoTypeInformation
        "Az objektum nem tartalmaz tagokat" | Set-Content $csvout
    }

    if(Test-Path -Path $csvout)
        {
            if ($noout -eq $false)
            {
                Write-Host "`nA fájl létrejött. Helye:" $csvout -ForegroundColor Green
            }
                "sep=,`n"+(Get-Content $csvout -Raw) | Set-Content $csvout            
        }
}

function Letezike 
{
    param ($obj)
    do
    {
        if (!(dsquery user -samid $obj) -and !(dsquery group -samid $obj))
            {                
                Write-Host "`nA megadott azonosító nem létezik`n" -ForegroundColor Red
                $obj = Read-Host -Prompt "Kérlek add meg újra a lekérdezendő azonosítót`nAzonosító"
            }
    } while (!(dsquery user -samid $obj) -and !(dsquery group -samid $obj))
    return $obj
}

function OUcheck
{
    param ($eredetiou)
    $ouletezik = $false
    do 
    {
        try
        {            
            $ou = OUnevfordito $eredetiou
            Get-ADOrganizationalUnit -Identity $ou | Out-Null
            $ouletezik = $true
        }
        catch
        {
            Write-Host "Nem létező OU-t adtál meg" -ForegroundColor Red
            $eredetiou = Read-Host -Prompt "Kérlek add meg a lekérdezni kívánt OU elérési útját!`nElérési út"
            $ouletezik = $false
        }
    } while ($ouletezik -eq $false)
    return $ou
}

function CSVdir
{
    param ($csvdir)
    if(!(Test-Path -Path $csvdir))
    {
        New-Item -ItemType directory -Path $csvdir | Out-Null
    }    
}


####### Program belépési pont ########

# Program címsor
$title = "AD Felhasználók és Csoportok - Adminisztrátori mód`n"

# Administrator jogok ellenőrzése - Ha a felhasználó admin, a normál $title van használva, ha nem admin, sárga színű, és figyelmeztetést kap
$admine = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (($admine.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) -eq $false)
    {
        cls
        $title = "AD Felhasználók és Csoportok - Felhasználói mód`n"
        Write-Host "AD Felhasználók és Csoportok - Felhasználói mód`n" -ForegroundColor Red
        Write-Host "FIGYELEM!!!`nNem admin jogokkal futtatod a programot!`n" -ForegroundColor Red
        Write-Host "Bizonyos funkciók így is működni fognak, de csoportok illetve felhasználók módosítására nem lesz jogosultságod."
        Read-Host -Prompt "`nHa ennek ellenére is futtatnád a programot, üss Entert"
    }
else 
    {
        $title
    }

# A program törzsének loopja, ezen belül helyezkedik el az összes lekérdezés
do
{ 
    # A kiválasztandó funkció bekérése #
    cls
    $title
    Write-Host "Mit szeretnél lekérdezni?`n`n(1) Egy csoporthoz tartozó felhasználókat`n(2) Egy felhasználó csoporttagságait`n(3) Egy OU összes csoportjának tagjait`n(4) Egy OU összes felhasználójának csoporttagságait`n(5) Egy OU számítógépeit, akár aktivitás/inaktivitás ideje szerint szűrve`n(6) Egy OU felhasználóit, akár aktivitás/inaktivitás ideje szerint szűrve"
    $mit = Valaszt ("1", "2", "3", "4", "5", "6")


    # A felhasználóval kapcsolatos műveletek #
    cls
    switch ($mit)
    {
    1 # Csoportokkal kapcsolatos műveletek #
        {
            # A csoportokkal kapcsolatos műveletek loopja, ebben helyezkedik el MINDEN csoporttal kapcsolatos művelet, az egy OU összes csoportjának lekérdezésén kívül. Az első loop a csoport nevének megadása ELŐTT kezdődik #
            do
            {
            cls
            $title
            $csopnev = Read-Host -Prompt "Kérlek add meg a lekérdezni kívánt csoport nevét!`nCsoportnév"
            $csopnev = Letezike $csopnev            

                # Ez a csoport nevének megadását követően induló loop. Ide akkor térünk vissza, ha a felhasználó ugyanezzel a csoporttal akar más műveletet végezni. #
                do
                {
                    # A rendszergazda ellenőrzött megkérdezése az adatokkal elvégzendő műveletről #   
                    cls
                    $title
                    Write-Host "Megtaláltam a $csopnev csoportot`n" -ForegroundColor Green
                    Write-Host "Csak kiiratni szeretnéd az eredményt, fájlba menteni, vagy egy másik csoporthoz hozzáadni ennek tagjait?`n`n(1) Ha kiíratnád`n(2) Ha fájlba mentetnéd`n(3) Ha másik csoporthoz adnád a tagokat"
                    $kiir = Valaszt ("1", "2", "3")

                    switch ($kiir)
                        {
                            1 # Csoport tagjainak kiírása #
                                {
                                    Get-ADGroupMember -identity $csopnev | Get-ADObject -Properties description, samAccountName | select @{n='Név'; e='name'}, @{n='Rendfokozat'; e='description'}, @{n='Felhasználónév'; e='samAccountName'} | Out-String
                                    Write-Host "(M) Ha más folyamatot szeretnél futtatni ugyanezzel a forrás csoporttal`n(U) Ha új csoportot szeretnél lekérdezni`n(N) Ha visszalépnél a program elejére`n(Q) Ha kilépnél"
                                    $kilep = Valaszt ("M", "N", "U", "Q")
                                }
                            2 # Csoport taglistájának fájlba mentése #
                                {
                                    $csvdir = "D:\AD-Out\Csoportok"
                                    CSVdir $csvdir

                                    $csvout = "$csvdir\$csopnev.csv"
                                    $ment = Get-ADGroupMember -identity $csopnev | Get-ADObject -Properties description, samAccountName | select @{n='Név'; e='name'}, @{n='Rendfokozat'; e='description'}, @{n='Felhasználónév'; e='samAccountName'}
                                    CSVfunkciok $ment $csvout
                                    
                                    Write-Host "Ha más műveletet szeretnél ezzel a csoporttal, nyomd meg az M-et`nHa új csoportot szeretnél lekérdezni, nyomd meg az U-t`nHa visszalépnél a program elejére, nyomd meg az N-t`nHa pedig kilépnél, nyomd meg a Q-t!"
                                    $kilep = Valaszt ("M", "N", "U", "Q")
                                }
                            3 # Csoport tagjainak hozzáadása másik csoporthoz #
                                {
                                    # Legbelső loop, ide akkor térünk vissza, ha a felhasználó ugyanennek a csoportnak a tagjait még más egyéb csoportokhoz is hozzá akarja adni #
                                    do
                                    {
                                        $kitol = Get-ADGroup $csopnev                                        
                                        cls
                                        $title
                                        Write-Host $kitol.name "csoport tagjainak másolása`n"
                                        # A célcsoport nevének ellenőrzött bekérése #
                                        $newgroup = Read-Host -Prompt "Kérlek, add meg a csoport nevét, amihez hozzá szeretnéd adni a tagokat"
                                        $newgroup = Letezike $newgroup

                                        # A tagok csoporthoz adásának folyamata #
                                        [array]$members = Get-ADGroupMember $csopnev;
                                        $kihez = Get-ADGroup $newgroup                    
                                        cls
                                        $title
                                        Write-Host $kitol.Name "csoport tagjainak hozzáadása" $kihez.Name "csoporthoz."

                                        $elemszam = $members.Count

                                        for ($i=0; $i -lt $elemszam; $i++)
                                            {
                                                # Hibák elkapása #
                                                try
                                                {
                                                    Add-ADGroupMember -Identity $newgroup -Members $members[$i]
                                                    Write-Host "`r$i/"$elemszam "másolása" -NoNewline
                                                }
                                                catch
                                                {                                    
                                                    $hiba = @($newgroup)
                                                }

                                                # Ablak bezáródás előtt a rendszergazda értesítése a folyamat eredményéről #
                                                if ($i -eq $elemszam-1)
                                                {
                                                    # Kigyűjtött hibák kiírása #                                    
                                                    if ($hiba.Count -gt 0)
                                                        {
                                                        cls
                                                        $title
                                                        Write-Host "`nA feladat végrehajtása sikertelen!`n" -ForegroundColor Red
                                                        Write-Host "Nincs jogosultságod a" $hiba "csoport módosítására" -ForegroundColor Red
                                                    }
                                                    else
                                                    {
                                                        cls
                                                        $title
                                                        Write-Host "`nA feladat hibák nélkül futott le." -ForegroundColor Green
                                                    }
                                                    Write-Host "(R) Ha hozzá akarnál adni valaki mást is ugyanezekhez a csoportokhoz`n(M) Ha más folyamatot szeretnél futtatni ugyanezzel a forrás csoporttal`n(U) Ha új csoportot szeretnél lekérdezni`n(N) Ha visszalépnél a program elejére`n(Q) Ha kilépnél"
                                                    $kilep = Valaszt ("M", "N", "Q", "U")
                                                }
                                            }
                                    } while ($kilep -eq "R")                    
                                }
                        }
                } while ($kilep -eq "M")
            } while ($kilep -eq "U")
        }

    2 # Egy felhasználó csoporttagságainak lekérdezése #
        {
            # A felhasználókkal kapcsolatos folyamatok loopja. Ide térünk vissza, ha a folyamat végén az app használója újra felhasználókkal kapcsolatos folyamatot szeretne futtatni.
            do
            {
                cls
                $title
                # A felhasználó nevének ellenőrzött bekérése #
                $username = Read-Host -Prompt "Kérlek add meg a lekérdezni kívánt felhasználó bejelentkezési nevét!`nAzonosító"
                $username = Letezike $username

                # A folyamat ugyanezen felhasználó adatain történő megismétlésének loopja. #
                do
                {
                    # A rendszergazda ellenőrzött megkérdezése az adatokkal elvégzendő műveletről #                
                    cls
                    $title
                    $kitol = Get-ADUser $username 
                    Write-Host "Megtaláltam" $kitol.name "felhasználót, bejelentkezési neve: $username`n" -ForegroundColor Green
                    Write-Host "Csak kiiratni szeretnéd az eredményt, fájlba menteni, vagy átmásolnád a csoporttagságait egy másik felhasználóhoz?`n(1) Ha kiíratnád`n(2) Ha fájlba mentetnéd`n(3) Ha más felhasználóhoz másolnád"
                    $kiir = Valaszt ("1", "2", "3")

                    switch ($kiir)
                    {
                        1 # Csoporttagságok kíírása #
                            {
                                cls
                                $title
                                Get-ADPrincipalGroupMembership $username | select  @{n='Csoportnév'; e='name'}  | Out-String
                                # Az eredmény konzolra kiírása után a felhasználótól a következő lépés bekérése #
                                Write-Host "(M) Ha más folyamatot szeretnél futtatni ugyanezzel a forrás felhasználóval`n(U) Ha új felhasználót szeretnél lekérdezni`n(N) Ha visszalépnél a program elejére`n(Q) Ha kilépnél"
                                $kilep = Valaszt ("M", "N", "U", "Q")
                            }
                        2 # Csoporttagságok fájlba mentése #
                            {
                                $csvdir = "D:\AD-Out\Felhasználók"
                                CSVdir $csvdir

                                $csvout = "$csvdir\$username-jogai.csv"
                                $ment = Get-ADPrincipalGroupMembership $username | select @{n='Csoportnév'; e='name'}
                                CSVfunkciok $ment $csvout                                

                                # Az eredmény konzolra kiírását követően a felhasználótól a következő lépés bekérése #
                                Write-Host "(M) Ha más folyamatot szeretnél futtatni ugyanezzel a forrás felhasználóval`n(U) Ha új felhasználót szeretnél lekérdezni`n(N) Ha visszalépnél a program elejére`n(Q) Ha kilépnél"
                                $kilep = Valaszt ("M", "N", "U", "Q")
                            }
                        3 # Csoporttagságok felhasználóhoz másolása #
                            {
                                # A bekért felhasználó több felhasználóhoz másolásának loopja. Ha egy másolás után az app használója úgy dönt, hogy más felhasználóhoz is bemásolná ugyanezeket a tagságokat, ide térünk vissza #
                                do 
                                {
                                    # A célfelhasználó adatainak ellenőrzött bekérése #
                                    cls
                                    $title          
                                    Write-Host $kitol.Name "felhasználó csoporttagságainak másolása`n"
                                    $newuser = Read-Host -Prompt "Kérlek add meg a felhasználó nevét, akihez másolni szeretnéd a csoporttagságokat`nAzonosító"
                                    $newuser = Letezike $newuser
                                    
                                    # A csoporttagságok másolásának folyamata #
                                    [array]$csopnevek = Get-ADPrincipalGroupMembership $username;
                                    $kihez = Get-ADUser $newuser

                                    $elemszam = $csopnevek.Count

                                    cls
                                    $title
                                    Write-Host $kitol.Name "felhasználó csoporttagságainak másolása" $kihez.Name "felhasználóhoz."
                                    for ($i=0; $i -lt $elemszam; $i++)
                                        {
                                            # Hibák elkapása - Van-e jog a csoportokhoz való hozzáadáshoz #
                                            try
                                                {
                                                    Add-ADGroupMember -Identity $csopnevek[$i] -Members $newuser
                                                    Write-Host "`r$i/"$elemszam "másolása" -NoNewline
                                                }
                                            catch
                                                {                                    
                                                    $hiba += @($csopnevek[$i].SamAccountName)
                                                }

                                            # Ablak bezáródás előtt a rendszergazda értesítése a folyamat eredményéről #
                                            if ($i -eq $elemszam-1)
                                                {
                                                    # Kigyűjtött hibák kiírása #
                                                    if ($hiba.Count -gt 0)
                                                    {
                                                        if ($hiba.Count -eq $elemszam)
                                                        {
                                                            cls
                                                            $title
                                                            Write-Host "Nincs jogosultságod a felhasználó hozzáadására a csoportokhoz!" -ForegroundColor Red
                                                        }
                                                        else {                                            
                                                            cls
                                                            $sikeres = $elemszam-$hiba.Count
                                                            $title
                                                            Write-Host "A feladat lefutott a következő hibákkal:`n" -ForegroundColor Yellow
                                                            for ($j=0; $j -lt $hiba.Count; $j++)
                                                                {
                                                                    Write-Host "Nincs jogosultságod a" $hiba[$j] "csoport módosítására" -ForegroundColor Yellow                                                    
                                                                }
                                                            Write-Host $kihez.Name "felhasználó sikeresen hozzáadva" $sikeres "csoporthoz a" $elemszam "csoportból.`n" -ForegroundColor Yellow
                                                            }
                                                        }
                                                    # Üzenet hibátlan eredmény esetén #
                                                    else
                                                        {
                                                            cls
                                                            $title
                                                            Write-Host "A feladat hibák nélkül futott le." -ForegroundColor Green
                                                        }
                                                    # Felhasználó megkérdezése a folyamat lefutását követő teendőkről #
                                                    Write-Host "(R) Ha hozzá akarnál adni valaki mást is ugyanezekhez a csoportokhoz`n(M) Ha más folyamatot szeretnél futtatni ugyanezzel a forrás felhasználóval`n(U) Ha új felhasználót szeretnél lekérdezni`n(N) Ha visszalépnél a program elejére`n(Q) Ha kilépnél"
                                                    $kilep = Valaszt ("R", "M", "N", "Q", "U")
                                                }
                                        }                                        
                                } while ($kilep -eq "R")                                
                            }
                    }
                } while ($kilep -eq "M")
            } while ($kilep -eq "U")
        }

    3 # Egy OU összes csoportjának tagjai #
        {
            do
            {
                cls
                $title
                do
                {
                    Write-Host "Egy OU ÖSSZES csoportjának lekérdezése`n"
                    $eredetiou = Read-Host -Prompt "Kérlek add meg a lekérdezni kívánt OU elérési útját!`nOU elérési út"
                    $ou = OUcheck $eredetiou
                    $ounev = OUment $ou
                
                    $vane = $true
                    [array]$csopnevek = Get-ADGroup -SearchBase $ou -Filter *

                    if($csopnevek.Length -eq 0)
                    {
                        Write-Host "A megadott OU-ban nincsenek csoportok`n" -ForegroundColor Red
                        $vane = $false                        
                    }                    
                } while ($vane -eq $false)

                $elemszam = $csopnevek.Count

                $csvdir = "D:\AD-Out\Csoportok\$ounev"
                CSVdir $csvdir

                    $progressbar = 100 / $elemszam
                    Write-Host "`nA folyamat állapota:"

                    for ($i=0; $i -lt $elemszam; $i++)
                    {
                        $csvname = $csopnevek[$i].name
                        $csvout = "$csvdir\$csvname.csv"
                        
                        $csopnev = Get-ADGroup $csopnevek[$i].samAccountName
                        $ment = Get-ADGroupMember -identity $csopnev | Get-ADObject -Properties description, samAccountName | select @{n='Név'; e='name'}, @{n='Rendfokozat'; e='description'}, @{n='Felhasználónév'; e='samAccountName'}
                        CSVfunkciok $ment $csvout $true
                        $percentage = [math]::Round($progressbar * ($i+1))
                        Write-Host "`r$Percentage%" -NoNewline
                    }               
                    
                Write-Host "`n`n(R) Ha más OU-t kérdeznél le`n(N) Ha visszalépnél a program elejére`n(Q) Ha kilépnél a programból"
                $kilep = Valaszt ("N", "Q", "R")
            } while ($kilep -eq "R")
        }

    4 # Egy OU minden felhasználójának lekérdezése #
        {
            do
            {
                cls
                $title
                do
                {
                    Write-Host "Egy OU ÖSSZES felhasználójának lekérdezése`n"
                    $eredetiou = Read-Host -Prompt "Kérlek add meg a lekérdezni kívánt OU elérési útját!`nOU elérési út"
                    $ou = OUcheck $eredetiou
                    $ounev = OUment $ou
                
                    $vane = $true
                    [array]$userek = Get-ADUser -SearchBase $ou -Filter *

                    if($userek.Length -eq 0)
                    {
                        Write-Host "A megadott OU-ban nincsenek felhasználók`n" -ForegroundColor Red
                        $vane = $false                        
                    }                    
                } while ($vane -eq $false)

                $elemszam = $userek.Count

                $csvdir = "D:\AD-Out\Felhasználók\$ounev"
                CSVdir $csvdir

                    $progressbar = 100 / $elemszam
                    Write-Host "`nA folyamat állapota:"

                    for ($i=0; $i -lt $elemszam; $i++)
                    {
                        $csvname = $userek[$i].samAccountName
                        $csvout = "$csvdir\$csvname.csv"
                        
                        $username = Get-ADUser $userek[$i].samAccountName
                        $ment = Get-ADPrincipalGroupMembership $username | select @{n='Csoportnév'; e='name'}
                        CSVfunkciok $ment $csvout $true
                        $percentage = [math]::Round($progressbar * ($i+1))
                        Write-Host "`r$Percentage%" -NoNewline
                    }               
                    
                Write-Host "`n`n(R) Ha más OU-t kérdeznél le`n(N) Ha visszalépnél a program elejére`n(Q) Ha kilépnél a programból"
                $kilep = Valaszt ("N", "Q", "R")
            } while ($kilep -eq "R")
        }

    5 # Egy OU számítógépei, akár aktivitás/inaktivitás szerint szűrve #
        {
            do
            {
                cls
                $title
                do
                {
                    Write-Host "Egy OU számítógépeinek lekérdezése`n"
                    $eredetiou = Read-Host -Prompt "Kérlek add meg a lekérdezni kívánt OU elérési útját!`nElérési út"
                    $ou = OUcheck $eredetiou
                    $ounev = OUment $ou                
                    
                    $vane = $true
                    $teszt = Get-ADComputer -Filter * -SearchBase $ou
                    
                    if($teszt.Length -eq 0)
                    {
                        Write-Host "A megadott OU-ban nincsenek számítógépek`n" -ForegroundColor Red
                        $vane = $false                        
                    }                    
                } while ($vane -eq $false)

                $csvdir = "D:\AD-Out\Számítógépek"
                CSVdir $csvdir
                
                cls
                $title
                Write-Host "A keresett OU létezik`n" -ForegroundColor Green
                Write-Host "Csak egy általános listát kérnél le, vagy aktivitás/inaktivitás ideje szerint is szűrnéd?`n`n(1) Általános lista`n(2) Aktivitás/inaktivitás szerint szűrt lista"
                $szurt = Valaszt ("1", "2")
                
                if ($szurt -eq 2)
                {
                    cls
                    $title
                    Write-Host "A(z)" $eredetiou "OU számítógépek lekérdezése`n"                
                    $napja = Read-Host -Prompt "Az elmúlt hány nap során aktív/inaktív gépeket szeretnéd lekérdezni?`nNapok száma"
                    $time = (Get-Date).Adddays(-($napja))

                    cls
                    $title
                    Write-Host "A(z)" $eredetiou "számítógépek elmúlt" $napja "napjának aktivitása`n"
                    Write-Host "Az aktív, vagy inaktív gépeket szeretnéd lekérdezni?`n(1) Ha az aktív gépeket`n(2) Ha az inaktív gépeket"
                    $avi = Valaszt ("1", "2")

                    if ($avi -eq "1")
                        {
                            $csvout = "$csvdir\$ounev-Elmult-$napja-NapbanAktivGepek.csv"
                            $ment = Get-ADComputer -Filter {LastLogonTimeStamp -gt $time} -SearchBase $ou -Properties LastLogonDate, OperatingSystem | select @{n='Gépnév'; e='name'}, @{n='Utolsó bejelentkezés';e='LastLogonDate'}, @{n='Operációs rendszer'; e='OperatingSystem'}
                        }
                    else
                        {
                            $csvout = "$csvdir\$ounev-Elmult-$napja-NapbanInaktivGepek.csv"
                            $ment = Get-ADComputer -Filter {LastLogonTimeStamp -lt $time} -SearchBase $ou -Properties LastLogonDate, OperatingSystem | select @{n='Gépnév'; e='name'}, @{n='Utolsó bejelentkezés';e='LastLogonDate'}, @{n='Operációs rendszer'; e='OperatingSystem'}
                        }
                }
                else
                {
                    cls
                    $title
                    $csvout = "$csvdir\$ounev-OU-Szamitogepei.csv"
                    $ment = Get-ADComputer -Filter * -SearchBase $ou -Properties LastLogonDate, OperatingSystem | select @{n='Gépnév'; e='name'}, @{n='Utolsó bejelentkezés';e='LastLogonDate'}, @{n='Operációs rendszer'; e='OperatingSystem'}
                }
                CSVfunkciok $ment $csvout
                Write-Host "`n(R) Ha más OU-t kérdeznél le`n(N) Ha visszalépnél a program elejére`n(Q) Ha kilépnél a programból"
                $kilep = Valaszt ("N", "Q", "R")
            } while ($kilep -eq "R")
        }

    6 # Egy OU felhasználói, akár aktivitás/inaktivitás szerint szűrve #
        {
            cls
            $title
            do
            {

                Write-Host "Egy OU felhasználóinak lekérdezése`n"
                $eredetiou = Read-Host -Prompt "Kérlek add meg a lekérdezni kívánt OU elérési útját!`nElérési út"
                $ou = OUcheck $eredetiou
                $ounev = OUment $ou

                $vane = $true
                $teszt = Get-ADUser -Filter * -SearchBase $ou

                if($teszt.Length -eq 0)
                    {
                        Write-Host "A megadott OU-ban nincsenek felhasználók`n" -ForegroundColor Red
                        $vane = $false
                    }                    
            } while ($vane -eq $false)

            $csvdir = "D:\AD-Out\Felhasználók"
            CSVdir $csvdir

            cls
            $title
            Write-Host "A keresett OU létezik`n" -ForegroundColor Green
            Write-Host "Csak egy általános listát kérnél le, vagy aktivitás/inaktivitás ideje szerint is szűrnéd?`n`n(1) Általános lista`n(2) Aktivitás/inaktivitás szerint szűrt lista"
            $szurt = Valaszt ("1", "2")

            if ($szurt -eq 2)
                {
                    cls
                    $title
                    Write-Host "A(z)" $eredetiou "OU felhasználók lekérdezése`n"                
                    $napja = Read-Host -Prompt "Az elmúlt hány nap során aktív/inaktív gépeket szeretnéd lekérdezni?`nNapok száma"
                    $time = (Get-Date).Adddays(-($napja))

                    cls
                    $title
                    Write-Host "A(z)" $eredetiou "felhasználók elmúlt" $napja "napjának aktivitása`n"
                    Write-Host "Az aktív, vagy inaktív gépeket szeretnéd lekérdezni?`n(1) Ha az aktív gépeket`n(2) Ha az inaktív gépeket"
                    $avi = Valaszt ("1", "2")

                    if ($avi -eq "1")
                        {
                            $csvout = "$csvdir\$ounev-Elmult-$napja-NapbanAktivFelhasznalok.csv"
                            $ment = Get-ADUser -Filter {LastLogonTimeStamp -gt $time} -SearchBase $ou -Properties name, SamAccountName, description, LastLogonDate | select @{n='Név'; e='name'}, @{n='Rendfokozat'; e='description'}, @{n='Felhasználónév'; e='samAccountName'}, @{n='Utolsó bejelentkezés';e='LastLogonDate'}
                        }
                    else
                        {
                            $csvout = "$csvdir\$ounev-Elmult-$napja-NapbanInaktivFelhasznalok.csv"
                            $ment = Get-ADUser -Filter {LastLogonTimeStamp -lt $time} -SearchBase $ou -Properties name, SamAccountName, description, LastLogonDate | select @{n='Név'; e='name'}, @{n='Rendfokozat'; e='description'}, @{n='Felhasználónév'; e='samAccountName'}, @{n='Utolsó bejelentkezés';e='LastLogonDate'}
                        }
                }
            else
                {
                    cls
                    $title
                    $csvout = "$csvdir\$ounev-OU-Felhasznaloi.csv"
                    $ment = Get-ADUser -Filter * -SearchBase $ou -Properties name, SamAccountName, description, LastLogonDate | select @{n='Név'; e='name'}, @{n='Rendfokozat'; e='description'}, @{n='Felhasználónév'; e='samAccountName'}, @{n='Utolsó bejelentkezés';e='LastLogonDate'}
                }
            CSVfunkciok $ment $csvout
            Write-Host "`n(R) Ha más OU-t kérdeznél le`n(N) Ha visszalépnél a program elejére`n(Q) Ha kilépnél a programból"
            $kilep = Valaszt ("N", "Q", "R")
        }
    }
} while ($kilep -ne "Q")