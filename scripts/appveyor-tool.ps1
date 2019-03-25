$CRAN = "https://cloud.r-project.org"
$MIKTEX_MIRROR = "https://miktex.org/download/ctan/systems/win32/miktex/setup/windows-x64/basic-miktex-2.9.7021-x64.exe"

$PERL_MIRROR = "http://strawberryperl.com/download/5.28.1.1/strawberry-perl-5.28.1.1-64bit-portable.zip"
#$PERL_MIRROR = "https://ftp.bit.nl/xbmc/build-deps/win32/strawberry-perl-5.28.0.1-64bit-portable.zip"

# Found at http://zduck.com/2012/powershell-batch-files-exit-codes/
Function Exec
{
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=1)]
        [scriptblock]$Command,
        [Parameter(Position=1, Mandatory=0)]
        [string]$ErrorMessage = "Execution of command failed.`n$Command"
    )
    $ErrorActionPreference = "Continue"
    & $Command 2>&1 | %{ "$_" }
    if ($LastExitCode -ne 0) {
        throw "Exec: $ErrorMessage`nExit code: $LastExitCode"
    }
}

Function Progress
{
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=0)]
        [string]$Message = ""
    )

    $ProgressMessage = '== ' + (Get-Date) + ': ' + $Message

    Write-Host $ProgressMessage -ForegroundColor Magenta
}

Function TravisTool
{
  [CmdletBinding()]
  param (
      [Parameter(Position=0, Mandatory=1)]
      [string[]]$Params
  )

  Exec { bash.exe ../travis-tool.sh $Params }
}

