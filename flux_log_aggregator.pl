#!/usr/bin/perl
# need the line above for Windows file systems. not needed for unix systems

#use warnings;
use strict;
use File::stat;
use POSIX;
use POSIX qw(strftime);
use Time::localtime;
use File::stat;
use Date::Format;
use Math::Complex;
use Cwd;

open(aggregateoutput, ">fluxlog_aggregate.txt");													# output file with all the flux data organized by element and date, no extrapolation performed yet
open(extrapolationoutput, ">extrapolation_aggregate.txt");											# output file with extrapolated data
open(extrapolationoutputfiltered, ">extrapolation_aggregate_filtered.txt");							# only keeps the extrapolated data for a "good" curve fit
open(warninglog, ">fluxlog_warning_log.txt");														# prints warnings that may appear and cause garbage outputs
open(fullregressionreport, ">full_regression_report.txt");											# prints all regression data, which is useful for debugging
open(arrheniusfits, ">arrhenius_fits.txt");															# captures only the Arrhenius fitting data
open(arrheniusfitsfiltered, ">arrhenius_fits_filtered.txt");										# only keeps the Arrhenius data for a "good" curve fit


####################################################################################################################
#                                       === Script Notes === 	                                                   #
####################################################################################################################
system("cls"); # clears command line screen
if(($ARGV[0] =~ /-h/i) or ($ARGV[0] =~ /-help/i)){
print "# \n";
print "# flux_log_aggregator.pl\n";
print "# \n";
print "# Parses through AMBER log files to collect flux data based on the element and date.\n";
print "# It calculated the average BEP for a given temp/valve position for that date. Output is stored in log_aggregate.txt\n";
print "# \n";
print "# User can provide an optional input file with extrapolation values. If no file is provided, this script automatically\n";
print "# uses extrapolation_values.txt\n";
print "# \n";
print "# As and Sb values undergo linear interpolation to calculate the value at 160 mils and 140 mils, repectively.\n";
print "# The Group IIIs, Bi, and rare earth materials undergo exponential interpolation for a set of values.\n";
print "# The interpolated values are calculated can be used to assess if source material is running out.\n";
print "# \n";
print "# === Output files that include fitting data ===\n";
print "#   	extrapolation_aggregate.txt 	-->	includes the element, date, test temp/valve position, test BEP, R^2, \n";
print "#									linear fitting parameters, sublimator temp, and cracker temp\n";
print "#	full_regression_report.txt		-->	Raw output from the script subroutines with the individual terms used to perform\n";
print "#									the regression as well as the Arrhenius fitting terms for non-valved-cracker sources\n";
print "#	arrhenius_fits.txt				-->	element, date, Amplitude, activation energy (eV), and R^2 for a given Arrhenius fit\n";
print "#									Obviously this is only used for non-valved-cracker sources\n";
print "# \n";
print "# Note: this script is useful to assess the status of materials across growth campaigns,\n";
print "# however, values may change slightly between each campaign and must be interpreted appropriately\n";
print "# \n";
print "# Possible future features to consider:print \n";
print "# - User-defined input regex patterns to include new elements\n";
print "# - Option for multiple fitting temperatures/positions, e.g. test at 150, 200, and 250 mils\n";
print "#\n";
die "help command was activated";
}
#### TODO ####
# test on unix system
#

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

	# Convert months into two digit number days
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

	# Convert the number days into two digits
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
	
	my ($inputDate) = @_; 												# input is a string
	print "inputDate: $inputDate\n";
	#$inputDate = ctime(stat($inputDate)->ctime);
	$inputDate = ctime(stat($inputDate)->mtime);
	
	## Debug testing
	#my $teststring = "Mar";
	#my $strlength = length($teststring);
	#my $testval = $dateHash{$teststring};
	#print "length: $strlength\tdateHash{$teststring}: $testval\n";
	
	$inputDate =~ /\D+\s+(\D+)\s+(\d+)\s+\d+\:\d+\:\d+\s+(\d+)/;		# strip off the month, day, and year information
	print "sub: $inputDate";
	#print "1:$1\t2: $2\t3: $3\n";	# test regex
	my $monthsss = $1;
	
	# Debugging
	#for my $c (split //, $monthsss) {
	#	print "hh: $c\n"
	#}
	
	# Get month information
	my $strlength=length($monthsss);
	my $tempMonths = $1;
	if ($strlength > 3){												# format the months string for hash processing below
		chop ($tempMonths);
	}
	my $month = $monthHash{$tempMonths};								# get the 2 digit month based on the 3 letter abbreviation
	
	# Get day information
	my $tempDays = $2;													# day could be 1 or 2 digits long
	my $day = $dayHash{$tempDays};										# convert the 1 or 2 digit day value into a 2 digit day value
	
	# Get year information
	my $year = $3;
	
	# Make new date in the YYYYMMDD format
	my $newDate = $year.$month.$day;
	my $newDateDashes = $year."-".$month."-".$day;
	print "newdate: $newDate\tyear: $year\tmonth: $month\tday: $day\n";	# output printing, mainly used for debugging
	
	return $newDate,$newDateDashes;

}	

