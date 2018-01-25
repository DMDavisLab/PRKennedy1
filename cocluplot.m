%% QuadPlotter

% Makes scatter plots of 2Ch clustering data from ClusterFields.
% Edit the default values below to save time typing them in again each time

% How to describe 'clustering'? These should match what you used in
% ProcSettings when producing the data tables.

if ~exist('ThresholdMainCh','var') % if one of these variables already exists then we don't need to respecify everything

    ThresholdMainCh = 65;   % Ch1 L(r) above this value is 'clustered'
    ThresholdCrossCh = 60;  % Ch1vsCh2 L(r) above this value is 'co-clustered'

    % How is your table organised?
    xCol = 3;               % Column with x coordinates for Ch1
    yCol = 4;               % Column with y coordinates for Ch1
    GFColMain = 12;         % Column with G&F values for Ch1
    GFColCross = 13;        % Column with G&F values for Ch1 vs Ch2

    % Sampling radii used for ClusterFields
    SamplingRadius = 30;    % Ch1 sampling radius
    SamplingRadius2 = 60;   % Ch1vsCh2 sampling radius
    RegionSize = 3000;      % Size of region (nm)
    
end

% Color specification.
% Values are 8 bit (i.e. 0-255) [R G B].
Quad_1_Color = [128 168 214];       % light blue
Quad_2_Color = [255 127 12];                  % orange ... or try [186 115 191] for purple (red/blue mix)
Quad_3_Color = [192 192 192];        % grey
Quad_4_Color = [214 128 128];       % light red
Hist_Main_Color = [214 38 38];      % red
Hist_Cross_Color = [32 117 214];    % blue

% Convert colors
Quad_1_Color = Quad_1_Color / 255;
Quad_2_Color = Quad_2_Color / 255;
Quad_3_Color = Quad_3_Color / 255;
Quad_4_Color = Quad_4_Color / 255;
Hist_Main_Color = Hist_Main_Color / 255;
Hist_Cross_Color = Hist_Cross_Color / 255;

% When scanning your folder, these text files will be ignored because we
% only want data-table text files.
IgnoreFilesNamedWith = {'RegionCropped','Centroids','Summary','vsCh'};
TargetFileExt = {'.txt'};
% TargetRegExp = 'T[0-9]+R[0-9]+Ch[0-9]+.txt';

%% Find the data folder and get list of useable text files
dirName = uigetdir(pwd,'Choose your main data folder (the foldering containing ''Numbers'')');

% Begin by not saving pooled data or region images, in case we are already processing pooled
% data. These get flipped on later if I think we are using regular data tables.
SavePooled = 0;
SaveRegionImages = 0;

if dirName ~=0
    cd(dirName);
    
    % Get list of data table files
     if isdir([dirName,'/Numbers'])
        cd('Numbers')
        
        if isdir([dirName,'/Numbers/RegionTables'])
            cd('RegionTables')
            DataFolder = '/Numbers/RegionTables';
        else
            DataFolder = '/Numbers';
        end

        % get list of txt files
        dirData = dir;                              % Get the data for the current directory
        dirIndex = [dirData.isdir];                 % Find the index for directories
        TXTfileList = {dirData(~dirIndex).name}';   % Get a list of the files
       
        IgnoredFiles = [];                              % Make a list of 'bad' files
        for f = 1:length(TXTfileList)
            [~, fname, ext] = fileparts(TXTfileList{f,1});
            if ~strcmp(ext,TargetFileExt{1,1})
                IgnoredFiles(end+1,1) = f;
            end
            
            for badname = 1:size(IgnoreFilesNamedWith,2)
                if ~isempty(strfind(fname,IgnoreFilesNamedWith{badname}))
                    IgnoredFiles(end+1,1) = f;
                    break
                end
            end
        end
        TXTfileList(IgnoredFiles) = [];
		TXTfileList = sort_nat(TXTfileList);
        % Add a check for 'purity'?
        clear TXTFileExt badFiles dirData dirIndex ext f fname
        cd('..')
    else
        error('This folder doesn''t contain a Numbers folder!');
    end

