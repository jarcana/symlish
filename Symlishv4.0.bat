@echo off

setlocal

:: Exit code: No arguments/help file
if "%~1"=="" (
  echo Usage: %~nx0 source_path
  echo        - First time it is run it will note the given path to a temp file
  echo          by checking if the file exists and if not, creating it.
  echo        - Second time it is run it will check against the temp file
  echo          If the file exists, and does not match, create symlink.
  echo        - All other cases will error with a message, like this one!
  echo
  echo        Written by: Jenny Arcana, 2023, GPLv3
  exit /b 1
)

:: Pull argument as source variable and sanitize it by removing all double quotes that might be put into it by accident
set "source=%~f1"
set "source=%source:"=%"

:: Exit code: No/bad source
if not exist "%source%" (
  echo Error: Source file or directory does not exist.
  exit /b 1
)

set "tempfile=%temp%\temp_symlink.txt"

:: If temp file exists, pull it into memory via "storedsource" and then check argument given against source written to temp file
if exist "%tempfile%" (
  set /p storedsource=<"%tempfile%"
  :: If they do not match, assume directory given is the intended destination for the link and proceed.
  if /i "%source%" neq "%storedsource%" (
    goto MakeSym
  ) else (
    :: Error code: Ïf they do match, throw an error reminding user that they already have a source selected
    if /i "%source%" equ "%storedsource%" (
    Echo Error: Source file or directory already selected
    exit /b 1
    ) else (
      :: Error code: I really don't know how youd get here
      Echo Error: Unknown
      exit /b 1
    )
  )
) else (
  :: If file does not exist, jump to MakeTemp
  goto MakeTemp
)

:MakeTemp
:: Exit code: Write to target file path to text file if it doesn't already exist. Intended behavior. Otherwise jumps to MakeSym or errors
echo "%source%" > "%tempfile%"
echo Success: Source path stored in "%tempfile%". Call the script again with a destination path to create a symlink.
exit /b 0

:MakeSym
:: Overwrites source variable with data pulled from temp file (would be very easy to exploit if the file was modified and the user allowed malicious code to run unknowingly expecting to be prompted for admin credentials to create symlinks)
set "source=%storedsource%"
if not exist "%storedsource%" (
  :: Exit code: Bad path in temp file. Protects against the code injection vulnerability above
  echo Error: Invalid path stored in "%tempfile%".
  exit /b 1
)

:: Pull argument as destination variable and sanitize it by removing all double quotes that might be put into it by accident, will only operate if all above conditions are met; Argument given does not match argument from the first time the script was run
set "destination=%~f1"
set "destination=%destination:"=%"

:: Fetches last leaf of directory tree and resolves it if is a file; to %filename%
for /f "tokens=*" %%a in ('powershell.exe -Command "Split-Path -Path \"%source%\" -Leaf -Resolve"') do set "filename=%%a"
:: Removes spaces at the end of the variable from above
set "filename=%filename: =%"
:: Sets up full final symlink path
set "target=%destination%\%filename%.link"

:: Exit code: Link file already exists under same name, delete temp file
if exist "%target%" (
  echo Error: Link file already exists. Deleting temp file.
  del "%tempfile%"
  exit /b 1
)

:: Create symlink, Note: Quoted very particularly to encase the path variables in quotes within the multi-layer execution
powershell.exe -WindowStyle hidden -Command "Start-Process powershell.exe -WindowStyle hidden -Verb RunAs -ArgumentList \"-Command New-Item -ItemType SymbolicLink -Path \`\"%target%\`\" -Target \`\"%source%\`\"  -Force\" -Wait"

:: If file was created properly, print success, and delete temp file
if exist "%target%" (
  echo Success: Created symlink for "%source%" at "%destination%". Deleting temp file.
  del "%tempfile%"
  exit /b 0
) else (
  :: Exit code: All other errors, and delete temp file
  echo Error: Failed to create symlink for "%source%" at "%destination%". Deleting temp file.
  del "%tempfile%"
  exit /b 1
)