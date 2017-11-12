if not exist "R-latest.tar.gz" (
powershell -Command "Invoke-WebRequest https://cran.r-project.org/src/base/R-latest.tar.gz -OutFile R-latest.tar.gz"
)
call .\scripts\build.bat R-latest.tar.gz 32
call .\scripts\build.bat R-latest.tar.gz 64
start %BUILDDIR%