else
    error('Cancelled?! So rude.');
end

%% Set or verify threshold values
prompt = {...
    'Threshold - Main Ch: ',...
    'Threshold - Cross Ch: ',...
    'Column for x coords: ',...
    'Column for y coords: ',...
    'Column for L(r) Main Ch: ',...
    'Column for L(r) Cross Ch: ',...
    'Sampling Radius - Main: ',...
    'Sampling Radius - Cross: ',...
    'Region Size (nm): '};
dlg_title = 'Enter threshold settings...';
num_lines = 1;
def = {...
    num2str(ThresholdMainCh),...
    num2str(ThresholdCrossCh),...
    num2str(xCol),...
    num2str(yCol),...
    num2str(GFColMain),...
    num2str(GFColCross),...
    num2str(SamplingRadius),...
    num2str(SamplingRadius2),...
    num2str(RegionSize)};
answer = inputdlg(prompt,dlg_title,num_lines,def);

if ~isempty(answer)
    ThresholdMainCh = str2double(answer(1,1));
    ThresholdCrossCh = str2double(answer(2,1));
    xCol = str2double(answer(3,1));
    yCol = str2double(answer(4,1));
    GFColMain = str2double(answer(5,1));
    GFColCross = str2double(answer(6,1));
    SamplingRadius = str2double(answer(7,1));
    SamplingRadius2 = str2double(answer(8,1));
    RegionSize = str2double(answer(9,1));
else
    error('Cancelled?! So rude.');
end

%% Set up results folder
% timestamp = ['CrossClusterPlot ThrMain=',num2str(ThresholdMainCh),' ThrCross=',num2str(ThresholdMainCh),' - ',datestr(fix(clock),'yyyymmdd@HHMMSS')];
% mkdir(timestamp);
% cd(timestamp);

rng('shuffle'); % shuffle the random seed by the current date and time
alphanums = ['a':'z' 'A':'Z' '0':'9'];
randname = alphanums(randi(numel(alphanums),[1 5]));
foldername = ['CoClu_',randname];
mkdir(fullfile(dirName,foldername));
cd(fullfile(dirName,foldername));

mkdir('FIGs');
mkdir('PNGs');
mkdir('Numbers');

%% Do things for each data table
Quad_Results = cell(size(TXTfileList,1),5);
Data_Pool = struct();

