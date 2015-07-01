# INQPlus
Extends EMC's INQ binary with ViPR SRM integration and mapping intelligence

Queries the specified ViPR SRM Web Service for information relating to block LUNs visible from the host.
	
Usage:
./inqplus.pl [--asm] [--help] [--pp] [--raw] [--sudo] [--vmax]

Parameters:
--asm
	Attempt to run asmcmd lsdsk to associate LUNs with ASM disk groups
--help
	Displays this message
--pp
	Filters for only EMC power devices
--raw
	Tells ASM parser that this host uses raw device mappings
--rawfile
	Specifies file for raw mappings.  If not specified, will default to /etc/udev/rules.d/60-raw.rules
--sudo
	Run inq binary with sudo
--vmax
	Attempts to find statistics on masked VMAX FAs for all devices
