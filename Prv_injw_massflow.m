%% =========================================================================
%  PRV Analysis & Visualization
%  =========================================================================
clear; clc; close all;

% Load the pre-calculated Enthalpy Lookup Table
if isfile('H_map_data.mat')
    load('H_map_data.mat'); 
else
    error('Could not find H_map_data.mat. Please run your setup script first.');
end

%% 1. CONFIGURATION & DATA LOADING
filename = 'Cleaned_OneWeekData.csv';
fprintf('Loading data from %s...\n', filename);

opts = detectImportOptions(filename);
opts.VariableNamingRule = 'preserve'; 
data = readtable(filename, opts);

% Define Time Vector and Row Count
time = 1:height(data); 
n = height(data); 

% Ambient Reference State
t_amb = 25;           % [°C]
p_amb = 1.01325;      % [Bar abs]
h_amb = H_map(p_amb, t_amb); 
s_amb = H_map(p_amb, t_amb); 

%% 2. DATA EXTRACTION & THERMODYNAMIC EVALUATION
% --- HP Header (50 bar) ---
m_50   = check_and_get(data, 'KW_821_14FE_0015') / 3.6; % Convert t/h to kg/s
p_50   = check_and_get(data, 'KW_921PISA001_XQ01'); 
t_50   = check_and_get(data, 'KW_821_14TI0015');    
h_50   = H_map(p_50, t_50);

% --- Turbine ---
m_turb = check_and_get(data, 'KW_921_01FE0101') / 3.6; 
p_turb = check_and_get(data, 'KW_921_00PI0101');
t_turb = check_and_get(data, 'KW_921_00TI0101');
h_turb = H_map(p_turb, t_turb);

% --- Boiler 15 ---
m_k15  = check_and_get(data, 'KW_821_15_FIQ0206') / 3.6;
p_k15  = check_and_get(data, 'KW_921_00P203');
t_k15  = check_and_get(data, 'KW_921TICA002_XQ01');
h_k15  = H_map(p_k15, t_k15);

% --- MD Header (20 bar) ---
p_20   = check_and_get(data, 'KW_921PICA029_XQ01'); 
t_20   = check_and_get(data, 'KW_921TICA002_XQ01'); 
h_20   = H_map(p_20, t_20);

% --- Injection / Desuperheating Water ---
p_water = check_and_get(data, 'KW_836PIA008_XQ01');
t_water = check_and_get(data, 'KW_836_00TI0201'); 
h_water = H_map(p_water, t_water);

% --- PRV Valve Positions (%) ---
prv_2 = nan(n, 1);
prv_3 = check_and_get(data, 'KW_921PCV004_XQ02');
prv_4 = check_and_get(data, 'KW_921PCV007_XQ02');
prv_5 = check_and_get(data, 'KW_921PCV021_XQ02');
prv_6 = check_and_get(data, 'KW_921PCV025_XQ02');
prv_7 = nan(n, 1);
prv_8 = nan(n, 1);

% --- Injection Valve Positions (%) ---
iw_2 = nan(n, 1);
iw_3 = check_and_get(data, 'KW_921TCV002_XQ02');
iw_4 = check_and_get(data, 'KW_921TCV004_XQ02');
iw_5 = check_and_get(data, 'KW_921TCV021_XQ02');
iw_6 = check_and_get(data, 'KW_921TCV025_XQ02');
iw_7 = nan(n, 1);
iw_8 = nan(n, 1);

% --- Downstream Reducer 5 & 6 Data ---
p_prv5 = check_and_get(data, 'KW_921PICA021_XQ01'); 
p_prv6 = check_and_get(data, 'KW_921PICA025_XQ01'); 
t_prv5 = check_and_get(data, 'KW_921TICA021_XQ01');                        
t_prv6 = check_and_get(data, 'KW_921TICA025_XQ01');

%% 3. MASS & ENERGY BALANCE CALCULATIONS
% Unmixed steam coming from the 50 bar system into the PRVs
m_steam_to_prv = m_50 - m_turb; 

% Spray water mass flow via steady-state energy balance
m_w = m_steam_to_prv .* (h_50 - h_20) ./ (h_20 - h_water);

% Massflow through 20 bar header
m_20 = m_steam_to_prv + m_k15 + m_w;

% Pressure & Temperature differences
p_prvs  = p_prv6 - p_prv5;
p_prv20 = p_20 - p_prv5;
t_prvs  = t_prv6 - t_prv5;
t_prv20 = t_20 - t_prv5;

%% 4. MOVING AVERAGE CALCULATIONS
window_size = 400; 

% Unweighted Moving Averages (Flows and Valve Positions)
mov_m_steam_to_prv = movmean(m_steam_to_prv, window_size, 'omitnan');
mov_m_w            = movmean(m_w, window_size, 'omitnan');
mov_m_20           = movmean(m_20, window_size, 'omitnan');
mov_prv_5          = movmean(prv_5, window_size, 'omitnan');
mov_iw_5           = movmean(iw_5, window_size, 'omitnan');