for t = 1:size(TXTfileList,1)
    CurrentTXTfile  = TXTfileList{t,1};
    data_import_tmp = importdata(fullfile(dirName,DataFolder,CurrentTXTfile));
    
    if ~isstruct(data_import_tmp)
        data_import = struct;
        data_import.data = data_import_tmp;
    else
        data_import = data_import_tmp;
    end
    
    clear data_import_tmp;
        
    % Determine names of things
    SaveTXTFileName = strsplit(CurrentTXTfile,'.txt');
    SaveTXTFileName = SaveTXTFileName{1,1};
    CurrentIDSplits = strsplit(SaveTXTFileName,{'T','R','Ch'});
    
    
    if size(CurrentIDSplits,2) == 4 % normal data from regular CF processing
        CurrentTable = num2str(CurrentIDSplits{2});
        CurrentRegion = num2str(CurrentIDSplits{3});
        CurrentChannel = num2str(CurrentIDSplits{4});
        SavePooled = 1;
        SaveRegionImages = 1;
    elseif size(CurrentIDSplits,2) == 5 && strfind(CurrentIDSplits{2},'ANDOM_') % someone is feeding it randomised data probably
        CurrentTable = num2str(CurrentIDSplits{3});
        CurrentRegion = num2str(CurrentIDSplits{4});
        CurrentChannel = num2str(CurrentIDSplits{5});
        SavePooled = 1;
        SaveRegionImages = 1;
    elseif size(CurrentIDSplits,2) == 3 % These are probably the pooled text files
        CurrentTable = num2str(CurrentIDSplits{2});
        CurrentRegion = ' Pooled';
        CurrentChannel = num2str(CurrentIDSplits{3});
        SavePooled = 0;
        SaveRegionImages = 0;
    else
        error('Something is wrong with your input file names');
    end
    
    if CurrentChannel == '1' % will need to update this for 3 channel data
        CrossChannel = '2';
    else
        CrossChannel = '1';
    end
    
    % Pool this file's data with it's companion table/channel
    if SavePooled == 1
        % Make a field for this channel if it doesn't already have one.
        labversion = strsplit(version,{'(',')'},'CollapseDelimiters',true); % Cope with different versions of MATLAB
        if strcmp(labversion(2),'R2014a') || strcmp(labversion(2),'R2014b')
            TableChannelPoolName = matlab.lang.makeValidName(['T',CurrentTable,'Ch',CurrentChannel]);
            if ~isfield(Data_Pool,matlab.lang.makeValidName(TableChannelPoolName))
                eval(['Data_Pool.',matlab.lang.makeValidName(TableChannelPoolName),'= [];']);
            end
        elseif strcmp(labversion(2),'R2013a') || strcmp(labversion(2),'R2013b')
            TableChannelPoolName = genvarname(['T',CurrentTable,'Ch',CurrentChannel]);
            if ~isfield(Data_Pool,genvarname(['T',CurrentTable,'Ch',CurrentChannel]))
                eval(['Data_Pool.',genvarname(['T',CurrentTable,'Ch',CurrentChannel]),'= [];']);
            end
        end
        
        % add the data to its relevent pool
        eval(['Data_Pool.',TableChannelPoolName,' = vertcat(Data_Pool.',TableChannelPoolName,',data_import.data);']);
    end

    quadXmin = 0;  
    quadXmax = 50*(ceil(max(data_import.data(:,GFColMain))/50));
    quadYmin = 0;
    quadYmax = 50*(ceil(max(data_import.data(:,GFColCross))/50));
    if quadYmax == 0
        if quadXmax == 0
            quadXmax = 400;
            quadYmax = 400; 
        else
            quadYmax = quadXmax;
        end
    end
    
    % plot everything on top of the same figure
    this_plot = figure('Visible','off');
    set(this_plot, 'PaperUnits', 'inches');
    set(this_plot, 'PaperSize', [5 5]);
    set(this_plot,'PaperPosition',[0 0 5 5]);
    hold on
    % set(this_plot,'Visible','on');
    
% L(r) Histograms
    subplot(4,4,[13,14,15])
    HistGFMainxValues = quadXmin:10:quadXmax;
    HistGFMain = hist(data_import.data(:,GFColMain),HistGFMainxValues);
    HistGFMainBar = bar(HistGFMainxValues,HistGFMain,'Facecolor',Hist_Main_Color,'Edgecolor','none');
    set(gca,'XLim',[quadXmin max(quadXmax,1.2*ThresholdMainCh)]);
    set(gca,'fontsize',8,'color','none');
    box off
%     MainHistMax = get(gca,'YLim');
    MainHistMax = 100*ceil(max(HistGFMain(:,2:(end-1)))/100);

    subplot(4,4,[4,8,12])
    HistGFCrossxValues = quadYmin:10:quadYmax;
    HistGFCross = hist(data_import.data(:,GFColCross),HistGFCrossxValues);
    HistGFCrossBar = bar(HistGFCrossxValues,HistGFCross,'Facecolor',Hist_Cross_Color,'Edgecolor','none');
    view([90 -90])
    set(gca,'XLim',[quadYmin max(quadYmax,1.2*ThresholdCrossCh)]);
    set(gca,'fontsize',8,'color','none');
    box off
%    CrossHistMax = get(gca,'YLim');
    CrossHistMax = 100*ceil(max(HistGFCross(:,2:(end-1)))/100);


