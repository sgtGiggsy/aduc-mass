### Language ###
$sysloc = Get-WinSystemLocale
if ($sysloc.Name -eq "hu-HU")
    {
        . .\hun.ps1
    }
else
    {
        . .\eng.ps1
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
            Write-Host $lang_ad_module_not_installed -ForegroundColor Red
            Read-Host
        break
        }
    } 

# Second check. It warns the user if they try to run the program with user level rights. Most functions work without admin rights, but it still worth to notify the user about it.
$admine = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (!($admine.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))
    {
        cls
        $title = $lang_title_user
        Write-Host $title -ForegroundColor Yellow
        Write-Host $lang_warn_not_admin -ForegroundColor Yellow
        $admin = $false
        Read-Host
    }
else 
    {
        $title = $lang_title_admin
        $admin = $true
        $title
    }
$script:path = "D:\AD-Out" # The root of the default save path for csvs.

### Functions ###

## Function to translate the traditional Domain/Organizational Unit form into the DistinguishedName that's needed to filter queries on a certain OU
function OUnevfordito
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

## This function is responsible to check if users entered one of the allowed choices
function Valaszt
{
    param($choice) # It receives an array of the possible choices, it's not fixed, so it doesn't matter if we have 2 allowed choices, or 30
    $probalkozottmar = $false
    do
    {        
        if ($probalkozottmar -eq $false) # Here the user enters their choice, if it's their first try
        {
            $valasztas = Read-Host -Prompt $lang_choose
        }
        else
        {
            Write-Host "`n`n$lang_choose_err" -ForegroundColor Yellow # This is the error message, the user gets here after every single bad entry
            $valasztas = Read-Host -Prompt $lang_choose
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
                Write-Host "`n$lang_file_not_created" -ForegroundColor Red # Warning if the file can't be created
            }        
        }
    }
    else
    {
        $lang_object_not_consist | Set-Content $csvout # This writes a default value in created csvs if the pipeline was empty
    }

    if(Test-Path -Path $csvout) # This tests if the file exist, notifies the user about it, and puts the separator part at the first line, in case csvs with comma separators aren't automatically recognized by Excell as spreadheets
        {
            if ($noout -eq $false)
            {
                Write-Host "`n$lang_file_is_created" $csvout -ForegroundColor Green
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
                Write-Host "`n$lang_id_not_exist" "`n" -ForegroundColor Red
                $obj = Read-Host -Prompt $lang_reenter_id
            }
    } while (@(Get-ADObject -Filter { SamAccountName -eq $obj }).Count -eq 0)
    return $obj
}

## This function checks if the OU the user entered, exist.
function OUcheck
{
    param ($eredetiou)
    $ouletezik = $false
    do 
    {
        try # It gets the value from the main part of the program, sends it to the ou-distinguishedname interpreter, then checks if it exist. If not, it asks the user to enter the value again
        {            
            $ou = OUnevfordito $eredetiou 
            Get-ADOrganizationalUnit -Identity $ou | Out-Null
            $ouletezik = $true
        }
        catch
        {
            Write-Host $lang_non_existent_ou -ForegroundColor Red
            $eredetiou = Read-Host -Prompt $lang_enter_ou
            $ouletezik = $false
        }
    } while ($ouletezik -eq $false)
    return $ou
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
            Write-Host $lang_directory_cant_be_created -ForegroundColor Red    
        }
    }
    return $csvpath
}

####### Program entry point ########

