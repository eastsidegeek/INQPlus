#!/usr/bin/perl
use SOAP::Lite;
use Data::Dumper::Names;
use Getopt::Long;
use Env qw(ORACLE_HOME ORACLE_SID);

my $argvvmax = '';
my $argvhelp = '';
my $argvpp = '';
my $argvsudo = '';
my $argvasm = '';
my $argvraw = '';
my $argvdemo = '';
my $argvrawfile = '';
GetOptions ('help' => \$argvhelp, 
			'vmax' => \$argvvmax, 
			'pp' => \$argvpp, 
			'sudo' => \$argvsudo, 
			'raw' => \$argvraw, 
			'asm' => \$argvasm,
			'demo' => \$argvdemo,
			'rawfile=s' => \$argvrawfile,
      'vsuser=s' => \$argvvsuser,
      'vspass=s' => \$argvvspass,
      'vshost=s' => \$argvvshost,
      'vsport=s' => \$argvvsport,
      'orasid=s' => \$argvorasid
    );

$username = ($argvvsuser)?($argvvsuser):'admin'; # set username and password here
$password = ($argvvspass)?($argvvspass):'changeme1';
$vshost = ($argvvshost)?($argvvshost):'lglov081.lss.emc.com'; # ViPR SRM Frontend
$vsport = ($argvvsport)?($argvvsport):'58080'; # ViPR SRM Frontend Port
$SOAP::Constants::DO_NOT_USE_CHARSET = 1;
my $soap = SOAP::Lite->new(
proxy=>"http://$vshost:$vsport/APG-WS/wsapi/report?wsdl",
);
$soap->soapversion('1.1');
my $serializer = $soap->serializer();

$serializer->register_ns('http://www.watch4net.com/APG/Web/XmlTree1','xt');
$serializer->register_ns('http://www.watch4net.com/APG/Remote/ReportManagerService','rep');
$serializer->register_ns('http://schemas.xmlsoap.org/soap/envelope/','soapenv');

if($argvhelp) {
	print "INQ Plus
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
--vsuser
  ViPR SRM username
--vsport
  ViPR SRM password
--vshost
  ViPR SRM frontend host
--vsport
  ViPR SRM frontend hostport

Copyright
Licensed under Creative Commons Attribution (CC BY)

Author
Written by Daniel Stafford (daniel.stafford\@emc.com)

inqplus 1.30	June 2015
	";
exit();
} # end if help

xmldefs();


################################### Run INQ
$cmd = 'inq -wwn';
if($argvpp) {
	$cmd .= ' -f_powerpath';
}
if($argvsudo) {
	$cmd = 'sudo '.$cmd;
}

if($argvdemo) {
	$inqout = 'Copyright (c) [1997-2013] EMC Corporation. All Rights Reserved.
	For help type inq -h.

	..............................

	----------------------------------------------------------------------------
	DEVICE           :VEND    :PROD            :WWN
	----------------------------------------------------------------------------
	/dev/emcpoweraj :EMC     :SYMMETRIX       :60000970888973589963533032443146';
	
# lightfoot 60000970888973589963533032443146

} else {
	$inqout = `$cmd`; # real data
} # end if argvdemo
##################################### End run INQ