% Equal histo axis and add threshold lines
    HistEventAxisMax = max([MainHistMax CrossHistMax]);
    subplot(4,4,[13,14,15])
    set(gca,'Ylim',[0 HistEventAxisMax],'Ticklength', [0 0]);
    yline = line([ThresholdMainCh,ThresholdMainCh],ylim);
    set(yline,'Color','k');

    subplot(4,4,[4,8,12])
    set(gca,'Ylim',[0 HistEventAxisMax],'Ticklength', [0 0]);
    yline = line([ThresholdCrossCh,ThresholdCrossCh],ylim);
    set(yline,'Color','k');
       
% Quadrant stats
    
    total_count = size(data_import.data,1);

    % quadrant 1
    quad1 = RegionCropper2(data_import.data,[quadXmin ThresholdMainCh ThresholdCrossCh quadYmax],[GFColMain GFColCross]);
    quad1_count = size(quad1,1);
    quad1_percent = (quad1_count / total_count)*100;

    % quadrant 2
    quad2 = RegionCropper2(data_import.data,[ThresholdMainCh quadXmax ThresholdCrossCh quadYmax],[GFColMain GFColCross]);
    quad2_count = size(quad2,1);
    quad2_percent = (quad2_count / total_count)*100;

    % quadrant 3
    quad3 = RegionCropper2(data_import.data,[quadXmin ThresholdMainCh quadYmin ThresholdCrossCh],[GFColMain GFColCross]);
    quad3_count = size(quad3,1);
    quad3_percent = (quad3_count / total_count)*100;

    % quadrant 4
    quad4 = RegionCropper2(data_import.data,[ThresholdMainCh quadXmax quadYmin ThresholdCrossCh],[GFColMain GFColCross]);
    quad4_count = size(quad4,1);
    quad4_percent = (quad4_count / total_count)*100;

    subplot(4,4,[1,2,3,5,6,7,9,10,11])

    hold on
    qplot(1) = scatter(quad1(:,GFColMain),quad1(:,GFColCross),3,'ob','filled');
    qplot(2) = scatter(quad2(:,GFColMain),quad2(:,GFColCross),3,'or','filled');
    qplot(3) = scatter(quad3(:,GFColMain),quad3(:,GFColCross),3,'og','filled');
    qplot(4) = scatter(quad4(:,GFColMain),quad4(:,GFColCross),3,'om','filled');
    
    %reinforce colors
    set(qplot(1),'MarkerFaceColor',Quad_1_Color);
    set(qplot(2),'MarkerFaceColor',Quad_2_Color);
    set(qplot(3),'MarkerFaceColor',Quad_3_Color);
    set(qplot(4),'MarkerFaceColor',Quad_4_Color);

    box off
    axis([quadXmin max(quadXmax,1.2*ThresholdMainCh) quadYmin max(quadYmax,1.2*ThresholdCrossCh)])
    set(gca,'fontsize',8,'color','none');
    title(['Table ',CurrentTable,' Region ',CurrentRegion,' - Channel ',CurrentChannel,' vs ',CrossChannel],'fontsize',10,'fontweight','bold');
     
    % add reference lines
    xline = refline([0 ThresholdCrossCh]);
    set(xline,'Color','k');
    yline = line([ThresholdMainCh,ThresholdMainCh],ylim);
    set(yline,'Color','k');    
    
% Add all the axis labels

    subplot(4,4,[1,2,3,5,6,7,9,10,11])
    ylabel(['L(',num2str(SamplingRadius2),') : Ch',CurrentChannel,' vs Ch',CrossChannel],'fontsize',8);
    set(gca,'fontsize',8,'color','none');
   
    subplot(4,4,[4,8,12])
    ylabel('Events','fontsize',8);
    set(gca,'fontsize',8,'color','none');
    
    subplot(4,4,[13,14,15])
    xlabel(['L(',num2str(SamplingRadius),') : Ch',CurrentChannel],'fontsize',8);
    ylabel('Events','fontsize',8);
    set(gca,'fontsize',8,'color','none');
    AlignAxisBottomgPosn = get(gca,'Position');
    
