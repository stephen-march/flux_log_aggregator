#!/usr/bin/perl
# need the line above for Windows file systems. not needed for unix systems

use warnings;
use strict;
use File::stat;
use POSIX;
use POSIX qw(strftime);
use Time::localtime;
use File::stat;
use Date::Format;
use Math::Complex;

open(aggregateoutput, ">fluxlog_aggregate.txt");													# output file 
open(extrapolationoutput, ">extrapolation_aggregate.txt");											# output file

####################################################################################################################
#                                       === Script Notes === 	                                                   #
####################################################################################################################
# flux_log_aggregator.pl
#
# Parses through AMBER log files to collect flux data based on the element and date.
# It calculated the average BEP for a given temp/valve position for that date. Output is stored in log_aggregate.txt
# 
# As and Sb values undergo linear interpolation to calculate the value at 150, 200, and 250 mils.
# The Group IIIs, Bi, and rare earth materials undergo exponential interpolation for a set of values.
# The interpolated values are calculated to assess if source material is running out.
#
# Note: this script is useful to assess the status of materials across growth campaigns,
# however, values may change slightly between each campaign and must be interpreted appropriately
#
#
#### TODO ####
# - interpolation functions, exponential and linear, probably need to set a minium for bf values
# -- see interpolation_test.pl in flux_aggregator\testing directory
# - Intip, Gatip, Albase --> In, Ga, Al
# -- NOTE: the STO files also happen to be in a different format, so need to somehow account for that...
# -- example: AFB's has a totally different format from everyone else
# - minimum interpolation values:
# -- for BEP, e.g. below 1e-8?
# -- for r^2 that are terrible, need to spit out values to test
# - Separate output file that has interpolated values, R^2 if possible
# -- yes! hardcoded for testing, but needs to become an input arg
# -- need to check that all possible sources are included and initialized in the subroutine and return all values in the script!
# - input args?
# -- start and end dates for a growth campaign
# -- input file with interpolation temps desired

####################################################################################################################
#                                       === Subroutines === 	                                                   #
####################################################################################################################

sub AverageValue{
		
		my(@inputArray) = @_;
		my $size = @inputArray;
		my $sum = 0;
		
		for (my $i=0;$i < $size; $i++){
			$sum = $sum+$inputArray[$i];
		}
		
		my $average = $sum/$size;
		
		return $average;
		
}


sub GetDate{

	my %monthHash = (
				Jan  =>  "01",
				Feb  =>  "02",
				Mar  =>  "03",
				Apr  =>  "04",
				May  =>  "05",
				Jun  =>  "06",
				Jul  =>  "07",
				Aug  =>  "08",
				Sep  =>  "09",
				Oct  =>  "10",
				Nov  =>  "11",
				Dec  =>  "12"
			);

	my %dayHash = (
				"1"  =>  "01",
				"2"  =>  "02",
				"3"  =>  "03",
				"4"  =>  "04",
				"5"  =>  "05",
				"6"  =>  "06",
				"7"  =>  "07",
				"8"  =>  "08",
				"9"  =>  "09",
				"10"  =>  "10",
				"11"  =>  "11",
				"12"  =>  "12",
				"13"  =>  "13",
				"14"  =>  "14",
				"15"  =>  "15",
				"16"  =>  "16",
				"17"  =>  "17",
				"18"  =>  "18",
				"19"  =>  "19",
				"20"  =>  "20",
				"21"  =>  "21",
				"22"  =>  "22",
				"23"  =>  "23",
				"24"  =>  "24",
				"25"  =>  "25",
				"26"  =>  "26",
				"27"  =>  "27",
				"28"  =>  "28",
				"29"  =>  "29",
				"30"  =>  "30",
				"31"  =>  "31",
			);

	my ($inputDate) = @_;
	
	my ($inputDate) = @_; # input is a string
	print "inputDate: $inputDate\n";
	#chomp($inputDate);
	#print "inputDate: $inputDate\n";
	#$inputDate = ctime(stat($inputDate)->ctime);
	$inputDate = ctime(stat($inputDate)->mtime);
	
	#my $teststring = "Mar";
	#my $strlength = length($teststring);
	#my $testval = $dateHash{$teststring};
	#print "length: $strlength\tdateHash{$teststring}: $testval\n";
	
	#chomp($inputDate);
	$inputDate =~ /\D+\s+(\D+)\s+(\d+)\s+\d+\:\d+\:\d+\s+(\d+)/;
	print "sub: $inputDate";
	print "1:$1\t2: $2\t3: $3\n";
	my $monthsss = $1;
	#chop($monthsss);
	
	#for debugging
	for my $c (split //, $monthsss) {
		print "hh: $c\n"
	}
	
	
	my $strlength=length($monthsss);
	print "month length: $strlength\n";
	my $tempMonths = $1;
	if ($strlength > 3){
	chop ($tempMonths);
	print "chop performed\n";
	}
	my $month = $monthHash{$tempMonths};
	my $tempDays = $2;
	#chop($tempDays);
	my $day = $dayHash{$tempDays};
	my $year = $3;
	my $newDate = $year.$month.$day;
	print "newdate: $newDate\tyear: $year\tmonth: $month\tday: $day\n";
	
	return $newDate;

}	

