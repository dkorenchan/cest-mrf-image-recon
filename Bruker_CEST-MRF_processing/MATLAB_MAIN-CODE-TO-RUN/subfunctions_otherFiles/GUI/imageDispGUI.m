% imageDispGUI: Creates an interactive figure which can be used to display
% imaging data, draw ROIs, and perform additional data analysis,
% particularly on ROI voxels. 
%
%   INPUTS:
%       img             -   Struct containing images
%       roi             -   Struct containing ROI data
%       specifiedflg    -   Struct containing logical indicators whether
%                           each type of dataset type has a specified scan
%                           number to process
%       scan_dirs       -   Struct containing scan directories
%                           corresponding with each type of dataset
%       parprefs        -   Struct containing user specific processing 
%                           options
%       PV360flg        -   Logical indicating whether the selected study is
%                           identified as being obtained with ParaVision 360
%                           (true) or an older ParaVision version (false)
%
%   OUTPUTS:    
%       img             -   Struct containing updated images
%       roi             -   Struct containing updated ROI data 
%
% This file contains several subfunctions within imageDispGUI() - see  
% final section for brief descriptions:
%   plotAxImg()
%   selDispGrp()
%   nameROI()
%   newROI()
%   selROI()
%   ROIconc()
%   ROIexch()
%   checkBoxesEnable()
%   fixROIconcQUESP()
%   useNomExchError()
%   toggleSettingFlags()
%   editSettingVals()
%   calcROIs()
%   finishFig()
%   
function [img,roi]=imageDispGUI(img,roi,specifiedflg,scan_dirs,parprefs,...
    PV360flg)
%% MAIN FUNCTION -- INITIALIZE VARIABLES

% Parameters for plotting: image names, labels, colorbars
[i_flds,lbls,cblims]=initPlotParams;
grps=fieldnames(i_flds);

roiidx=1;
if isfield(roi,'name')
    nROI=numel(roi);
    roinames={roi.name};
else
    nROI=0;
    roinames=cell(1);    
end
newname=['ROI' num2str(nROI+1)];

rt=table;

% Set checkbox-related flags to false (to reflect initial values)
roi(1).fixConcQUESPflg=false;
roi(1).useNomExchflg=false;

% Set display options
settings.maskImgs=true;
settings.dpMaskVal=0.999;

% Set initial plotting group, based upon what was loaded
if isfield(img,'MRF')
    plotgrp='MRF';
else
    plotgrp='other';
end

% Screen size/resolution (for plotting)
scrsz = get(groot,'ScreenSize');
sppi = get(groot,'ScreenPixelsPerInch');


%% MAIN FUNCTION -- FIGURE GENERATION

% Make separate uifigure for table displaying ROI stats
tfig=uifigure('Position',[0 0 1100 500]);

% Display input 1H images in interactive GUI figure
drawfig =figure('Position',[0,round(scrsz(4)*1/6),round(scrsz(3)*2/3),...
    round(scrsz(4)*3/4)]*sppi,'Units','inches');

bg1 = uipanel('Position',[0 .1 .1 .9]);

% Controls for ROI editing + display

% Other display items
uicontrol(bg1,'Style','checkbox','Position',[10 735 120 22],...
    'Callback',@toggleSettingFlags,'Tag','maskImgs',...
    'Value',settings.maskImgs,'String','Mask images using');
uicontrol(bg1,'Style','text','Position',[30 710 90 30],...
    'String','dot-product loss');
uicontrol(bg1,'Style','text','Position',[30 690 80 15],...
    'String','Mask threshold:');
nr=uicontrol(bg1,'Style','edit','Position',[30 670 80 20],...
    'String',num2str(settings.dpMaskVal),'Tag','dpMaskVal',...
    'Callback',@editSettingVals);

% Selection for which group of images to display
uicontrol(bg1,'Style','text','Position',[5 625 160 15],...
    'String','Active display group:');
uicontrol(bg1,'Style','popupmenu','Position',[0 610 160 10],...
    'String',grps,'Callback',@selDispGrp);

% ROI creation
uicontrol(bg1,'Style','text','Position',[30 535 80 15],...
    'String','New ROI name:');
nr=uicontrol(bg1,'Style','edit','Position',[30 510 80 20],...
    'String',newname,'Callback',@nameROI);
uicontrol(bg1,'Style','pushbutton','Position',[0 480 140 30],...
    'String','Draw new ROI on slice','Callback',@newROI);

% ROI selection and editing
rbg=uibuttongroup('Position',[.005 .28 .09 .37],...
    'Visible',nROI>0);
uicontrol(rbg,'Style','text','Position',[20 295 80 15],...
    'String','Active ROI:');