% Add a legend in the missing plot spot
    LegendArea = subplot(4,4,16);
    QuadPlotLegendPosn = get(gca,'position');
    QuadPlotLegendPosn(2) = AlignAxisBottomgPosn(2)/2;
    delete(LegendArea)
    
    hleg = legend([qplot(1),qplot(2),qplot(3),qplot(4)] , ...
        {['Q1: ',num2str(quad1_percent,3),' %'], ...
        ['Q2: ',num2str(quad2_percent,3),' %'], ...
         ['Q3: ',num2str(quad3_percent,3),' %'], ...
         ['Q4: ',num2str(quad4_percent,3),' %']});
    legend('boxoff');
    set(hleg,'fontsize',8);
    set(hleg,'Position',QuadPlotLegendPosn);
    
% Add results to data table
    
    Quad_Results{t,1} = SaveTXTFileName;
    Quad_Results{t,2} = CurrentChannel;
    Quad_Results{t,3} = quad1_percent;
    Quad_Results{t,4} = quad2_percent;
    Quad_Results{t,5} = quad3_percent;
    Quad_Results{t,6} = quad4_percent;

    % Add labels to the threshold line markers
    % 0.1*get(gca,'YLim')
    % 0.1*get(gca,'XLim')
    text(15,ThresholdCrossCh+12,num2str(ThresholdCrossCh),'fontsize',5,'HorizontalAlignment','Right');
    text(ThresholdMainCh+15,12,num2str(ThresholdMainCh),'fontsize',5,'HorizontalAlignment','Right');

    hgsave(this_plot,fullfile('FIGs', strcat(SaveTXTFileName,'_quadrantplot.fig')));
    print(this_plot,'-dpng','-r300',fullfile('PNGs', strcat(SaveTXTFileName, '_quadrantplot.png')));
    close(this_plot);
    
    if SaveRegionImages == 1
        
        this_other_plot = figure('Color','w', 'visible', 'on', 'Renderer', 'OpenGL', 'Units', 'pixels','Visible','off'); %painters?
        set(this_other_plot, 'PaperUnits', 'inches', 'PaperSize', [12 12], 'PaperPositionMode', 'manual', 'PaperPosition', [0 0 12 12]);
       
        set(gca,'Units','inches','DataAspectRatio', [1,1,1],'Position', [1 1 10 10],'YTick',zeros(1,0),'XTick',zeros(1,0));    
        box('off');
        hold('on');

        eplot(1) = scatter(quad1(:,xCol),quad1(:,yCol),3,'ob','filled');
        eplot(2) = scatter(quad2(:,xCol),quad2(:,yCol),3,'or','filled');
        eplot(3) = scatter(quad3(:,xCol),quad3(:,yCol),3,'og','filled');
        eplot(4) = scatter(quad4(:,xCol),quad4(:,yCol),3,'om','filled');
        
        axis square image tight
        set(gca, 'Visible','off');

        %reinforce colors
        set(eplot(1),'MarkerFaceColor',Quad_1_Color);
        set(eplot(2),'MarkerFaceColor',Quad_2_Color);
        set(eplot(3),'MarkerFaceColor',Quad_3_Color);
        set(eplot(4),'MarkerFaceColor',Quad_4_Color);

        axis square image

        SaveHighDPI = strcat('-r',num2str(RegionSize / 10));
    
        %write to a temp image
        print('-dpng',SaveHighDPI,'tmp_precrop_Points.png');
    
        %load the temp image
        PointsTMP = imread('tmp_precrop_Points.png');

        %crop the temp image
        CropStripWidth = RegionSize / 10;
        CroppedPointsTMP = PointsTMP(1+CropStripWidth:(end-CropStripWidth),1+CropStripWidth:(end-CropStripWidth),:);
    
        hgsave(this_other_plot,fullfile('FIGs', strcat(SaveTXTFileName,'_regionbyquad.fig')));
        close(this_other_plot);
        
        imwrite(CroppedPointsTMP,fullfile('PNGs', strcat(SaveTXTFileName, '_regionbyquad.png')),'png');
        %print(this_other_plot,'-dpng',SaveHighDPI,fullfile('PNGs', strcat(SaveTXTFileName, '_regionbyquad.png')));

        
        %     if ProcSet.UseFolders==true
        %         imwrite(CroppedPointsTMP,fullfile('Points', strcat(FileName, ' Points.png')),'png');
        %     else
        %         imwrite(CroppedPointsTMP,strcat(FileName, ' Points.png'),'png');
        %     end
    
        delete('tmp_precrop_Points.png');
    %     close(gcf);
        
    end
    
    InfoMessage = ['[ ',num2str(ceil((t / size(TXTfileList,1))*100)),'% ] Processed ',SaveTXTFileName,' (Table ',num2str(t),' of ',num2str(size(TXTfileList,1)),').'];
    disp(InfoMessage);