##################################### Process INQ
my @inqlines = split /[\n^]+/, $inqout;
foreach my $inqline (@inqlines) {
	if($inqline =~ /([\w\/\d]+).*(\d{32})/) {
		$device = $1;
		$wwn = $2;
		$device =~ /^\/dev\/(\w+)/;
		$power = $1;
        $luns{$power}{'wwn'} = $wwn; # Used for ASM processing
       
		my $filter = " &amp; partsn=='$wwn'";
		$query = $xml1 . $filter . $xml2;

		my $result = $soap->getReport(SOAP::Data->type('xml' => $query)); # end getReport call
    #print Dumper($result);
		
		$data = ($result->envelope)->{'Body'}->{'getReportResponse'}->{'table-element'}->{'table'}->{'data'}->{'tr'};
		# $data is an array ref of all elements
		# $data->[0] is a single element
		# $data->[0]->{'ts'}->[0] is first column, first row
		print "\n#### Results for $device ####\n";
		#foreach $item (@$properties) {
		#	print $item->{'ts'}->[0]."\n";
		#}
		$arraysn = $data->{'ts'}->[0];
		$luns{$power}{'array'} = $arraysn;  # Get Array serial from ViPR SRM, populate %luns for  optional ASM processing
		$lunid = $data->{'ts'}->[1];
		$luns{$power}{'lun'} = $lunid;
		$policy = $data->{'ts'}->[2];
		$readiopsavg = $data->{'tv'}->[0];
		$writeiopsavg = $data->{'tv'}->[1];
		$readthruavg = $data->{'tv'}->[2];
		$writethruavg = $data->{'tv'}->[3];
		$readlatavg = $data->{'tv'}->[4];
		$writelatavg = $data->{'tv'}->[5];
		$readiopsmax = $data->{'tv'}->[6];
		$writeiopsmax = $data->{'tv'}->[7];
		$readthrumax = $data->{'tv'}->[8];
		$writethrumax = $data->{'tv'}->[9];
		$readlatmax = $data->{'tv'}->[10];
		$writelatmax = $data->{'tv'}->[11];
		$capacity = $data->{'tv'}->[12];
		$used = $data->{'tv'}->[13];
		$model = $data->{'ts'}->[3];
		$capacity =~ s/,//g;
		$used =~ s/,//g;
    if($capacity > 0) {
		  $percent = ($used / $capacity) * 100;
		  $percent = sprintf '%.2f',$percent;
    } else {
      $percent = "N/A";
    }
		print "LUN ID $lunid uses FAST policy $policy on Array $arraysn of type $model\n";
		print "$used GB allocated ($percent%) out of a total of $capacity GB\n";
		print "Last hour averages\n";
		print "Read IOPS\tWrite IOPS\tRead Tput\tWrite Tput\tRead Lat\tWrite Lat\n";
		print "$readiopsavg\t\t$writeiopsavg\t\t$readthruavg\t\t$writethruavg\t\t$readlatavg\t\t$writelatavg\n";
		print "Last hour maxs\n";
		print "Read IOPS\tWrite IOPS\tRead Tput\tWrite Tput\tRead Lat\tWrite Lat\n";
		print "$readiopsmax\t\t$writeiopsmax\t\t$readthrumax\t\t$writethrumax\t\t$readlatmax\t\t$writelatmax\n";
		#print Dumper($data);
		
		if($argvvmax) {
			
			$query = $xml3 . $filter . $xml4;
		
			my $result = $soap->getReport(SOAP::Data->type('xml' => $query)); # end getReport call
			$data = ($result->envelope)->{'Body'}->{'getReportResponse'}->{'compound-element'}->{'compound-element'}->{'compound-element'}->{'table-element'}->{'table'}->{'data'}->{'tr'} ;
			#print Dumper($data);
			#$data is an array ref of all elements
			# $data->[0] is a single element
			# $data->[0]->{'ts'}->[0] is first column, first row
			
			if(ref($data) eq 'ARRAY') {
				foreach $item (@$data) {
					print "Masked director ".$item->{'ts'}." averages ".$item->{'tv'}->[1]."% busy, with a peak of ".$item->{'tv'}->[2]."%\n";
				} # end if ARRAY
			}
			elsif(ref($data) eq 'HASH') { # this means the LUN is masked to a single FA
				print "Masked director ".$data->{'ts'}." averages ".$data->{'tv'}->[1]."% busy, with a peak of ".$data->{'tv'}->[2]."%\n";
			} # end elsif HASH
		} # end if vmax
		
		
	} # end if inqline
} # end foreach

##################################### End INQ processing