% Moving Weighted Averages (Weighted by matching steam flow profiles)
mov_p_prv5  = compute_moving_weighted_avg(p_prv5, m_steam_to_prv, window_size);
mov_p_prv6  = compute_moving_weighted_avg(p_prv6, m_steam_to_prv, window_size);
mov_p_prvs  = compute_moving_weighted_avg(p_prvs, m_steam_to_prv, window_size);
mov_p_prv20 = compute_moving_weighted_avg(p_prv20, m_steam_to_prv, window_size);

mov_t_prv5  = compute_moving_weighted_avg(t_prv5, m_steam_to_prv, window_size);
mov_t_prv6  = compute_moving_weighted_avg(t_prv6, m_steam_to_prv, window_size);
mov_t_prvs  = compute_moving_weighted_avg(t_prvs, m_steam_to_prv, window_size);
mov_t_prv20 = compute_moving_weighted_avg(t_prv20, m_steam_to_prv, window_size);

% Moving Main Header metrics (Weighted by total 20-bar system load)
mov_p_20 = compute_moving_weighted_avg(p_20, m_20, window_size);
mov_t_20 = compute_moving_weighted_avg(t_20, m_20, window_size);

% Global Scalars for Text Displays (Single Values for Titles/Legends)
global_m_steam = mean(m_steam_to_prv, 'omitnan');
global_m_w     = mean(m_w, 'omitnan');
global_m_20    = mean(m_20, 'omitnan');
global_prv_5   = mean(prv_5, 'omitnan');
global_iw_5    = mean(iw_5, 'omitnan');

global_delta_p    = mean(p_prvs, 'omitnan');
global_delta_t    = mean(t_prvs, 'omitnan');

global_delta_p20    = mean(p_prv20, 'omitnan');
global_delta_t20    = mean(t_prv20, 'omitnan');

%% 5. VISUALIZATION: SINGLE FIGURE TABBED LAYOUT
% Initialize a unified dashboard window
main_fig = figure('Name', 'System Performance & PRV Diagnostics Dashboard', ...
                  'Color', 'w', 'Units', 'normalized', 'Position', [0.1, 0.1, 0.75, 0.75]);

% Create the core tab framework container within the figure window
tab_manager = uitabgroup(main_fig);

%% =========================================================================
%  TAB 1: PRV 5 DETAILED PROCESS DIAGNOSTICS
%  =========================================================================
tab_prv5 = uitab(tab_manager, 'Title', 'PRV 5 Performance Diagnostics');

% Graph 1: PRV 5 Moving Steam Flow Trend vs Valve Position Profile
ax1 = subplot(2,2,1, 'Parent', tab_prv5);
yyaxis(ax1, 'left');
plot(time, mov_m_steam_to_prv, 'b', 'LineWidth', 1.5);
ylabel('Steam Flow [kg/s]');
yyaxis(ax1, 'right');
plot(time, mov_prv_5, 'r--', 'LineWidth', 1.2);
ylabel('Valve Position [%]');
title(sprintf('PRV 5 Steam Mass Flow vs Valve Position\n(Global Steam Avg: %.2f kg/s | Valve Avg: %.1f%%)', global_m_steam, global_prv_5));
xlabel('Time (s)');
grid on;

% Graph 2: PRV 5 Moving Spray Water Flow Trend vs Injection Valve Position Profile
ax2 = subplot(2,2,2, 'Parent', tab_prv5);
yyaxis(ax2, 'left');
plot(time, mov_m_w, 'b', 'LineWidth', 1.5);
ylabel('Injection Water Flow [kg/s]');
yyaxis(ax2, 'right');
plot(time, mov_iw_5, 'r--', 'LineWidth', 1.2);
ylabel('Valve Position [%]');
title(sprintf('PRV 5 Injection Water Mass Flow vs Valve Position\n(Global Water Avg: %.2f kg/s | Injection Avg: %.1f%%)', global_m_w, global_iw_5));
xlabel('Time (s)');
grid on;

% Compute the Pearson correlation coefficient (ignoring any NaNs)
[r_matrix, ~] = corrcoef(m_steam_to_prv, m_w, 'Rows', 'complete');
flow_correlation = r_matrix(1,2); 

% Print the result to the command window
fprintf('The statistical correlation between steam and water flow is: %.4f\n', flow_correlation);

% Graph 3: Localized Pressure Drop Analysis (Post-Reducer 5 vs Main Header Target)
subplot(2,2,3, 'Parent', tab_prv5);
plot(time, mov_p_prv5, 'b', 'LineWidth', 1.2); hold on;
plot(time, mov_p_20, 'm', 'LineWidth', 1.2);
plot(time, mov_p_prv20, 'r', 'LineWidth', 1.5);
title('Post-PRV 5 Pressure vs 20 Bar Header Pressure (Smoothed)');
xlabel('Time (s)'); ylabel('Pressure [bar]');

