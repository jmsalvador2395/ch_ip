@echo off

rem | Author: John Salvador (With a little help from Austin Estes)


rem | HOW TO USE:
rem | put onto desktop, run as administrator, and then follow the prompts
rem | if you have cmd open often, put this in C:\Windows\ to run anywhere from cmd
rem
rem | accepts CIDR notation


setlocal enabledelayedexpansion

rem *****************Defaults*****************
rem | Change these to suit your needs
rem
rem | interface_name is the name of the network adapter you want to control
rem | default_ip and default_netmask are used when the script is called without any command line input
set interface_name=Ethernet
set default_ip=10.1.1.2
set default_netmask=255.255.255.0

rem ***************End Defaults***************



set def_gtwy=
set ip=
set subnet=
set netbits=24
set cidr=0
set cli=0

rem ***********************************Section 1***********************************
rem | extract the individual octets (and subnet if cidr notation is used)
rem | checks if CLI input was used
if not "%1"=="" (
	rem | checks if dhcp is the input and turns it on if true
	if "%1"=="dhcp" (
		netsh interface ip set address name=%interface_name% dhcp
		if !errorlevel!==0 (
			echo Success
		) else (
			echo Failure
		)
		pause
		exit /b
	)
	set cli=1
	for /f "tokens=1-5* delims=./" %%a in ("%1") do (
		set ip=%1
		set first_oct=%%a
		set scnd_oct=%%b
		set third_oct=%%c
		set fourth_oct=%%d

		rem | check if cidr was used
		if not "%%e%"=="" (
			set /a netbits=%%e
			set cidr=1
		)
	)
	rem | if %2 is empty then set it to the default netmask or else just set it to %2
	if "x%2"=="x" (
		set subnet=%default_netmask%
	) else (
		set subnet=%2
	)
)
rem ***********************************End of section 1***********************************

rem ***********************************Section 2***********************************
rem | this section prompts for ip settings if not passed as command line arguments
if %cli%==0 (
	echo.
	echo ******************************
	echo Leave blank for default values
	echo ******************************
	echo.

	set /p ip="IP (enter dhcp to turn on): "
)

if "!ip!"=="" (
	if %cli%==0 (
		set ip=%default_ip%
	)
)

if "!ip!"=="dhcp" (
	netsh interface ip set address %interface_name% dhcp
	if !errorlevel!==0 (
		echo Success
	) else (
		echo Failure
	)
	pause
	exit /b
)

rem | check if CIDR is used
if not x%ip:/=%==x%ip% (
	if %cli%==0 (
		set /p def_gtwy="Default Gateway (Default - based on ip & subnet): "
		for /f "tokens=1-5* delims=./" %%a in ("!ip!") do (
			set first_oct=%%a
			set scnd_oct=%%b
			set third_oct=%%c
			set fourth_oct=%%d
			set netbits=%%e
			set cidr=1
		)
		if not "x!def_gtwy!"=="x" (
			netsh interface ip set address name=%interface_name% static addr="!ip!" gateway="!def_gtwy!"
			if !errorlevel!==0 (
				echo Success
			) else (
				echo Failure
			)
			pause
			exit /b
		
		)
	)
rem | goes here if CIDR was not used
) else (
	for /f "tokens=1-4* delims=." %%a in ("!ip!") do (
		set first_oct=%%a
		set scnd_oct=%%b
		set third_oct=%%c
		set fourth_oct=%%d
		set netbits=%%e
	)
	if %cli%==0 (
		set /p subnet="Subnet Mask: "
		if "x!subnet!"=="x" (
			set subnet=%default_netmask%
		)
		set /p def_gtwy="Default Gateway: " 
	)
)


rem ***********************************End of section 2***********************************

rem ***********************************Section 3***********************************
rem | this section is for calculating the default gateway based on the provided ip and subnet mask
rem | the script gets to this section if no gateway was explicitly provided


rem | set the requested ip if gateway is specified
if %cli%==0 (
	if not "%ip%"=="" (
		if not "%subnet%"=="" (
			if not "%def_gtwy%"=="" (
				netsh interface ip set address name=%interface_name% static addr="%ip%" mask="%subnet%" gateway="%def_gtwy%"
				if !errorlevel!==0 (
					echo Success
				) else (
					echo Failure
				)
				pause
				exit /b
			)
		)
	)
) else (
	if %cidr%==1 (
		if not "%2"=="" (
			netsh interface ip set address name=%interface_name% static addr="%1" gateway="%2"
			if !errorlevel!==0 (
				echo Success
			) else (
				echo Failure
			)
			pause
			exit /b
		)
	) else (
		if not "%3"=="" (
			netsh interface ip set address name=%interface_name% static addr="%1" mask="%2" gateway="%3"
			if !errorlevel!==0 (
				echo Success
			) else (
				echo Failure
			)
			pause
			exit /b
		)
	)
)