##################################### Process ASM
if($argvasm) {
	if($argvdemo) {
		$asmout = ' 1104837   380139  1104837  ASM_DB_GROUP_01       ASM_DB_GROUP       REGULAR         System                         UNKNOWN  /dev/raw/raw215';  # sample data
	} else {
    $orasid = ($argvorasid)?$argvorasid:'+ASM';
    $exportcmd = 'export '.$orasid;
		`exportcmd`;
    $asmout = `sudo -E -u oracle $ORACLE_HOME/bin/asmcmd lsdsk -k`;  # real data
	} # end if argvdemo
	
	#print "Processing ASM \n";
	my @lines = split /[\n^]+/, $asmout;
	foreach my $line (@lines) {
       #                        TMB     FMB     OSMB    Name    FG      FGT     Red     Path
       #                 1       2      3        4       5       6       7        8       9
       if($line =~ /\s+(\d+)\s+(\d+)\s+(\d+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+([\/\w]+)/) {
              
			$path = $9;
			$name = $4;
			#print "Found path $path, name $name\n";
			$associations{$path}{'asm'} = $name;
       } # end if line
	} # end foreach asmout
	
	if($argvraw) {
	
		if($argvdemo) {
			$rawout = 'ACTION=="add", KERNEL=="emcpoweraj1", RUN+="/bin/raw /dev/raw/raw215 %N"';
		} else {
			
      $rawfile = ($argvrawfile)?($argvrawfile):'/etc/udev/rules.d/60-raw.rules'; # set raw file
			$rawcmd = 'cat '.$rawfile;
			$rawout = `$rawcmd`;
		} # end if argvraw
		
		#print "Processing RAW\n";
		my @lines = split /[\n^]+/, $rawout;
		foreach my $line (@lines) {
			   #print "Line is $line\n";
			   if($line =~ /^ACTION=="[aA][dD][dD]".*KERNEL=="(\w+)".*\/bin\/raw ([\/\w]+)\s.*/) {
					  $power = $1;
					  $path = $2;
					  $power =~ /(.*)\d$/;
					  $power = $1;
					  #print "Found power $power, $path path\n";
					  $associations{$path}{'power'} = $power;
			   } # end if line
		} # end foreach rawout

	} # end if argvraw
	
	#print "Processing asm assocations\n";
	for my $asmkey (keys %associations) {
		   #print "asmkey is $asmkey\n";
		   $thispower = $associations{$asmkey}{'power'};
		   $thisasmg = $associations{$asmkey}{'asm'};
		   #print "Power is $thispower, asmg is $thisasmg\n";
		   
		   for my $lunkey (keys %luns) {
				  #print "Testing against lunkey $lunkey\n";
				  if($lunkey eq $thispower) {
						 #print "Found hit\n";
						 $luns{$lunkey}{'asmg'} = $thisasmg;
						 
				  } # end if lunkey eq thispower
		   } # end for keys luns
	} # end for keys association

	print "\n\nASM Associations\nASM Group\tPowerDev\tArray\tLUN\tWWN\n";
	for my $lunkey (keys %luns) {
		if(length($luns{$lunkey}{'asmg'}) > 0) {
		print $luns{$lunkey}{'asmg'}."\t".$lunkey."\t".$luns{$lunkey}{'array'}."\t".$luns{$lunkey}{'lun'}."\t".$luns{$lunkey}{'wwn'}."\n";
	} # end if length
} # end for keys luns
	
	
} # end if argvasm
############################################## End ASM Processing



############################################## Subroutines and stuff
sub SOAP::Transport::HTTP::Client::get_basic_credentials {

return $username => $password;
} # end overload of basic credentials

sub xmldefs {
$xml1 = '<xt:node name="UNIX LUN Report 1.0" singleNodeId="4093e8b4">
  <xt:property type="NodeFilter" filterExpression="vstatus==\'active\' &amp; parttype==\'LUN\' &amp; devtype==\'Array\'';
  
$xml2='"/>
  <xt:property type="ReportPreferences" duration="l6h" preferredPeriod="3600"/>
  <xt:property type="PropertyNodeColumn" name="Array" property="serialnb"/>
  <xt:property type="PropertyNodeColumn" name="LUN ID" property="part"/>
  <xt:property type="PropertyNodeColumn" name="FAST Policy" property="polname"/>
  <xt:property type="PropertyNodeColumn" name="Tier" property="hcatier"/>
  <xt:property type="ValueNodeColumn" name="Read IOPS (Avg)" filterExpression="name==\'ReadRequests\'" period="3600" forcePeriod="never" timeThreshold="1" summaryLabel=""/>
  <xt:property type="ValueNodeColumn" name="Write IOPS (Avg)" filterExpression="name==\'WriteRequests\'" period="3600" forcePeriod="never" timeThreshold="1" summaryLabel=""/>
  <xt:property type="ValueNodeColumn" name="Read Throughput (Avg)" filterExpression="name==\'ReadThroughput\'" period="3600" forcePeriod="never" timeThreshold="1" summaryLabel=""/>
  <xt:property type="ValueNodeColumn" name="Write Throughput (Avg)" filterExpression="name==\'WriteThroughput\'" period="3600" forcePeriod="never" timeThreshold="1" summaryLabel=""/>
  <xt:property type="ValueNodeColumn" name="Read Latency (Avg)" filterExpression="name==\'ReadResponseTime\'" period="3600" forcePeriod="never" timeThreshold="1" summaryLabel=""/>
  <xt:property type="ValueNodeColumn" name="Write Latency (Avg)" filterExpression="name==\'WriteResponseTime\'" period="3600" forcePeriod="never" timeThreshold="1" summaryLabel=""/>
  <xt:property type="ValueNodeColumn" name="Read IOPS (Max)" filterExpression="name==\'ReadRequests\'" period="3600" forcePeriod="never" aggregationFunc="max" timeThreshold="1" summaryLabel=""/>
  <xt:property type="ValueNodeColumn" name="Write IOPS (Max)" filterExpression="name==\'WriteRequests\'" period="3600" forcePeriod="never" aggregationFunc="max" timeThreshold="1" summaryLabel=""/>
  <xt:property type="ValueNodeColumn" name="Read Throughput (Max)" filterExpression="name==\'ReadThroughput\'" period="3600" forcePeriod="never" aggregationFunc="max" timeThreshold="1" summaryLabel=""/>
  <xt:property type="ValueNodeColumn" name="Write Throughput (Max)" filterExpression="name==\'WriteThroughput\'" period="3600" forcePeriod="never" aggregationFunc="max" timeThreshold="1" summaryLabel=""/>
  <xt:property type="ValueNodeColumn" name="Read Latency (Max)" filterExpression="name==\'ReadResponseTime\'" period="3600" forcePeriod="never" aggregationFunc="max" timeThreshold="1" summaryLabel=""/>
  <xt:property type="ValueNodeColumn" name="Write Latency (Max)" filterExpression="name==\'WriteResponseTime\'" period="3600" forcePeriod="never" aggregationFunc="max" timeThreshold="1" summaryLabel=""/>
  <xt:property type="ValueNodeColumn" name="Capacity" filterExpression="name==\'Capacity\'" period="3600" forcePeriod="never" timeThreshold="1" summaryLabel=""/>
  <xt:property type="ValueNodeColumn" name="Allocated Cap" filterExpression="name==\'PoolUsedCapacity\'" period="3600" forcePeriod="never" timeThreshold="1" summaryLabel=""/>
  <xt:property type="PropertyNodeColumn" name="Model" property="model"/>
  <xt:node name="partsn" singleNodeId="220ea478">
    <xt:property type="NodeExpansion" expandOn="partsn"/>
    <xt:property type="ReportPreferences" defaultMode="lst"/>
  </xt:node>
</xt:node>';

$xml3='<xt:node xmlns="http://www.watch4net.com/APG/Web/XmlTree1" name="FA Busy 1.0 Encapsulated" singleNodeId="6735ed34">
  <xt:property xsi:type="ReportPreferences" defaultMode="mix"/>
  <xt:node name="FA Busy 1.0" singleNodeId="f5d943ba">
    <xt:property xsi:type="NodeFilter" filterExpression="vstatus==\'active\' &amp; parttype==\'LUN\' &amp; devtype==\'Array\' ';

$xml4 = '"/>
    <xt:property xsi:type="ReportPreferences" defaultMode="mix" duration="l6h"/>
    <xt:node name="Connect to AccessToLUN" singleNodeId="39a46dcd">
      <xt:property xsi:type="NodeFilter" filterExpression="parttype==\'AccessToLUN\'"/>
      <xt:property xsi:type="NodeExpansion" expandOn="part&lt;type=split;properties=lunname;level-up=9999&gt;,device&lt;type=split;properties=device;level-up=9999&gt;" filterMode="select"/>
      <xt:property xsi:type="ReportPreferences" defaultMode="mix" duration="l6h"/>
      <xt:property xsi:type="NodePropertyNodeColumn" name="VMAX FA" nodeProperty="name"/>
      <xt:property xsi:type="ValueNodeColumn" name="Avg IOPS" resultName="FAIOPS" period="3600" forcePeriod="never" useTimeRange="true" summaryLabel=""/>
      <xt:property xsi:type="ValueNodeColumn" name="Avg %Busy" resultName="FAUtilization" period="3600" forcePeriod="never" useTimeRange="true" summaryLabel="">
        <xt:threshold severity="OK" value="0.0"/>
        <xt:threshold severity="MAJOR" value="50.0"/>
        <xt:threshold severity="CRITICAL" value="70.0"/>
      </xt:property>
      <xt:property xsi:type="ValueNodeColumn" name="Max %Busy" resultName="FAUtilization" period="3600" forcePeriod="never" aggregationFunc="max" useTimeRange="true" valuesAggregationFunc="max" summaryLabel="">
        <xt:threshold severity="OK" value="0.0"/>
        <xt:threshold severity="MAJOR" value="60.0"/>
        <xt:threshold severity="CRITICAL" value="80.0"/>
      </xt:property>
      <xt:node name="Connect to MV" singleNodeId="f0953854">
        <xt:property xsi:type="NodeFilter" filterExpression="parttype==\'Access\'"/>
        <xt:property xsi:type="NodeExpansion" expandOn="device&lt;type=split;properties=device;level-up=9999&gt;,viewname&lt;type=split;properties=part;level-up=9999&gt;" filterMode="select"/>
        <xt:property xsi:type="ReportPreferences" displayMode="3" duration="l6h"/>
        <xt:property xsi:type="PropertyNodeColumn" name="FA" resultName="FA Properties" period="3600" useTimeRange="false" timeThreshold="4" property="part"/>
        <xt:property xsi:type="ValueNodeColumn" name="Avg IOPS" resultName="FAIOPS" period="3600" forcePeriod="never" timeThreshold="4" summaryLabel=""/>
        <xt:property xsi:type="ValueNodeColumn" name="Avg %Busy" resultName="FAUtilization" period="3600" forcePeriod="never" timeThreshold="4" summaryLabel="">
          <xt:threshold severity="OK" value="0.0"/>
          <xt:threshold severity="MAJOR" value="50.0"/>
          <xt:threshold severity="CRITICAL" value="70.0"/>
        </xt:property>
        <xt:property xsi:type="ValueNodeColumn" name="Max %Busy" resultName="FAUtilization" period="3600" forcePeriod="never" aggregationFunc="max" timeThreshold="4" summaryLabel="">
          <xt:threshold severity="OK" value="0.0"/>
          <xt:threshold severity="MAJOR" value="60.0"/>
          <xt:threshold severity="CRITICAL" value="80.0"/>
        </xt:property>
        <xt:node name="Connect to FA" singleNodeId="abdd6978">
          <xt:property xsi:type="NodeFilter" filterExpression="parttype==\'Controller\'"/>
          <xt:property xsi:type="NodeExpansion" expandOn="director&lt;type=split;value-separator=,;properties=part;level-up=9999&gt;,device&lt;type=split;properties=device;level-up=9999&gt;" filterMode="select"/>
          <xt:property xsi:type="ReportPreferences" defaultMode="lst" duration="l6h"/>
          <xt:formula formulaId="util.Nop4">
            <xt:parameter name="First Value" xsi:type="ResultFormulaParameterDefinition" result="FAIOPS"/>
            <xt:parameter name="Second Value" xsi:type="ResultFormulaParameterDefinition" result="FAUtilization"/>
            <xt:parameter name="Third Value" xsi:type="ResultFormulaParameterDefinition" result="FA Properties"/>
            <xt:parameter name="Fourth Value" xsi:type="EmptyFormulaParameterDefinition"/>
            <xt:result name="FAIOPS" default="false" graphable="false"/>
            <xt:result name="FAUtilization" default="false" graphable="false"/>
            <xt:result name="FA Properties" default="false" graphable="false"/>
            <xt:result name="Fourth Result" default="false" graphable="false"/>
          </xt:formula>
          <xt:node name="part" singleNodeId="e72f4b6a">
            <xt:property xsi:type="NodeExpansion" expandOn="part" filterMode="both"/>
            <xt:property xsi:type="ReportPreferences" displayMode="3" defaultMode="dmx" duration="l6h"/>
            <xt:formula formulaId="util.Nop4">
              <xt:parameter name="First Value" xsi:type="FilterFormulaParameterDefinition" filter="name==\'CurrentUtilization\'"/>
              <xt:parameter name="Second Value" xsi:type="FilterFormulaParameterDefinition" filter="name==\'Requests\'"/>
              <xt:parameter name="Third Value" properties="part" xsi:type="EmptyFormulaParameterDefinition"/>
              <xt:parameter name="Fourth Value" xsi:type="EmptyFormulaParameterDefinition"/>
              <xt:result name="FAUtilization" default="false" graphable="false"/>
              <xt:result name="FAIOPS" default="false" graphable="false"/>
              <xt:result name="FA Properties" default="false" graphable="false"/>
              <xt:result name="Fourth Result" default="false" graphable="false"/>
            </xt:formula>
          </xt:node>
        </xt:node>
      </xt:node>
    </xt:node>
  </xt:node>
</xt:node>
'; 

} # end sub xmldefs