sub ReadExtrapolationFile{

	my $fh = $_[0];																		# file handle for input file name
	open(inputfile, "<$fh");															# input file, set as an input arg later

	my %valveTempHash;
	my %dateRangeHash;
	my $element;
	my $value;
	my $r2;
	open(inputvaluestest, ">inputvaluestest.txt");
	
	while (my $line = <inputfile>) {													# reads through each line of the file
	
		chomp($line);																	# segments the file based on white space	

		# Regex patterns for the input file
		my $restartDate = qr/Start date\s+=\s+(\d{8})/;									# example: Start date = 20170115 
		my $reendDate = qr/End date\s+=\s+(\d{8})/;										# example: End date = 20170125
		my $reCrackerWholeNumber = qr/(\D+) valve position = (\d+)/;					# example: As valve position = 200
		my $reCrackerDecimal = qr/(\D+) valve position = (\d+\.\d+)/;					# example: As valve position = 200.0
		my $reCellWholeNumber = qr/(\D+) temp = (\d+)/;									# example: Ga temp = 1030
		my $reCellDecimal = qr/(\D+) temp = (\d+\.\d+)/;								# example: Ga temp = 1030.0
		my $rer2 = qr/r2\s+\=\s+(\d\.\d+)/;												# example: 0.985
		
		# Save off start date
		if ($line =~ $restartDate){
			my $startDate = $1;
			$dateRangeHash{start} = $startDate; 
		}

		# Save off end date
		if ($line =~ $reendDate){
			my $endDate = $1;
			$dateRangeHash{end} = $endDate;
		}		

		# Save off end date
		if ($line =~ $rer2){
			$r2 = $1;
		}	
		
		# Save off extrapolation valved-cracker positions and cell temperature data
		if (($line =~ $reCrackerWholeNumber) or ($line =~ $reCrackerDecimal) or ($line =~ $reCellWholeNumber) or ($line =~ $reCellDecimal)){
			$element = $1;
			$value = $2;
			$valveTempHash{$element} = $value;
			print inputvaluestest  "element: $element\tvalue: $value\n";
		}
		
			
	}
	
	close(inputfile);
	
	return (\%valveTempHash,\%dateRangeHash,$r2);											# returns hashes (in reference form) of the input values and dates

}

sub Sum{
	
	# add up all the values of an input array
	my @numbers = @{$_[0]}; 							# dereference input array
	my $sum = 0;										# initialize sum to zero
	for ( @numbers ) {
		$sum += $_;
	}
	
	return $sum;
}

sub SumSqr{
	
	# add up all the (x_i)^2 values of an array 
	my @numbers = @{$_[0]}; 							# dereference input array
	my $sum = 0;										# initialize sum to zero
	my $val;
	foreach $val ( @numbers ) {
		$sum += $val**2;
	}
	
	return $sum;
}

sub InnerProduct{

	# perfom inner product array element-wise multiplication/addition
	my @array1 = @{$_[0]}; # dereference input array
	my @array2 = @{$_[1]}; # dereference input array
	my $sum = 0;
	my $termCount = scalar(@array1);
	for (my $i=0; $i <= $termCount; $i++) {  
	   $sum += ($array1[$i] * $array2[$i]);
    }
	
	return $sum;
}