rs=uicontrol(rbg,'Style','popupmenu','Position',[10 285 120 10],...
    'String',roinames,'Callback',@selROI);
uicontrol(rbg,'Style','text','Position',[20 210 90 45],...
    'String','Nominal concentration for active ROI:');
nc=uicontrol(rbg,'Style','edit','Position',[10 195 120 20],...
    'String','','Callback',@ROIconc);
uicontrol(rbg,'Style','text','Position',[20 150 90 45],...
    'String','Nominal exchange rate for active ROI:');
ne=uicontrol(rbg,'Style','edit','Position',[10 145 120 20],...
    'String','','Callback',@ROIexch);
uicontrol(rbg,'Style','text','Position',[10 100 110 45],...
    'String','(NOTE: put in units of mM/s^-1. Set to Inf or Nan if not using.)');
ncf=uicontrol(rbg,'Style','checkbox','Position',[10 80 120 22],...
    'Callback',@fixROIconcQUESP,'Enable','off','String','Fix concentration');
ncft=uicontrol(rbg,'Style','text','Position',[10 53 110 30],...
    'String','to nominal value for QUESP fitting','Enable','off');
nee=uicontrol(rbg,'Style','checkbox','Position',[10 30 120 22],...
    'Callback',@useNomExchError,'Enable','off','String','Use nominal');
neet=uicontrol(rbg,'Style','text','Position',[10 3 110 30],...
    'String','exchange rates for error maps','Enable','off');

% Status indicator
si = uicontrol(bg1,'Style','text','Position',[0 110 150 40],...
    'String','','FontSize',18,'FontWeight','bold');

% Finish button
uicontrol(bg1,'Style','pushbutton','Position',[20 40 100 60],...
    'String','FINISH AND SAVE','Callback',@finishFig);

% Detect how to initially set QUESP conc fix and nominal exch use 
% checkboxes status
checkBoxesEnable;

plotAxImg; 
if isfield(roi,'mask')
    calcROIs;
end
waitfor(drawfig);


%% INTERNAL CALLBACK FUNCTIONS FOR UI ELEMENTS


% plotAxImg: plots all axial images for the selected plotgrp
function plotAxImg
% Generate masks for each image group
% if exist('mask.mat','file')
%     disp('Mask found for imaging data - loading...')
%     load('mask.mat','mask');
if settings.maskImgs %mask all MRF images using dot-product loss
    mask.MRF=(img.MRF.dp>settings.dpMaskVal);
else
    mask.MRF=true(size(img.(plotgrp).(i_flds.(plotgrp){1})));
end
mask.ErrorMaps=true(size(img.(plotgrp).(i_flds.(plotgrp){1})));
mask.other=true(size(img.(plotgrp).(i_flds.(plotgrp){1})));
set(si,'String','Loading...')
pause(0.01) % ensures the status text above displays
if strcmp(plotgrp,'ErrorMaps')
    tiledlayout(2,9);
    nexttile;axis('off')
else
    tiledlayout(2,6);
end
for iii = 1:length(i_flds.(plotgrp))
    % Plot image, making voxels outside ROIs black (if ErrorMaps)
    nexttile([1 2]); imagesc(zeros([size(img.(plotgrp).(i_flds.(plotgrp){iii})),3]));
    hold on;
    if strcmp(plotgrp,'ErrorMaps')
        if contains(i_flds.(plotgrp){iii},'fs')
            allROImask=zeros(size(img.(plotgrp).(i_flds.(plotgrp){iii})));
            if isfield(roi,'nomConc')
                for jjj=1:nROI           
                    if ~isempty(roi(jjj).nomConc)
                        if ~isinf(roi(jjj).nomConc) && ~isnan(roi(jjj).nomConc)
                            allROImask=allROImask+roi(jjj).mask;
                        end
                    end
                end
            end    
        else
            allROImask=sum(reshape([roi.mask],[size(roi(1).mask),length(roi)]),3);
        end
        ei=imagesc(img.(plotgrp).(i_flds.(plotgrp){iii}).*mask.ErrorMaps); ...
            title(lbls.(plotgrp).title{iii},'FontSize',18);
        % If QUESP error maps: use R^2 mask to mask out non-fitted values
        if contains(i_flds.(plotgrp){iii},'QUESP')
            set(ei,'AlphaData',allROImask.*img.other.RsqMask);
        else
            set(ei,'AlphaData',allROImask);
        end
        axis('equal','off');
        cb=colorbar; clim(cblims.(plotgrp){iii}); cb.FontSize = 14;
        cb.Label.String=lbls.(plotgrp).cb{iii}; cb.Label.FontSize=16;
        colormap(bluewhitered);
        hold off;
        if iii==4 %jump down to next plotting row
            nexttile; axis('off')
        end
    else
        imagesc(img.(plotgrp).(i_flds.(plotgrp){iii}).*mask.(plotgrp)); ...
            title(lbls.(plotgrp).title{iii},'FontSize',18);
        axis('equal','off');
        cb=colorbar; clim(cblims.(plotgrp){iii}); cb.FontSize = 14;
        cb.Label.String=lbls.(plotgrp).cb{iii}; cb.Label.FontSize=16;
        colormap default;
        if isfield(roi,'coords') 
            for jjj=1:length(roi)
                drawpolygon('Position',roi(jjj).coords);
            end
        end
        if iii==3 % add in another spacer plot
            nexttile; axis('off')
        end
    end
