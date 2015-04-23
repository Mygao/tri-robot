function [ Planes ] = detectPlaneInstances_lidar_v3( meshRaw, visflag, resetParam )

persistent ONESCAN_         % single scan resolution 
persistent NUMSCAN_      % number of scans (in horizontal direction)
persistent v_angles
persistent s_angles
persistent Ccb_prev
persistent Tcb_prev

% parameters 
persistent normalComp_param 
persistent thre_svalue 
persistent thre_clusterSize 
persistent thre_memberSize 
persistent param_meanShiftResol 
persistent param_meanShiftWeights 

if isempty(ONESCAN_) || resetParam.flag 
    loadPersistentVariablesL_0421;
end

if isempty(ONESCAN_),
    Planes = [];
    return;
end

% params{1} : Transformation Matrix
Ccb = eye(3);
Tcb = zeros(3,1);
if isempty(Ccb_prev)
    Ccb_prev = Ccb;
    Tcb_prev = Tcb;
end


%Tcb = Tcb + Ccb*tr_kinect2head;

% if params == 0
Planes = [];
Points3D = [];
PlaneID = 0;

% %%
% meshRaw = reshape(typecast(meshRaw,'single'), [ONESCAN_ NUMSCAN_]);
meshRaw(meshRaw>3) = 0;             % clamp on ranges
meshRaw(meshRaw<0.5) = 0;
[mesh_, s_, v_] = scan2DepthImg_spherical0( meshRaw, s_angles, v_angles); % remove repeated measure   

mesh_ = medfilt2(mesh_,[3 3]);

