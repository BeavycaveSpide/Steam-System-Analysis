%% order of magnitude Analysis

T = 180;
P = 2.5;


h_25bar = PropsSI('H', 'P', P * 1e5, 'T', T+273.15, 'Water');
s_25bar = PropsSI('S', 'P', P * 1e5, 'T', T+273.15, 'Water');
h_pd = h_25bar - (h_25bar *0.01); 
P_drop = PropsSI('P','H', h_pd, 'S', s_25bar,  'Water');
T_drop = PropsSI('T','H', h_pd, 'S', s_25bar,  'Water') + 273.15;
h_1 = (h_25bar *0.01);
v_min = sqrt(2*(h_1));
z_min = (h_1)/9.81;
Q_min = h_25bar - h_pd;


fprintf('Kinetic energy due to velocity %.4f m/s\n', v_min);
fprintf('Potential energy from a change in heigth of %.4f m\n', z_min);
fprintf('The dropped pressure is: %.4f bar\n', P-P_drop / 1e5);
fprintf('The dropped temperature is: %.4f bar\n', T-T_drop / 1e5);
fprintf('Heat loss equal to 1 percent of the enthalpy: %.4f Kj\n', Q_min);