sub ReadExtrapolationFile{

	my $fh = $_[0];																		# file handle for input file name
	open(inputfile, "<");																# input file, set as an input arg later

	my %valveTempHash;
	my $element;
	my $value;
	
	while (my $line = <inputfile>) {														# reads through each line of the file
			
		chomp($line);																	# segments the file based on white space	

		if (($line =~ m/(\D+) valve position = (\d+)/) or ($line =~ m/(\D+) temp = (\d+)/)){
			$element = $1;
			$value = $2;
			$valveTempHash{$element} = $value;
		}
			
	}
	
	close(inputfile);
	
	return (\%valveTempHash);																# returns hash of the input values

}

sub Sum{
	
	my @numbers = @{$_[0]}; # dereference input array
	my $sum = 0;
	for ( @numbers ) {
		$sum += $_;
	}
	
	return $sum;
}

sub SumSqr{
	
	my @numbers = @{$_[0]}; # dereference input array
	my $sum = 0;
	my $val;
	foreach $val ( @numbers ) {
		$sum += $val**2;
	}
	
	return $sum;
}

sub InnerProduct{

	my @array1 = @{$_[0]}; # dereference input array
	my @array2 = @{$_[1]}; # dereference input array
	my $sum = 0;
	my $termCount = scalar(@array1);
	for (my $i=0; $i <= $termCount; $i++) {  
	   $sum += $array1[$i] * $array2[$i];
    }
	
	return $sum;
}

sub LinearRegression{

	my @x = @{$_[0]}; # input x array
	my @y = @{$_[1]}; # input y array

	my $nX = scalar(@x); # size of x array
	my $nY = scalar(@y); # size of y array
	if ($nX != $nY) { die "nX and nY arrays are different sizes! Linear interpolation fail! ";}

	# http://www.statisticshowto.com/how-to-find-a-linear-regression-equation/
	# y = a + bx
	#
	# a = (sum(y)*sum(x^2)-sum(x)*sum(xy)) / (n*sum(x^2)-sum(x)^2)
	# b = (n*sum(xy)-sum(x)*sum(y)) / (n*sum(x^2)-sum(x)^2)
	# denominator is same in both cases
	#

	my $sumx = Sum(\@x);
	my $sumy =Sum(\@y);
	my $sumxy = InnerProduct(\@x,\@y);
	my $sumxsqr = SumSqr(\@x);
	my $sqrsumx = (Sum(\@x))**2;
	my $sumysqr = SumSqr(\@y);
	my $sqrsumy = (Sum(\@y))**2;

	print "sum(x): $sumx\n";
	print "sum(y):  $sumy\n";
	print "sum(xy):  $sumxy\n";
	print "sum(x^2):  $sumxsqr\n";
	print "sum(x)^2:  $sqrsumx\n";
	print "sum(y^2):  $sumysqr\n";
	print "sum(y)^2:  $sqrsumy\n";

	my $a = (Sum(\@y) * SumSqr(\@x) - Sum(\@x) * InnerProduct(\@x,\@y)) / ($nX*SumSqr(\@x) - Sum(\@x)**2);
	my $b = ($nX*InnerProduct(\@x,\@y) - Sum(\@x)*Sum(\@y)) / ($nX*SumSqr(\@x) - Sum(\@x)**2);
	my $r = ($nX*InnerProduct(\@x,\@y) - Sum(\@x)*Sum(\@y)) / sqrt( ($nX*SumSqr(\@x) - Sum(\@x)**2) * ($nX*SumSqr(\@y) - Sum(\@y)**2));
	my $r2 = $r**2;

	print "a: $a\tb: $b\tr^2: $r2\n";

	return ($a,$b,$r2);

}

sub ExponentialRegression {

	my @x = @{$_[0]}; # input x array
	my @y = @{$_[1]}; # input y array
	
	# convert to linear expression via ln(y value)
	my @linearY;
	my $tempY;
	foreach my $oldY (@y){
		$tempY = log($oldY);
		push(@linearY, $tempY);
	}
	
	# perform linear regression and interpolate/extrapolate to desired x value
	my ($a,$b,$r2) = LinearRegression(\@x,\@linearY);
	return ($a,$b,$r2);
	
}