rem | puts all the mask bits into an integer. this part should be cleaned at some point
if %cidr%==0 (
	set /a counter=0
	set /a all_mask_bits=0
	for /f "tokens=1-4* delims=." %%a in ("%subnet%") do (
		set /a mask_oct=%%a
		set /a all_mask_bits+=!mask_oct!
		set /a "all_mask_bits<<=8"
		set /a mask_oct=%%b
		set /a all_mask_bits+=!mask_oct!
		set /a "all_mask_bits<<=8"
		set /a mask_oct=%%c
		set /a all_mask_bits+=!mask_oct!
		set /a "all_mask_bits<<=8"
		set /a mask_oct=%%d
		set /a all_mask_bits+=!mask_oct!
		rem | calculate the requested amount of network bits
		:loop1
		set /a "comparison=1&!all_mask_bits!"
		if !comparison!==0 (
			set /a counter+=1
			set /a "all_mask_bits>>=1"
			set /a "comparison=1&!all_mask_bits!"
			goto loop1
		)
		set /a netbits=32-!counter!
	)
)

set /a all_mask_bits=0
for /l %%i in (1,1,%netbits%) do (
	set /a "all_mask_bits<<=1"
	set /a all_mask_bits+=1
)
set /a diff=32-%netbits%
for /l %%i in (1,1,%diff%) do (
	set /a "all_mask_bits<<=1"
)

rem | put all the ip bits into one integer
if %cli%==1 (
	for /f "tokens=1-4* delims=./" %%a in ("%1") do (
		set /a all_gtwy_bits=%first_oct%
		set /a "all_gtwy_bits<<=8"
		set /a all_gtwy_bits+=%scnd_oct%
		set /a "all_gtwy_bits<<=8"
		set /a all_gtwy_bits+=%third_oct%
		set /a "all_gtwy_bits<<=8"
		set /a all_gtwy_bits+=%fourth_oct%
	)
) else (
	for /f "tokens=1-4* delims=./" %%a in ("%ip%") do (
		set /a all_gtwy_bits=%first_oct%
		set /a "all_gtwy_bits<<=8"
		set /a all_gtwy_bits+=%scnd_oct%
		set /a "all_gtwy_bits<<=8"
		set /a all_gtwy_bits+=%third_oct%
		set /a "all_gtwy_bits<<=8"
		set /a all_gtwy_bits+=%fourth_oct%
	)

)

rem | calculate the network portion of the gateway
set /a "all_gtwy_bits=!all_mask_bits!&!all_gtwy_bits!"

rem | calculate the host portion of the gateway
set /a "gtwy_host_bits=-1^^!all_mask_bits!"
set /a all_gtwy_bits+=!gtwy_host_bits!
if %netbits% lss 31 (
	set /a all_gtwy_bits-=1
)

rem | separate the bits into their respective octets
set /a "gtwy4_oct=255&!all_gtwy_bits!"
set /a "all_gtwy_bits>>=8"
set /a "gtwy3_oct=255&!all_gtwy_bits!"
set /a "all_gtwy_bits>>=8"
set /a "gtwy2_oct=255&!all_gtwy_bits!"
set /a "all_gtwy_bits>>=8"
set /a "gtwy1_oct=255&!all_gtwy_bits!"


rem | set the ip, netmask, and calculated gateway
if %cidr%==1 (
	netsh interface ip set address name=%interface_name% static addr="%ip%" gateway="!gtwy1_oct!.!gtwy2_oct!.!gtwy3_oct!.!gtwy4_oct!"
	if !errorlevel!==0 (
		echo Success
	) else (
		echo Failure
	)
	pause
	exit /b
) else (
	netsh interface ip set address name=%interface_name% static addr="%ip%" mask="%subnet%" gateway="!gtwy1_oct!.!gtwy2_oct!.!gtwy3_oct!.!gtwy4_oct!"
	if !errorlevel!==0 (
		echo Success
	) else (
		echo Failure
	)
	pause
	exit /b
)
rem ***********************************End of section 3***********************************
