if not exist "R-devel.tar.gz" (
powershell -Command "Invoke-WebRequest https://stat.ethz.ch/R/daily/R-devel.tar.gz -OutFile R-devel.tar.gz"
)
call .\scripts\build.bat R-devel.tar.gz 32
call .\scripts\build.bat R-devel.tar.gz 64
start %BUILDDIR%