end

    disp('Saving quadrant results to file...');
    % Save the quadrant measurements to a text file
    fid = fopen('Summary.txt','w');
    SummaryHeaders = {'FileName','Channel ID','Quad 1 (%)','Quad 2 (%)','Quad 3 (%)','Quad 4 (%)'};
    fprintf(fid,'%s\t%s\t%s\t%s\t%s\t%s\r\n',SummaryHeaders{:});
    for row = 1:size(Quad_Results,1)
        fprintf(fid,'%s\t%s\t%.3f\t%.3f\t%.3f\t%.3f\r\n',Quad_Results{row,:});
    end
    fid = fclose(fid);
        
%% Dump the pooled data to text files
    if SavePooled == 1
        disp('Saving pooled results files...');
        
        % Extract the file names from the field names
        DataPoolNames = fieldnames(Data_Pool);
                
        for p = 1:numel(DataPoolNames);
            SavePoolName = [DataPoolNames{p},'.txt'];
            
            % open the text file
            fid = fopen(fullfile(dirName,foldername,'Numbers',SavePoolName),'w');
            
            % build a string for the header format
            HeaderFormat = '%s';
            if isfield(data_import,'colheaders')
                for g = 1:(length(data_import.colheaders)-1)
                    HeaderFormat = strcat(HeaderFormat,'\t%s'); % replace \t with a comma for csv
                end
                
                % write headers and newline
                fprintf(fid,HeaderFormat,data_import.colheaders{:});
                fprintf(fid,'\r\n');
                fid = fclose(fid);
            
            else
                disp('[ ! ] You are missing headers or have a different number of headers than data columns. Making up headers for pooled tables.');
                for g = 1:(size(data_import.data,2)-1)
                    HeaderFormat = strcat(HeaderFormat,'\t%s'); % replace \t with a comma for csv
                end
                
                HeaderLength = size(data_import.data,2);
                FakeHeaders = cell(1,HeaderLength);
                FakeHeaders(:) = {'Data'};
                
                % write headers and newline
                fprintf(fid,HeaderFormat,FakeHeaders{:});
                fprintf(fid,'\r\n');
                fid = fclose(fid);
            end

            % append the data table
            TablePooledData = Data_Pool.(DataPoolNames{p});
            dlmwrite(fullfile(dirName,foldername,'Numbers',SavePoolName),TablePooledData,'-append','delimiter','\t');
        end
    else
        % if we aren't saving the pooled data then delete the empty Numbers
        % folder to avoid confusion
        rmdir(fullfile(dirName,foldername,'Numbers'));
    end
    
%% Wrap up
    cd('..');
    DispMsg = ['All done! You can find the output in ',fullfile(dirName,foldername)];
    disp(DispMsg);