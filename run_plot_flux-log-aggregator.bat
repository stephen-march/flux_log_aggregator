@echo off
perl flux_log_aggregator.pl
perl separate_element_data.pl
MATLAB -r plot_element_data
