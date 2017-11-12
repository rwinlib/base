if not exist "R-patched.tar.gz" (
powershell -Command "Invoke-WebRequest https://stat.ethz.ch/R/daily/R-patched.tar.gz -OutFile R-patched.tar.gz"
)
call .\scripts\build.bat R-patched.tar.gz 32
call .\scripts\build.bat R-patched.tar.gz 64
start %BUILDDIR%
