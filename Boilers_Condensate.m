%% =========================================================================
%  Boiler Analysis
%  =========================================================================
clear; clc; close all;

%% 1. CONFIGURATION & DATA LOADING
filename = 'Cleaned_OneWeekData.csv';
fprintf('Loading data from %s...\n', filename);

% Use preserve rule to read tags exactly as they appear in the CSV
opts = detectImportOptions(filename);
opts.VariableNamingRule = 'preserve'; 
data = readtable(filename, opts);

%% Ambient Conditions
T_amb = 25; % [Celsius]
P_amb = 1; % [Bar]
h_amb = coolprop('H', 'P', P_amb * 1e5, 'T', T_amb + 273.15, 'Water') * 1e-3;
s_amb = coolprop('S', 'P', P_amb * 1e5, 'T', T_amb + 273.15, 'Water') * 1e-3;

% FIX: Extract the raw vector first to create a valid time-series operational mask
Tfw_in_raw = Get(data, 'KW_836TI002_XQ01');
Tfw_in_vec = Tfw_in_raw(:); 

% Create the operational mask & time vectors
active_idx = Tfw_in_vec > 50; 
N = length(Tfw_in_vec);
time_raw = datetime(2026, 5, 25, 8, 1, 0) + minutes(0:N-1)';
time_plot = time_raw(active_idx);

% Calculate the overall mean for reference if needed
Tfw_in = mean(Tfw_in_vec, 'omitnan');



%% Boiler 13 (Steady-State Means)
m_13 = mean(Get(data, 'KW_821FI303_XQ01')) ;
m_13fw = mean(Get(data, 'KW_821FI302_XQ01'));
T_13 = mean(Get(data, 'KW_821T307_XQ01'));
T_13fw = mean(Get(data, 'KW_821TI302_XQ01'));
P_13 = mean(Get(data, 'KW_821PT365'));
P_13drum = mean(Get(data, 'KW_821PISY363_XQ01'));
P13_fw = mean(Get(data, 'KW_836PISA013_XQ01'));
m_13fuel = mean(Get(data, 'KW_963FIQ018_XQ01'));
h13_s = coolprop('H', 'P', P_13 * 1e5, 'T', T_13 + 273.15, 'Water') * 1e-3; % kJ/kg
h13_fw = coolprop('H', 'P', P13_fw * 1e5, 'T', T_13fw + 273.15, 'Water') * 1e-3; % kJ/kg
P_13diff = P_13drum - P_13; 

%% Boiler 14 (Time-Series Vectors & 80% Capacity Window)
m_14_time = Get(data, 'KW_821_14FE_0015') / 3.6;
T_14_time = Get(data, 'KW_821_14TI0015');
P_14_time = Get(data, 'KW_821_14PI0015');
T14_fw_time = Get(data, 'KW_836T008_XQ01'); 
m14_urea_time = Get(data, 'KW_821_14FIT7301') / 3.6; 
m14_fw_time = Get(data, 'KW_836_00FIQ0201') / 3.6;
T14_fweco_time = Get(data, 'KW_836_00TI0201');
T14_fgeco_time = (Get(data, 'KW_821_14TICA1470') + Get(data, 'KW_821_14TICSA0006')) / 2; 
T14_fg_time = Get(data, 'KW_821_14TIC1456'); 
P14_fw_time = Get(data, 'KW_836PISA013_XQ01'); 

% Identify 80% Capacity Window based on raw data indices
max_capacity = max(m_14_time); 
target_flow = 0.65 * max_capacity;
tolerance = 0.02 * max_capacity; 
idx_80 = find(m_14_time >= (target_flow - tolerance) & m_14_time <= (target_flow + tolerance));

if isempty(idx_80)
    error('No data points found at ~80%% capacity. Try widening the tolerance.');
end

% Extract Scalar Variables at exactly 80% Capacity
m_14 = mean(m_14_time(idx_80));
T_14 = mean(T_14_time(idx_80));
P_14 = mean(P_14_time(idx_80));
T14_fw = mean(T14_fw_time(idx_80));
m14_urea = mean(m14_urea_time(idx_80));
m14_fw = mean(m14_fw_time(idx_80));
m14_totfw = m14_urea + m14_fw;
T14_fweco = mean(T14_fweco_time(idx_80));
T14_fgeco = mean(T14_fgeco_time(idx_80));
T14_fg = mean(T14_fg_time(idx_80));
P14_fw = mean(P14_fw_time(idx_80));