Function InstallR {
  [CmdletBinding()]
  Param()

  if ( -not(Test-Path Env:\R_VERSION) ) {
    $version = "patched"
  }
  Else {
    $version = $env:R_VERSION
  }

  if ( -not(Test-Path Env:\R_ARCH) ) {
    $arch = "i386"
  }
  Else {
    $arch = $env:R_ARCH
  }

  Progress ("Version: " + $version)

  If ($version -eq "devel") {
    $url_path = ""
    $version = "devel"
  }
  ElseIf (($version -eq "stable") -or ($version -eq "release")) {
    $url_path = ""
    $version = $(ConvertFrom-JSON $(Invoke-WebRequest http://rversions.r-pkg.org/r-release-win).Content).version
    If ($version -eq "3.2.4") {
      $version = "3.2.4revised"
    }
  }
  ElseIf ($version -eq "patched") {
    $url_path = ""
    $version = $(ConvertFrom-JSON $(Invoke-WebRequest http://rversions.r-pkg.org/r-release-win).Content).version + "patched"
  }
  ElseIf ($version -eq "oldrel") {
    $version = $(ConvertFrom-JSON $(Invoke-WebRequest http://rversions.r-pkg.org/r-oldrel).Content).version
    $url_path = ("old/" + $version + "/")
  }
  Else {
      $url_path = ("old/" + $version + "/")
  }

  Progress ("URL path: " + $url_path)

  $rurl = $CRAN + "/bin/windows/base/" + $url_path + "R-" + $version + "-win.exe"

  Progress ("Downloading R from: " + $rurl)
  & "C:\Program Files\Git\mingw64\bin\curl.exe" -s -o ../R-win.exe -L $rurl

  Progress "Running R installer"
  Start-Process -FilePath ..\R-win.exe -ArgumentList "/VERYSILENT /DIR=C:\R" -NoNewWindow -Wait

  $RDrive = "C:"
  echo "R is now available on drive $RDrive"

  Progress "Setting PATH"
  $env:PATH = $RDrive + '\R\bin\' + $arch + ';' + 'C:\MinGW\msys\1.0\bin;' + $env:PATH

  Progress "Testing R installation"
  Rscript -e "sessionInfo()"
}

Function InstallRtools {
  if ( -not(Test-Path Env:\RTOOLS_VERSION) ) {
    Progress "Determining Rtools version"
    $rtoolsver = $(Invoke-WebRequest ($CRAN + "/bin/windows/Rtools/VERSION.txt")).Content.Split(' ')[2].Split('.')[0..1] -Join ''
  }
  Else {
    $rtoolsver = $env:RTOOLS_VERSION
  }

  $rtoolsurl = $CRAN + "/bin/windows/Rtools/Rtools$rtoolsver.exe"

  Progress ("Downloading Rtools from: " + $rtoolsurl)
  & "C:\Program Files\Git\mingw64\bin\curl.exe" -s -o ../Rtools-current.exe -L $rtoolsurl

  Progress "Running Rtools installer"
  Start-Process -FilePath ..\Rtools-current.exe -ArgumentList "/TYPE=full /VERYSILENT" -NoNewWindow -Wait

  $RtoolsDrive = "C:"
  echo "Rtools is now available on drive $RtoolsDrive"

  Progress "Setting PATH"
  if ( -not(Test-Path Env:\GCC_PATH) ) {
    $gcc_path = "gcc-4.6.3"
  }
  Else {
    $gcc_path = $env:GCC_PATH
  }
  $env:PATH = $RtoolsDrive + '\Rtools\bin;' + $RtoolsDrive + '\Rtools\MinGW\bin;' + $RtoolsDrive + '\Rtools\' + $gcc_path + '\bin;' + $env:PATH
  $env:BINPREF=$RtoolsDrive + '/Rtools/mingw_$(WIN)/bin/'
}

Function Bootstrap {
  [CmdletBinding()]
  Param()

  Progress "Bootstrap: Start"

  Progress "Adding GnuWin32 tools to PATH"
  $env:PATH = "C:\Program Files (x86)\Git\bin;" + $env:PATH

  Progress "Setting time zone"
  tzutil /g
  tzutil /s "GMT Standard Time"
  tzutil /g

  InstallR

  if ((Test-Path "src") -or ($env:USE_RTOOLS)) {
    InstallRtools
  }
  Else {
    Progress "Skipping download of Rtools because src/ directory is missing."
  }

  Progress "Downloading and installing travis-tool.sh"
  Invoke-WebRequest https://raw.github.com/krlmlr/r-appveyor/master/r-travis/scripts/travis-tool.sh -OutFile "..\travis-tool.sh"
  echo '@bash.exe ../travis-tool.sh %*' | Out-File -Encoding ASCII .\travis-tool.sh.cmd
  cat .\travis-tool.sh.cmd
  bash -c "echo '^travis-tool\.sh\.cmd$' >> .Rbuildignore"
  cat .\.Rbuildignore

  $env:PATH.Split(";")

  Progress "Setting R_LIBS_USER"
  $env:R_LIBS_USER = 'c:\RLibrary'
  if ( -not(Test-Path $env:R_LIBS_USER) ) {
    mkdir $env:R_LIBS_USER
  }

  Progress "Bootstrap: Done"
}

Function SetTimezone {
  Progress "Setting time zone"
  tzutil /g
  tzutil /s "GMT Standard Time"
  tzutil /g
}

Function InstallMiktex {
  $miktexinstall = "--unattended --auto-install=yes --shared --package-set=basic"

  Progress ("Downloading " + $MIKTEX_MIRROR)
  & "C:\Program Files\Git\mingw64\bin\curl.exe" -s -o ../basic-miktex-x64.exe -L $MIKTEX_MIRROR

  Progress ("Installing MiKTeX: " + $miktexinstall)
  Start-Process -FilePath ..\basic-miktex-x64.exe -ArgumentList $miktexinstall -NoNewWindow -Wait

  Progress "Setting PATH variable for current process"
  $env:PATH = 'C:\Program Files\MiKTeX 2.9\miktex\bin\x64;' + $env:PATH

  Progress "Installing CTAN packages"
  mpm --admin --install=fancyvrb
  mpm --admin --install=inconsolata 
  mpm --admin --install=epsf
  mpm --admin --install=mptopdf
  mpm --admin --install=url
  mpm --admin --install=preprint

  # Enable auto-install, just in case
  initexmf --admin --enable-installer
  initexmf --admin --set-config-value "[MPM]AutoInstall=1"   

  # See https://tex.stackexchange.com/a/129523/12890
  $conffile = "C:\Program Files\MiKTeX 2.9\miktex\config\updmap.cfg"
  Progress "Adding zi4.map"
  initexmf --admin --update-fndb
  Add-Content $conffile "`nMap zi4.map`n"
  initexmf --admin --mkmaps

  # First time running 'pdflatex' always fails with some inite
  Progress "Trying pdflatex..."
  # pdflatex.exe --version
  Progress "MiKTeX installation: Done"
}

Function InstallPerl {
  Progress ("Downloading Perl from: " + $PERL_MIRROR)
  & "C:\Program Files\Git\mingw64\bin\curl.exe" -s -o ../strawberry.zip -L $PERL_MIRROR

  Progress "Extracting Perl"
  7z x ../strawberry.zip -oc:\Strawberry | Out-Null

  Progress "Perl installation: Done"
  & "C:\Strawberry\perl\bin\perl.exe" --version
}

Function InstallInno {
  $inno_url = "http://jrsoftware.org/download.php/is-unicode.exe?site=2"
  #$inno_url = "https://github.com/jrsoftware/issrc/releases/download/is-5_6_1/innosetup-5.6.1-unicode.exe"

  Progress ("Downloading InnoSetup from: " + $inno_url)
  & "C:\Program Files\Git\mingw64\bin\curl.exe" -s -o ../innosetup.exe -L $inno_url

  Progress "Installig InnoSetup"
  Start-Process -FilePath ..\innosetup.exe -ArgumentList /SILENT -NoNewWindow -Wait

  Progress "InnoSetup installation: Done"
  Get-ItemProperty "C:\Program Files (x86)\Inno Setup 5\ISCC.exe"
}

function CheckExitCode($msg) {
  if ($LastExitCode -ne 0) {
    Throw $msg
  }
}

function SignFiles($files) {
  & $env:SignTool sign /f $env:KeyFile /p "$env:CertPassword" /tr http://sha256timestamp.ws.symantec.com/sha256/timestamp /td sha256 /fd sha256 $files
  CheckExitCode "Failed to sign files."
}

function AppCertKit($files) {
  & $env:CertKit reset
  & $env:CertKit test -apptype desktop -setuppath $files -appusage peruser -reportoutputpath certreport.xml
  CheckExitCode "Failed to run App Certification Kit."
}
