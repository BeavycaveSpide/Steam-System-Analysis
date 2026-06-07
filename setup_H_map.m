%% =========================================================================
%  Generate Thermodynamic Lookup Tables (H_map_data.mat)
%  =========================================================================
clear; clc;

disp('Generating Thermodynamic Lookup Tables using CoolProp...');
disp('This may take a minute depending on grid resolution.');

% --- 1. Define Grid Boundaries ---
% Pressure [bar]: 1 bar to 60 bar
P_vec = linspace(1, 60, 200);    

% Temperature [°C]: 10 °C (ambient/treated water) to 600 °C (superheated steam)
T_vec = linspace(10, 600, 300);  

% Create 2D arrays for the map
[P_grid, T_grid] = ndgrid(P_vec, T_vec);

% Preallocate arrays for Enthalpy and Entropy
H_grid = zeros(size(P_grid));
S_grid = zeros(size(P_grid));

% --- 2. Calculate Properties ---
for i = 1:numel(P_grid)
    % Convert to SI units for standard CoolProp (Pascals and Kelvin)
    P_Pa = P_grid(i) * 1e5;       
    T_K  = T_grid(i) + 273.15;    
    
    try
        % 1st Attempt: Standard Python-to-MATLAB CoolProp syntax
        h_J_kg = py.CoolProp.CoolProp.PropsSI('H', 'P', P_Pa, 'T', T_K, 'Water');
        s_J_kg_K = py.CoolProp.CoolProp.PropsSI('S', 'P', P_Pa, 'T', T_K, 'Water');
        
        H_grid(i) = h_J_kg / 1000; 
        S_grid(i) = s_J_kg_K / 1000;
        
    catch
        try
            % 2nd Attempt: Native MATLAB MEX CoolProp syntax
            h_J_kg = CoolProp.PropsSI('H', 'P', P_Pa, 'T', T_K, 'Water');
            s_J_kg_K = CoolProp.PropsSI('S', 'P', P_Pa, 'T', T_K, 'Water');
            
            H_grid(i) = h_J_kg / 1000; 
            S_grid(i) = s_J_kg_K / 1000;
            
        catch
            % If P and T are not independent (e.g., exactly on the saturation dome),
            % CoolProp throws an error. We assign NaN to prevent crashing.
            H_grid(i) = NaN;
            S_grid(i) = NaN;
        end
    end
end

% --- 3. Create Fast Lookup Functions ---
% griddedInterpolant creates high-speed mathematical functions from the grids
H_map = griddedInterpolant(P_grid, T_grid, H_grid, 'linear', 'none');
S_map = griddedInterpolant(P_grid, T_grid, S_grid, 'linear', 'none');

% --- 4. Save to MAT file ---
save('H_map_data.mat', 'H_map', 'S_map');

disp('Success! H_map_data.mat has been created and saved.');
disp('You can now run your main Exergy Calculations script.');