sub LinearRegression{

	my @x = @{$_[0]}; # input x array
	my @y = @{$_[1]}; # input y array

	my $nX = scalar(@x); # size of x array
	my $nY = scalar(@y); # size of y array
	if ($nX != $nY) { die "nX and nY arrays are different sizes! Linear interpolation fail! ";}

	# General form of a simple linear regression
	# http://www.statisticshowto.com/how-to-find-a-linear-regression-equation/
	# y = a + bx
	#
	# a = (sum(y)*sum(x^2)-sum(x)*sum(xy)) / (n*sum(x^2)-sum(x)^2)
	# b = (n*sum(xy)-sum(x)*sum(y)) / (n*sum(x^2)-sum(x)^2)
	# r = (n*sum(xy)-sum(x)*sum(y)) / sqrt( (n*sum(x^2)-sum(x)^2) * (n*sum(y^2)-sum(y)^2) )
	# r2 = r^2
	# denominator is same in both cases
	#

	# Calculating the various regression terms, see the each called subroutine for details
	my $sumx = Sum(\@x);
	my $sumy = Sum(\@y);
	my $sumxy = InnerProduct(\@x,\@y);
	my $sumxsqr = SumSqr(\@x);
	my $sqrsumx = (Sum(\@x))**2;
	my $sumysqr = SumSqr(\@y);
	my $sqrsumy = (Sum(\@y))**2;

	# Printing out the regressions terms
	print "### Regression terms ###\n";
	print fullregressionreport "### Regression terms ###\n";
	print "sum(x): $sumx\n";
	print fullregressionreport "sum(x): $sumx\n";
	print "sum(y):  $sumy\n";
	print fullregressionreport "sum(y):  $sumy\n";
	print "sum(xy):  $sumxy\n";
	print fullregressionreport "sum(xy):  $sumxy\n";
	print "sum(x^2):  $sumxsqr\n";
	print fullregressionreport "sum(x^2):  $sumxsqr\n";
	print "sum(x)^2:  $sqrsumx\n";
	print fullregressionreport "sum(x)^2:  $sqrsumx\n";
	print "sum(y^2):  $sumysqr\n";
	print fullregressionreport "sum(y^2):  $sumysqr\n";
	print "sum(y)^2:  $sqrsumy\n";
	print fullregressionreport "sum(y)^2:  $sqrsumy\n";
	
	# Calculate the a, b, and r^2 terms
	my $a = (Sum(\@y) * SumSqr(\@x) - Sum(\@x) * InnerProduct(\@x,\@y)) / ($nX*SumSqr(\@x) - Sum(\@x)**2);
	my $b = ($nX*InnerProduct(\@x,\@y) - Sum(\@x)*Sum(\@y)) / ($nX*SumSqr(\@x) - Sum(\@x)**2);
	my $r = ($nX*InnerProduct(\@x,\@y) - Sum(\@x)*Sum(\@y)) / sqrt( ($nX*SumSqr(\@x) - Sum(\@x)**2) * ($nX*SumSqr(\@y) - Sum(\@y)**2));
	my $r2 = $r**2;

	# Print/save the regression data
	print "Regression form: y = a + b*x\n";
	print "a: $a\tb: $b\tr^2: $r2\n";
	print fullregressionreport "Regression form: y = a + b*x\n";
	print fullregressionreport "a: $a\tb: $b\tr^2: $r2\n";
	
	return ($a,$b,$r2);

}

sub ExponentialRegression {

	# Convert to natural log values then run the linear regression

	my @x = @{$_[0]}; # input x array
	my @y = @{$_[1]}; # input y array
	
	# convert to linear expression via ln(y value)
	my @linearY;
	my $tempY;
	foreach my $oldY (@y){
		$tempY = log($oldY);
		push(@linearY, $tempY);
		print fullregressionreport "oldY: $oldY ---> ln(oldY): $tempY\n";
	}
	
	# perform linear regression and interpolate/extrapolate to desired x value
	my ($a,$b,$r2) = LinearRegression(\@x,\@linearY);
	return ($a,$b,$r2);
	
}

sub LinearInterpolation {

	# Perform linear interpolation following the form y = a + b*x
	# In this case, the x value is a test value specified by the user, e.g. valve position or 1/T of a cell
	
	my($a,$b,$testX) = @_;

	my $testY = $a + $b*$testX;
	return $testY;
}

