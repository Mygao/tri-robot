% by Bhoram Lee
% Mar 2015
classdef PLANE
    
    % a'x+b=0  (projected line equation)
    properties
        id 
        a   
        b
        e1, e2 % end points
        pair % corner pair infomation
    end
    
    methods
        function p = initialize(p, plane, id_)
            p.id = id_;
            a = plane.Normal(1:2);
            b = plane.Normal'* plane.Center;
        end
        
        function [fp, x_post, sig_post] = update(fp, meas)           
            meas.value;
            sigy2 = fp.Sig2_y(meas.param);
            sum_sx_sy = (fp.P + sigy2);
            fp.x = (sigy2*fp.x + fp.P*meas.value)/sum_sx_sy;
            fp.P = sigy2*fp.P/sum_sx_sy;

            x_post = fp.x;
            sig_post = sqrt(fp.P);
        end
        
        function [fp, x_prior, sig_prior]= propagate(fp, u)
            sigx2 = 0.01;
            if nargin == 2
                fp.x = fp.x + u;
                sigx2 = fp.Sig2_x(u);
            end
                
            fp.P = fp.P + sigx2;
            x_prior = fp.x;
            sig_prior = sqrt(fp.P);           
        end
    end
    
    methods (Access = private)       
               
        function s = Sig2_y(fp,param)
            % s = (1*param + 0.03)^2; % sig ~ linear     
            s = (0.05)^2; % sig ~ linear     
        end
        
        function s = Sig2_x(pf,param)
            % s = (1*param + 0.01)^2; % sig ~ linear     
            s = (0.05)^2; % sig ~ linear    
        end
        
    end
    
end

