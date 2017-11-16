::set target=R-devel.tar.gz
set TARBALL=%1
if not exist "%TARBALL%" (
echo File not found: %TARBALL% && exit /b 1
)

::set WIN=32
::set WIN=64
set WIN=%2

::globals
set STARTDIR=%CD%
set SOURCEDIR=%~dp0..
mkdir ..\BUILD
cd ..\BUILD
set BUILDDIR=%CD%

echo SOURCEDIR: %SOURCEDIR%
echo BUILDDIR: %BUILDDIR%

:: Set name of target
set VERSION=%TARBALL:~0,-7%
set R_NAME=%VERSION%-win%WIN%
set R_HOME=%BUILDDIR%\%R_NAME%
set TMPDIR=%TEMP%

:: For multilib build
set HOME32=%BUILDDIR%\%VERSION%-win32

:: Add rtools executables in path
set PATH=C:\rtools\bin;%PATH%

:: Copy sources
rm -Rf %R_NAME%
mkdir %R_NAME%
tar -xf %SOURCEDIR%/%TARBALL% -C %R_NAME% --strip-components=1
set XR_HOME=%R_HOME:\=/%
set XHOME32=%HOME32:\=/%
sed -e "s|@win@|%WIN%|" -e "s|@home@|%XR_HOME%|" -e "s|@home32@|%XHOME32%|" %SOURCEDIR%\files\MkRules.local.in > %R_HOME%/src/gnuwin32/MkRules.local

:: Copy libraries
cp -R %SOURCEDIR%\libcurl %R_HOME%\libcurl
cp -R %SOURCEDIR%\Tcltk\Tcl%WIN% %R_HOME%\Tcl
cp -R %SOURCEDIR%\extsoft %R_HOME%\extsoft
cp %SOURCEDIR%\files\curl-ca-bundle.crt %R_HOME%\etc\curl-ca-bundle.crt

:: Temporary fix for cairo stack
mkdir %BUILDDIR%\%R_NAME%\cairo
cp -R %SOURCEDIR%\cairo\lib\x64 %R_HOME%\cairo\win64
cp -R %SOURCEDIR%\cairo\lib\i386 %R_HOME%\cairo\win32
xcopy /s "%SOURCEDIR%\cairo\include\cairo" "%R_HOME%\cairo\win32"
xcopy /s "%SOURCEDIR%\cairo\include\cairo" "%R_HOME%\cairo\win64"

sed -i "s/-lcairo -lpixman-1 -lpng -lz/-lcairo -lfontconfig -lfreetype -lpng -lpixman-1 -lexpat -lharfbuzz -lbz2 -lz/" %R_HOME%/src/library/grDevices/src/cairo/Makefile.win

:: Remove BOM from this file
sed -i "1s/^\xEF\xBB\xBF//" %R_HOME%/src/gnuwin32/installer/CustomMsg.iss

:: Mark output as experimental
::sed -i "s/Under development (unstable)/EXPERIMENTAL/" %R_HOME%/VERSION
::echo cat('R-experimental') > %R_HOME%/src/gnuwin32/fixed/rwver.R
sed -i "s/Unsuffered Consequences/Blame Jeroen/" %R_HOME%/VERSION-NICK

:: Add rtools 'make' to the user path
echo PATH="C:\Rtools\bin;${PATH}" > %R_HOME%/etc/Renviron.site
sed -i "s/ETC_FILES = Rprofile.site/ETC_FILES = Renviron.site Rprofile.site/" %R_HOME%/src/gnuwin32/installer/Makefile

:: Switch dir
cd %R_HOME%/src/gnuwin32

:: Download 'extsoft' directory
:: make rsync-extsoft

:: Build 32bit R version only
IF "%WIN%"=="32" (
make 32-bit > %BUILDDIR%/32bit.log 2>&1
if %errorlevel% neq 0 (
	echo ERROR: 'make 32-bit' failure! Inspect 32bit.log for details.
	exit /b 2
) else (
	cd %SOURCEDIR%
	echo make 32-bit complete!
	exit /b 0
)
)

:: Build 64bit version + installer
make distribution > %BUILDDIR%/distribution.log 2>&1
if %errorlevel% neq 0 (
	echo ERROR: 'make distribution' failure! Inspect distribution.log for details.
	exit /b 2
)
echo make distribution complete!

make check-all > %BUILDDIR%/check.log 2>&1
if %errorlevel% neq 0 (
	echo ERROR: 'make check-all' failure! Inspect check.log for details.
	type %builddir%\check.log
	exit /b 2
)

:: Get the actual version name
call %R_HOME%\src\gnuwin32\cran\target.cmd

:: Get the SVN revision number
set /p SVNSTRING=<%R_HOME%/SVN-REVISION
set REVISION=%SVNSTRING:~10%

:: Copy files to ship in the distribution
cp %R_HOME%/SVN-REVISION %BUILDDIR%/SVN-REVISION.%target%
cp %R_HOME%/src/gnuwin32/cran/%target%-win.exe %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/md5sum.txt %BUILDDIR%/md5sum.txt.%target%
cp %R_HOME%/src/gnuwin32/cran/NEWS.%target%.html %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/CHANGES.%target%.html %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/README.%target% %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/target.cmd %BUILDDIR%/

:: Infer release from target.cmd, for example "R-3.4.2-patched"
IF "%target:~-5,5%"=="devel" (
cp %R_HOME%/src/gnuwin32/cran/rdevel.html %BUILDDIR%/
) ELSE IF "%target:~-7,7%"=="patched" (
cp %R_HOME%/src/gnuwin32/cran/rpatched.html %BUILDDIR%/
) ELSE IF "%target:~0,3%"=="R-3" (
cp %R_HOME%/src/gnuwin32/cran/index.html %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/rw-FAQ.html %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/release.html %BUILDDIR%/
) ELSE (
echo "Unknown target type: %target%"
exit /b 1
)

:: Done
cd %STARTDIR%