end
set(si,'String','')
end


% selDispGrp: Set active group of images to plot + display ROI values
function selDispGrp(source,~)
plotgrp = grps{source.Value};
if isfield(roi,'mask')
    calcROIs;
end
plotAxImg;
end


% nameROI: sets name for new ROI once created
function nameROI(source,~)
    newname = source.String;
end


% newROI: Allows user to draw ROI on a slice without a previous one, or to
% delete the current ROI for redrawing
function newROI(~,~)
current_roi=drawpolygon;
roi(nROI+1).coords=current_roi.Position;
roi(nROI+1).mask=createMask(current_roi,img.(plotgrp).size(2),img.(plotgrp).size(1));
roi(nROI+1).name=newname;
roi(nROI+1).nomConc=NaN; %need to initialize!
roi(nROI+1).nomExch=NaN; %need to initialize!
if isempty(roinames{1})
    roinames={roi(nROI+1).name};
else
    roinames=[roinames {roi(nROI+1).name}];
end
nROI=nROI+1;
% Make items in GUI pertaining to ROIs visible
if nROI > 0
    set(rbg,'Visible','on');
end
newname=['ROI' num2str(nROI+1)];
set(nr,'String',newname);
set(rs,'String',roinames);
calcROIs;
checkBoxesEnable;
plotAxImg;
end


% selROI: Sets which ROI is the active one in the plotting GUI
function selROI(source,~)
roiidx=source.Value;
if isfield(roi(roiidx),'nomConc')
    set(nc,'String',num2str(roi(roiidx).nomConc));
else
    set(nc,'String','Inf');
end
if isfield(roi(roiidx),'nomExch')
    set(ne,'String',num2str(roi(roiidx).nomExch));
else
    set(ne,'String','Inf');
end
end


% ROIconc: Adds a field to variable roi indicating what
% nominal concentration is (in mM)
function ROIconc(source,~)
roi(roiidx).nomConc=str2double(source.String);
calcROIs;
plotAxImg;
%Make checkbox for concentration fixing active if all ROIs have a valid
%concentration specified (and enforce roi(1).fixConcQUESPflg=false if not!)
checkBoxesEnable;
end


% ROIexch: Adds a field to variable roi indicating what
% nominal exchange is (in s^-1)
function ROIexch(source,~)
roi(roiidx).nomExch=str2double(source.String);
if roi(1).useNomExchflg
    calcROIs;
end
%Make checkbox for nominal exchange rate use active if all ROIs have a 
%valid exchange rate specified (and enforce roi(1).useNomExchflg=false if 
%not!)
checkBoxesEnable;
end


% checkBoxesEnable: Checks to see whether user should be allowed to set
% roi(1).fixConcQUESPflg (i.e. whether all ROIs have valid specified
% nominal concentration values) or roi(1).useNomExchflg (i.e. whether all 
% ROIs have valid specified nominal exchange values). Update GUI elements 
% and output logical result
function checkBoxesEnable
% Check for nomConc-related checkbox
if isfield(roi,'nomConc')
    if sum(isnan([roi.nomConc])+isinf([roi.nomConc]))>0 || ...
            length([roi.nomConc])<nROI
        roi(1).fixConcQUESPflg=false;
        set(ncf,'Enable','off');
        set(ncft,'Enable','off');
    else
        set(ncf,'Enable','on');
        set(ncft,'Enable','on');
    end
else
    roi(1).fixConcQUESPflg=false;
    set(ncf,'Enable','off');
    set(ncft,'Enable','off');
end
% Check for nomExch-related checkbox
if isfield(roi,'nomExch')
    if sum(isnan([roi.nomExch])+isinf([roi.nomExch]))>0 || ...
            length([roi.nomExch])<nROI
        roi(1).useNomExchflg=false;
        set(nee,'Enable','off');
        set(neet,'Enable','off');
    else
        set(nee,'Enable','on');
        set(neet,'Enable','on');
    end
