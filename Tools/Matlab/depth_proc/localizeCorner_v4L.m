function pose = localizeCorner_v4L(Planes,metad,reset)

persistent p1
persistent p2
persistent a1
persistent b1
persistent a1_orth
persistent a2
persistent b2
persistent theta_x
persistent meas_x
persistent meas_y
persistent theta_head
persistent theta_body
persistent inters
persistent orig
persistent prev_odo
persistent Fx  % filter for x location (distance)
persistent Fy  % filter for y location (distance)

vis=1;
visinit = 0;
MAX_DIST = 2.0; % meter
MIN_SIZE = 3000;

odoflag = 0;
if isfield(metad,'tfG16')
    odoflag = 1;
    if 1 %numel(metad.tfG16) > 1
        T = reshape(metad.tfL16{2},4,4)';
        metad.head_angles = zeros(1,2);
    %else
    %    T = reshape(metad.tfG16,4,4)';
    end
    elr = dcm2eulr(T(1:3,1:3));    
    metad.odom = [T(1,4) T(2,4) elr(3)];
end
          
if isempty(p1) || (nargin == 3 && reset == 1)
    p1.init = false;     p1.sign = 0;     
    p2.init = false;     p2.sign = 0;    
    a1 = [0;0]; b1 = 0;
    a1_orth = [0;0];
    a2 = [0;0]; b2 = 0;
    theta_x = 0;
    inters = [0 0]';
    if odoflag
        prev_odo = metad.odom;
        orig = prev_odo;
        Fx = BayesianFilter1D; %Fx = Fx.initialize(0, 4);
        Fy = BayesianFilter1D; %Fy = Fy.initialize(0, 4);
    end
    visinit = 1;
    meas_x = 0;
    meas_y = 0;
    theta_head = 0;
    theta_body = 0;
end

pose = struct('x',0,'y',0,'isValid1',p1.init,'isValid2',p2.init,...
              'theta_body',theta_body,'theta_head',theta_head);