sub ExponentialInterpolation {

	# Perform exponential regression by first converting the data into a linear format using 1/T
	# to fit to Arrhenius model.
	# Next, exponentiate the result 

	my @x = @{$_[0]}; # input x array
	my @y = @{$_[1]}; # input y array
	my $testX = $_[2]; # test x value
	
	# Get natural log linear regression values
	my ($a,$b,$r2) = ExponentialRegression(\@x,\@y);
	
	# Find fitted Arrhenius value for some temperature in Kelvin
	my $invertedTestX = 1/$testX;											# invert for arrhenius fitting
	my $testY = LinearInterpolation($a,$b,$invertedTestX);
	
	# Save off linear fitting data
	print fullregressionreport "testY: $testY\ttestX: $testX\n";
	
	# Exponentiate the data and save it
	my $expY = exp($testY);
	print fullregressionreport "testY: $testY ---> exp(testY): $expY\n";
	
	return ($expY,$a,$b,$r2);	

}

sub InvertArray {
	
	# Invert the values of an arry, e.g. converting an array of temperatures T --> 1/T 
	
	my @originalArray = @{$_[0]}; 				# input x array
	my $newVal;
	my @newArray;
	
	foreach my $curVal (@originalArray){
		$newVal = 1/$curVal;
		push(@newArray,$newVal);
	}
	
	return (\@newArray);
}

sub CelciusToKelvin	{

	# Convert an array of temperatures in Celcius to Kelvin

	my @originalArray = @{$_[0]}; 				# input temp array in celcius
	my $newVal;
	my @newArray;
	my $conversionFactor = 273.15;
	
	
	foreach my $curVal (@originalArray){
		$newVal = $curVal + $conversionFactor;
		push(@newArray,$newVal);
	}

	return (\@newArray);
}
	
sub CelciusToKelvinScalar	{

	# Convert a scalar from Celcius to Kelvin

	my $originalTemp = $_[0]; 					# input temp in celcius
	my $conversionFactor = 273.15;
	my $newVal = $originalTemp + $conversionFactor;
	
	return ($newVal);
}

sub ArrheniusTerms	{
	
	# Calculate Arrhenius model fitting terms for cells
	# Uses the form BEP = Amplitude*exp(-E_activation/(k_Boltzmann * Temp))
	
	my($a,$b) = @_;
	my $eVkBoltzmann = 8.6173303e-5;			# Boltzmann constant in eV/K
	my $activationEnergy = $b*(-$eVkBoltzmann);	# element activation energy in eV, minus sign because of the form of Arrhenius equation
	my $amplitude = exp($a);					# amplitude for Arrhenius equation
	
	return ($amplitude,$activationEnergy);

}
	
####################################################################################################################
#                                       === Variables === 	                                                       #
####################################################################################################################

#------------------------------------- Hashes --------------------------------------------
my %fluxLogData;
my %extrapolationData;
my %dateHashDash;
#------------------------------------- arrays --------------------------------------------
my @fileInfo;
my @curBEP;
my @x;
my @y;

#------------------------------------- Literals ------------------------------------------
#my $log_dir = "C:/AMBER/Log Files"; # note: can use unix file syntax for Windows
my $line;
#my $logDirectory = cwd(); # gets the present working directory in unix systems
#my $logDirectory = "C:/Users/stephen/Desktop/2017 spring/flux_aggregator/amber_logs_medium";
my $logDirectory = "C:/Users/stephen/Desktop/2017 spring/flux_aggregator/2017_early_log_files";	# must be the same directory as this script
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
my $STOTypeFlag;
my $BG;
my $BGAvg;
my $KtoCConversion = 273.15;
my $minAsValvePosition = 160; 		# don't fit any As data below this valve position
my $minSbValvePosition = 140; 		# don't fit any Sb data below this valve position
my $r2Test = 0.985;

####################################################################################################################
#                                       === Code Body === 	                                                       #
####################################################################################################################

system("cls"); # clears command line screen


# Determine input file with extrapolation values
my $extrapolationInputFile = $ARGV[0];		# input file from command line. In Windows, run as ><dir>\ perl flux_log_aggregator.pl "<input_file_name>"
if (not defined $extrapolationInputFile) {
  warn "No input file provided, so looking for \"extrapolation_values.txt\"\n";
  print warninglog "No input file provided, so looking for \"extrapolation_values.txt\"\n";
  warn "No input file provided, so looking for \"extrapolation_values.txt\"\n";
  $extrapolationInputFile = "extrapolation_values.txt";
  $r2Test = 0.985;
}