# The main loop of the program. The user won't leave this from now, until they close the program. #
do
{ 
    # Choose from the given options #
    cls
    $title
    Write-Host $lang_main_menu $lang_old_path $script:path
    $mit = Valaszt ("1", "2", "3", "4", "5", "6", "S")

    cls
    switch ($mit)
    {
    1 # Actions on a single group. Get users, write them on the host, save them into a csv, or copy its users to another group #
        {
            do # The main loop of this menu #
            {
            cls
            $title
            $csopnev = Read-Host -Prompt $lang_enter_group_name
            $csopnev = Letezike $csopnev # It calls the function to check if the entered groupname exist

                # Second loop in this program. We get here if we want to do different tasks with the group #
                do
                {                       
                    cls
                    $title
                    Write-Host $lang_i_found $csopnev $lang_the_group -ForegroundColor Green
                    if ($admin) # As we probably don't want users to modify groups, most likely they don't even have rights to do so, we won't even show the option to them
                    {
                        Write-Host $lang_group_whats_next_admin
                        $kiir = Valaszt ("1", "2", "3")
                    }
                    else
                    {
                        Write-Host $lang_group_whats_next_user
                        $kiir = Valaszt ("1", "2", "3")
                    }

                    switch ($kiir)
                        {
                            1 # Write users of the group on console #
                                {
                                    Get-ADGroupMember -identity $csopnev | Get-ADObject -Properties description, samAccountName | select @{n=$lang_name; e='name'}, @{n=$lang_description; e='description'}, @{n=$lang_username; e='samAccountName'} | Out-String
                                    Write-Host $lang_group_whats_next
                                    $kilep = Valaszt ("M", "N", "U", "Q")
                                }
                            2 # Save users of the group in a csv #
                                {
                                    $csvdir = $lang_groups
                                    $csvdir = CSVdir $csvdir

                                    $csvout = "$csvdir\$csopnev.csv"
                                    $ment = Get-ADGroupMember -identity $csopnev | Get-ADObject -Properties description, samAccountName | select @{n=$lang_name; e='name'}, @{n=$lang_description; e='description'}, @{n=$lang_username; e='samAccountName'}
                                    CSVfunkciok $ment $csvout
                                    
                                    Write-Host "`n$lang_group_whats_next"
                                    $kilep = Valaszt ("M", "N", "U", "Q")
                                }
                            3 # Add users to another group #
                                {
                                    # Inner loop. We repeat this, if we want to add the contents of the group to another group #
                                    do
                                    {
                                        $kitol = Get-ADGroup $csopnev                                        
                                        cls
                                        $title
                                        Write-Host $lang_group_members_copy_the $kitol.name $lang_group_members_copy"`n"
                                        $newgroup = Read-Host -Prompt $lang_enter_target_group
                                        $newgroup = Letezike $newgroup

                                        # The process of adding the members to the other group #
                                        [array]$members = Get-ADGroupMember $csopnev;
                                        $kihez = Get-ADGroup $newgroup                    
                                        cls
                                        $title
                                        Write-Host $kitol.Name $lang_group_members_copying $kihez.Name $lang_to_group

                                        $elemszam = $members.Count

                                        for ($i=0; $i -lt $elemszam; $i++)
                                            {
                                                # Catch exceptions #
                                                try
                                                {
                                                    Add-ADGroupMember -Identity $newgroup -Members $members[$i]
                                                    Write-Host "`r$i/"$elemszam $lang_copy_of -NoNewline
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
                                            if ($hiba -eq $true)
                                            {
                                                cls
                                                $title
                                                Write-Host $lang_task_unsuccesful -ForegroundColor Red
                                                Write-Host $lang_you_have_no_rights $kihez.Name $lang_to_modify_group -ForegroundColor Red
                                                }
                                            else
                                            {
                                                cls
                                                $title
                                                Write-Host $lang_task_fully_succesful -ForegroundColor Green
                                            }
                                            Write-Host "`n"r$lang_copy_groups_whats_next
                                            $kilep = Valaszt ("M", "N", "Q", "R", "U")                                            
                                    } while ($kilep -eq "R")                    
                                }
                        }
                } while ($kilep -eq "M")
            } while ($kilep -eq "U")
        }

    2 # Actions on a single user. Get ugroup memberships, write them on the host, save them into a csv, or copy them to another user #
        {            
            do # The main loop of this menu #
            {
                cls
                $title
                $username = Read-Host -Prompt $lang_enter_username
                $username = Letezike $username # It calls the function to check if the entered username exist
                
                do # Second loop in this program. We get here if we want to do different tasks with the user #
                {          
                    cls
                    $title
                    $kitol = Get-ADUser $username 
                    Write-Host $lang_i_found $username $lang_the_user $kitol.name"`n" -ForegroundColor Green
                    if ($admin) # As we probably don't want users to modify groups, most likely they don't even have rights to do so, we won't even show the option to them
                    {
                        Write-Host $lang_user_whats_next_admin
                        $kiir = Valaszt ("1", "2", "3")
                    }
                    else
                    {
                        Write-Host $lang_user_whats_next_user
                        $kiir = Valaszt ("1", "2", "3")
                    }

                    switch ($kiir)
                    {
                        1 # Write group memberships on the console #
                            {
                                cls
                                $title
                                Get-ADPrincipalGroupMembership $username | select  @{n=$lang_group_name; e='name'}  | Out-String
                                Write-Host "`n$lang_user_whats_next"
                                $kilep = Valaszt ("M", "N", "U", "Q")
                            }
                        2 # Saving group memberships in a file #
                            {
                                $csvdir = $lang_users
                                $csvdir = CSVdir $csvdir

                                $csvout = "$csvdir\$username-$lang_s_rights.csv"
                                $ment = Get-ADPrincipalGroupMembership $username | select @{n=$lang_group_name; e='name'}
                                CSVfunkciok $ment $csvout                                

                                Write-Host "`n$lang_user_whats_next"
                                $kilep = Valaszt ("M", "N", "U", "Q")
                            }
                        3 # Copying group memberships to another user #
                            {
                                # Inner loop. We get back here if the user of the program wants to copy source user's memberships to another user #
                                do 
                                {
                                    cls
                                    $title          
                                    Write-Host $kitol.Name $lang_users_groups_copy
                                    $newuser = Read-Host -Prompt $lang_enter_target_user
                                    $newuser = Letezike $newuser
                                    
                                    # A The process of copying memberships #
                                    [array]$csopnevek = Get-ADPrincipalGroupMembership $username;
                                    $kihez = Get-ADUser $newuser
                                    $elemszam = $csopnevek.Count

                                    cls
                                    $title
                                    Write-Host $kitol.Name $lang_users_groups_copying $kihez.Name $lang_to_user
                                    for ($i=0; $i -lt $elemszam; $i++)
                                        {
                                            # Catch exceptions. It won't show them here, but collected at the end of the process #
                                            try
                                                {
                                                    Add-ADGroupMember -Identity $csopnevek[$i] -Members $newuser
                                                    Write-Host "`r$i/"$elemszam $lang_copy_of -NoNewline
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
                                                cls
                                                $title
                                                Write-Host $lang_have_no_rights_to_modify_groups -ForegroundColor Red
                                            }
                                            else  # In case of a partially succesful task. We'll write the collected unsuccesful processes here
                                            {
                                                cls
                                                $sikeres = $elemszam-$hiba.Count
                                                $title
                                                Write-Host $lang_task_ended_with_errors -ForegroundColor Yellow
                                                for ($j=0; $j -lt $hiba.Count; $j++)
                                                    {
                                                        Write-Host $lang_you_have_no_rights $hiba[$j] $lang_to_modify_group -ForegroundColor Yellow                                                    
                                                    }
                                                # A notification about the number of succesful copies
                                                Write-Host $kihez.Name $lang_user_added $sikeres $lang_to_group_of $elemszam $lang_of_groups -ForegroundColor Yellow
                                            }
                                        }
                                        # Best case scenario, notification in case of a fully succesful task #
                                        else
                                        {
                                            cls
                                            $title
                                            Write-Host $lang_task_fully_succesful -ForegroundColor Green
                                        }
                                        Write-Host $lang_copy_users_whats_next
                                        $kilep = Valaszt ("R", "M", "N", "Q", "U")                                                                                
                                } while ($kilep -eq "R")                                
                            }
                    }
                } while ($kilep -eq "M")
            } while ($kilep -eq "U")
        }

    3 # All members of all groups from a certain OU, collected in separate csvs #
        {
            do
            {
                cls
                $title
                do
                {
                    Write-Host $lang_all_groups_of_ou
                    $eredetiou = Read-Host -Prompt $lang_enter_ou                        
                    $ou = OUcheck $eredetiou # It calls the function to check if the entered OU exist
                    $ounev = $Script:ounev # It calls the $script:ounev variable from OUcheck function, so we could create separate folders by OUs
                
                    $vane = $true
                    [array]$csopnevek = Get-ADGroup -SearchBase $ou -Filter *

                    if($csopnevek.Length -eq 0) # This conditional checks if there are groups in the OU, and doesn't let the user continue until they enter an OU that has groups in it
                    {
                        Write-Host $lang_no_groups_in_ou -ForegroundColor Red
                        $vane = $false                        
                    }                    
                } while ($vane -eq $false)

                $elemszam = $csopnevek.Count

                $csvdir = "$lang_groups\$ounev"
                $csvdir = CSVdir $csvdir

                    $progressbar = 100 / $elemszam # To count one item means how much in percentage of the whole process
                    Write-Host $lang_progress

                    for ($i=0; $i -lt $elemszam; $i++)
                    {
                        $csvname = $csopnevek[$i].name
                        $csvout = "$csvdir\$csvname.csv"
                        
                        $csopnev = Get-ADGroup $csopnevek[$i].samAccountName
                        $ment = Get-ADGroupMember -identity $csopnev | Get-ADObject -Properties description, samAccountName | select @{n=$lang_name; e='name'}, @{n=$lang_description; e='description'}, @{n=$lang_username; e='samAccountName'}
                        CSVfunkciok $ment $csvout $true
                        $percentage = [math]::Round($progressbar * ($i+1)) # To count the current percentage
                        Write-Host "`r$Percentage%" -NoNewline # To show the current percentage to the user, without putting it into a new line
                    }               
                    
                Write-Host "`n$lang_ou_whats_next"
                $kilep = Valaszt ("N", "Q", "R")
            } while ($kilep -eq "R")
        }

    4 # All memberships of every user in a certain OU #
        {
            do
            {
                cls
                $title
                # Loop that gets the OU, checks if there are users in it, then continues
                do
                {
                    Write-Host $lang_all_users_of_ou                    
                    $eredetiou = Read-Host -Prompt $lang_enter_ou
                    $ou = OUcheck $eredetiou
                    $ounev = $Script:ounev
                
                    $vane = $true
                    [array]$userek = Get-ADUser -SearchBase $ou -Filter *

                    if($userek.Length -eq 0) 
                    {
                        Write-Host $lang_no_users_in_ou -ForegroundColor Red
                        $vane = $false                        
                    }                    
                } while ($vane -eq $false)

                $elemszam = $userek.Count

                $csvdir = "$lang_users\$ounev"
                $csvdir = CSVdir $csvdir

                    $progressbar = 100 / $elemszam
                    Write-Host $lang_progress

                    for ($i=0; $i -lt $elemszam; $i++)
                    {
                        $csvname = $userek[$i].samAccountName
                        $csvout = "$csvdir\$csvname.csv"
                        
                        $username = Get-ADUser $userek[$i].samAccountName
                        $ment = Get-ADPrincipalGroupMembership $username | select @{n=$lang_group_name; e='name'}
                        CSVfunkciok $ment $csvout $true
                        $percentage = [math]::Round($progressbar * ($i+1))
                        Write-Host "`r$Percentage%" -NoNewline
                    }               
                    
                Write-Host "`n$lang_ou_whats_next"
                $kilep = Valaszt ("N", "Q", "R")
            } while ($kilep -eq "R")
        }

    5 # All PCs of a certain OU, filtered or not filtered by recent activity #
        {
            do
            {
                cls
                $title
                # Loop that gets the OU, checks if there are PCs in it, then continues
                do
                {
                    Write-Host $lang_all_computers_of_ou
                    $eredetiou = Read-Host -Prompt $lang_enter_ou
                    $ou = OUcheck $eredetiou
                    $ounev = $Script:ounev                
                    
                    $vane = $true
                    $teszt = Get-ADComputer -Filter * -SearchBase $ou
                    
                    if($teszt.Length -eq 0)
                    {
                        Write-Host $lang_no_computers_in_ou -ForegroundColor Red
                        $vane = $false                        
                    }                    
                } while ($vane -eq $false)

                $csvdir = $lang_computers
                $csvdir = CSVdir $csvdir
                
                cls
                $title
                Write-Host $lang_ou_exist -ForegroundColor Green
                Write-Host $lang_generic_or_activity_filtered # Decide what kind of list we'd like to recieve
                $szurt = Valaszt ("1", "2")
                
                if ($szurt -eq 2) # In case we'd like a filtered list
                {
                    cls
                    $title
                    Write-Host $lang_the $eredetiou $lang_computers_of_ou
                    $napja = Read-Host -Prompt $lang_how_many_days
                    $time = (Get-Date).Adddays(-($napja))

                    cls
                    $title
                    Write-Host $lang_the $eredetiou $lang_computers_last $napja $lang_days_of_activity
                    Write-Host $lang_active_or_inactive # Decide if we'd like a list about the active, or inactive PCs
                    $avi = Valaszt ("1", "2")

                    if ($avi -eq "1")
                        {
                            $csvout = "$csvdir\$ounev-$lang_last-$napja-$lang_days_active_pc.csv"
                            $ment = Get-ADComputer -Filter {LastLogonTimeStamp -gt $time} -SearchBase $ou -Properties LastLogonDate, OperatingSystem | select @{n=$lang_computername; e='name'}, @{n=$lang_last_logon;e='LastLogonDate'}, @{n=$lang_OS; e='OperatingSystem'}
                        }
                    else
                        {
                            $csvout = "$csvdir\$ounev-$lang_last-$napja-$lang_days_inactive_pc.csv"
                            $ment = Get-ADComputer -Filter {LastLogonTimeStamp -lt $time} -SearchBase $ou -Properties LastLogonDate, OperatingSystem | select @{n=$lang_computername; e='name'}, @{n=$lang_last_logon;e='LastLogonDate'}, @{n=$lang_OS; e='OperatingSystem'}
                        }
                }
                else
                {
                    cls
                    $title
                    $csvout = "$csvdir\$ounev-OU-$lang_computers.csv"
                    $ment = Get-ADComputer -Filter * -SearchBase $ou -Properties LastLogonDate, OperatingSystem | select @{n=$lang_computername; e='name'}, @{n=$lang_last_logon;e='LastLogonDate'}, @{n=$lang_OS; e='OperatingSystem'}
                }
                CSVfunkciok $ment $csvout
                Write-Host $lang_ou_whats_next
                $kilep = Valaszt ("N", "Q", "R")
            } while ($kilep -eq "R")
        }

    6 # All Users of an OU, filtered or not filtered by their activity #
        {
            cls
            $title
            # Loop that gets the OU, checks if there are users in it, then continues
            do
            {

                Write-Host $lang_users_of_ou
                $eredetiou = Read-Host -Prompt $lang_enter_ou
                $ou = OUcheck $eredetiou
                $ounev = $Script:ounev

                $vane = $true
                $teszt = Get-ADUser -Filter * -SearchBase $ou

                if($teszt.Length -eq 0)
                    {
                        Write-Host $lang_no_users_in_ou -ForegroundColor Red
                        $vane = $false
                    }                    
            } while ($vane -eq $false)

            $csvdir = $lang_users
            $csvdir = CSVdir $csvdir

            cls
            $title
            Write-Host $lang_ou_exist -ForegroundColor Green
            Write-Host $lang_generic_or_activity_filtered
            $szurt = Valaszt ("1", "2") # Decide what kind of list we'd like to recieve

            if ($szurt -eq 2) # In case we'd like a filtered list
                {
                    cls
                    $title
                    Write-Host $lang_the $eredetiou $lang_ou_users                
                    $napja = Read-Host -Prompt $lang_how_many_days
                    $time = (Get-Date).Adddays(-($napja))

                    cls
                    $title
                    Write-Host $lang_the $eredetiou $lang_users_last $napja $lang_days_of_activity
                    Write-Host $lang_active_or_inactive # Decide if we'd like a list about the active, or inactive users 
                    $avi = Valaszt ("1", "2")

                    if ($avi -eq "1")
                        {
                            $csvout = "$csvdir\$ounev-$lang_last-$napja-$lang_days_active_users.csv"
                            $ment = Get-ADUser -Filter {LastLogonTimeStamp -gt $time} -SearchBase $ou -Properties name, SamAccountName, description, LastLogonDate | select @{n=$lang_name; e='name'}, @{n=$lang_description; e='description'}, @{n=$lang_username; e='samAccountName'}, @{n=$lang_last_logon;e='LastLogonDate'}
                        }
                    else
                        {
                            $csvout = "$csvdir\$ounev-$lang_last-$napja-$lang_days_inactive_users.csv"
                            $ment = Get-ADUser -Filter {LastLogonTimeStamp -lt $time} -SearchBase $ou -Properties name, SamAccountName, description, LastLogonDate | select @{n=$lang_name; e='name'}, @{n=$lang_description; e='description'}, @{n=$lang_username; e='samAccountName'}, @{n=$lang_last_logon;e='LastLogonDate'}
                        }
                }
            else
                {
                    cls
                    $title
                    $csvout = "$csvdir\$ounev-OU-$lang_users_of.csv"
                    $ment = Get-ADUser -Filter * -SearchBase $ou -Properties name, SamAccountName, description, LastLogonDate | select @{n=$lang_name; e='name'}, @{n=$lang_description; e='description'}, @{n=$lang_username; e='samAccountName'}, @{n=$lang_last_logon;e='LastLogonDate'}
                }
            CSVfunkciok $ment $csvout
            Write-Host $lang_ou_whats_next
            $kilep = Valaszt ("N", "Q", "R")
        }
    S # Modify the save path of csvs
        {
            cls
            $title
            Write-Host $lang_old_path $script:path "`n"                            
            $newpath = Read-Host -Prompt $lang_new_path

            if(!(Test-Path -Path $newpath))
            {
                Write-Host $lang_folder_not_exist
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
                            Write-Host "`n$lang_directory_cant_be_created" -ForegroundColor Red
                            Write-Host $lang_new_or_exit
                            $neworold = Valaszt ("1", "2")
                            
                            if ($neworold -eq "2")
                            {
                                $newpath = $script:path
                            }
                            else
                            {
                                $newpath = Read-Host -Prompt $lang_new_path
                            }
                        }
                    } 
                } while (!(Test-Path -Path $newpath) -and $fold -eq "1" -and $neworold -ne "2")
            }

            $script:path = $newpath
        }
    }
} while ($kilep -ne "Q")