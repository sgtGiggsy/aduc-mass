# aduc-mass
PowerShell code to mass manage active directory objects like users, groups and computers.
It's a very basic console tool at the moment, but in my line of work I found it very powerful, as Active Directory Users and Computers lack some important features.

# Functions
* Collect the group memberships of a user, and either output them on the console, save them into a csv, or assign them to another user
* Collect the members of a group, and either output them on the console, save them into a csv, or assign them to another group
* Collect the group memberships of all users in an OU, and save them into separate CSVs in a directory, named after the OU
* Collect the members of all groups in an OU, and save them into separate CSVs in a directory, named after the OU
* Collect all users of an OU into a CSV, either filtered by their last logon date, or not
* Collect all computers of an OU into a CSV, either filtered by their last logon date, or not

# Things to know
To make the user's job easier, it can translate the more userfriendly `domain\OU\OU` structure into the distinguishedName, that's required in queries to collect objects from an OU. It can also handle all the exceptions (non-existent OU, OU that doesn't have the queried type of object, username, groupname, not enough rights to modify groups, create files) I encountered so far. It notifies the user of successful, partially successful, unsuccesful outputs of the operations. It also uses an own foldertree (AD-Out, by default it's created in the root of drive D:, but it can be modified by the user) to collect the CSVs, so it doesn't clutter the user's hard drive.

# FAQ
> Does it work without RSAT (Remote Server Administration Tool) installed on the computer?

Yes, and no. Basically it was designed to be used on a computer that *has* RSAT installed, but It *can* work without it. To make it work, you'll need `Microsoft.ActiveDirectory.Management.dll`, and `Microsoft.ActiveDirectory.Management.resources.dll` to be put in the same folder as the ps1 file is. Obviously I can't share these DLLs *(it goes without saying you should never download DLLs from any untrusted source)* but you can get them from a PC that has RSAT installed. If a PC has neither RSAT installed, nor these two DLLs in the same folder as the ps1 file, the program won't run at all (it checks these two conditions at the begining, and if neither is met, it won't let you continue).

> Where can I find these DLLs?

Ironically you'll need a computer that has RSAT installed. The DLLs are in their folders with the same name under `C:\Windows\Microsoft.NET\assembly\GAC_64` or `GAC_32` in case of 32bit OS.

> Which languages are supported?

The program supports English and Hungarian. As my native language is Hungarian, the English translation most likely has grammatical and other errors, though I hope not so many. The comments are also in English.

> It's good and everything, but everytime I'd like to use it, I have to run the script from command line? Couldn't it be a proper executable?

Okay, this might be a beginner question that nobody would ask, but I since I've put it there, I'm gonna answer it. You can compile the ps1 file to an executable with PS2EXE anytime. https://gallery.technet.microsoft.com/scriptcenter/PS2EXE-GUI-Convert-e7cb69d5

# Future plans
**Functions**

Bulk disabling, and bulk deleting users.

**Other plans**

I plan to rewrite the code with a more object oriented approach, but I'm very novice in any kinds of programming, so it might takes some time. Or not. We'll see.
In a very-VERY distant future I plan to rewrite the code in C# so it could have a decent GUI.

Despite I mentioned rewriting the code several times, it already works relatively bugfree as it is, and I can recommend it to every AD admin, who is allowed to use only PowerShell and ADUC to manage their Active Directory.

# Known bugs
When it searches the name of the entered object, it checks among both users and groups, so it gives false positive result in case it finds the name among the other type of object.

# Other
Of course, I look forward to suggestions, bug reports, or anything else you could come up.