% Thermodynamic & Efficiency Calculations at 80% Capacity
h14_fw = coolprop('H', 'P', P14_fw * 1e5, 'T', T14_fweco + 273.15, 'Water') * 1e-3; 
h14_s = coolprop('H', 'P', P_14 * 1e5, 'T', T_14 + 273.15, 'Water') * 1e-3; 
h14_fwpre_eco = coolprop('H', 'P', P14_fw * 1e5, 'T', T14_fw + 273.15, 'Water') * 1e-3; 
s14_fw = coolprop('S', 'P', P14_fw * 1e5, 'T', T14_fweco + 273.15, 'Water') * 1e-3; 
s14_s = coolprop('S', 'P', P_14 * 1e5, 'T', T_14 + 273.15, 'Water') * 1e-3; 

Q_flue = m14_fw * (h14_fw - h14_fwpre_eco); 
m14_flue = Q_flue / (1.08 * ((T14_fg + 273.15) - (T14_fgeco + 273.15)));
X14_fg = m14_flue * 1.08 * ((T14_fgeco + 273.15) - (T_amb + 273.15)) - (T_amb + 273.15) * log((T14_fgeco + 273.15)/(T_amb + 273.15)); 
e14_water = (h14_fw - h_amb) - (T_amb + 273.15) * (s14_fw - s_amb);
e14_steam = (h14_s - h_amb) - (T_amb + 273.15) * (s14_s - s_amb);
k14_eff = 0.9; % Assumed Boiler Efficiency
HHV_wood = 11000; % KJ/kg (HHV value of wood chips)
m14_fuel = (m_14 * (h14_s - h14_fw)) / (k14_eff * HHV_wood);
k14_2eff = (e14_steam * m_14) / (m14_fuel * HHV_wood + e14_water * m14_fw);

%% Graph Boiler 14 Flow & Moving Average
% FIX: Shifted x-axis from plain numbers to actual datetime timeline
figure('Name', 'Boiler 14 Steam Flow Analysis', 'Color', 'w');
hold on;
plot(time_raw, m_14_time, 'Color', [0.7, 0.85, 1], 'LineWidth', 1, 'DisplayName', 'Steam Flow');

% Calculate and overlay moving average on the matching full timeline
window_size = 1000;
m14_s_MA = movmean(m_14_time, window_size, 'omitnan');
plot(time_raw, m14_s_MA, 'b-', 'LineWidth', 2.5, 'DisplayName', 'Flowrate Average'); 

% Highlight the 80% capacity points using matching timestamps
plot(time_raw(idx_80), m_14_time(idx_80), 'r.', 'MarkerSize', 8, 'DisplayName', '65% Capacity Points');
grid on; box on;
title('Boiler 14: Steam Flow & Moving Average Over Time');
xlabel('Time');
ylabel('Steam Flow Rate (kg/s)');
legend('Location', 'best');
xtickformat('dd-MM HH:mm');
xtickangle(45);
hold off;

%% Display Boiler 14 Metrics
fprintf('\n--- Boiler 14 Variables at ~65%% Capacity ---\n');
fprintf('Steam Flow (m_14):         %.2f kg/s\n', m_14);
fprintf('Steam Temp (T_14):         %.2f °C\n', T_14);
fprintf('Steam Press (P_14):        %.2f bar\n', P_14);
fprintf('Fuel flow (m14_fuel):      %.2f kg/s\n', m14_fuel);
fprintf('Feedwater Flow (m14_fw):   %.2f kg/s\n', m14_fw);
fprintf('Flue Gas Temp (T14_fg):    %.2f °C\n', T14_fg);
fprintf('Eco Flue Gas Temp:         %.2f °C\n', T14_fgeco);
fprintf('-----------------------------------------\n');
fprintf('Second Law Efficiency:     %.2f%%\n', k14_2eff * 100);
fprintf('\n=================== k-14 Boiler ===================\n');
fprintf('Second Law Efficiency:     %.2f %%\n', k14_2eff * 100);
fprintf('Available work from flue gas: %.2f kW \n', X14_fg );
fprintf('=========================================================\n');

%% Boiler 15 (Filtered for Active Operation & Time-Series Plotting)
fuel_raw  = Get(data, 'KW_821_15_FITQ5001'); 
steam_raw = Get(data, 'KW_821_15_FIQ0206');
fw_raw    = Get(data, 'KW_821_15_FIQ0202');
T15_raw   = Get(data, 'KW_921T022_XQ01');
T15e_raw  = Get(data, 'KW_821_15TT5004');
P15_raw   = Get(data, 'KW_921_00P203');
T15_fw    = T14_fw;

