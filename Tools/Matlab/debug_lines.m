%close all;

%logdir = strcat('Data/', 'lines3', '/');
logdir = '/tmp/';

% Grab the common metadata
fid = fopen(strcat(logdir,'count_d_m.log'));
meta = fread(fid, Inf,'*int8');
metadata = msgpack('unpack', meta);
fclose(fid);

% counts
fid = fopen(strcat(logdir,'count_d_r.log'));
cnt = fread(fid,Inf,'*int');
cnt = reshape(cnt, [metadata.MAXR, metadata.NTH]);
cnt = cnt(1:metadata.NR, :);
fclose(fid);
figure(1);
clf;
%cnt(cnt<100)=0;
imagesc(cnt);
a_radon = gca;
set(a_radon, 'XLim', [1, metadata.NTH], 'YLim', [1, metadata.NR]);
%set(a_radon, 'xlimmode','manual',...
%'ylimmode','manual',...
%'ydir','reverse');

% Read the labelB image
fid = fopen(strcat(logdir,'labelB_d_r.log'));
labelB = fread(fid,Inf,'*uint8');
labelB = reshape(labelB, [metadata.wb, metadata.hb])';
fclose(fid);

% Plot labelB
cbk=[0 0 0];cr=[1 0 0];cg=[0 1 0];cb=[0 0 1];cy=[1 1 0];cw=[1 1 1];
cmap = [cbk;cr;cy;cy;cb;cb;cb;cb;cg;cg;cg;cg;cg;cg;cg;cg;cw];
figure(2);
clf;
image(labelB);
a_labelB = gca;
colormap(cmap);
axis image;
hold on;
set(a_labelB, 'XLim', [1, metadata.wb], 'YLim', [1, metadata.hb]);
%plot([1, metadata.wb],[1, metadata.hb],'k-');



% Show the lines
for i=1:numel(metadata.ijs)
    propsLine = metadata.ijs{i};
    l_x = uint8([propsLine.iMin, propsLine.iMean, propsLine.iMax]+1);
    l_y = uint8([propsLine.jMin, propsLine.jMean, propsLine.jMax]+1);

    %l_x = uint8([propsLine.iMean]);
    %l_y = uint8([propsLine.jMean]);

    plot(l_x,l_y,'r*-', 'LineWidth', 3);

    %if mod(i,2)==0
    %  plot(l_x,l_y,'b*-', 'LineWidth', 3);
      %plot(l_y,l_x,'k*-', 'LineWidth', 3);
    %else
    %  disp('other')
    %  plot(l_x,l_y,'r*-', 'LineWidth', 3);
      %plot(l_y,l_x,'y*-', 'LineWidth', 3);
    %end
    %l_y = double([propsLine.iMin, propsLine.iMean, metadata.iMax]);
    %l_x = double([propsLine.jMin, propsLine.jMean, metadata.jMax]);
    %set(p_l, 'Xdata', l_x + 1);
    %set(p_l, 'Ydata', l_y + 1);
end
