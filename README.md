# aduc-mass
PowerShell code to mass manage active directory objects like users, groups and computers.

It's a very basic console tool at the moment, but in my line of work I found it very powerful, as Active Directory Users and Computers lack some important features. Right now it's able to do the following things:
* Collect the group memberships of a user, and either output them on the console, save them into a csv, or assign them to another user
* Collect the members of a group, and either output them on the console, save them into a csv, or assign them to another group
* Collect the group memberships of all users in an OU, and save them into separate CSVs in a directory, named after the OU
* Collect the members of all groups in an OU, and save them into separate CSVs in a directory, named after the OU
* Collect all users of an OU into a CSV, either filtered by their last logon date, or not
* Collect all computers of an OU into a CSV, either filtered by their last logon date, or not

To make the user's job easier, it can translate the more userfriendly `domain\OU\OU` structure into the distinguishedName, that's required in queries to collect objects from an OU. It can also handle all the exceptions (non-existent OU, OU that doesn't have the queried type of object, username, groupname, not enough rights to modify groups, create files) I encountered so far. It notifies the user of successful, partially successful, unsuccesful outputs of the operations. It also uses an own foldertree (AD-Out, by default it's created in the root of drive D:, but it can be modified by the user) to collect the CSVs, so it doesn't clutter the user's hard drive.
> Does it work without RSAT (Remote Server Administration Tool) installed on the computer?

Yes, and no. It *can* work without RSAT installed, but you'll need `Microsoft.ActiveDirectory.Management.dll`, and `Microsoft.ActiveDirectory.Management.resources.dll` to be put in the same folder where the ps1 file is. Obviously I can't share these DLLs *(it goes without saying you should never download DLLs from any untrusted source)* but you can get them from a PC that has RSAT installed. If a PC has neither RSAT installed, nor these two DLLs in the same folder as the ps1 file, the program won't run at all (it checks these two conditions at the begining, and if neither is met, it won't let you continue).

The language of the program is now English, you just have to download the language file with the main program.

# Future plans
I plan to rewrite the code with a more object oriented approach, but I'm very novice in any kinds of programming, so it might takes some time. Or not. We'll see.
In a very-VERY distant future I plan to rewrite the code in C# so it could have a decent GUI.

Despite I mentioned rewriting the code several times, it already works bugfree as it is, and I can recommend it to every AD admin, who is allowed to use only PowerShell and ADUC to manage their Active Directory.
