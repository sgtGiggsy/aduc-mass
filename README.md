# aduc-mass
PowerShell code to mass manage active directory objects like users, groups and computers.
It's a very basic console tool at the moment, but in my line of work I found it very powerful, as Active Directory Users and Computers lack some important features.

# Functions
* Collect the group memberships or selectable attributes of a user, and either output them on the console, save them into a csv, or assign them to another user
* Collect the members of a group, and either output them on the console, save them into a csv, or assign them to another group
* Collect the group memberships of all users in an OU, and save them into separate CSVs in a directory, named after the OU
* Collect the members of all groups in an OU, and save them into separate CSVs in a directory, named after the OU
* Collect all users into a CSV, select the attributes we want to show, and filter the result by activity, OU, or enabled/disabled state
* Collect all computers into a CSV, select the attributes we want to show, and filter the result by activity, OU, or enabled/disabled state
* Change user attributes with the contents of a CSV file, while making a backup of the previous attributes.

# Things to know
To make the user's job easier, it can translate the more userfriendly `domain\OU\OU` structure into the distinguishedName, that's required in queries to collect objects from an OU. It can also handle all the exceptions (non-existent OU, OU that doesn't have the queried type of object, username, groupname, not enough rights to modify groups, create files) I encountered so far. It notifies the user of successful, partially successful, unsuccesful outputs of the operations. It also uses an own foldertree (AD-Out, by default it's created in the root of drive D:, but it can be modified by the user) so it doesn't clutter the user's hard drive.

# FAQ
> Does it work without RSAT (Remote Server Administration Tools) installed on the computer?

Yes, and no. Basically it was designed to be used on a computer that *has* RSAT installed, but It *can* work without it. To make it work, you'll need `Microsoft.ActiveDirectory.Management.dll`, and `Microsoft.ActiveDirectory.Management.resources.dll` to be put in the same folder as the ps1 file. Obviously I can't share these DLLs *(it goes without saying you should never download DLLs from any untrusted source)* but if you get them, the program will work without RSAT. If a PC has neither RSAT installed, nor these two DLLs in the same folder as the ps1 file, the program won't run at all (it checks these two conditions at the begining, and if neither is met, it won't let you continue).

> Where can I find these DLLs?

Ironically you'll need a computer that has RSAT installed. The DLLs are in their folders with the same name under `C:\Windows\Microsoft.NET\assembly\GAC_64` or `GAC_32` in case of 32bit OS.

> Which languages are supported?

The program supports English and Hungarian. As my native language is Hungarian, the English translation most likely has grammatical and other errors, though I hope not so many. The comments are also in English. In case you'd like to help me with a translation to your language, I'd be very grateful, but on my own I won't make other translations.

> Do you plan to add functions like adding one user to one group?

I do plan to add more features, but only ones that expand the functionality of ADUC (Active Directory Users and Computers), I see no point in implementing features that already work well in it. I am open to suggestions that can make this program more useful though.

> It's good and everything, but are you serious that everytime I'd like to use it, I have to run the script from command line? Couldn't it be a proper executable?

Okay, this might be such a beginner question that nobody on this site would ask, but since I've put it there, I'm gonna answer it. You can compile the ps1 file to an executable with PS2EXE anytime you'd like. https://gallery.technet.microsoft.com/scriptcenter/PS2EXE-GUI-Convert-e7cb69d5 Don't try to use the GUI version of the compiled EXEs though, in this case, that **REALLY** doesn't work as intended.

# Future plans
**Functions, improvements**

* Bulk copying, bulk disabling and bulk deleting users, computers
* Navigation in the menus with arrow keys

**Other plans**

In a very-VERY distant future I plan to rewrite the code to have a GUI. I considered both C# and PowerShell, but I'm not entirely sure about if I'll actually do it. My main goal with this program was to give admins (naming my colleagues with zero PowerShell knowledge) a free tool they are allowed to use even where third party applications are forbidden. As it just being a PowerShell script (a longer one though, but still) it's probably allowed to use to everyone who has admin rights in their Active Directory. But I'm really not sure if the same would be true about a program that uses C# libraries too, instead of solely relying on PowerShell.


# Known bugs
* The progress counter doesn't show correct value during the actions. It doesn't concern the usage, the values it gives are more or less accurate, and it will be fixed in the next released by changing the counter to a better method.
* The part that collects the unmodifiable attributes during the mass modify function acts strangely, and I don't yet know why. It does collect the unsuccesful changes, but it lists all the attributes before the unsuccesful ones. Basically it gives the needed information, just looks ugly.
* It gives false positive results when the searched object doesn't exist in the type (group, user) we checked, but exist in the other one. I know what causes it, but it doesn't obstruct daily work with the program (two objects can't have the same name in AD, so you most likely meet this bug only if you selected the wrong menu), so it wasn't a priority.

# Other
Of course, I look forward to feature suggestions, bug reports, or anything else you'd like to add.
