%% =========================================================================
%  Condensate Flow (Anonymized)
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

% Extract the raw vector first to create a valid time-series operational mask
Tfw_in_raw = Get(data, 'KW_836TI002_XQ01');
Tfw_in_vec = Tfw_in_raw(:); 

% Create the operational mask & time vectors
active_idx = Tfw_in_vec > 50; 
N = length(Tfw_in_vec);
time_raw = datetime(2026, 5, 25, 8, 1, 0) + minutes(0:N-1)';
time_plot = time_raw(active_idx);

% Calculate the overall mean for reference if needed
Tfw_in = mean(Tfw_in_vec, 'omitnan');

%% Low pressure steam clients
% --- Extract individual flows ---
LD_Client_01_raw      = Get(data, 'KW_923F030_XQ01'); % missing 100% of data
LD_Client_01   = mean(LD_Client_01_raw(active_idx), 'omitnan') / 3.6;
LD_Client_02_raw        = Get(data, 'KW_923FIQ036_XQ01'); % Total LD Client 02
LD_Client_02   = mean(LD_Client_02_raw(active_idx), 'omitnan') / 3.6;
LD_Client_03_raw     = Get(data, 'KW_TC_923FIQ043'); % missing 100% of data
LD_Client_03   = mean(LD_Client_03_raw(active_idx), 'omitnan') / 3.6;
LD_Client_04_raw       = Get(data, 'KW_923FIQ045');
LD_Client_04   = mean(LD_Client_04_raw(active_idx), 'omitnan') / 3.6;
LD_Client_05_raw     = Get(data, 'KW_TC_923FIQ031'); % missing 100% of data
LD_Client_05   = mean(LD_Client_05_raw(active_idx), 'omitnan') / 3.6;
LD_Client_06_raw       = Get(data, 'KW_923FIQ028_XQ01'); % missing 100% of data
LD_Client_06   = mean(LD_Client_06_raw(active_idx), 'omitnan') / 3.6;
LD_Client_07_raw      = Get(data, 'KW_923FIQ001_XQ01'); % missing 100% of data
LD_Client_07   = mean(LD_Client_07_raw(active_idx), 'omitnan') / 3.6;
LD_Client_08_raw      = Get(data, 'KW_923FIQ024_XQ01');
LD_Client_08   = mean(LD_Client_08_raw(active_idx), 'omitnan') / 3.6;
LD_Client_09_raw = Get(data, 'KW_TC_923FIQ037'); % missing 100% of data
LD_Client_09   = mean(LD_Client_09_raw(active_idx), 'omitnan') / 3.6;
LD_Client_10_raw    = Get(data, 'KW_TC_923FIQ040');
LD_Client_10   = mean(LD_Client_10_raw(active_idx), 'omitnan') / 3.6;
LD_Client_11_raw        = Get(data, 'KW_923FIQ031_XQ01');
LD_Client_11   = mean(LD_Client_11_raw(active_idx), 'omitnan') / 3.6;
LD_Client_12_raw   = Get(data, 'KW_923FIQ029_XQ01');
LD_Client_12   = mean(LD_Client_12_raw(active_idx), 'omitnan') / 3.6;
LD_Client_13_raw     = Get(data, 'KW_923FIQ012_XQ01');
LD_Client_13   = mean(LD_Client_13_raw(active_idx), 'omitnan') / 3.6;
LD_Client_14_raw      = Get(data, 'KW_923FIQ005_XQ01'); % missing 100% of data
LD_Client_14   = mean(LD_Client_14_raw(active_idx), 'omitnan') / 3.6;

m_lp_users_raw  = (LD_Client_01_raw + LD_Client_02_raw + LD_Client_03_raw + LD_Client_04_raw + LD_Client_05_raw + ...
    LD_Client_06_raw + LD_Client_07_raw + LD_Client_08_raw + LD_Client_09_raw + ...
    LD_Client_10_raw + LD_Client_11_raw + LD_Client_12_raw + LD_Client_13_raw + LD_Client_14_raw) / 3.6;

m_lp_users  = LD_Client_01 + LD_Client_02 + LD_Client_03 + LD_Client_04 + LD_Client_05 + ...
    LD_Client_06 + LD_Client_07 + LD_Client_08 + LD_Client_09 + ...
    LD_Client_10 + LD_Client_11 + LD_Client_12 + LD_Client_13 + LD_Client_14;

