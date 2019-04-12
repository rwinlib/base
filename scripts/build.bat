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

:: Needed to fix tar symlinks
set MSYS=winsymlinks:lnk
tar -xf %SOURCEDIR%/%TARBALL% -C %R_NAME% --strip-components=1
set MSYS=
set XR_HOME=%R_HOME:\=/%
set XHOME32=%HOME32:\=/%
sed -e "s|@win@|%WIN%|" -e "s|@home@|%XR_HOME%|" -e "s|@home32@|%XHOME32%|" %SOURCEDIR%\files\MkRules.local.in > %R_HOME%/src/gnuwin32/MkRules.local

:: Copy libraries
cp -R %SOURCEDIR%\libcurl %R_HOME%\libcurl
cp -R %SOURCEDIR%\Tcltk\Tcl%WIN% %R_HOME%\Tcl
cp -R %SOURCEDIR%\baselibs %R_HOME%\extsoft
cp %SOURCEDIR%\files\curl-ca-bundle.crt %R_HOME%\etc\curl-ca-bundle.crt

:: Temporary fix for cairo stack
mkdir %BUILDDIR%\%R_NAME%\cairo
cp -R %SOURCEDIR%\cairo\lib\x64 %R_HOME%\cairo\win64
cp -R %SOURCEDIR%\cairo\lib\i386 %R_HOME%\cairo\win32
xcopy /s "%SOURCEDIR%\cairo\include\cairo" "%R_HOME%\cairo\win32"
xcopy /s "%SOURCEDIR%\cairo\include\cairo" "%R_HOME%\cairo\win64"


:: Mark output as experimental
::sed -i "s/Under development (unstable)/EXPERIMENTAL/" %R_HOME%/VERSION
::echo cat('R-experimental') > %R_HOME%/src/gnuwin32/fixed/rwver.R
::sed -i "s|Unsuffered Consequences|Blame Jeroen|" %R_HOME%/VERSION-NICK

::echo PATH="C:\Rtools\bin;${PATH}" > %R_HOME%/etc/Renviron.site

:: apply local patches
cd %R_HOME%
patch -p1 -i %SOURCEDIR%\patches\cairo.diff

:: patch -p1 -i %SOURCEDIR%\patches\objdump.diff
patch -p1 -i %SOURCEDIR%\patches\shortcut.diff

:: Switch dir
cd %R_HOME%/src/gnuwin32

:: Remove BOM from this file (needed for non-unicode innosetup)
:: sed -i "1s|^\xEF\xBB\xBF||" installer/CustomMsg.iss

:: Add 'make' to the user path
:: sed -i "s|ETC_FILES = Rprofile.site|ETC_FILES = Renviron.site Rprofile.site|" installer/Makefile

:: Allow overriding LOCAL_SOFT variable at runtime
set LOCAL_SOFT=%XR_HOME%/extsoft
sed -i "s|LOCAL_SOFT =|#LOCAL_SOFT|" fixed/etc/Makeconf
::sed -i "s|LOCAL_SOFT =|LOCAL_SOFT ?= \$(R_USER)/R/\$(COMPILED_BY)|" fixed/etc/Makeconf

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
cd %BUILDDIR%
cp %R_HOME%/SVN-REVISION SVN-REVISION.%target%
cp %R_HOME%/src/gnuwin32/cran/%target%-win.exe .
cp %R_HOME%/src/gnuwin32/cran/md5sum.txt md5sum.txt.%target%
cp %R_HOME%/src/gnuwin32/cran/NEWS.%target%.html .
cp %R_HOME%/src/gnuwin32/cran/CHANGES.%target%.html .
cp %R_HOME%/src/gnuwin32/cran/README.%target% .
cp %R_HOME%/src/gnuwin32/cran/target.cmd .

:: Infer release from target.cmd, for example "R-3.4.2-patched"
IF "%target:~-5,5%"=="devel" (
set reltype=devel
) ELSE IF "%target:~-7,7%"=="patched" (
set reltype=patched
) ELSE IF "%target:~-2,2%"=="rc" (
set reltype=patched
) ELSE IF "%target:~-5,5%"=="alpha" (
set reltype=patched
) ELSE IF "%target:~-4,4%"=="beta" (
set reltype=patched
) ELSE IF "%target:~0,3%"=="R-3" (
set reltype=release
) ELSE (
echo "Unknown target type: %target%"
exit /b 1
)

:: Symlink (disabled because doesn't survive sftp)
:: ln -s %target%-win.exe R-%reltype%.exe
echo %target%-win.exe > R-%reltype%.txt

:: Webpages to ship on CRAN
IF "%reltype%"=="devel" (
cp %R_HOME%/src/gnuwin32/cran/rdevel.html .
) ELSE IF "%reltype%"=="patched" (
cp %R_HOME%/src/gnuwin32/cran/rpatched.html .
cp %R_HOME%/src/gnuwin32/cran/rtest.html .
) ELSE IF "%reltype%"=="release" (
cp %R_HOME%/src/gnuwin32/cran/index.html .
cp %R_HOME%/src/gnuwin32/cran/md5sum.txt .
cp %R_HOME%/src/gnuwin32/cran/rw-FAQ.html .
cp %R_HOME%/src/gnuwin32/cran/release.html .
set REVISION=%target%
)

:: Done
cd %STARTDIR%
