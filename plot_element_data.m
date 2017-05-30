function [] = plot_element_data( BEPorTemp )
%plot_element_data.m plots the output from flux_log_aggregator.pl
%   input: BEPorTemp -- =1 plot the BEP vs. time for a fixed temp
%                       =2 plot the temp vs. time for a fixed BEP

% user variables
col_date = 1;
col_testtemp = 2;
col_BEP = 3;

% select the column to use for plotting and for labeling
if BEPorTemp == 1
    col_select = col_BEP;
    col_label = col_testtemp;
elseif BEPorTemp == 2
    col_select = col_testtemp;
    col_label = col_BEP;
else
    warning('an incorrect BEPorTemp value was provided!');
end

% find the files in the directory that end with -filtered.txt
struct_pattern = '*-filtered.txt';

%% Select the path, expand to take this as an input
%file_dir = 'C:\Users\stephen\Desktop\2016 fall\Bi for ESW\FTIR_Bi_for_ESW';
%cd(file_dir); % change to the specified directory with the files to aggregate
%cd('pwd');
files = dir(struct_pattern); % creates struct of the dpt file names present in the current dir

%% Perform aggregation into a single matrix
aggregate_matrix = [];
Header_vector = {};
for i=1:length(files)
    
    % collects data from the i-th file to be aggregated
    cur_file = files(i).name; % gives full file name
    
    % open the current file as a csv
    cur_element_data = csvread(cur_file);
    
    % strips of parts of file name
    [filepath,filename,fileext] = fileparts(cur_file); 
    
    % save off element name to use as the title of the graph
    nameparts = textscan(filename, '%s %s','delimiter','-');
    chart_title = nameparts{1};
    
    % plot data as a scatter plot
    figure;
    format_in = 'yyyymmdd'; % pick the format of the input text files
    dn=datenum(num2str(cur_element_data(:,col_date)),format_in); % convert the dates 
                                                          % to something the computer 
                                                          % can interpret as dates
    scatter(dn,cur_element_data(:,col_select));
    datetick('x','keepticks','keeplimits');     % set the x-axis to be a date format
       
    % set the x, y, and title info for the plot
    title(chart_title);
    curval = num2str(cur_element_data(1,col_label));
    if BEPorTemp == 1
        ylabel('BEP'); 
        title(strcat(chart_title,{' '},curval,{' '},'C or mil'));
        testtemp_str = strcat(chart_title,{' '},curval,{' '},'C or mil');
    end
    if BEPorTemp == 2
        ylabel('temp (C) or valve position (mil)');    
        title(strcat(chart_title,{' '},curval,{' '},'BEP'));
        testtemp_str = strcat(chart_title,{' '},curval,{' '},'BEP');
    end
    xlabel('Date');

    % parameters for making good figures
    max_x = max(dn);
    min_x = min(dn);
    max_y = max(cur_element_data(:,col_select));
    min_y = min(cur_element_data(:,col_select));
    delta_x = max_x - min_x;
    delta_y = max_y - min_y;
    prefactor = 0.9;
    x_scaling = prefactor*delta_x + min_x;
    y_scaling = prefactor*delta_y + min_y;
    pos_x = x_scaling;
    pos_y = y_scaling;
    
    % add a label to the plot so we know what it is
    %str = {testtemp_str};
    %text(pos_x,pos_y,str{1}) 
end

end