NUMS_ = size(mesh_,1);
NUMV_ = size(mesh_,2);
Xind = repmat([1:NUMS_]',1,NUMV_); 
Yind = repmat(1:NUMV_,NUMS_,1); % index in 1D array    
validInd = find(mesh_>0);   
mask = zeros(size(mesh_));
mask(validInd) = 1;
% Convert to x, y, z 
cv_ = zeros(size(mesh_)); sv_ = cv_; cs_ = cv_; ss_ = cv_;
cv_(validInd) = cos(v_(validInd));
sv_(validInd) = sin(v_(validInd));
cs_(validInd) = cos(s_(validInd));
ss_(validInd) = sin(s_(validInd));
X0 = cs_.*cv_.*mesh_;
Y0 = ss_.*cv_.*mesh_; 
Z0  = -sv_.*mesh_ ;

figure(visflag), hold off;
showPointCloud(X0(:),Y0(:),Z0(:),[0.5 0.5 0.5],'VerticalAxis', 'Z', 'VerticalAxisDir', 'Up','MarkerSize',2);
hold on;
%% Normal Computation
[N, S] = computeNormal_lidarB(X0, Y0, Z0, mask, normalComp_param(1), normalComp_param(2));
validNormal = (find( sum(S,1) > 0)); 
validNormal = validNormal(find(S(4,validNormal)<thre_svalue));

% figure(5), scatter3(N(1,validNormal),N(2,validNormal),N(3,validNormal),5,[0.5 0.5 0.5], 'filled'); hold on;

%% Clustering  
data = [  Xind(validNormal) ; Yind(validNormal)];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% generate initial mean information HERE for better starting 
[finalMean,clusterXYcell,nMembers] = sphericalMeanShiftxyB(data,N(1:3,validNormal),param_meanShiftResol,param_meanShiftWeights);

% for each cluster
blankConnImg = zeros(floor(NUMS_/normalComp_param(2)),NUMV_);
for tt = 1: size(finalMean,2)      
    if nMembers(tt) > thre_clusterSize  % if cluster size is big enough
        
        connImg = blankConnImg;
        index = validNormal(clusterXYcell{tt}); 
        [index_x, index_y] = ind2sub([NUMS_ NUMV_],index);
        index_xsub = floor(index_x / normalComp_param(2));
        index_ysub = index_y;
        index_ = sub2ind(size(blankConnImg),index_xsub, index_ysub);
        connImg(index_) = 1;
        
       % Connectivity Check   
        L = bwlabel(connImg,4);
        NL = max(L(:));
        for t=1:NL
            indices{t} = find(L==t);
            count_(t) = length(indices{t});
        end
       

       if NL >0
            for t = 1: length(count_)                 
                if count_(t) > thre_memberSize % if the connected bloc is big enough 
                    [dummy,whichcell] = intersect(index_ , indices{t});    
       
                    if ~isempty(whichcell)   
                     %% Find center, bbox, boundary
                        [yind_s, xind_s] = ind2sub(size(connImg),indices{t}');
                        center_s = round(mean([xind_s;yind_s],2));
                       
                        Pts = [];
                        bbox = getBoundingBox(yind_s,xind_s);
                        Bbox = zeros(3,size(bbox,1));
                        [dummy,whichcell__] = intersect(index_ , sub2ind(size(connImg), bbox(:,1), bbox(:,2)));   
                        Bbox(1,:) = X0(index(whichcell__));
                        Bbox(2,:) = Y0(index(whichcell__));
                        Bbox(3,:) = Z0(index(whichcell__));
                        
                        % 8-directional extreme points 
                        pts = find8ExtremePoints(connImg, center_s, t);
                        if ~isempty(pts)                               
                            [dummy,whichcell_] = intersect(index_ , sub2ind(size(connImg), pts(:,1), pts(:,2)));  
                          
                            Pts(1,:) = X0(index(whichcell_));
                            Pts(2,:) = Y0(index(whichcell_));
                            Pts(3,:) = Z0(index(whichcell_));                                                                             
                        end       
                        
                     %% refinement 
                        % (could test using svd and find the principal axes?) 
                        [c, ins] = estimatePlaneL_useall( X0(index(whichcell)), Y0(index(whichcell)), Z0(index(whichcell)));
                     
                        %% save output 
                        if ~isempty(c) && numel(ins) > thre_memberSize
                            n_ = c(1:3);
                            n_ = -n_/norm(n_);
                           
                            z_mean = mean(Z0(index(whichcell(ins))));                                  
                            x_mean = mean(X0(index(whichcell(ins))));
                            y_mean = mean(Y0(index(whichcell(ins))));
                                                                          
                            Center = [x_mean; y_mean; z_mean];
                            
                            if Center'*n_ > 0
                                n_ = -n_;
                            end
 
                            if n_(3) > 0.9 
                            
                            PlaneID = PlaneID + 1;
                            Planes{PlaneID} = struct('Center', Center,...
                                                     'Normal', n_ ,...
                                                     'Points', [Pts Bbox],...
                                                     'Size',numel(ins));      
                                                 
                            
                            Points3D{PlaneID} = [ X0(index(whichcell)); Y0(index(whichcell)); Z0(index(whichcell)) ];
                            end
                        end
                    end
                end
            end
        end
        
    end % end of for each cluster
end
    
       
 % Coordinate Transformation
if 1 %~isempty(params)
    for t = 1:PlaneID  
        
        Planes{t}.Center = Ccb*Planes{t}.Center + Tcb;
        Planes{t}.Points = Ccb*Planes{t}.Points + repmat(Tcb,1,size(Planes{t}.Points,2)) ;
        Planes{t}.Normal = Ccb*Planes{t}.Normal;
        
        if visflag
            ALL = Ccb*Points3D{t} + repmat(Tcb,1,length(Points3D{t}));
            randcolor = rand(1,3); % 0.5*(finalMean(3:5,tt)+1);   
            figure(visflag), 
            showPointCloud(ALL(1,:), ALL(2,:),ALL(3,:),...
                  randcolor,'VerticalAxis', 'Z', 'VerticalAxisDir', 'Up','MarkerSize',5);
            nvec = [Planes{t}.Center  Planes{t}.Center+Planes{t}.Normal*0.15];
            figure(visflag),
            plot3(nvec(1,:), nvec(2,:), nvec(3,:),'-', 'Color', [0 0 0], 'LineWidth',2);
            plot3(Planes{t}.Points(1,:), Planes{t}.Points(2,:), Planes{t}.Points(3,:),'.', 'Color', [0 0 0]);
        end
    end
end
    

end

