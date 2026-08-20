clear all
% Given Conditions

global A_A A_B p1 p3 F %#ok<*GVMIS>
A_A = 3;
A_B = 1;
p1  = 28;
p3  = 0;
F   = 5;
% Initial Guesses

global u_Ai u_Bi P_2i
u_Ai = 5/3;
u_Bi = 5;
P_2i = 25;
%% Relaxation Searches

N=50;
iter = 1:N;
a_range = 0:0.1:1;
a_u_R_array = nan([length(a_range),N]);
a_p_R_array = nan([length(a_range),N]);
for i = 1:length(a_range)
    [~,~,~,~,a_u_R_array(i,:)] = main(N,1,a_range(i));
    [~,~,~,~,a_p_R_array(i,:)] = main(N,a_range(i),1);
end
writematrix(a_u_R_array,"Search.xlsx","Sheet","Velocity");
writematrix(a_p_R_array,"Search.xlsx","Sheet","Pressure");

%%
figure(Theme="light",Position=[0 0 600 400]);
subplot(2,1,1)
title("Residuals from Relaxation Parameters")
plot(iter,a_u_R_array);
ylabel("|R|")
xlabel("Iteration")
legend("\alpha_u = "+a_range')
subplot(2,1,2)
dR = diff(a_u_R_array(:,2:end),1,2);
plot(iter(2:end-1),dR)
title("Change of Residuals over ")
ylabel("\partial|R|/\partiali")
xlabel("Iteration")
saveas(gcf,"./Figures/Residual_Derivative.jpg")
%%
figure(Theme="light",Position=[0 0 600 200]);
subplot(1,2,1)
title("Velocity Relaxation Range")
dR_ave = mean(diff(a_u_R_array(:,2:end),1,2),2);
plot(a_range,dR_ave)
ylabel("(\partial|R|/\partiali)_{ave}")
xlabel("\alpha_u")
subplot(1,2,2)
title("Pressure Relaxation Range")
dR_ave = mean(diff(a_p_R_array(:,2:end),1,2),2);
plot(a_range,dR_ave)
ylabel("(\partial|R|/\partiali)_{ave}")
xlabel("\alpha_P")
saveas(gcf,"./Figures/Relaxation_Range.jpg")
%%
%Velocity relaxation factor
alpha_u = [0.1, 0.5, 1];
%Pressure relaxation factor
alpha_P = 1;

iter = 1:N;
for a_u = alpha_u
    [u_A,u_B,p_2,P_2,R] = main(N,alpha_P,a_u);
    figure(Theme="light",Position=[0 0 400 300]);
    subplot(2,1,1)
    hold on
    title("\alpha_u = "+a_u+"   \alpha_p = "+alpha_P)
    plot(iter,u_A,'DisplayName',"u_A")
    plot(iter,u_B,'DisplayName',"u_B")
    ylabel("Velocity")
    xlabel("Iteration Number")
    legend()
    xlim([1,N])
    hold off
    subplot(2,1,2)
    semilogy(iter,R)
    ylabel("Absolute Residual")
    xlabel("Iteration Number")
    xlim([1,N])
    % fprintf("p_2 = %0.2f\nu_A = %0.2f\nu_B = %0.2f",P_2(end),u_A(end),u_B(end));
    saveas(gcf,"./Figures/Relaxation_Search_"+a_u+".jpg")
end
%%
N = 50;

alpha_u = 0.4;
alpha_P = 1 - (2*alpha_u - alpha_u^2);

[u_A,u_B,p_2,P_2,R] = main(N,alpha_P,alpha_u);

iter = 1:N;

figure(Theme="light",Position=[0 0 800 600]);
sgtitle("\alpha_u = "+alpha_u+"   \alpha_p = "+alpha_P)

subplot(2,2,1)
hold on
plot(iter,u_A,'DisplayName',"u_A")
plot(iter,u_B,'DisplayName',"u_B")
ylabel("Velocity")
xlabel("Iteration Number")
legend()
xlim([1,N])
hold off

subplot(2,2,4)
plot(iter,p_2)
ylabel("p_2'")
xlabel("Iteration Number")
xlim([1,N])

subplot(2,2,2)
plot(iter,P_2)
ylabel("P_2")
xlabel("Iteration Number")
xlim([1,N])

subplot(2,2,3)
semilogy(iter,R)
ylabel("Absolute Residual")
xlabel("Iteration Number")
xlim([1,N])
saveas(gcf,"./Figures/Converging_Values.jpg")
%%
function [u_A,u_B,p_2,P_2,R] = main(N,alpha_P,alpha_u)
arguments
    N %Number of Iterations
    alpha_P %Pressure Relaxation Parameter
    alpha_u %Velocity Relaxation Parameter
    % F %Flow Rate
    % u_Ai %Point A Velocity Initial Guess
    % u_Bi %Point B Velocity Initial Guess
    % P_2i %Zone 2 Pressure Initial Guess
end
iter = 1:N;

u_A = zeros([N,1]);
u_B = zeros([N,1]);
P_2 = zeros([N,1]);
p_2 = zeros([N,1]);
R   = zeros([N,1]);

% Initial Guesses
global u_Ai u_Bi P_2i F
u_A(1) = u_Ai;
u_B(1) = u_Bi;
P_2(1) = P_2i;
R(1)   = nan;

for i=iter(1:end-1)
    [u_A(i+1),u_B(i+1),p_2(i+1),P_2(i+1),R(i+1)] = Molecule(P_2(i),u_A(i),u_B(i),alpha_P,alpha_u);
    if R(i+1) > 100
        table(u_A,u_B,p_2,P_2,R)
        error("Iteration "+i+": Residual Too Large")
        return
    end
end

Results = table(F*ones([N,1]),u_A,u_B,p_2,P_2,R);
Results = renamevars(round(Results,4), "Var1", "F");
writetable(Results,"Results.xlsx","Sheet",sprintf("alpha_u = %0.2f, alpha_p = %0.2f",alpha_u,alpha_P));
end

function [uA,uB,p2p,p2,R] = Molecule(pd2,udA,udB,alpha_P,alpha_u)
global A_A A_B p1 p3 F

% Pressure correction is determined by setting continuity at internal nodes
% $${p_2 }^{\prime } =\frac{F\left(A_A u_A^* -A_B u_B^* \right)}{A_A^2 +A_B^2}$$
p2p = F*(A_A*udA - A_B*udB)/(A_A^2 + A_B^2);

% Update pressure 
% $$p_2 =p_2^* +{p_2 }^{\prime }$$
p2 = pd2 + alpha_P*p2p;

% $$u_A^{\prime } =\frac{A_A }{F_A }\left(p_1^{\prime } -p_2^{\prime } \right)$$
uAp = A_A/F*(p1 - p2);

% $$u_B^{\prime } =\frac{A_B }{F_B }\left(p_2^{\prime } -p_3^{\prime } \right)+u_A^{\prime}$$
uBp = A_B/F*(p2 - p3) + uAp;

% Update Velocities using under-relaxation
uA = (1 - alpha_u)*udA + alpha_u*uAp;
uB = (1 - alpha_u)*udB + alpha_u*uBp;
 
% Update flow rates  
% $$F_A =A_A^2 \frac{p_1 -p_2^* }{F}$$
F_A = A_A^2*(p1 - pd2)/F;

% $$F_B =A_B u_A^* +A_B^2 \frac{\left(p_2^* -p_3 \right)}{F}$$
F_B = A_B*udA + A_B^2*(pd2 - p3)/F;

% Show that continuity is satisfied by residual approaching zero 
R = abs(F_A - F_B);
end