else
    roi(1).useNomExchflg=false;
    set(nee,'Enable','off');
    set(neet,'Enable','off');
end
end


% fixROIconcQUESP: Toggles flag roi.fixConcQUESPflg to fix QUESP ROI 
% concentrations to specified nominal values 
function fixROIconcQUESP(~,~)
roi(1).fixConcQUESPflg=~roi(1).fixConcQUESPflg;    
calcROIs;
end


% useNomExchError: Toggles flag roi.useNomExchflg to use specified nominal 
% values for exchange rates when showing error maps
function useNomExchError(~,~)
roi(1).useNomExchflg=~roi(1).useNomExchflg;
calcROIs;
plotAxImg;
end


% toggleSettingFlags: Toggles flags in variable settings
function toggleSettingFlags(src,~)
settings.(src.Tag)=~settings.(src.Tag);
plotAxImg;
end


% editSettingVals: Changes stored numerical values in variable settings
function editSettingVals(src,~)
settings.(src.Tag)=str2double(src.String);
plotAxImg;
end


% calcROIs: Calculate mean +/- std for each ROI, display in bottom. Also
% generate MRF % error maps from nominal concentration and QUESP exchange 
% rate
function calcROIs
% Calculate QUESP values using ROI-masked images (if QUESP loaded in)
img.ErrorMaps.kswAbs=zeros(size(roi(1).mask));
img.ErrorMaps.kswPct=zeros(size(roi(1).mask));
img.ErrorMaps.kswQUESPAbs=zeros(size(roi(1).mask));
img.ErrorMaps.kswQUESPPct=zeros(size(roi(1).mask));
if specifiedflg.QUESP
    [~,~,~,~,roi]=QUESP_load_proc(fullfile(scan_dirs.base_dir,scan_dirs.QUESP,...
        'pdata','1'),img.other.t1wIR,parprefs,PV360flg,roi);
    %Generate ksw error maps for MRF and QUESP
    for iii=1:nROI
        % First, set the true ROI-specific exchange rate based on user
        % specifications. If QUESP means are requested (or if not all ROIs
        % have a specified exchange rate), use QUESP values.
        if isfield(roi,'nomExch')
            if sum(~isinf([roi.nomExch])&~isnan([roi.nomExch]))==nROI && ...
                    roi(1).useNomExchflg
                true_ksp=roi(iii).nomExch;
            else
                true_ksp=roi(iii).kswQUESP.ROIfit;
            end
        else
            true_ksp=roi(iii).kswQUESP.ROIfit;
        end
        % MRF
        subimg=(img.MRF.ksw-true_ksp).*roi(iii).mask;
        img.ErrorMaps.kswAbs=img.ErrorMaps.kswAbs+subimg;
        img.ErrorMaps.kswPct=img.ErrorMaps.kswPct+...
            subimg./true_ksp*100;
        % QUESP
        subimg2=(img.other.kswQUESP-true_ksp).*roi(iii).mask.*img.other.RsqMask;
        img.ErrorMaps.kswQUESPAbs=img.ErrorMaps.kswQUESPAbs+subimg2;
        img.ErrorMaps.kswQUESPPct=img.ErrorMaps.kswQUESPPct+...
            subimg2./true_ksp*100;        
    end
else
    for iii=1:nROI
        roi(iii).fsQUESP.ROIfit=0;
        roi(iii).kswQUESP.ROIfit=0;
    end
end

% Calculate % error maps on MRF concentration (for all ROIs with a
% specified nominal concentration), and QUESP if specified
img.ErrorMaps.fsAbs=zeros(size(roi(1).mask));
img.ErrorMaps.fsPct=zeros(size(roi(1).mask));
img.ErrorMaps.fsQUESPAbs=zeros(size(roi(1).mask));
img.ErrorMaps.fsQUESPPct=zeros(size(roi(1).mask));
for iii=1:nROI
    if isfield(roi,'nomConc')
        if ~isempty(roi(iii).nomConc)
            if ~isinf(roi(iii).nomConc) && ~isnan(roi(iii).nomConc)
                subimg=(img.MRF.fs-roi(iii).nomConc).*roi(iii).mask;
                img.ErrorMaps.fsAbs=img.ErrorMaps.fsAbs+subimg;
                img.ErrorMaps.fsPct=img.ErrorMaps.fsPct+...
                    subimg./roi(iii).nomConc*100;
                if specifiedflg.QUESP
                    subimg2=(img.other.fsQUESP-roi(iii).nomConc).*roi(iii).mask...
                        .*img.other.RsqMask;
                    img.ErrorMaps.fsQUESPAbs=img.ErrorMaps.fsQUESPAbs+subimg2;
                    img.ErrorMaps.fsQUESPPct=img.ErrorMaps.fsQUESPPct+...
                        subimg2./roi(iii).nomConc*100;                   
                end
            end
        end
    end