% Use sprintf inside the legend arguments list
legend('Post-Reducer 5 Outlet Pressure', ...
       '20 Bar Header Pressure', ...
       sprintf('Pressure Difference, Average: %.2f bar', global_delta_p20), ...
       'Location', 'best');
grid on;

% Graph 4: Thermal Energy Gradient Analysis (Post-Reducer 5 vs Main Header State)
subplot(2,2,4, 'Parent', tab_prv5);
plot(time, mov_t_prv5, 'b', 'LineWidth', 1.2); hold on;
plot(time, mov_t_20, 'm', 'LineWidth', 1.2);
plot(time, mov_t_prv20, 'r', 'LineWidth', 1.5);
title('Post-PRV 5 Temperarure vs 20 Bar Header Temperature (Smoothed)');
xlabel('Time (s)'); ylabel('Temperature [°C]');
legend('Post-Reducer 5 Outlet Temperature', ...
       '20 Bar Header Temperature', ...
       sprintf('Temperature Differencec, Average: %.2f C',global_delta_t20), ...
       'Location', 'best');
grid on;

%% =========================================================================
%  TAB 2: INTEGRATED SYSTEM HEADERS & SECONDARY VALVE METRICS
%  =========================================================================
tab_system = uitab(tab_manager, 'Title', 'Overall System & Balance Analysis');

% Graph 1: Total Smoothed Operating Load of the Main Distribution Header
subplot(2,2,1, 'Parent', tab_system);
plot(time, mov_m_20, 'b', 'LineWidth', 1.5);
title(sprintf('Mass Flow through 20 Bar Header \n(Overall Header Operating Mass Flow Avg: %.2f kg/s)', global_m_20));
xlabel('Time (s)'); ylabel('Flow Rate [kg/s]');
grid on;

% Graph 2: Comparative Feed Stream Flows entering the Station Loop
subplot(2,2,2, 'Parent', tab_system);
plot(time, mov_m_steam_to_prv, 'b', time, mov_m_w, 'r', 'LineWidth', 1.5);
title('Steam and Injection water Flowrates');
xlabel('Time (s)'); ylabel('Flow Rate [kg/s]');
legend('Steam Mass Flow', ...
       'Injection water Water Mass Flow', ...
       'Location', 'best');
grid on;

% Graph 3: Pressure Differential Evaluation between Reducer Units 5 and 6
subplot(2,2,3, 'Parent', tab_system);
plot(time, mov_p_prv5, 'Color', [0.5, 0.5, 0.5], 'LineWidth', 1.2); hold on;
plot(time, mov_p_prv6, 'Color', [0.2, 0.6, 0.8], 'LineWidth', 1.2);
plot(time, mov_p_prvs, 'r', 'LineWidth', 1.5);
title('PRV 5 vs PRV 6 Pressure');
xlabel('Time / Data Point'); ylabel('Pressure [bar]');
legend('Post-Reducer 5 Pressure', ...
       'Post-Reducer 6 Pressure', ...
       sprintf('Pressure Deviation, Average: %.2f bar', global_delta_p), ...
       'Location', 'best');
grid on;

% Graph 4: Temperature Differential Evaluation between Reducer Units 5 and 6
subplot(2,2,4, 'Parent', tab_system);
plot(time, mov_t_prv5, 'c', 'LineWidth', 1.2); hold on;
plot(time, mov_t_prv6, 'k', 'LineWidth', 1.2);
plot(time, mov_t_prvs, 'r', 'LineWidth', 1.5);
title('Inter-Valve Balancing: PRV 5 vs PRV 6 Temperature Lines');
xlabel('Time / Data Point'); ylabel('Temperature [°C]');
legend('Post-Reducer 5 Temperature', ...
       'Post-Reducer 6  Temperature', ...
       sprintf('Thermal Deviation, Average: %.2f C',global_delta_t), ...
       'Location', 'best');
grid on;

%% =========================================================================
%  HELPER FUNCTIONS
%  =========================================================================
function val = check_and_get(tbl, tag)
% Checks if the target tag exists in the table workspace. 
% Returns data if found; otherwise throws a warning and returns an array of NaNs.
    if ismember(tag, tbl.Properties.VariableNames)
        val = tbl.(tag);
    else
        warning('Tag "%s" not found in the dataset. Filling with NaN.', tag);
        val = nan(height(tbl), 1);
    end
end

function mwa = compute_moving_weighted_avg(val, weights, window_size)
% Sanitizes out NaNs and runs an optimized, vectorised moving sum calculation 
% to find the moving weighted average without loop bottlenecks.
    v_clean = val;
    w_clean = weights;
    
    nan_mask = isnan(v_clean) | isnan(w_clean) | (w_clean < 0);
    v_clean(nan_mask) = 0;
    w_clean(nan_mask) = 0;
    
    moving_numerator   = movsum(v_clean .* w_clean, window_size);
    moving_denominator = movsum(w_clean, window_size);
    
    mwa = moving_numerator ./ moving_denominator;
    mwa(moving_denominator == 0) = nan; % Prevents division by zero errors
end