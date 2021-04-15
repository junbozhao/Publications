% This class defines the model of 8-th order synchronous machine

% Author(s): Yue Zhu
% Reference Book: Power System Dynamic and Stability, P54

%% Class

classdef SynchronousMachineFull_SMAVRGOV < SimplexPS.Class.ModelAdvance
    
    properties(Access = protected)
        psi_f;
        ws;
        L;
        Va0;
        Vpid0;
    end
    
    methods
        % constructor
        function obj = SynchronousMachineFull_SMAVRGOV(varargin)
            % Support name-value pair arguments when constructing object
            setProperties(obj,nargin,varargin{:});
        end
    end
    
    methods(Static)
        %% signal list
        
        function [State,Input,Output] = SignalList(obj)
                 % Vx1 and Vx2 are two middle states for PID.
          State = {'i_d', 'i_q', 'w', 'theta','Ed1','Eq1','Psi1d','Psi2q',...
              'Efd','Vr','Rf','Va','Vx1','Vx2','G2', 'G3', 'T_m'};
          Input	 = {'v_d','v_q','Tref','Vref','Vss'};
          Output = {'i_d','i_q','w','theta'};
        end
        %% Equilibrium point
        function [x_e,u_e,xi] = Equilibrium(obj)
            % Get the power PowerFlow values
            P 	= obj.PowerFlow(1);
            Q	= obj.PowerFlow(2);
            V	= obj.PowerFlow(3);
            xi	= obj.PowerFlow(4);
            w   = obj.PowerFlow(5);            
            % Get parameters
            % Synchronous machine
            X=obj.Para(1);
            R=obj.Para(2);
            Xd=obj.Para(3); %synchronous reactance in d axis
            Xd1=obj.Para(4); %transient reactance
            Xd2=obj.Para(5); %subtransient reactance
            Td1=obj.Para(6); %d-axis open circuit transient time constant
            Td2=obj.Para(7); %d-axis open circuit sub-transient time constant
            Xq=obj.Para(8);
            Xq1=obj.Para(9);
            Xq2=obj.Para(10);
            Tq1=obj.Para(11);
            Tq2=obj.Para(12);
            H=obj.Para(13);
            D=obj.Para(14);
            %Exciter DC4B
            TR=obj.Para(15);
            KA=obj.Para(16);
            TA=obj.Para(17);
            VRmax=obj.Para(18);
            VRmin=obj.Para(19);
            KE=obj.Para(20);
            TE=obj.Para(21);
            E1=obj.Para(22);
            SE1=obj.Para(23);
            E2=obj.Para(24);
            SE2=obj.Para(25);
            KF=obj.Para(26);
            TF=obj.Para(27);
            KP=obj.Para(28);
            KI=obj.Para(29);
            KD=obj.Para(30);
            TD=obj.Para(31);
            Bex=log(SE1/SE2)/(E1-E2);
            Aex=SE1*exp(-Bex*E1);
            Rgov = obj.Para(42);
            T1gov = obj.Para(43);
            T2gov = obj.Para(44);
            T3gov = obj.Para(45);
            Dtgov = obj.Para(46);
 
            % Calculate Equilibriums
            i_DQ = (conj(P+1j*Q)/V);
            Eint = V- i_DQ*(R+1j*Xq); %internal voltage
            sigma = angle(Eint);           
            i_dq = i_DQ * exp(1j*(-sigma+pi/2));
            i_d = real(i_dq);
            i_q = imag(i_dq);
            v_dq = V * exp(1j*(-sigma+pi/2));
            v_d = real(v_dq);
            v_q = imag(v_dq);           
            Efd = abs(Eint)+(Xq-Xd)*i_d;
            Eq1 = Efd+(Xd-Xd1)*i_d;           
            Ed1 = -(Xq-Xq1)*i_q;
            Psi1d=Eq1+(Xd1-X)*i_d;
            Psi2q=-Ed1+(Xq1-X)*i_q;
            obj.ws = w; % record synchronous rotor speed.
            obj.L = X/w; % record inductor value
           
            Psi_q = R*i_d-v_d;
            Psi_d = -R*i_q+v_q;            
            T_e = Psi_d*i_q-Psi_q*i_d;%Psi_q*i_d-Psi_d*i_q;
            T_m = T_e;
            
            Vss=0;
            Vt=abs(v_d+1j*v_q);
            Vref=Vt;
            Vr = Vt;
            Va=KE*Efd+Efd*Aex*exp(Bex*Efd);  % not 0
            if Va>=Vt*VRmax
                Va = Vt*VRmax;
            elseif Va<= Vt*VRmin
                Va = Vt*VRmin;
            end  
            Rf=-KF/TF*Efd;  % not 0
            Vf=Rf+KF/TF*Efd; %=0
            Vx=Vss+Vref-Vr-Vf; %=0
            Vx2=-KD/TD*Vx; %=0
            Vpid=Va/KA; % not 0
            if Vpid>=VRmax
                Vpid = VRmax;
            elseif Vpid<= VRmin
                Vpid = VRmin;
            end            
            Vx1=Vpid-Vx2-Vx*(KP+KD/TD); % not 0
            obj.Vpid0=Vpid; % save the steady value for later saturation.
            obj.Va0=Va;
            
            G3=T_m;
            G2=G3;
            G1=G2;
            Tref=G1*Rgov;
            
            xi = xi+sigma-pi/2;
            theta = xi;
                
            % Get equilibrium
            x_e = [i_d; i_q; w; theta; Ed1; Eq1; Psi1d; Psi2q; Efd; Vr; Rf; Va; Vx1; Vx2;...
                G2; G3; T_m];
            u_e = [v_d; v_q; Tref; Vref; Vss];
            % Get equilibrium
            xi  = [xi];    %output of this function.
         
        end
        
        %% State-space
        function [Output] = StateSpaceEqu(obj,x,u,CallFlag)
                        % Get parameters
            L=obj.L;
            ws=obj.ws;
            X=obj.Para(1);
            R=obj.Para(2);
            Xd=obj.Para(3); %synchronous reactance in d axis
            Xd1=obj.Para(4); %transient reactance
            Xd2=obj.Para(5); %subtransient reactance
            Td1=obj.Para(6); %d-axis open circuit transient time constant
            Td2=obj.Para(7); %d-axis open circuit sub-transient time constant
            Xq=obj.Para(8);
            Xq1=obj.Para(9);
            Xq2=obj.Para(10);
            Tq1=obj.Para(11);
            Tq2=obj.Para(12);
            H=obj.Para(13);
            D=obj.Para(14);
            %Exciter DC4B
            TR=obj.Para(15);
            KA=obj.Para(16);
            TA=obj.Para(17);
            VRmax=obj.Para(18);
            VRmin=obj.Para(19);
            KE=obj.Para(20);
            TE=obj.Para(21);
            E1=obj.Para(22);
            SE1=obj.Para(23);
            E2=obj.Para(24);
            SE2=obj.Para(25);
            KF=obj.Para(26);
            TF=obj.Para(27);
            KP=obj.Para(28);
            KI=obj.Para(29);
            KD=obj.Para(30);
            TD=obj.Para(31);
            Bex=log(SE1/SE2)/(E1-E2);
            Aex=SE1*exp(-Bex*E1);
            Rgov = obj.Para(42);
            T1gov = obj.Para(43);
            T2gov = obj.Para(44);
            T3gov = obj.Para(45);
            Dtgov = obj.Para(46);
            
                i_d = x(1);
                i_q = x(2);
                w = x(3);
                theta = x(4);
                Ed1 = x(5);
                Eq1 = x(6);
                Psi1d = x(7);
                Psi2q = x(8);
                Efd = x(9);
                Vr = x(10);
                Rf = x(11);
                Va = x(12);
                Vx1= x(13);
                Vx2=x(14);
                G2=x(15);
                G3=x(16);
                T_m=x(17);
                
                v_d  = u(1);
                v_q  = u(2);
                Tref  = u(3);
                Vref  = u(4);
                Vss = u(5);
          
            % State space equations
          	% dx/dt = f(x,u)
            % y     = g(x,u)

            if CallFlag == 1        
            % ### Call state equation: dx/dt = f(x,u)
                % Auxiliary equations
                Psi_d = Xd2*i_d+(Xd2-X)/(Xd1-X)*Eq1 + (Xd1-Xd2)/(Xd1-X)*Psi1d; %book 
                Psi_q = Xq2*i_q-(Xq2-X)/(Xq1-X)*Ed1 + (Xq1-Xq2)/(Xq1-X)*Psi2q;
                ws=obj.ws;
                T_e = Psi_d*i_q-Psi_q*i_d;%T_e = (Psi_q*i_d-Psi_d*i_q);
                % State equations
                dtheta = w;
                dw     = ws*(T_e - T_m - (D/ws)*(w-ws))/(2*H);
                dEd1 = (-Ed1+(Xq-Xq1)*(-i_q+(Xq1-Xq2)/(Xq1-X)^2*(-Psi2q+(Xq1-X)*i_q-Ed1)))/Tq1;
                dEq1 = (Efd-Eq1+(Xd-Xd1)*(i_d+(Xd1-Xd2)/(Xd1-X)^2*(Psi1d-(Xd1-X)*i_d-Eq1)))/Td1;                 
                dPsi1d = (-Psi1d+Eq1+(Xd1-X)*i_d)/Td2;
                dPsi2q = (-Psi2q-Ed1+(Xq1-X)*i_q)/Tq2;
                di_d = (ws*(v_d-R*i_d+w/ws*Psi_q)-(Xd2-X)/(Xd1-X)*dEq1-(Xd1-Xd2)/(Xd1-X)*dPsi1d)/Xd2; 
                di_q = (ws*(v_q-R*i_q-w/ws*Psi_d)+(Xq2-X)/(Xq1-X)*dEd1-(Xq1-Xq2)/(Xq1-X)*dPsi2q)/Xq2;
                
                % Exciter state equations
                Vf=Rf+KF/TF*Efd;
                Vx=Vss+Vref-Vr-Vf;
                Vpid=Vx1+Vx2+(KP+KD/TD)*Vx;
                Vt=abs(v_d+1j*v_q);
                if Va>=Vt*VRmax
                    Va = Vt*VRmax;
                elseif Va<=Vt*VRmin
                    Va = Vt*VRmin;
                end
                if Vpid>=VRmax
                    Vpid = VRmax;
                elseif Vpid<=VRmin
                    Vpid = VRmin;
                end               
                dEfd = (Va-(KE*Efd+Efd*Aex*exp(Bex*Efd)))/TE;
                dVr  = (Vt-Vr)/TR;
                dRf  = (-Rf-KF/TF*Efd)/TF;
                dVa  = (-Va+KA*Vpid)/TA;
                dVx1 = KI*Vx;
                dVx2 = (-Vx2-KD/TD*Vx)/TD;
                Delta_w = -(w - ws);
                G1 = (Tref-Delta_w)/Rgov;
                dG2 = (G1-G2)/T1gov;
                dG3=(G2+T2gov*dG2-G3)/T3gov;
                dT_m=(dG3-(-dw*Dtgov));
                
                f_xu = [di_d; di_q; dw; dtheta; dEd1; dEq1; dPsi1d; dPsi2q; ...
                    dEfd; dVr; dRf; dVa; dVx1; dVx2; dG2; dG3; dT_m];
                Output = f_xu;
            elseif CallFlag == 2    
            % ### Call output equation: y = g(x,u)
                %i_ex = 0;
                g_xu = [i_d; i_q; w; theta];
                Output = g_xu;
            end
        end
        
    end

end     % End class definition