% --- OUT FLOWS (MD Steam - 20 bar) ---
MD_Client_01_raw    = Get(data, 'KW_921F021_XQ01');
MD_Client_01   = mean(MD_Client_01_raw(active_idx), 'omitnan') / 3.6;
MD_Client_02_raw      = Get(data, 'KW_TC_921FIQ004');
MD_Client_02   = mean(MD_Client_02_raw(active_idx), 'omitnan') / 3.6;
MD_Client_03_raw    = Get(data, 'KW_921FIQ022_XQ01'); % missing 100% of data
MD_Client_03   = mean(MD_Client_03_raw(active_idx), 'omitnan') / 3.6;
MD_Client_04_raw   = Get(data, 'KW_TC_921FIQ006');
MD_Client_04   = mean(MD_Client_04_raw(active_idx), 'omitnan') / 3.6;
MD_Client_05_raw     = Get(data, 'KW_TC_921FIQ005');
MD_Client_05   = mean(MD_Client_05_raw(active_idx), 'omitnan') / 3.6;

m_mp_users_raw = (MD_Client_01_raw + MD_Client_02_raw + MD_Client_03_raw + MD_Client_04_raw + MD_Client_05_raw) / 3.6;
m_mp_users = MD_Client_01 + MD_Client_02 + MD_Client_03 + MD_Client_04 + MD_Client_05;

fprintf('Medium pressure condensate: %.2f kg/s\n', m_mp_users);
fprintf('Low pressure condensate: %.2f kg/s\n', m_lp_users);

%% Condensate volumetric flow return from clients (m3/h)
condensate_cl1_raw = Get(data, 'KW_934F001_XQ01');   % FLOW CONDENSATE CLIENT 01
condensate_cl2_raw = Get(data, 'KW_934FIQ006_XQ01'); % FLOW CONDENSATE CLIENT 02
condensate_cl3_raw = Get(data, 'KW_934FIQ021_XQ01'); % FLOW CONDENSATE CLIENT 03
condensate_cl4_raw = Get(data, 'KW_934FIQ012');      % FLOW CONDENSATE CLIENT 04

%% Client physical properties (For thermodynamic density & mass flow conversion)
temp_cl_02         = Get(data, 'KW_934T002_XQ01');   % TEMPERATURE CONDENSATE CLIENT 02 (°C)
temp_cl_03         = Get(data, 'KW_934T021_XQ01');   % TEMPERATURE CONDENSATE CLIENT 03 (°C)
conductivity_cl_01 = Get(data, 'KW_934QIA001_XQ01'); % CONDUCTIVITY CONDENSATE CLIENT 01 (µS/cm)

% Condensate volumetric flow return from buildings (m3/h)
condensate_b2_raw = Get(data, 'KW_934FIQ004_XQ01'); % FLOW CONDENSATE BLDG 02
condensate_b3_raw = Get(data, 'KW_934FIQ005_XQ01'); % FLOW CONDENSATE BLDG 03
condensate_b4_raw = Get(data, 'KW_934FIQ007_XQ01'); % FLOW CONDENSATE BLDG 04
condensate_b5_raw = Get(data, 'KW_934FIQ008_XQ01'); % FLOW CONDENSATE BLDG 05
condensate_b6_raw = Get(data, 'KW_934FIQ009_XQ01'); % FLOW CONDENSATE BLDG 06

%% Net building flows to prevent double-counting in mass balance
condensate_cl1 = mean(condensate_cl1_raw(active_idx), 'omitnan') / 3.6; 
condensate_cl2 = mean(condensate_cl2_raw(active_idx), 'omitnan') / 3.6; 
condensate_cl3 = mean(condensate_cl3_raw(active_idx), 'omitnan') / 3.6; 
condensate_cl4 = mean(condensate_cl4_raw(active_idx), 'omitnan') / 3.6; 
condensate_b2  = mean(condensate_b2_raw(active_idx), 'omitnan') / 3.6; 
condensate_b3  = mean(condensate_b3_raw(active_idx), 'omitnan') / 3.6; 
condensate_b4  = mean(condensate_b4_raw(active_idx), 'omitnan') / 3.6; 
condensate_b5  = mean(condensate_b5_raw(active_idx), 'omitnan') / 3.6; 
condensate_b6  = mean(condensate_b6_raw(active_idx), 'omitnan') / 3.6; 

m_cond_raw = (condensate_cl1_raw + condensate_cl2_raw + condensate_cl3_raw + condensate_cl4_raw + ...
             condensate_b2_raw + condensate_b3_raw + condensate_b4_raw + condensate_b5_raw + condensate_b6_raw) ./ 3.6;
m_cond = condensate_cl1 + condensate_cl2 + condensate_cl3 + condensate_cl4 + ...
         condensate_b2 + condensate_b3 + condensate_b4 + condensate_b5 + condensate_b6;

t_cond_raw = Get(data, 'KW_934T021_XQ01'); 
t_cond = mean(t_cond_raw(active_idx), 'omitnan');
fprintf('Condensate returned %.2f kg/s\n', m_cond);

% Demi water is added to the feedwater tanks
m_demi_raw = Get(data, 'KW_817FIQ101_XQ01'); 
m_demi = mean(m_demi_raw(active_idx), 'omitnan');