# Collect extrapolation values from user's input file
my ($tempHashRef,$dateRangeHashRef,$r2Test) = ReadExtrapolationFile($extrapolationInputFile);
my %extrapolationHash = %{$tempHashRef};													# extrapolation fit values
my %dateRangeHash = %{$dateRangeHashRef};													# date range values
my $word1 = "start";
my $word2 = "end";
my $startDate = $dateRangeHash{$word1};
my $endDate = $dateRangeHash{$word2};

# Collect files that are flux logs and store data in flux
opendir(DIR, $logDirectory) or die "cannot open dir $logDirectory: $!";
while ($filename = readdir(DIR)) { 

	
	# File regex patterns
	my $reFilename1 = qr/.*\s+-\s+.*Flux.log/;						# example: B170105 - STO - AsFlux.log
	my $reFilename2 = qr/.*\s+-\s+.*Fluxes.log/; 					# example: B170105 - STO - InFluxes.log or B170102 STO - Ga In - Group3Fluxes.log
	my $reFilename3 = qr/.*\s+-\s+.*Flux.*.log/;					# example: B170104 - Sb As STO - AsFluxLow.log
	my $reFilename4 = qr/.*\s+-\s+(Sb|As)\s+.*GroupVFlux.*.log/;	# example: B170102 STO - Sb - GroupVFlux.log
	
	# Get the YYYYMMDD date format for a file and calculate if the current file's date is before or after the start and end times
	# specified from the user's input file date range
	my ($fileDateMath,$fileDate) = GetDate($filename);
	$dateHashDash{$fileDateMath} = $fileDate;				# save off the YYYY-MM-DD date format in a hash
	my $testDateMathStart = $fileDateMath - $startDate;
	my $testDateMathEnd = $fileDateMath - $endDate;
	$fileDate = $fileDateMath;
	
	# If the file name matches one fo the file regex patterns above, parse through it to collect flux data
	if(($fileDateMath >= $startDate) and ($fileDateMath <= $endDate) and (($filename =~ $reFilename4) or ($filename =~ $reFilename1) or ($filename =~ $reFilename2) or ($filename =~ $reFilename3))){

		# Printing for commandline output
		print "====\n";
		print "matched filename: $filename\n";
		
		# Initializing values for this file
		$countT = 0;																		# initialize $countT
		$lastT = 0;																			# initialize $lastT
		$maxSizeT = 0;																		# initialize $maxSizeT
		$sizeT = 0;																			# initialize $sizeT
		$flagSize = 0;																		# initialize $flagSize
		$element = "ZZ";																	# dummy element ZZ, if the file is formatted correctly, this will get updated
		$STOTypeFlag = 0;																	# initialize $STOTypeFlag

		undef(@x);																			# initialize @x, used to collect temperature or valve positions
		undef(@y);																			# initialize @y, used to colelct BEP data
			
		open(my $fh, '<:encoding(UTF-8)', $filename) or die "Could not open file '$filename' $!";
		
		while ($line = <$fh>) {																# reads through each line of the file

			chomp($line);																	# segments the file based on white space
			
			# Regex patterns for parsing through STO data
			my $reElementV1 = qr/(\S{2})\D{0,4}Temp Flux bg1 avgbg2/;													# STO v1 element finding
			my $reElementV2 = qr/\#Cell=(\D\D)/;																		# STO v2 and Newton element finding
			my $reV1 = qr/(\S{2})\D{0,4}Temp.*(\d\.\d+E\+\d)\s+(\d\.\d+E\-\d+)\s+(\d\.\d+E\-\d+)\s+(\d\.\d+E\-\d+)/;	# STO v1 regex
			my $reV2 = qr/(\d\.\d+E\+\d)\s+(\d\.\d+E\-\d+)\s+(\d\.\d+E\-\d+)\s+(\d\.\d+E\-\d+)/;						# STO v2 and Newton regex
			my $reSiffElement = qr/(\D{2})\s+Temp\s+BEP\-BK/;															# Sifferman and Salas old STO format
			my $reSublimator = qr/SUB\=\s+(\d\.\d+E\+\d)/;																# example: SbSUB=	7.200000E+1
			my $reCracker = qr/Cracker\=\s+(\d\.\d+E\+\d)/;																# example: SbCracker=	9.000000E+2
			
			
			if ($line =~ $reElementV1){
				$element = $1;																# collect element symbol
				$STOTypeFlag = 1;															# indicates this is STO V1
			}
			
			if ($line =~ $reElementV2){
				$element = $1;																# collect element symbol
				$STOTypeFlag = 2;															# indicates this is STO v2 or Newton
			}
			
			if ($line =~ $reSiffElement){
				$element = $1;																# collect element symbol
				$STOTypeFlag = 3;															# indicates this is STO v2 or Newton
				$flagSize = 0;																# resets flagSize to allow for multiple elements
				$countT = 0;
				undef(@curBEP);																# resets @curBEP array for the next temp/valve grouping
				#print warninglog "## FOUND Siff formatting, element: $element on file date: $fileDate\n";
			}
			
			if ($line =~ $reSublimator){
				$fluxLogData{$element}{$fileDate}{"sublimator"} = $1; 
			}
			
			if ($line =~ $reCracker){
				$fluxLogData{$element}{$fileDate}{"cracker"} = $1; 
			}
			
			my $reV1V2Newton = qr/(\d\.\d+E\+\d+)\s+(\d\.\d+E\-\d+)\s+(\d\.\d+E\-\d+)\s+(\d\.\d+E\-\d+)/;
			my $reSiffData = qr/\t(\d\.\d+E\+\d+)\s+(\d\.\d+E\-\d+)$/;
			
			# If the current line of the STO file matches the regex pattern for a line with data, collect and save the data
			if (($line =~ $reV1V2Newton) or ($line =~ $reSiffData)){
				
				### Collecting the data for the current line
				
				# Check for STO v1 formatting
				if ($STOTypeFlag == 1){															
					$T = $1; 																# cell temp
					$BEP = $2; 																# BEP = Flux - BGAvg, as calculated by AMBER
					$BG = $3; 																# background beam flux from the 1st background measurement 
					$BGAvg = $4; 															# average collected from 20 background measurements								
				}
				
				# Check for STO v2 and Newton formatting				
				if ($STOTypeFlag == 2){															
					$T = $1; 																# cell temp
					$BGBF = $2; 															# background beam flux
					$BF = $3; 																# measured beam flux with shutter open
					$BEP = $4; 																# BEP = BF - BGBF, as calculated by AMBER
				}
				
				# Check for STO v2 and Newton formatting
				if ($STOTypeFlag == 3){															
					$T = $1; 																# cell temp
					$BEP = $2; 																# BEP = BF - BGBF, as calculated by AMBER
				}
				
				### Saving STO data into hashes
				
				# Reached a new temp or valve position
				if($T != $lastT){															
					
					$sizeT = 0;																# reinitiallize $sizeT
					$countT++;																# keep track of which temp or valve position you have for your file
					
					if($countT > 1){														# $countT = 1 means this is the first data point, so there no data collected to perform average calculation
						
						$averageBEP = AverageValue(@curBEP);								# calculate average temp or valve position for the previous temp/valve position
						$fluxLogData{$element}{$fileDate}{$lastT} = $averageBEP;			# write $averageBEP to flux log data hash
						
						push(@y,$averageBEP);
						push(@x,$lastT);
					}
					
					undef(@curBEP);															# resets @curBEP array for the next temp/valve grouping
					$lastT = $T;															# set $lastT for the next loop iteration
				
				}
				
				# Temp or valve position was the same as the previous line in the file
				if($T == $lastT){															
					
					push(@curBEP, $BEP); 													# adds $BEP to the end of @curBEP array
					$sizeT++;
					
					if($countT == 1){
						
						$maxSizeT = $sizeT;													# unique to the first temp/valve grouping: captures max number of times this temp/valve position is used
					
					}
					
					if($sizeT == $maxSizeT){
					
						$flagSize = 1;														# raises flag incase this is the last line of data for this element, then avg BEP is calculated for the last temp/valve grouping
						
					}
				}

				$lastT = $T;																# set $lastT = $T for to compare the next line to the current line upon the next loop iteration
				
			}
			
			# If the max number for a group of temps or valve positions is reached, perform average calculation of the BEPs at a given temp or valve position
			if($flagSize == 1){																
			
				if(($element =~ m/ZZ/) and ($STOTypeFlag == 0)){print warninglog "flagZize ==1 found element ZZ\tcur file name: $filename\n";}	# DEBUG line
				$averageBEP = AverageValue(@curBEP);										# calculate average temp or valve position
				$fluxLogData{$element}{$fileDate}{$lastT} = $averageBEP;					# write $averageBEP to flux log data hash
			
				push(@y,$averageBEP);
				push(@x,$lastT);			
			
			}
		
	}
	
	close($fh);
	
	}

	
}