sub LinearInterpolation {
	
	my($a,$b,$testX) = @_;

	my $testY = $a + $b*$testX;
	return $testY;
}

sub ExponentialInterpolation {

	my @x = @{$_[0]}; # input x array
	my @y = @{$_[1]}; # input y array
	my $testX = $_[2]; # test x value
	
	# get natural log linear regression values
	my ($a,$b,$r2) = ExponentialRegression(\@x,\@y);
	my $testY = LinearInterpolation($a,$b,$testX);
	my $expY = exp($testY);
	
	return ($expY,$a,$b,$r2);	

}

####################################################################################################################
#                                       === Variables === 	                                                       #
####################################################################################################################

#------------------------------------- Hashes --------------------------------------------
my %fluxLogData;
my %extrapolationData;

#------------------------------------- arrays --------------------------------------------
my @fileInfo;
my @curBEP;
my @x;
my @y;

#------------------------------------- Literals ------------------------------------------
#my $log_dir = "C:/AMBER/Log Files"; # note: can use unix file syntax for Windows
my $line;
my $logDirectory = "C:/Users/stephen/Desktop/2017 spring/flux_aggregator/amber_logs_medium";
#my $logDirectory = "C:/Users/stephen/Desktop/2017 spring/flux_aggregator/testlog";
my $filename;
my $fileAccessed;
my $fileModified;
my $fileCreated;
my $fileDate;
my $countT;
my $lastT;
my $maxSizeT;
my $sizeT;
my $flagSize;
my $element;
my $T;
my $BGBF;
my $BF;
my $BEP;
my $averageBEP;

####################################################################################################################
#                                       === Code Body === 	                                                       #
####################################################################################################################

system("cls"); # clears command line screen

#opendir(DIR, $log_dir) or die "cannot open dir $log_dir: $!";
#my @file= readdir(DIR);
#closedir(DIR);

# collect files that are flux logs and store data in flux
opendir(DIR, $logDirectory) or die "cannot open dir $logDirectory: $!";
while ($filename = readdir(DIR)) { 
	#print "filename: $filename\n";
  
	if(($filename =~ m/.*\s+-\s+(.*)Flux.log/) or ($filename =~ m/.*\s+-\s+(.*)Fluxes.log/) or ($filename =~ /.*\s+-\s+(.*)Flux.*.log/)){

		my @teststat = stat($filename);
		
		print "====\n";
		print "matched filename: $filename\n";
		#print "pre-ctime filename: $filename\n";
		
		my $fileDate = GetDate($filename);
	
	
	
		# my $fileDate = ctime(stat($filename)->ctime);
		# #print "fileDate: $fileDate\n";
		# $fileDate = GetDate($fileDate);
		# print "FileDate mod: $fileDate\n"; # last modified date

		#$fileDate = "20170101"; #hardcoded, remove after debugging
		
		$countT = 0;																		# initialize $countT
		$lastT = 0;																			# initialize $lastT
		$maxSizeT = 0;																		# initialize $maxSizeT
		$sizeT = 0;																			# initialize $sizeT
		$flagSize = 0;																		# initialize $flagSize
		$element = $1;	
		undef(@x);																			# initialize @x
		undef(@y);																			# initialize @y
		#print "$element\n"; 																# check that the correct element name is captured

		open(my $fh, '<:encoding(UTF-8)', $filename) or die "Could not open file '$filename' $!";
		
		while ($line = <$fh>) {																# reads through each line of the file
			chomp($line);																	# segments the file based on white space
			#print "$line\n";
			
			# 9.050000E+2	4.324200E-10	3.179300E-7	3.174976E-7 # group IIIs and Bi
			# 2.300000E+2	2.151500E-9	2.781500E-6	2.779348E-6 # group Vs
			
			if ($line =~ m/\#Cell=(\D\D)/){
				$element = $1;																# Collect element symbol
				#print "element: $element\n";
			}
			
			if ($line =~ m/(\d\.\d+E\+\d+)\s+(\d\.\d+E\-\d+)\s+(\d\.\d+E\-\d+)\s+(\d\.\d+E\-\d+)/){
					
				$T = $1; 																	# cell temp
				$BGBF = $2; 																# background beam flux
				$BF = $3; 																	# measured beam flux with shutter open
				$BEP = $4; 																	# BEP = BGBF - BF, as calculated by AMBER
				
				if($T != $lastT){															# reached a new temp or valve position
					
					$sizeT = 0;																# reinitiallize $sizeT
					$countT++;																# keep track of which temp or valve position you have for your file
					
					if($countT > 1){
						
						$averageBEP = AverageValue(@curBEP);								# calculate average temp or valve position for the previous temp/valve position
						$fluxLogData{$element}{$fileDate}{$lastT} = $averageBEP;			# write $averageBEP to flux log data hash
						
						push(@y,$averageBEP);
						push(@x,$lastT);
					}
					
					undef(@curBEP);															# resets @curBEP array for the next temp/valve grouping
					$lastT = $T;															# set $lastT for the next loop iteration
				
				}
				
				if($T == $lastT){															# temp or valve position was the same as the previous line in the file
					
					push(@curBEP, $BEP); 													# adds $BEP to the end of @curBEP array
					$sizeT++;
					
					if($countT == 1){
						
						$maxSizeT = $sizeT;													# unique to the first temp/valve grouping: captures max number of times this temp/valve position is used
					
					}
					
					if($sizeT == $maxSizeT){
					
						$flagSize = 1;														# raises flag incase this is the last line of the file to make sure the avg BEP is calculated for the last temp/valve grouping
						
					}
				}

				$lastT = $T;																# set $lastT = $T for to compare the next line to the current line upon the next loop iteration
				
			}
			
			if($flagSize == 1){																# If the max
			
				$averageBEP = AverageValue(@curBEP);										# calculate average temp or valve position
				$fluxLogData{$element}{$fileDate}{$lastT} = $averageBEP;					# write $averageBEP to flux log data hash
			
				push(@y,$averageBEP);
				push(@x,$lastT);			
			
			}
		
	}
	
	close($fh)
	
	}

	
}