% Steam is added to the degasser/deaerator
m_dead_raw = Get(data, 'KW_TC_923FIQ015A');
m_dead   = mean(m_dead_raw(active_idx), 'omitnan') / 3.6;
m_degasserin = m_cond + m_demi + m_dead;

m_degasserout_raw = Get(data, 'KW_836FIQ012_XQ01'); 
m_degasserout = mean(m_degasserout_raw(active_idx), 'omitnan') / 3.6; 
m_degasser_error = m_degasserin - m_degasserout;

level_degasser_raw = Get(data, 'KW_836LICSA003_XQ01');
level_degasser = mean(level_degasser_raw(active_idx), 'omitnan');

fprintf('Difference in flow from degasser %.2f\n', m_degasser_error); 
fprintf('Average tank level %.2f %%\n ', level_degasser);

t_degasser1_raw = Get(data, 'KW_836TI002_XQ01'); 
p_degasser1_raw = Get(data, 'KW_836PICA003_XQ01'); 
t_degasser = mean(t_degasser1_raw(active_idx), 'omitnan');
p_degasser = mean(p_degasser1_raw(active_idx), 'omitnan');

%% Graph Condensate vs Supplied steam
msteam_raw  = m_lp_users_raw(:) + m_mp_users_raw(:); 
m_cond_raw  = m_cond_raw(:);
mreturn_raw = m_cond_raw;

% Filter vectors using active_idx to match time_plot dimensions
msteam_raw  = msteam_raw(active_idx);
mreturn_raw = mreturn_raw(active_idx);

window_size = 1000; 
msteam_MA   = movmean(msteam_raw, window_size, 'omitnan');
mreturn_MA  = movmean(mreturn_raw, window_size, 'omitnan');

figure('Name', 'Steam Supplied vs Condensate Returned', 'Color', 'w');
hold on;

% Background transient scatter dots
scatter(time_plot, msteam_raw, 7, [0.75, 0.85, 1], 'filled', ...
    'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0.8, 'HandleVisibility', 'off'); 
scatter(time_plot, mreturn_raw, 7, [1, 0.8, 0.8], 'filled', ...
    'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0.8, 'HandleVisibility', 'off'); 

% Smooth moving average trend lines
plot(time_plot, msteam_MA, 'b', 'LineWidth', 2.5, 'DisplayName', 'Steam Supplied (2.5 + 20 bar)'); 
plot(time_plot, mreturn_MA, 'r', 'LineWidth', 2.5, 'DisplayName', 'Condensate Return'); 

% Formatting
grid on; box on;
xlabel('Time');
ylabel('Steam/Condensate (kg/s)');
title(['Steam Supply vs Condensate Return (' num2str(window_size) '-Point Moving Average)']);
legend('Location', 'best');
max_val = max([max(msteam_raw), max(mreturn_raw), 10]); 
ylim([0, max_val * 1.15]); 

if isdatetime(time_plot)
    xtickformat('dd-MM HH:mm');
    xtickangle(45);
end
hold off;

%% Boiler 14 (Time-Series Vectors & 80% Capacity Window)
m_14_time = Get(data, 'KW_821_14FE_0015') / 3.6;
T_14_time = Get(data, 'KW_821_14TI0015');
P_14_time = Get(data, 'KW_821_14PI0015');
T14_fw_time = Get(data, 'KW_836T008_XQ01'); 
m14_chem_time = Get(data, 'KW_821_14FIT7301') / 3.6; % Anonymized chemical treatment flow
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
m14_chem = mean(m14_chem_time(idx_80));
m14_fw = mean(m14_fw_time(idx_80));
m14_totfw = m14_chem + m14_fw;
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
HHV_gas_fuel = 54.4 * 1e3; % Anonymized gas high-heating value
k15_eff  = (m_15 * (h15_s - h15_fw)) / (m15_fuel * HHV_gas_fuel);
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
k15_eff_t  = (m_15_t .* (h15_s_t - h15_fw)) ./ (m15_fuel_t * HHV_gas_fuel) * 100;
k15_2eff_t = ((e15_steam_t .* m_15_t) - (e15_water * m15_fw_t)) ./ (e15_fuel * m15_fuel_t) * 100;

% Filter transient edge-spikes
invalid_idx = k15_eff_t > 100 | k15_eff_t < 0 | k15_2eff_t > 100 | k15_2eff_t < 0;
k15_eff_t(invalid_idx)  = NaN;
k15_2eff_t(invalid_idx) = NaN;

% Moving averages of active data window
window_size = 2000; 
k15_eff_MA   = movmean(k15_eff_t, window_size, 'omitnan');
k15_2eff_MA  = movmean(k15_2eff_t, window_size, 'omitnan');

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