% no plane observed yet
if p1.init == false
    
    if ~isempty(Planes) % first observation        
       ref_ = 0; 
       d1 = abs(Planes{1}.Normal'*Planes{1}.Center);
       if d1 < MAX_DIST &&  abs(Planes{1}.Normal(3)) < 0.1 % set maximum distance 
            ref_ = 1;
       end
       
       if numel(Planes) > 1  % two planes if lucky 
           
           d2 = abs(Planes{2}.Normal'*Planes{2}.Center);
           if d2 > MAX_DIST || abs(Planes{2}.Normal(3)) > 0.1
               Planes{2} = [];
           elseif ref_ == 0 
                ref_ = 2;
           else
               % If they look too similar, choose one
               if abs(Planes{1}.Normal'*Planes{2}.Normal) > 0.9
                if (abs(Planes{1}.Normal'*Planes{1}.Center) > abs(Planes{2}.Normal'*Planes{2}.Center))
                    ref_ = 2;
                else
                    Planes{2} = [];
                end
               end
           end
       end       
        
        if ref_ > 0
            % the largest plane normal becomes the x 
            p1.init = true;
            % Let the normal of this plane be the x-axis
            theta_x = atan2(Planes{ref_}.Normal(2),Planes{ref_}.Normal(1));  
            a1 = Planes{ref_}.Normal(1:2); a1 = a1/norm(a1);
            a1_orth = Rot2d(pi/2)*a1; 
            p1.sign = 1;% sign(theta_x); 
            b1 = Planes{ref_}.Normal'*Planes{ref_}.Center;
            meas_x = -b1;
            pose.x = -b1;
             if odoflag
                Fx = Fx.initialize(pose.x, 1);
             end
            % Compute "theta"s here 
            theta_body = theta_x
            theta_head = theta_body - metad.head_angles(1)
            inters = -Rot2d(theta_x)*[ pose.x; 0];

             if numel(Planes) > 1 && ~isempty(Planes{2}) && (ref_+1 < 3)
                 
                 

                p2.init = true;
                p2.sign = sign(Planes{1}.Normal(1).*Planes{2}.Normal(2) - Planes{1}.Normal(2).*Planes{2}.Normal(1)) ;
                a2 = Planes{2}.Normal(1:2); a2 = a2/norm(a2);
                b2 = Planes{2}.Normal'*Planes{2}.Center;
                pose.y = -b2;
                meas_y = -b2;
                 if odoflag
                     Fy = Fy.initialize(pose.y, 1);
                 end

                % compute intersect point
                inters = [a1'; a2']\[b1; b2];
             end
        end
     
    end
    
else % p1 initialized 
    
    update_p1 = 0;    
    update_p2 = 0;
    cr = [];
    
    if odoflag  
    
        % consider yaw
        % u = [metad.odom(1:2) metad.imu_rpy(3)]  - prev_odo;
        u = metad.odom  - prev_odo;
        dl = norm(u(1:2));
        ang = theta_body;

        % update according to motion
        ux = cos(theta_x)*dl;

        [Fx, x, ~] = Fx.propagate(ux); 
        pose.x = x;
       
        if p2.init == true
            uy = sin(theta_x)*dl;
            [Fy, y, ~] = Fy.propagate(uy);
            pose.y = y;
        end
    end
    
    % if new measurements available, identify them first 
    if ~isempty(Planes)         
        
        d1 = abs(Planes{1}.Normal'*Planes{1}.Center);
        if d1  < MAX_DIST && abs(Planes{1}.Normal(3)) < 0.1% set maximum distance 
            % is the first plane p1 or not? 
            n1_ = Planes{1}.Normal(1:2); n1_ = n1_/norm(n1_);
            cr(1) = cos(ang)*n1_(2) - sin(ang)*n1_(1);
            if abs(cr(1)) > 0.9 % cross product with x-axis_wall large           
               update_p2 = 1;   % the second plane 
            else 
               update_p1 = 1;
            end  
        end
                    
        
        % if another measurement available, identify it too 
        if numel(Planes) > 1 
                                 
            d2 = abs(Planes{2}.Normal'*Planes{2}.Center);
            if d2  < MAX_DIST &&  abs(Planes{2}.Normal(3)) < 0.1 % set maximum distance 
                
                % is this p1 or not?             
                n2_ = Planes{2}.Normal(1:2); n2_ = n2_/norm(n2_);
                cr(2) =  cos(ang)*n2_(2) - sin(ang)*n2_(1);
                if abs(cr(2)) > 0.9
                   update_p2 = 2;
                else
                   update_p1 = 2;
                end     
            end
        end
        
    end
    
    % update the filter   
    if update_p1 > 0
        x_meas = -Planes{update_p1}.Normal'*Planes{update_p1}.Center;
        if odoflag
            meas.value = x_meas;
            meas.param = 0;
            [Fx, x, Px] = Fx.update(meas); 
            pose.x = x;
        else
            pose.x = x_meas;
        end
        meas_x = x_meas;
        theta_body = atan2(Planes{update_p1}.Normal(2), Planes{update_p1}.Normal(1)) 
        theta_head = theta_body - metad.head_angles(1) 

    end
    
     if update_p2 > 0
         
        if p2.init == false 
            if Planes{update_p2}.Size > MIN_SIZE % if first time the plane #2 is observed 
                p2.init = true;
                p2.sign = sign(cr(update_p2)); 
                a2 = Planes{update_p2}.Normal(1:2); a2 = a2/norm(a2);
                b2 = Planes{update_p2}.Normal'*Planes{update_p2}.Center;
                pose.y = -b2;
                if odoflag
                    Fy = Fy.initialize(pose.y, 1);
                end
                 % compute intersect point            
                inters = [a1'; a2']\[b1; b2];
                meas_y = pose.y;
            end
        else
            % update the filter 
            y_meas = -Planes{update_p2}.Normal'*Planes{update_p2}.Center;
            if odoflag
                meas.value = y_meas;
                meas.param = 0;
                [Fy, y, Py] = Fy.update(meas);    
                pose.y = y;
            else
                pose.y = y_meas;
            end
            meas_y = y_meas;     
            
            if update_p1 == 0
                 theta_body = atan2(Planes{update_p2}.Normal(2), Planes{update_p2}.Normal(1)) - p2.sign*pi/2
                 theta_head = theta_body - metad.head_angles(1) 
            end
        end       
     end    
end

if theta_body < -pi
    theta_body = 2*pi + thetabody;
end

if theta_head < -pi
    theta_head = 2*pi + thetabody;
end

pose.isValid1 = p1.init;
pose.isValid2 = p2.init;
pose.theta_body = -theta_body;
pose.theta_head = -theta_head;

 if odoflag
   % prev_odo = [metad.odom(1:2) metad.imu_rpy(3)];
    prev_odo = metad.odom;
 end

if vis && pose.isValid1

    if 1 % visinit == 1
        figure(13), subplot(1,2,2);  
        hold off; 
      

        if p1.init == true              
            if abs(a1(2)) > abs(a1(1))
                px = [-0.5; 2];
                py =  (b1 - a1(1)*px)/a1(2) ;
            else
                py = [-2; 2];
                px =  (b1 - a1(2)*py)/a1(1) ;
            end        
            plot(py,px,'Color',[0.7 1 0.7], 'LineWidth',4);    hold on;   
            text(double(-sign(a1(2))*1), double(1.5),'Wall 1');
        end

        if p2.init == true
            if abs(a2(2)) > abs(a2(1))
                px = [-0.5; 2];
                py =  (b2- a2(1)*px)/a2(2) ;
            else
                py = [-2; 2];
                px =  (b2 - a2(2)*py)/a2(1) ;
            end    
            plot(py,px,'Color',[0.7 0.7 1], 'LineWidth',4);
            text(double(-sign(a2(2))*1), double(1.5),'Wall 2');
            plot(inters(2), inters(1),'ko','MarkerSize',7,'MarkerFaceColor','k');
        end        
        
        plot(0,0,'k+');axis equal;  
        axis([-2 2 -0.5 2]);  
        set(gca,'XDir','reverse');
        set(gca,'XTick',[],'YTick',[]);
        % xlabel('y_b_0');
        % ylabel('x_b_0');
    end
    
    
    del_odo = metad.odom-orig;
    v_odo = Rot2d(metad.odom(3)-orig(3))*[0.25; 0];
    plot(del_odo(2), del_odo(1), '.','Color',0.5*ones(1,3));
    plot([del_odo(2) del_odo(2)+v_odo(2)], [del_odo(1) del_odo(1)+v_odo(1)], '-','Color',0.5*ones(1,3),'LineWidth',2); 
    
    curpos = Rot2d(theta_x)*[ pose.x;p2.sign*pose.y] + inters;   
    curmeas = Rot2d(theta_x)*[ meas_x;p2.sign*meas_y] + inters;
  
    v_head1 = Rot2d(-theta_head+theta_x+pi/6)*[1; 0] ;
    v_head2 = Rot2d(-theta_head+theta_x-pi/6)*[1; 0] ;
    v_body = Rot2d(-theta_body+theta_x)*[0.25; 0] ;
    plot(curpos(2), curpos(1), 'bo');  
    plot(curmeas(2), curmeas(1), 'r.');       
    plot([curpos(2) curpos(2)+v_head1(2)], [curpos(1) curpos(1)+v_head1(1)], 'b:');      
    plot([curpos(2) curpos(2)+v_head2(2)], [curpos(1) curpos(1)+v_head2(1)], 'b:');    
    plot([curpos(2) curpos(2)+v_body(2)], [curpos(1) curpos(1)+v_body(1)], 'k-','LineWidth',2);   
    
    w1_ = b1*a1;           
    plot([curpos(2) curpos(2)+w1_(2)], [curpos(1) curpos(1)+w1_(1)], '-','Color',[0.7 1 0.7]);  
    
    text(double(curpos(2)+0.5*w1_(2)), double(curpos(1)+0.5*w1_(1)),sprintf('%0.2f',pose.x));
    if p2.init
        w2_ = b2*a2;   
        plot([curpos(2) curpos(2)+w2_(2)], [curpos(1) curpos(1)+w2_(1)], '-','Color',[0.7 0.7 1]);  
        text(double(curpos(2)+0.5*w2_(2)), double(curpos(1)+0.5*w2_(1)),sprintf('%0.2f',pose.y));
    end
end
   
end
            