closedir(DIR);



### Printing a hash and performing curve fitting

print aggregateoutput "element\tdate\tcell temp (C) or valve position (mil)\tBEP\tsublimator temp (C)\tcracker temp (C)\n";
print extrapolationoutput "element\tdate\ttest temp/valve position\ttest BEP\tR^2\ta\tb\tsublimator temp (C)\tcracker temp (C)\n";
print arrheniusfits "element\tdate\tamplitude\tactivtation energy (eV)\tR^2\n";
print arrheniusfitsfiltered "element\tdate\tamplitude\tactivtation energy (eV)\tR^2\n";
print extrapolationoutputfiltered "element\tdate\ttest temp/valve position\ttest BEP\tR^2\ta\tb\tsublimator temp (C)\tcracker temp (C)\n";

my $r2Test = 0.985;

# Loop through each element, alphabetically
foreach $element (sort keys %fluxLogData){

	# Loop through each file date, chronologically
	foreach $fileDate (sort {$a <=> $b} keys (%{$fluxLogData{$element}})){
		
		# Initialize values for the current loop
		my @curValveTemp;
		my @curBEP;
		my $subTemp = "";
		my $crackerTemp = "";

		my $dateDash = $dateHashDash{$fileDate};
		
		# Loop through each temperature or valve position, from lowest to highest
		foreach $T (sort {$a <=> $b} keys (%{$fluxLogData{$element}{$fileDate}})){

			$BEP = $fluxLogData{$element}{$fileDate}{$T};
			
			# Set sublimator and cracker temp if As or Sb is found
			if(($element =~ m/[AS][sb]/) and (($T =~ m/sublimator/) or ($T =~ m/cracker/))){					
				$subTemp = $fluxLogData{$element}{$fileDate}{"sublimator"};
				$crackerTemp = $fluxLogData{$element}{$fileDate}{"cracker"};
			}
			# Print the data for the current hash key value
			else {
				print aggregateoutput "$element\t$dateDash\t$T\t$BEP\t$subTemp\t$crackerTemp\n";
				print "Element: $element\tDate: $dateDash\tTemp/Valve Position: $T\tBEP: $BEP\tsublimator temp: $subTemp\tcracker temp: $crackerTemp\n";
			}
		
			# Save the temperature/valve position and BEP data for regression fitting later
			# Only collect data above minimum valve position for As and Sb or collect any of the data without restrictions for the rest of the cells
			if ((($element =~ m/As/) and ($T >= $minAsValvePosition)) or (($element =~ m/Sb/) and ($T >= $minSbValvePosition)) or (($element =~ m/[ABGIEL][lianru]/) or ($element =~ m/B/)) ){	
				push(@curValveTemp,$T);
				push(@curBEP,$BEP);
			}
		}
		
		my $sizeTArray = scalar(@curValveTemp);													# use to check that there are multiple data points before performing regression
		
		
		# If As or Sb, use linear extrapolation to get desired valve position
		if(($element =~ m/[AS][sb]/) and ($sizeTArray >1) ){									
			
			# Redundent, but keeping for future testing
			my $subTemp = $fluxLogData{$element}{$fileDate}{"sublimator"};
			my $crackerTemp = $fluxLogData{$element}{$fileDate}{"cracker"};
			
			# Perform linear interpolation
			my $testValveTemp = $extrapolationHash{$element};									# get the test value that was collected from the input file that was put into hash
			print fullregressionreport "========\nelement: $element\tfile date: $dateDash\n";
			my ($a,$b,$r2) = LinearRegression(\@curValveTemp,\@curBEP);
			my $testBEP = LinearInterpolation($a,$b,$testValveTemp);
			
			# Print/save data
			print extrapolationoutput "$element\t$dateDash\t$testValveTemp\t$testBEP\t$r2\t$a\t$b\t$subTemp\t$crackerTemp\n";
			print fullregressionreport "$element\t$dateDash\t$testValveTemp\t$testBEP\t$r2\t$a\t$b\t$subTemp\t$crackerTemp\n";
			print "Element: $element\tDate: $dateDash\tTest Temp/Valve Position: $testValveTemp\tTest BEP: $testBEP\tr^2: $r2\ta: $a\tb: $b\tsubimlator temp: $subTemp\tcracker temp: $crackerTemp\n";
		
			if($r2 >= $r2Test){
				print extrapolationoutputfiltered "$element\t$dateDash\t$testValveTemp\t$testBEP\t$r2\t$a\t$b\t$subTemp\t$crackerTemp\n";
			}
		
		}
		
		# If NOT As or Sb, use exponential extrapolation for Arrhenius fitting
		elsif((($element =~ m/[ABGIEL][lianru]/) or ($element =~ m/B/)) and ($sizeTArray >1) ) {
			
			# Clean up the temperature from T --> 1/T and Celcius to Kelvin
			my $testValveTemp = $extrapolationHash{$element};									# get the test value that was collected from the input file that was put into hash
			$testValveTemp = CelciusToKelvinScalar($testValveTemp);								# convert the test temp to Kelvin
			my $kelvinTempRef = CelciusToKelvin(\@curValveTemp);
			@curValveTemp = @{$kelvinTempRef};													# re-reference temp arrary converted from celcius to kelvin
			my $tempRef = InvertArray(\@curValveTemp);											# invert  @curValveTemp for temps 1/T for Arrhenius fitting
			@curValveTemp = @{$tempRef};														# re-reference the flipped temperature array
			print fullregressionreport "========\nelement: $element\tfile date: $dateDash\n";
			
			# Perform exponential/Arrhenius fitting
			my ($testBEP,$a,$b,$r2) = ExponentialInterpolation(\@curValveTemp,\@curBEP,$testValveTemp);
			my ($amp, $actE) = ArrheniusTerms($a,$b);
			my $KtoCTemp = $testValveTemp - $KtoCConversion;									# convert the test temp back to degrees C from Kelvin
			
			# Print/save data
			print extrapolationoutput "$element\t$dateDash\t$KtoCTemp\t$testBEP\t$r2\t$a\t$b\n";
			print "Element: $element\tDate: $dateDash\tTest Temp/Valve Position: $KtoCTemp\tTest BEP: $testBEP\tr^2: $r2\ta: $a\tb:$b\n";
			print fullregressionreport "Arrhenius fit terms -- amplitude: $amp\tactivation energy (eV): $actE\n";
			print arrheniusfits "$element\t$dateDash\t$amp\t$actE\t$r2\n";
			
			
			if($r2 >= $r2Test){
				print arrheniusfitsfiltered "$element\t$dateDash\t$amp\t$actE\t$r2\n";
				print extrapolationoutputfiltered "$element\t$dateDash\t$KtoCTemp\t$testBEP\t$r2\t$a\t$b\n";
			}
		}
		
		# Not enough data points to perform regression! Need more than one data point...
		elsif($sizeTArray == 1){																
			
			# Set the fitting values to 0 so it is clear in the output file that there was insufficient data
			my $testValveTemp = $extrapolationHash{$element};									# Use the test value that was collected from the input file
			my $testBEP = 0;
			my $r2 = 0;
			my $a = 0;
			my $b = 0;
			
			# Print/save data, send note to warning log that regression was not performed
			print extrapolationoutput "$element\t$dateDash\t$testValveTemp\t$testBEP\t$r2\t$a\t$b\n";
			print "Element: $element\tDate: $dateDash\tTest Temp/Valve Position: $testValveTemp\tTest BEP: $testBEP\tr^2: $r2\ta: $a\tb:$b\n";
			print warninglog "The element called: ( $element ) from date stamp ($dateDash) only has one data point, so no regression was performed! Check input file and make sure it matches this script's regex so all data was collected correctly."
		}
		
		# The user-definied input file did not specify an extrapolation value, so no curve fitting was performed
		else {
			warn "The element called: ( $element ) is not included in the input file values!!!\n";
			print warninglog "The element called: ( $element ) from date stamp ($dateDash) is not included in the input file values!!! Check input file and make sure it matches this script's regex."
		}
				
	print "============================\n";

	}
}

close (aggregateoutput);
close (extrapolationoutput);
close (arrheniusfits);
close (warninglog);
close (fullregressionreport);
close (inputvaluestest);