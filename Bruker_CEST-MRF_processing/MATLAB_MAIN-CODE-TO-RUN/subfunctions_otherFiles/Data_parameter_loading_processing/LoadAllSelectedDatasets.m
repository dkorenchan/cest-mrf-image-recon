% LoadAllSelectedDatasets: Takes in structures specifying the selected scan
% directories to load and what types of datasets they pertain to, along
% with other processing parameters, and returns all processed images (or 
% dummy images, if not selected by user) by calling the respective 
% loading/processing functions:
%   MRFLoad()
%   T1T2Load()
%   QUESP_load_proc()
%   WASSR_load_proc()
%
%   INPUTS:
%       specifiedflg    -   Struct containing logical indicators whether
%                           each type of dataset type has a specified scan
%                           number to process
%       scan_dirs       -   Struct containing scan directories
%                           corresponding with each type of dataset
%       i_flds          -   Struct containing cell arrays of names of the 
%                           images pertaining to how struct 'img' is  
%                           organized, further organized by plotting groups
%       cfg             -   Struct containing subfields describing user
%                           configuration settings: paths to load/save 
%                           folders, scripts, etc.
%       parprefs        -   Struct containing user specific processing 
%                           options
%       PV360flg        -   Logical indicating whether the selected study is
%                           identified as being obtained with ParaVision 360
%                           (true) or an older ParaVision version (false)
%       
%   OUTPUTS:
%       img             -   Struct containing images obtained by processing
%                           all specified datasets
%

function img=LoadAllSelectedDatasets(specifiedflg,scan_dirs,i_flds,cfg,...
    parprefs,PV360flg)

grps=fieldnames(i_flds);

%% LOAD INTO MATLAB: MRF 
if specifiedflg.MRF
    % Set up config struct to include location of MRF dataset
    cfg.loadMRF=fullfile(scan_dirs.base_dir,scan_dirs.MRF,'pdata','1');
%     MRFdirs.pydir=py_dir;
%     MRFdirs.pyfile=py_file;
%     MRFdirs.bash=bashfn;
%     MRFdirs.condaenv=conda_env;
%     MRFdirs.pyenv=py_env;
    disp(['MRF data: loading from ' cfg.MRFfn ' if found...'])
    [img.MRF,info.MRF]=MRF_load_proc(cfg,i_flds.MRF,parprefs,PV360flg);
    img.MRF.size=size(img.MRF.dp);
    disp('MRF data loading and processing complete!')
end


%% LOAD INTO MATLAB: T1 + T2
if specifiedflg.T1map
    disp('T1 map: loading fitted T1 map from scanner-generated DICOMs...')
    img.other.t1wIR=T1T2Load(fullfile(scan_dirs.base_dir,scan_dirs.T1map,...
        'pdata','2','dicom'),cfg.ext_dir);
    img.other.size=size(img.other.t1wIR);
    disp('T1 map loading complete!')
end

if specifiedflg.T2map
    disp('T2 map: loading fitted T1 map from scanner-generated DICOMs...')
    try
        img.other.t2wMSME=T1T2Load(fullfile(scan_dirs.base_dir,scan_dirs.T2map,...
            'pdata','2','dicom'),cfg.ext_dir);
    catch
        img.other.t2wMSME=T1T2Load(fullfile(scan_dirs.base_dir,scan_dirs.T2map,...
            'pdata','3','dicom'),cfg.ext_dir);
    end
    img.other.size=size(img.other.t2wMSME);
    disp('T2 map loading complete!')
end


%% LOAD INTO MATLAB: QUESP
if specifiedflg.QUESP
    disp('QUESP data: loading...')
    [img.other.fsQUESP,img.other.kswQUESP,Rsq,info.QUESP]=QUESP_load_proc(...
        fullfile(scan_dirs.base_dir,scan_dirs.QUESP,'pdata','1'),...
        img.other.t1wIR,parprefs,PV360flg);
    img.other.RsqMask=(Rsq>=parprefs.RsqThreshold);
    img.other.size=size(img.other.fsQUESP);
    disp('QUESP data loading and processing complete!')
end


%% LOAD INTO MATLAB: WASSR
if specifiedflg.WASSR
    disp('WASSR data: loading...')
    [img.other.B0WASSR,~,~,info.WASSR]=WASSR_load_proc(...
        fullfile(scan_dirs.base_dir,scan_dirs.WASSR,'pdata','1'),parprefs,...
        PV360flg);
    img.other.size=size(img.other.B0WASSR);
    disp('WASSR data loading and processing complete!')
end


%% DUMMY IMAGES FOR NONSELECTED DATASET TYPES
if ~prod(cell2mat(struct2cell(specifiedflg))) 
    disp('Filling in non-specified image datasets with dummy images...')
    if isfield(img,'MRF')
        dummysize=img.MRF.size;
    else
        dummysize=img.other.size;
    end
    for ii=1:numel(grps)
        if ~isfield(img,grps{ii})
            img.(grps{ii})=struct;
        end
        for jj=1:numel(i_flds.(grps{ii}))
            if ~isfield(img.(grps{ii}),i_flds.(grps{ii}){jj})
                img.(grps{ii}).(i_flds.(grps{ii}){jj})=zeros(dummysize);
            end
        end
    end
end