end   

% Construct table of ROI values
if strcmp(plotgrp,'MRF')
    ProtonDensity=cell(nROI,1);
    T1=cell(nROI,1);
    T2=cell(nROI,1);
    Concentration=cell(nROI,1);
    ExchangeRate=cell(nROI,1);
    QUESP_ROIConcentration=cell(nROI,1);
    QUESP_ROIExchangeRate=cell(nROI,1);
elseif strcmp(plotgrp,'other')
    B0=cell(nROI,1);
    T1=cell(nROI,1);
    T2=cell(nROI,1);
    QUESPConcentration=cell(nROI,1);
    QUESPExchangeRate=cell(nROI,1);
end
for iii=1:nROI
    nn=numel(grps);
    for jjj=1:nn
        grp=grps{jjj};
        for kkk=1:length(i_flds.(grp))
            vals=img.(grp).(i_flds.(grp){kkk})(roi(iii).mask);
            vals=vals(vals~=0); %remove 0's
            roi(iii).(i_flds.(grp){kkk}).mean=mean(vals);
            roi(iii).(i_flds.(grp){kkk}).std=std(vals);
        end
    end
    if strcmp(plotgrp,'MRF')
        ProtonDensity{iii}=[num2str(roi(iii).dp.mean,'%0.4f') ' ' char(177) ' ' ...
            num2str(roi(iii).dp.std,'%0.4f')];
        T1{iii}=[num2str(roi(iii).t1w.mean,'%2.2f') ' ' char(177) ' ' ...
            num2str(roi(iii).t1w.std,'%2.2f') ' s'];
        T2{iii}=[num2str(roi(iii).t2w.mean,'%1.4f') ' ' char(177) ' ' ...
            num2str(roi(iii).t2w.std,'%1.4f') ' s'];
        Concentration{iii}=[num2str(roi(iii).fs.mean,'%3.1f') ' ' char(177) ' ' ...
            num2str(roi(iii).fs.std,'%3.1f') ' mM'];
        ExchangeRate{iii}=[num2str(roi(iii).ksw.mean,'%5.0f') ' ' char(177) ' ' ...
            num2str(roi(iii).ksw.std,'%5.0f') ' s^-1'];
        QUESP_ROIConcentration{iii}=[num2str(roi(iii).fsQUESP.ROIfit,'%3.1f') ' mM'];
        QUESP_ROIExchangeRate{iii}=[num2str(roi(iii).kswQUESP.ROIfit,'%5.0f') ' s^-1'];       
    elseif strcmp(plotgrp,'other')
        B0{iii}=[num2str(roi(iii).B0WASSR.mean,'%2.2f') ' ' char(177) ' ' ...
            num2str(roi(iii).B0WASSR.std,'%2.2f') ' Hz'];
        T1{iii}=[num2str(roi(iii).t1wIR.mean,'%2.2f') ' ' char(177) ' ' ...
            num2str(roi(iii).t1wIR.std,'%2.2f') ' s'];
        T2{iii}=[num2str(roi(iii).t2wMSME.mean,'%1.4f') ' ' char(177) ' ' ...
            num2str(roi(iii).t2wMSME.std,'%1.4f') ' s']; 
        QUESPConcentration{iii}=[num2str(roi(iii).fsQUESP.mean,'%3.1f') ' ' char(177) ' ' ...
            num2str(roi(iii).fsQUESP.std,'%3.1f') ' mM'];
        QUESPExchangeRate{iii}=[num2str(roi(iii).kswQUESP.mean,'%5.0f') ' ' char(177) ' ' ...
            num2str(roi(iii).kswQUESP.std,'%5.0f') ' s^-1'];
    end
end
ROIName = {roi.name}';
if strcmp(plotgrp,'MRF')
    rt = table(ROIName,ProtonDensity,T1,T2,Concentration,ExchangeRate,...
        QUESP_ROIConcentration,QUESP_ROIExchangeRate);
elseif strcmp(plotgrp,'other')
    rt = table(ROIName,B0,T1,T2,QUESPConcentration,QUESPExchangeRate);
end
clf(tfig);
uitable(tfig,'Data',rt,'Position',[20 20 1000 300],'ColumnEditable',false);
end


% finishFig: Finish all figure stuff, continue function
function finishFig(~,~)
close(tfig)
close(drawfig)
end
end