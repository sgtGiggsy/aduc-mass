# aduc-mass
PowerShell code to mass manage active directory objects like users, groups and computers.

It's a very basic console tool at the moment, but in my line of work I found it very powerful, as Active Directory Users and Computers lack some important features. Right now it's able to do the following things:
* Collect the group memberships of a user, and either output them on the console, save them into a csv, or assign them to another user
* Collect the members of a group, and either output them on the console, save them into a csv, or assign them to another group
* Collect the group memberships of all users in an OU, and save them into separate CSVs in a directory, named after the OU
* Collect the members of all groups in an OU, and save them into separate CSVs in a directory, named after the OU
* Collect all users of an OU into a CSV, either filtered by their last logon date, or not
* Collect all computers of an OU into a CSV, either filtered by their last logon date, or not

To make the user's job easier, it can translate the more userfriendly domain\OU\OU structure into the distinguishedName, that's required in queries to collect objects from an OU. It can also handle all the exceptions (non-existent OU, username, groupname, not enough rights to modify groups, create files) I encountered so far. It notifies the user of successful, partially successful, unsuccesful outputs of the operations. It also uses an own foldertree (AD-Out, by default it's created in the root of drive D:) to collect the CSVs, so it doesn't clutter the user's hard drive.

# Future plans
As I use the program in Hungarian environment, both the language of the program, and the comments are Hungarian. I plan to turn it into a more flexible form, so at least English language can be supported.
I also plan to rewrite the code with a more object oriented approach, but I'm very novice in any kinds of programming, so it might takes some time. Or not. We'll see.
In a very-VERY distant future I plan to rewrite the code in C# so it could have a decent GUI.

Despite I mentioned rewriting the code several times, it already works bugfree as it is, and I can recommend it to every AD admin, who is allowed to use only PowerShell and ADUC to manage their Active Directory.
