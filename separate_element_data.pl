#!/usr/bin/perl
# need the line above for Windows file systems. not needed for unix systems

#use warnings;
use strict;
use File::stat;
use POSIX;
use POSIX qw(strftime);
use File::stat;
use Math::Complex;
use Cwd;

# possible files to open...
# only using extrapolation_aggregate_filtered.txt
#open(aggregateoutput, "<fluxlog_aggregate.txt");											# output file with all the flux data organized by element and date, no extrapolation performed yet
#open(extrapolationoutput, "<extrapolation_aggregate.txt");									# output file with extrapolated data
open(extrapolationoutputfiltered, "<extrapolation_aggregate_filtered.txt");					# only keeps the extrapolated data for a "good" curve fit
#open(warninglog, "<fluxlog_warning_log.txt");												# prints warnings that may appear and cause garbage outputs
#open(fullregressionreport, "<full_regression_report.txt");									# prints all regression data, which is useful for debugging
#open(arrheniusfits, "<arrhenius_fits.txt");												# captures only the Arrhenius fitting data
#open(arrheniusfitsfiltered, "<arrhenius_fits_filtered.txt");								# only keeps the Arrhenius data for a "good" curve fit

my $appendString = "-filtered.txt";		# append to the end of each new file generated
my $newFilename;
my $lastElement = "ZZ";

# read through the file and save off the individual element data in a .csv
while (my $line = <extrapolationoutputfiltered>) {
	
	chomp($line);		# segments the file based on white space	

	# Example of input lines:
	# element	date	test temp/valve position	test BEP	R^2	a	b	sublimator temp (C)	cracker temp (C)
	# Al	2017-01-07	1150	1.17740328430162e-007	0.999402404919561	10.0100564866362	-36951.863085659
	my $reLine = qr/(\D{2})\s+(\d{4}\-\d{2}\-\d{2})\s+(\d+)\s+(\d+\.\d+e\-\d+)\s+(\d\.\d+)/;
	
	if ($line =~ $reLine) {
		
		my $element = $1;
		my $date = $2;
		my $temp = $3;
		my $BEP = $4;
		my $r2 = $5;
				
		if ($date =~ /(\d{4})\-(\d{2})\-(\d{2})/){
			my $year = $1;
			my $month = $2;
			my $day = $3;
			my $newDate = $year.$month.$day;	# save date in YYYYMMDD form
			
			$newFilename = $element.$appendString;
			
			# Delete the contents of the file before appending to it
			if ($element !~ $lastElement){
				open(outputfile, '>', $newFilename);	
				close(outputfile);
			}
			
			open(outputfile, '>>', $newFilename);
			print outputfile "$newDate,$temp,$BEP,$r2\n";
			close(outputfile);
			print "$element\t$date\t$temp\t$BEP\t$r2\n";
		}
		
		$lastElement = $element;
	}
	
		
}