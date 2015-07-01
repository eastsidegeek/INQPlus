# INQPlus
<p>Extends EMC's INQ binary with ViPR SRM integration and mapping intelligence</p>

<p>Queries the specified ViPR SRM Web Service for information relating to block LUNs visible from the host.</p>
	
Usage:<br>
<p>./inqplus.pl [--asm] [--help] [--pp] [--raw] [--sudo] [--vmax]</P>

Parameters:<br>
--asm<br>
&nbsp;&nbsp;&nbsp;&nbsp;Attempt to run asmcmd lsdsk to associate LUNs with ASM disk groups<br>
--help<br>
&nbsp;&nbsp;&nbsp;&nbsp;Displays this message<br>
--pp<br>
&nbsp;&nbsp;&nbsp;&nbsp;Filters for only EMC power devices<br>
--raw<br>
&nbsp;&nbsp;&nbsp;&nbsp;Tells ASM parser that this host uses raw device mappings<br>
--rawfile<br>
&nbsp;&nbsp;&nbsp;&nbsp;Specifies file for raw mappings.  If not specified, will default to /etc/udev/rules.d/60-raw.rules<br>
--sudo<br>
&nbsp;&nbsp;&nbsp;&nbsp;Run inq binary with sudo<br>
--vmax<br>
&nbsp;&nbsp;&nbsp;&nbsp;Attempts to find statistics on masked VMAX FAs for all devices<br>

