function h = show_monitor_thorwin
global cam

h = []
h.init = @init;
h.process_msg = @process_msg;





    function init()
        figure(1);
        clf;
        set(gcf,'position',[1 1 600 450]);
        f_mainA = gca;
        f_yuyv  = axes('Units','Normalized','position',[0.0 0.5 1/3 0.5]);
        f_lA    = axes('Units','Normalized','position',[1/3 0.5 1/3 0.5]);
        f_lB    = axes('Units','Normalized','position',[2/3 0.5 1/3 0.5]);
        f_field = axes('Units','Normalized','position',[0.0 0.0 0.5 0.5]);
        
        %set(f_lA, 'Visible', 'off');
        %set(f_lB, 'Visible', 'off');
        %set(f_yuyv, 'Visible', 'off');
        %set(f_field, 'Visible', 'off');
        
        cam = {};
        
        % Colormap for the labeled image
        cbk=[0 0 0];cr=[1 0 0];cg=[0 1 0];cb=[0 0 1];cy=[1 1 0];cw=[1 1 1];
        cam.cmap = [cbk;cr;cy;cy;cb;cb;cb;cb;cg;cg;cg;cg;cg;cg;cg;cg;cw];
        
        % LABELB
        set(gcf, 'CurrentAxes', f_lB);
        im_lB = image(zeros(1));
        colormap(cam.cmap);
        
        % LABELA
        set(gcf,'CurrentAxes',f_lA);
        im_lA = image(zeros(1));
        colormap(cam.cmap);
        hold on;
        p_ball = plot([0],[0], 'y*');
        % Remove from the plot
        set(p_ball,'Xdata', []);
        set(p_ball,'Ydata', []);
        r_ball = rectangle('Position', [0 0 1 1],...
            'Curvature',[1,1], 'EdgeColor', 'b', 'LineWidth', 2);
        p_post = cell(2,1);
        for i=1:numel(p_post)
            p_post{i} = plot([0],[0], 'b-', 'LineWidth', 2);
            % Remove from the plot
            set(p_post{i},'Xdata', []);
            set(p_post{i},'Ydata', []);
        end
        % Assume up to 3 obstacles
        h_obstacle = cell(3,1);
        for i=1:numel(h_obstacle)
            h_obstacle{i} = plot([0],[0], 'r-', 'LineWidth', 2);
            % Remove from the plot
            set(h_obstacle{i},'Xdata', []);
            set(h_obstacle{i},'Ydata', []);
        end
        
        % Assume up to 4 lines
        h_line = cell(4, 1);
        for i=1:numel(h_line)
            h_line{i} = plot([0], [0], 'm--', 'LineWidth', 3);
            % Remove from the plot
            set(h_line{i},'Xdata', []);
            set(h_line{i},'Ydata', []);
        end
        
        % yuyv
        set(gcf,'CurrentAxes',f_yuyv);
        im_yuyv = image(zeros(1));
        
        % Show the field here
        %set(gcf,'CurrentAxes',f_field);
        
        cam.h_field = f_field;
        hold on;
        
        % Debug messages
        set(gcf,'CurrentAxes',f_mainA);
        % top ones
        cam.a_debug_ball=uicontrol('Style','text','Units','Normalized',...
            'Position', [0.5 0.25 1/6 0.25],'FontSize',10, ...
            'BackgroundColor',[0.9 0.7 0.7],...
            'FontName','Arial');
        
        cam.a_debug_goal=uicontrol('Style','text','Units','Normalized',...
            'Position', [2/3 0.25 1/6 0.25], 'FontSize',10, ...
            'BackgroundColor',[0.7 0.7 0.9],...
            'FontName','Arial');
        
        cam.a_debug_obstacle=uicontrol('Style','text','Units','Normalized',...
            'Position', [5/6 .25 1/6 0.25],'FontSize',10, ...
            'BackgroundColor',[0.7 0.7 0.7], ...
            'FontName','Arial');
        % bottom ones
        cam.a_debug_line=uicontrol('Style','text','Units','Normalized',...
            'Position', [0.5 0 1/6 0.25],'FontSize',10, ...
            'BackgroundColor',[1 1 1],...
            'FontName','Arial');
        cam.a_debug_corner = uicontrol('Style','text','Units','Normalized',...
            'Position', [2/3 0 1/6 0.25], 'FontSize',10, ...
            'BackgroundColor',[0.9 0.9 0.7],...
            'FontName','Arial');
        cam.w_debug = uicontrol('Style','text','Units','Normalized',...
            'Position', [5/6 0 1/6 0.25], 'FontSize',10, ...
            'BackgroundColor',[0.7 0.9 0.7],...
            'FontName','Arial');
        
        
        
        
        %{
    cam.a_debug_ball = annotation('textbox',...
        [0.6 0 0.13 1],...
        'String','Top Camera',...
        'FontSize',10,...
        'FontName','Arial',...
        'LineStyle','--',...
        'EdgeColor',[1 1 0],...
        'LineWidth',2,...
        'BackgroundColor',[0.9  0.9 0.9],...
        'Color',[0.84 0.16 0]);

    cam.a_debug_goal = annotation('textbox',...
        [0.73 0 0.13 1],...
        'String','Top Camera',...
        'FontSize',10,...
        'FontName','Arial',...
        'LineStyle','--',...
        'EdgeColor',[1 1 0],...
        'LineWidth',2,...
        'BackgroundColor',[0.9  0.9 0.9],...
        'Color',[0.84 0.16 0]);
    cam.a_debug_obstacle = annotation('textbox',...
        [0.86 0 0.14 1],...
        'String','Top Camera',...
        'FontSize',10,...
        'FontName','Arial',...
        'LineStyle','--',...
        'EdgeColor',[1 1 0],...
        'LineWidth',2,...
        'BackgroundColor',[0.9  0.9 0.9],...
        'Color',[0.84 0.16 0]);

    % World debug
    cam.w_debug = annotation('textbox',...
        [0 0 0.3 0.5],...
        'String','Localization',...
        'FontSize',12,...
        'FontName','Arial'...
    );
            %}
            % Save the camera handles
            
            cam.f_lA = f_lA;
            cam.im_lA = im_lA;
            cam.f_lB = f_lB;
            cam.im_lB = im_lB;
            cam.f_yuyv = f_yuyv;
            cam.f_field = f_field;
            cam.im_yuyv = im_yuyv;
            cam.p_ball = p_ball;
            cam.r_ball = r_ball;
            cam.p_post = p_post;
            cam.h_obstacle = h_obstacle;
            cam.h_line = h_line;
            % Plot scale
            % Default: labelA is half size, so scale twice
            scale = 2;
            cam.scale = 2;
            
            % Turn off all axes
            % http://stackoverflow.com/questions/16399452/how-to-remove-axis-in-matlab
            set(findobj(gcf, 'type','axes'), 'Visible','off')
            
    end


    function [needs_draw] = process_msg(metadata, raw, cam)
        % Process each type of message
        msg_id = char(metadata.id);
        needs_draw = 0;
        if strcmp(msg_id,'detect')
            % Clear graphics objects
            % ball
            set(cam.p_ball,'Xdata', [],'Ydata', []);
            % TODO: assume up to 3 obstacles for now
            for i=1:numel(cam.h_obstacle)
                % obstacles
                set(cam.h_obstacle{i}, 'Xdata', [], 'Ydata', []);
            end
            for i=1:numel(cam.p_post)
                % posts
                set(cam.p_post{i},'Xdata', [],'Ydata', []);
            end
            for i=1:numel(cam.h_line)
                % obstacles
                set(cam.h_line{i}, 'Xdata', [], 'Ydata', []);
            end
            
            % Set the debug information
            set(cam.a_debug_ball, 'String', char(metadata.debug.ball));
            set(cam.a_debug_goal, 'String', char(metadata.debug.post));
            set(cam.a_debug_line, 'String', char(metadata.debug.line));
            set(cam.a_debug_obstacle, 'String', char(metadata.debug.obstacle));
            
            % Process the ball detection result
            if isfield(metadata,'ball')
                %TODO: use ball t to remove old ball
                
                % Show our ball on the YUYV image plot
                % ball_c = metadata.ball.centroid * cam.scale;
                % ball_radius = (metadata.ball.axisMajor / 2) * cam.scale;
                % ball_box = [ball_c(1)-ball_radius ball_c(2)-ball_radius...
                %     2*ball_radius 2*ball_radius];
                % set(cam.p_ball, 'Xdata', ball_c(1));
                % set(cam.p_ball, 'Ydata', ball_c(2));
                % set(cam.r_ball, 'Position', ball_box);
                
                % Show ball on label image
                ball_c = metadata.ball.centroid;
                ball_radius = (metadata.ball.axisMajor / 2);
                ball_box = [ball_c(1)-ball_radius ball_c(2)-ball_radius...
                    2*ball_radius 2*ball_radius];
                set(cam.p_ball, 'Xdata', ball_c(1));
                set(cam.p_ball, 'Ydata', ball_c(2));
                set(cam.r_ball, 'Position', ball_box);
            else
                %REMOVE BALL IF WE CANNOT SEE IT!
                set(cam.p_ball, 'Xdata', []);
                set(cam.p_ball, 'Ydata', []);
                set(cam.r_ball, 'Position', [0 0 0.0001 0.0001]);
                
            end
            if isfield(metadata,'posts')
                % Show on the plot
                % TODO: array of plot handles, for two goal posts
                for i=1:numel(metadata.posts)
                    postStats = metadata.posts{i};
                    
                    % Plot on YUYV image
                    % post_c = postStats.centroid * cam.scale;
                    % w0 = postStats.axisMajor / 2 * cam.scale;
                    % h0 = postStats.axisMinor / 2 * cam.scale;
                    
                    % Plot on label image
                    post_c = postStats.post.centroid;
                    w0 = postStats.post.axisMajor / 2;
                    h0 = postStats.post.axisMinor / 2;
                    post_o = postStats.post.orientation;
                    
                    rot = [cos(post_o) sin(post_o); -sin(post_o) cos(post_o)]'; %'
                    x11 = post_c + [w0 h0] * rot;
                    x12 = post_c + [-w0 h0] * rot;
                    x21 = post_c + [w0 -h0] * rot;
                    x22 = post_c + [-w0 -h0] * rot;
                    post_box = [x11; x12; x22; x21; x11];
                    % Draw
                    set(cam.p_post{i}, 'XData', post_box(:,1), 'YData', post_box(:,2));
                end
            end
            
            if isfield(metadata, 'obstacles')
                obstacles = metadata.obstacles;
                for i=1:min(2, numel(obstacles.iv))
                    obs_c = obstacles.iv{i};
                    wo = obstacles.axisMajor(i)/2;
                    ho = obstacles.axisMinor(i)/2;
                    obs_o = obstacles.orientation(i);
                    
                    obs_rot = [cos(obs_o) sin(obs_o); -sin(obs_o) cos(obs_o)]';%'
                    x11 = obs_c + [wo ho] * obs_rot;
                    x12 = obs_c + [-wo ho] * obs_rot;
                    x21 = obs_c + [wo -ho] * obs_rot;
                    x22 = obs_c + [-wo -ho] * obs_rot;
                    obs_box = [x11; x12; x22; x21; x11];
                    
                    set(cam.h_obstacle{i}, 'XData', obs_box(:,1), 'YData', obs_box(:,2));
                end
            end
            
            if isfield(metadata, 'line')
                %metadata.line
                for i=1:numel(metadata.line)
                    endpoint = metadata.line{i}.epA + 0.5;
                    %[endpoint(1), endpoint(2)]
                    %cam.h_line{i}
                    %numel(cam.h_line)
                    %numel(metadata.line.endpoint)
                    set(cam.h_line{i},'Xdata', [endpoint(1), endpoint(2)]);
                    set(cam.h_line{i},'Ydata', [endpoint(3), endpoint(4)]);
                end
                
            end
            
        elseif strcmp(msg_id,'world')
            if isfield(metadata, 'world')
                % msg_struct, vision_struct, scale, drawlevel, name
                drawlevel = 1;
                name = 'alvin';
                
                set(gcf,'CurrentAxes',cam.f_field);
                plot_robot(gca,metadata.world, [], 1.5, drawlevel, name);
                hold on;
                if isfield(metadata.world,'traj')
                    num=metadata.world.traj.num;
                    if num>0
                        trajx = metadata.world.traj.x;
                        trajy = metadata.world.traj.y;
                        plot(trajx(1:num),trajy(1:num),'r');
                        
                        kickneeded = metadata.world.traj.kickneeded;
                        goal1 = metadata.world.traj.goal1;
                        goal2 = metadata.world.traj.goal2;
                        ballglobal = metadata.world.traj.ballglobal;
                        ballglobal2 = metadata.world.traj.ballglobal2;
                        ballglobal3 = metadata.world.traj.ballglobal3;
                        
                        plot([ballglobal(1) ballglobal2(1) ballglobal3(1)],...
                            [ballglobal(2) ballglobal2(2) ballglobal3(2)],...
                            'b','LineWidth',2);
                        
                        plot([ballglobal2(1) goal1(1)],[ballglobal2(2) goal1(2)],'k--');
                        plot([ballglobal2(1) goal2(1)],[ballglobal2(2) goal2(2)],'k--');
                    end
                end
                
                if isfield(metadata.world,'line')
                    line = metadata.world.line;
                    if( line.detect==1 )
                        %nLines=line.nLines;
                        for i=1:numel(line.v1)
                            v1=line.v1{i};
                            v2=line.v2{i};
                            plot(-[v1(2) v2(2)],[v1(1) v2(1)],'k','LineWidth',2);
                        end
                    end
                end
                
                hold off;
                
                % Show messages
                set(cam.w_debug, 'String', char(metadata.world.info));
                needs_draw = 1;
            end
            
        elseif strcmp(msg_id,'head_camera')
            
            %disp(metadata);
            compression = char(metadata.c);
            if strcmp(compression, 'jpeg')
                % Assume always JPEG
                cam.yuyv = djpeg(raw);
                [nc, nr] = size(cam.yuyv);
                yuyv_scaled = imresize(cam.yuyv, [nr, nc]);
                set(cam.im_yuyv,'Cdata', yuyv_scaled);
                % Set limits always, should not cost much CPU
                xlim(cam.f_yuyv,[0 nc]);
                ylim(cam.f_yuyv,[0 nr]);
            elseif strcmp(compression, 'yuyv')
                nr = metadata.w;
                nc = metadata.h;
                [ycbcr, rgb] = yuyv2rgb(typecast(raw,'uint32'));
                rgb = reshape(rgb, [metadata.w / 2, metadata.h, 3]);
                rgb = permute(rgb,[2,1,3]);
                cam.yuyv = rgb;
                yuyv_scaled = imresize(cam.yuyv, [nr nc]);
                set(cam.im_yuyv,'Cdata', yuyv_scaled);
                xlim(cam.f_yuyv,[0 nc]);
                ylim(cam.f_yuyv,[0 nr]);
            end
            needs_draw = 1;
        elseif strcmp(msg_id,'labelA')
            cam.labelA = reshape(zlibUncompress(raw),[metadata.w,metadata.h])';
            set(cam.im_lA, 'Cdata', cam.labelA);
            xlim(cam.f_lA, [0 metadata.w]);
            ylim(cam.f_lA, [0 metadata.h]);
            needs_draw = 1;
        elseif strcmp(msg_id,'labelB')
            cam.labelB = reshape(zlibUncompress(raw),[metadata.w,metadata.h])';
            set(cam.im_lB,'Cdata', cam.labelB);
            xlim(cam.f_lB,[0 metadata.w]);
            ylim(cam.f_lB,[0 metadata.h]);
            needs_draw = 1;
        end
    end
end