closedir(DIR);



# Collect extrapolation values
my $extrapolationInputFile = "extrapolation_values.txt";
my $tempHashRef = ReadExtrapolationFile($extrapolationInputFile);
my %extrapolationHash = %{$tempHashRef};

# printing a hash

# foreach $element (keys %fluxLogData){
#	foreach $fileDate (keys (%{$fluxLogData{$element}})){
#		foreach $T (keys (%{$fluxLogData{$element}{$fileDate}})){

print aggregateoutput "element\tDate\tCell temp or valve position\tBEP\n";

 foreach $element (sort keys %fluxLogData){
	foreach $fileDate (sort {$a <=> $b} keys (%{$fluxLogData{$element}})){
		
		my @curValveTemp;
		my @curBEP;
		
		foreach $T (sort {$a <=> $b} keys (%{$fluxLogData{$element}{$fileDate}})){

			$BEP = $fluxLogData{$element}{$fileDate}{$T};
			print "Element: $element\tDate: $fileDate\tTemp/Valve Position: $T\tBEP: $BEP\n";
			print aggregateoutput "$element\t$fileDate\t$T\t$BEP\n";
		
			push(@curValveTemp,$T);
			push(@curBEP,$BEP);
		
		}
		
		if($element =~ m/[AS][sb]/){															# if As or Sb, use linear extrapolation to get desired valve position
			my $testValveTemp = $extrapolationHash{$element};									# get the test value that was collected from the input file that was put into hash
			my ($a,$b,$r2) = LinearRegression(\@curValveTemp,\@curBEP);
			my $testBEP = LinearInterpolation($a,$b,$testValveTemp);
		
			print extrapolationoutput "$element\t$fileDate\t$testValveTemp\t$testBEP\t$r2\n";
			print "Element: $element\tDate: $fileDate\tTest Temp/Valve Position: $testValveTemp\tTest BEP: $testBEP\tr^2: $r2\n";
		}
		elsif(($element =~ m/[ABGIEL][lianru]/) or ($element =~ m/B/)) {						# if NOT As or Sb, use exponential extrapolation
			my $testValveTemp = $extrapolationHash{$element};									# get the test value that was collected from the input file that was put into hash
			my ($testBEP,$a,$b,$r2) = ExponentialInterpolation(\@curValveTemp,\@curBEP,$testValveTemp);
		
			print extrapolationoutput "$element\t$fileDate\t$testValveTemp\t$testBEP\t$r2\n";
			print "Element: $element\tDate: $fileDate\tTest Temp/Valve Position: $testValveTemp\tTest BEP: $testBEP\tr^2: $r2\n";
		}
		else {
			warn "The element called: ( $element ) is not included in the input file values!!!\n";
		}
				
	print "============================\n";

	}
}

close (aggregateoutput);
close (extrapolationoutput);