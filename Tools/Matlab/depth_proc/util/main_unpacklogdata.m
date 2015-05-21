close all;
clear all;

DEPTH_W = 512;
DEPTH_H = 424;
RGB_W = 1920;
RGB_H = 1080;

% Set the path and names
% The unpacked data will be saved under <foldername>/Unpacked/<datestamp> 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
foldername = '~/Data/LOGS_Lab_0324_2';
datestamp_kinect =[]; '03.25.2015.16.42.08';
datestamp_lidar = '03.25.2015.16.36.42'; %'03.25.2015.12.48.31';%[];% '02.24.2015.17.24.03'; 
showkinectimage = true;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
OFFSET = 0;

filename_depth = sprintf('k2_depth_r_%s.log',datestamp_kinect);
filename_rgb = sprintf('k2_rgb_r_%s.log', datestamp_kinect);

% search the files 
olderFolder = cd(foldername);
logFiles = dir('*.log');
cd(olderFolder);
flag_depth = find(cellfun(@(x) strcmp(x,filename_depth),{logFiles(:).name}));
flag_rgb = find(cellfun(@(x) strcmp(x,filename_rgb),{logFiles(:).name}));
flag_lidar = [];
if ~isempty(datestamp_lidar)
    filename_lidar = sprintf('mesh_r_%s.log',datestamp_lidar);
    flag_lidar = find(cellfun(@(x) strcmp(x,filename_lidar),{logFiles(:).name}));
end

% depth & rgb
if ~isempty(flag_depth) && ~isempty(flag_rgb)
    f_depth = fopen(sprintf('%s/%s', foldername,filename_depth));     
    fid = fopen(sprintf('%s/k2_depth_m_%s.log', foldername,datestamp_kinect));
    depthMeta = fread(fid,Inf,'*uint8');fclose(fid);
    depthMeta = msgpack('unpacker', depthMeta, 'uint8');

    f_rgb = fopen(sprintf('%s/%s', foldername,filename_rgb));     
    fid = fopen(sprintf('%s/k2_rgb_m_%s.log',foldername,datestamp_kinect));
    rgbMeta = fread(fid,Inf,'*uint8');fclose(fid);
    rgbMeta = msgpack('unpacker',rgbMeta,'uint8');
    
    olderFolder = cd(foldername);
    if ~exist('Unpacked','dir'),mkdir('Unpacked');end
    cd('Unpacked');
    % if ~exist(datestamp_kinect,'dir'),mkdir(datestamp_kinect);end
    cd(olderFolder);
end

% lidar
if ~isempty(flag_lidar), 
    f_lidar = fopen(sprintf('%s/%s', foldername,filename_lidar));     
    fid = fopen(sprintf('%s/mesh_m_%s.log',foldername, datestamp_lidar));
    meshMeta = fread(fid, Inf, '*uint8');fclose(fid);
    meshMeta = msgpack('unpacker', meshMeta, 'uint8');
    
    olderFolder = cd(foldername);
    if ~exist('Unpacked','dir'),  mkdir('Unpacked'); end
    cd('Unpacked');    
    if ~exist(strcat(datestamp_lidar,'l'),'dir'), mkdir(strcat(datestamp_lidar,'l')); end
    cd(olderFolder);
end

% depth & rgb
if  ~isempty(flag_depth) && ~isempty(flag_rgb),   
    ilog = 0;
    Nlog =  length(depthMeta);
    while ~feof(f_depth) && ilog < Nlog
        ilog = ilog + 1;    
   
        metad = depthMeta{ilog}; 
        depthRaw = fread(f_depth, [DEPTH_W, DEPTH_H], '*single');
        if showkinectimage == true
            figure(1), imagesc(depthRaw'); axis equal;
        end
        
        metar = rgbMeta{ilog};
        rgbJPEG = fread(f_rgb, metar.rsz, '*uint8');
        rgb_img0 = djpeg(rgbJPEG);
        rgb_img(:,:,1) = rgb_img0(:,:,1);
        rgb_img(:,:,2) = rgb_img0(:,:,2);
        rgb_img(:,:,3) = rgb_img0(:,:,3);       
     	if showkinectimage == true
        %    figure(2), imshow(rgb_img);     
        end
    
        save(strcat(foldername,'/Unpacked/',datestamp_kinect,'/',sprintf('%04d.mat',ilog+OFFSET)),'depthRaw', 'rgb_img', 'metad', 'metar');
        % save(strcat(foldername,'/Unpacked/03.25.2015.16.40.27/',sprintf('%04d.mat',ilog+OFFSET)),'depthRaw', 'rgb_img', 'metad', 'metar');
    
        pause(0.05);
        
        disp(strcat('kinect :',int2str(ilog) ,'/', int2str(Nlog)));
    end
    disp('kinect : Unpacked all!');
    fclose(f_depth);
    fclose(f_rgb);
end

% lidar
if ~isempty(flag_lidar), 
    ilog = 0;
    Nlog = length(meshMeta);
    while ~feof(f_lidar) && ilog < Nlog
        ilog = ilog + 1;    

        metal = meshMeta{ilog};
        n_scanlines = metal.dims(1);
        n_returns = metal.dims(2);   
        meshRaw = fread(f_lidar, [n_returns n_scanlines], '*single')';        
        figure(1), imagesc(meshRaw);
        
        save(strcat(foldername,'/Unpacked/',datestamp_lidar,'l/',sprintf('%lidar04d.mat',ilog)),'meshRaw', 'metal');
    
        pause(0.2);   
        
        disp(strcat('lidar :',int2str(ilog) ,'/', int2str(Nlog)));
    end
    fclose(f_lidar);
    disp('lidar : Unpacked all!');
end