% Mean calculations for Active Steady-State
m15_fuel = (mean(fuel_raw(active_idx), 'omitnan') * 0.8) / 3600; 
m_15     = mean(steam_raw(active_idx), 'omitnan') / 3.6;         
m15_fw   = mean(fw_raw(active_idx), 'omitnan') / 3.6;           
T_15     = mean(T15_raw(active_idx), 'omitnan');
T15_econ = mean(T15e_raw(active_idx), 'omitnan');
P_15     = mean(P15_raw(active_idx), 'omitnan');
P15_fw   = P14_fw; 

% Thermodynamic Properties (Mean values)
h15_fw = coolprop('H', 'P', P15_fw * 1e5, 'T', T15_fw + 273.15, 'Water') * 1e-3; 
h15_s  = coolprop('H', 'P', P_15 * 1e5, 'T', T_15 + 273.15, 'Water') * 1e-3; 
s15_fw = coolprop('S', 'P', P15_fw * 1e5, 'T', T15_fw + 273.15, 'Water') * 1e-3; 
s15_s  = coolprop('S', 'P', P_15 * 1e5, 'T', T_15 + 273.15, 'Water') * 1e-3; 
e15_water = (h15_fw - h_amb) - (T_amb+273.15)*(s15_fw - s_amb);
e15_steam = (h15_s - h_amb) - (T_amb+273.15)*(s15_s - s_amb);
e15_fuel  = 51.5 * 1e3; 

% Steady-State Efficiencies
HHV_aard = 54.4 * 1e3; 
k15_eff  = (m_15 * (h15_s - h15_fw)) / (m15_fuel * HHV_aard);
k15_2eff = ((e15_steam * m_15) - (e15_water * m15_fw)) / (e15_fuel * m15_fuel);

fprintf('\n=================== k-15 Boiler (Active) ===================\n');
fprintf('Thermal Eff:            %.2f %%\n', k15_eff * 100);
fprintf('Second Law Efficiency:  %.2f %%\n', k15_2eff * 100);
fprintf('=========================================================\n');

% --- Boiler 15 Real-Time Vector Analysis ---
m15_fuel_t = (fuel_raw(active_idx) * 0.8) / 3600; 
m_15_t     = steam_raw(active_idx) / 3.6;         
m15_fw_t   = fw_raw(active_idx) / 3.6;           
T_15_t     = T15_raw(active_idx);
P_15_t     = P15_raw(active_idx);

h15_s_t  = coolprop('H', 'P', P_15_t * 1e5, 'T', T_15_t + 273.15, 'Water') * 1e-3; 
s15_s_t  = coolprop('S', 'P', P_15_t * 1e5, 'T', T_15_t + 273.15, 'Water') * 1e-3; 
e15_steam_t = (h15_s_t - h_amb) - (T_amb + 273.15) .* (s15_s_t - s_amb);

k15_eff_t  = (m_15_t .* (h15_s_t - h15_fw)) ./ (m15_fuel_t * HHV_aard) * 100;
k15_2eff_t = ((e15_steam_t .* m_15_t) - (e15_water * m15_fw_t)) ./ (e15_fuel * m15_fuel_t) * 100;

% Filter transient edge-spikes
invalid_idx = k15_eff_t > 100 | k15_eff_t < 0 | k15_2eff_t > 100 | k15_2eff_t < 0;
k15_eff_t(invalid_idx)  = NaN;
k15_2eff_t(invalid_idx) = NaN;

% Moving averages of active data window
window_size = 2000; 
k15_eff_MA   = movmean(k15_eff_t, window_size, 'omitnan');
k15_2eff_MA  = movmean(k15_2eff_t, window_size, 'omitnan');

%% Graph Boiler 15 Efficiency Performance
figure('Name', 'Boiler 15 Real-Time Efficiency Analysis', 'Color', 'w');
hold on;

% Scatter the background transient dots
scatter(time_plot, k15_eff_t, 7, [0.75, 0.85, 1], 'filled', 'HandleVisibility', 'off'); 
scatter(time_plot, k15_2eff_t, 7, [1, 0.8, 0.8], 'filled', 'HandleVisibility', 'off'); 

