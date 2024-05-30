:: in this config file, define the specifics of your gitsync project just like a cmd file

:: WHAT2BACKUP= list of files and subfolders to backup, default is everything recursively
::              Make it blank to disable local backups
set WHAT2BACKUP=.\*

:: BACKUP_FOLDER=%~dp0\backup by default, defaine another path here
set BACKUP_FOLDER=%~dp0\backup

:: WHAT2EXCLUDE= list of files and subfolders to exclude, 7z format
set WHAT2EXCLUDE=-xr!backup -xr!.svn -xr!.git     -xr!*.7z -xr!*.zip -xr!*.msi -xr!*.msu -xr!*.log -xr!*.exe -xr!*.dll -xr!*.bin -xr!*.mp3 -xr!*.mp4 -xr!*.wmv -xr!*.key -xr!*.crt -xr!*.crl -xr!*.pem -xr!*.cer 

:: rotation=how many backup-%CURRENT_DATE_NOSEP%-%CURRENT_TIME%.7z to append to the main backup.7z before rebuilding it from scratch
set rotation=20

:: editor must be able to lock on the commit file, notepad does that, notepad++ does not. Test with your own
set editor=notepad

:: PROJECT= should match the root folder
set PROJECT=gitsync

:: projectConfig= can be empty == the main batch file that holds a line that says "set version=x.y.z", scrapped to fill in commit file header
set projectConfig=%PROJECT%.cmd

:: buildVersion= a version string like x.y.z used as header in the commit file, coming from %projectConfig%
:: If your project does not have such a file, and buildVersionAutomated=empty, your will be prompted for a version == not unattended
:: setting up buildVersionAutomated=x.y.z avoids this prompt pause, if you want this script to be fully unattended and not have a projectConfig file
set buildVersionAutomated=

:: textFiles are textFiles extensions, add your own to the list
set textFiles=*.txt *.md *.cmd *.bat *.pl *.py *.awk *.ps1 *.ini *.cfg *.sql *.xml *.yml *.yaml *.conf *.config *.json *.properties

:: doUnix2dos will process textFiles with busybox unix2dos before :local_backup
:: That is, if busybox.exe is present on your system in %PATH%
:: This will reset the Archive attribute and the modified time
set doUnix2dos=true