% Smooth moving average trend lines
plot(time_plot, k15_eff_MA, 'b', 'LineWidth', 2.5, 'DisplayName', 'Thermal Efficiency (\eta_{th}) MA'); 
plot(time_plot, k15_2eff_MA, 'r', 'LineWidth', 2.5, 'DisplayName', 'Second Law Efficiency (\eta_{II}) MA'); 

grid on; box on;
xlabel('Time');
ylabel('Efficiency (%)');
title(['Boiler 15 Operational Efficiency (' num2str(window_size) '-Point Moving Average)']);
legend('Location', 'best');
ylim([0 100]); 

if isdatetime(time_plot)
    xtickformat('dd-MM HH:mm');
    xtickangle(45);
end
hold off;
% Unit conversion & Array formatting
mcond1_raw  = Get(data, 'KW_923FIQ036_XQ01') ./ 3.6;
mcond2_raw  = Get(data, 'KW_TC_921FIQ004') ./ 3.6;
mcond       = mcond1_raw(:) + mcond2_raw(:); 
mreturn_raw = Get(data, 'KW_TC_934FIQ023') ./ 3.6;
mreturn_raw = mreturn_raw(:);

% FIX: Filter vectors using active_idx to match time_plot dimensions
mcond       = mcond(active_idx);
mreturn_raw = mreturn_raw(active_idx);

window_size = 2000; 
mcond_MA    = movmean(mcond, window_size, 'omitnan');
mreturn_MA  = movmean(mreturn_raw, window_size, 'omitnan');
%% Graph Condensate vs Supplied steam
figure('Name', 'Steam Supplied vs Condensate Returned', 'Color', 'w');
hold on;
scatter(time_plot, mcond, 7, [0.75, 0.85, 1], 'filled', ...
    'MarkerFaceAlpha', 0.3, 'MarkerEdgeAlpha', 0.3, 'HandleVisibility', 'off'); 
scatter(time_plot, mreturn_raw, 7, [1, 0.8, 0.8], 'filled', ...
    'MarkerFaceAlpha', 0.3, 'MarkerEdgeAlpha', 0.3, 'HandleVisibility', 'off'); 
plot(time_plot, mcond_MA, 'b', 'LineWidth', 2.5, 'DisplayName', 'Condensate Returned'); 
plot(time_plot, mreturn_MA, 'r', 'LineWidth', 2.5, 'DisplayName', 'Steam Supplied (2.5 + 20 bar)'); 
grid on; box on;
xlabel('Time');
ylabel('Steam/Condensate (kg/s)');
title(['Steam Supply vs Condensate Return (' num2str(window_size) '-Point Moving Average)']);
legend('Location', 'best');
ylim([0 100]); 
if isdatetime(time_plot)
    xtickformat('dd-MM HH:mm');
    xtickangle(45);
end
hold off;

%% Steam Out to Clients (Means)
m_cl2 = mean(Get(data, 'KW_921F021_XQ01'))/3.6;
m_cl3 = mean(Get(data, 'KW_921FIQ022_XQ01'))/3.6; 
m_cl4 = mean(Get(data, 'KW_923F030_XQ01'))/3.6; 
m_cl5 = mean(Get(data, 'KW_923FIQ036_XQ01'))/3.6;
m_cl6 = mean(Get(data, 'KW_923FIQ045'))/3.6;

%% Overall Plant Mass Balance (Means)
m_in = m_13 + m_14 + m_15;
m_out = m_cl2 + m_cl3 + m_cl4 + m_cl5 + m_cl6;
m_loss = m_in - m_out;

%% Custom Extraction Function
function val = Get(dataTable, tag)
    if ismember(tag, dataTable.Properties.VariableNames)
        val = dataTable{:, tag};
        if iscell(val) || isstring(val)
            val = str2double(string(val)); 
        end
        is_nan_val  = isnan(val);
        is_zero_val = (val == 0); 
        bad_indices = is_nan_val | is_zero_val;
        total_bad = sum(bad_indices);
        total_samples = length(val);
        
        if total_bad > 0
            percent_bad = (total_bad / total_samples) * 100;
            fprintf('Tag %s: %.1f%% data missing.\n', tag, percent_bad);
            if total_bad == total_samples
                val = zeros(total_samples, 1);
            else
                val(is_zero_val) = NaN;
                val = fillmissing(val, 'linear', 'EndValues', 'nearest');
            end
        end
    else
        fprintf('Tag %s: 100%% data missing (Tag not found).\n', tag);
        val = zeros(height(dataTable), 1);
    end
end