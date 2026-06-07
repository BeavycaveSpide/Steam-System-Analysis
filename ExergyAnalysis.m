%% =========================================================================
%  Exergy Calculations (Anonymized)
%  =========================================================================
clear; clc; close all;

%% 1. CONFIGURATION & DATA LOADING
filename = 'Cleaned_OneWeekData.csv';
fprintf('Loading data from %s...\n', filename);

% Use preserve rule to read tags exactly as they appear in the CSV
opts = detectImportOptions(filename);
opts.VariableNamingRule = 'preserve';
data = readtable(filename, opts);

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

% Ambient Reference State
T_amb = 25 + 273.15;           % [°C]
P_amb = 1.01325;      % [Bar abs]
h_amb  = coolprop('H', 'P', P_amb * 1e5, 'T', T_amb, 'Water') * 1e-3;
s_amb  = coolprop('S', 'P', P_amb * 1e5, 'T', T_amb, 'Water') * 1e-3;

%% 2. EXTRACT OPERATIONAL ARRAYS & THERMODYNAMIC STATES
% --- HP Header (50 bar) ---
m_50_raw   = Get(data, 'KW_821_14FE_0015');
P_in_v_raw = Get(data, 'KW_921PISA001_XQ01'); % [bar]
t_50_raw   = Get(data, 'KW_821_14TI0015');    % [°C]
m_50     = mean(m_50_raw(active_idx), 'omitnan') / 3.6;
P_in_v   = mean(P_in_v_raw(active_idx), 'omitnan');
t_50   = mean(t_50_raw(active_idx), 'omitnan');
h_50  = coolprop('H', 'P', P_in_v * 1e5, 'T', t_50 + 273.15, 'Water') * 1e-3;
s_50   = coolprop('S', 'P', P_in_v * 1e5, 'T', t_50 + 273.15, 'Water') * 1e-3;

% --- LD Header (2.5 bar) ---
p_25_raw = Get(data, 'KW_923PICA001_XQ01'); % [bar]
t_25_raw     = Get(data, 'KW_923TIA001_XQ01');  % [°C]
p_25   = mean(p_25_raw(active_idx), 'omitnan');
t_25   = mean(t_25_raw(active_idx), 'omitnan');
h_25  = coolprop('H', 'P', p_25 * 1e5, 'T', t_25 + 273.15, 'Water') * 1e-3;
s_25   = coolprop('S', 'P', p_25 * 1e5, 'T', t_25 + 273.15, 'Water') * 1e-3;

% --- Turbine ---
m_turb_raw = Get(data, 'KW_921_01FE0101');
p_turb_raw = Get(data, 'KW_921_00PI0101');
t_turb_raw = Get(data, 'KW_921_00TI0101');
t_turb_out_raw = Get(data, 'KW_923_00TI0201');
p_turb_out_raw = Get(data, 'KW_923_00PI0201');
m_turb   = mean(m_turb_raw(active_idx), 'omitnan') / 3.6;
p_turb   = mean(p_turb_raw(active_idx), 'omitnan');
t_turb   = mean(t_turb_raw(active_idx), 'omitnan');
p_turb_out   = mean(p_turb_out_raw(active_idx), 'omitnan');
t_turb_out   = mean(t_turb_out_raw(active_idx), 'omitnan');
h_turb  = coolprop('H', 'P', p_turb * 1e5, 'T', t_turb + 273.15, 'Water') * 1e-3;
s_turb   = coolprop('S', 'P', p_turb * 1e5, 'T', t_turb + 273.15, 'Water') * 1e-3;
h_turb_out  = coolprop('H', 'P', p_turb_out * 1e5, 'T', t_turb_out + 273.15, 'Water') * 1e-3;
s_turb_out   = coolprop('S', 'P', p_turb_out * 1e5, 'T', t_turb_out + 273.15, 'Water') * 1e-3;
h_turb_ideal = coolprop('H', 'S',s_turb * 1e3,'P',p_turb_out * 1e5, 'Water') * 1e-3;

% --- Injection / Desuperheating Water ---
p_water_raw = Get(data, 'KW_836PIA008_XQ01');
t_water_raw = Get(data, 'KW_836_00TI0201');
p_water   = mean(p_water_raw(active_idx), 'omitnan');
t_water   = mean(t_water_raw(active_idx), 'omitnan');
h_water  = coolprop('H', 'P', p_water * 1e5, 'T', t_water + 273.15, 'Water') * 1e-3;
s_water   = coolprop('S', 'P', p_water * 1e5, 'T', t_water + 273.15, 'Water') * 1e-3;

% --- Boiler 15 ---
m_k15_raw = Get(data, 'KW_821_15_FIQ0206');
p_k15_raw = Get(data, 'KW_921_00P203');
t_k15_raw = Get(data, 'KW_921TICA002_XQ01');
m_k15   = mean(m_k15_raw(active_idx), 'omitnan') / 3.6;
p_k15   = mean(p_k15_raw(active_idx), 'omitnan');
t_k15   = mean(t_k15_raw(active_idx), 'omitnan');
h_k15  = coolprop('H', 'P', p_k15 * 1e5, 'T', t_k15 + 273.15, 'Water') * 1e-3;
s_k15   = coolprop('S', 'P', p_k15 * 1e5, 'T', t_k15 + 273.15, 'Water') * 1e-3;

% --- MD Header (20 bar) ---
P_mout_v_raw = Get(data, 'KW_921PICA029_XQ01'); % [Bar]
t_20_raw     = Get(data, 'KW_921TICA002_XQ01'); % [°C]
P_mout_v   = mean(P_mout_v_raw(active_idx), 'omitnan');
t_20   = mean(t_20_raw(active_idx), 'omitnan');
h_20  = coolprop('H', 'P', P_mout_v * 1e5, 'T', t_20 + 273.15, 'Water') * 1e-3;
s_20   = coolprop('S', 'P', P_mout_v * 1e5, 'T', t_20 + 273.15, 'Water') * 1e-3;

% --- City Heating & Vent ---
m_Lvent_in_raw = Get(data, 'KW_923-00FIQ033');
m_Svent_in_raw = Get(data, 'KW_TC_923FIQ042'); % missing 90% of data
m_w_city_raw   = Get(data, 'KW_834-00FIQA031');
m_Lvent_in   = mean(m_Lvent_in_raw(active_idx), 'omitnan') / 3.6;
m_Svent_in   = mean(m_Svent_in_raw(active_idx), 'omitnan') / 3.6;
m_w_city   = mean(m_w_city_raw(active_idx), 'omitnan') / 3.6;
p_city_in_raw  = Get(data, 'KW_834-00PISA043');
t_city_in_raw  = Get(data, 'KW_834-00TIA034');
p_city_in   = mean(p_city_in_raw(active_idx), 'omitnan');
t_city_in   = mean(t_city_in_raw(active_idx), 'omitnan');
p_city_out_raw = Get(data, 'KW_834-00PIZA046');
t_city_out_raw = Get(data, 'KW_834-00TICSA036');
p_city_out   = mean(p_city_out_raw(active_idx), 'omitnan');
t_city_out   = mean(t_city_out_raw(active_idx), 'omitnan');
h_city_in   = coolprop('H', 'P', p_city_in * 1e5, 'T', t_city_in + 273.15, 'Water') * 1e-3;
s_city_in    = coolprop('S', 'P', p_city_in * 1e5, 'T', t_city_in + 273.15, 'Water') * 1e-3;
h_city_out   = coolprop('H', 'P', p_city_out * 1e5, 'T', t_city_out + 273.15, 'Water') * 1e-3;
s_city_out   = coolprop('S', 'P', p_city_out * 1e5, 'T', t_city_out + 273.15, 'Water') * 1e-3;

% Energy balance over the city heating condenser.
h_condensate = h_city_out; % Approximating steam condensate out = water out temp
m_steam_city = m_w_city .* (h_city_out - h_city_in) ./ (h_25 - h_condensate);
% Steam that isn't condensed for city heating is lost to the large vent
m_Lvent_loss = m_steam_city - m_Lvent_in;

% 2. Calculate raw enthalpy arrays (assuming h_25 is a constant or has a raw vector counterpart)
h_city_in_raw  = coolprop('H', 'P', p_city_in_raw * 1e5, 'T', t_city_in_raw + 273.15, 'Water') * 1e-3;
h_city_out_raw = coolprop('H', 'P', p_city_out_raw * 1e5, 'T', t_city_out_raw + 273.15, 'Water') * 1e-3;
h_condensate_raw = h_city_out_raw;

% 3. Compute raw steam mass flow vector using element-by-element operations (.* and ./)
m_steam_city_raw = (m_w_city_raw ./ 3.6) .* (h_city_out_raw - h_city_in_raw) ./ (h_25 - h_condensate_raw);

% --- Deaerator ---
% Deaerator blows steam into the degasser, exergy out in this system and a
% point where improvements can be made. What if you got the steam from somewhere else? 
m_dead_raw = Get(data, 'KW_923FIQ015A_XQ01');
m_dead   = mean(m_dead_raw(active_idx), 'omitnan') / 3.6;

% --- Sootblower ---
% Useful steam out of the system
m_soot_raw = Get(data, 'KW_821_14FIA0001');
m_soot   = mean(m_soot_raw(active_idx), 'omitnan') / 3.6;

% --- Low Pressure Steam Clients ---
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

m_lp_users  = LD_Client_01 + LD_Client_02 + LD_Client_03 + LD_Client_04 + LD_Client_05 + ...
    LD_Client_06 + LD_Client_07 + LD_Client_08 + LD_Client_09 + ...
    LD_Client_10 + LD_Client_11 + LD_Client_12 + LD_Client_13 + LD_Client_14;

m_lp_users_raw  = LD_Client_01_raw + LD_Client_02_raw + LD_Client_03_raw + LD_Client_04_raw + LD_Client_05_raw + ...
    LD_Client_06_raw + LD_Client_07_raw + LD_Client_08_raw + LD_Client_09_raw + ...
    LD_Client_10_raw + LD_Client_11_raw + LD_Client_12_raw + LD_Client_13_raw + LD_Client_14_raw;

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

m_mp_users = MD_Client_01 + MD_Client_02 + MD_Client_03 + MD_Client_04 + MD_Client_05;
m_mp_users_raw = MD_Client_01_raw + MD_Client_02_raw + MD_Client_03_raw + MD_Client_04_raw + MD_Client_05_raw;

% --- PRV 5 ---
% Downstream Reducer 5 & 6 Data
% Unmixed steam coming from the 50 bar system into the PRVs
m_steam_to_prv = m_50 - m_turb;
m_steam_to_prv_raw = m_50_raw - m_turb_raw;

% Spray water mass flow via steady-state energy balance
m_w = m_steam_to_prv .* (h_50 - h_20) ./ (h_20 - h_water);
m_prv = m_steam_to_prv + m_w;

% Spray water mass flow vector (time-series) via steady-state energy balance
P_in_v_raw_safe = max(P_in_v_raw, 0.05);
t_50_raw_safe = max(t_50_raw, 0.01);
P_mout_v_raw_safe = max(P_mout_v_raw, 0.05);
t_20_raw_safe = max(t_20_raw, 0.01);
p_water_raw_safe = max(p_water_raw, 0.05);
t_water_raw_safe = max(t_water_raw, 0.01);

h_50_raw = coolprop('H', 'P', P_in_v_raw_safe * 1e5, 'T', t_50_raw_safe + 273.15, 'Water') * 1e-3;
h_20_raw = coolprop('H', 'P', P_mout_v_raw_safe * 1e5, 'T', t_20_raw_safe + 273.15, 'Water') * 1e-3;
h_water_raw = coolprop('H', 'P', p_water_raw_safe * 1e5, 'T', t_water_raw_safe + 273.15, 'Water') * 1e-3;
m_w_raw = m_steam_to_prv_raw .* (h_50_raw - h_20_raw) ./ max(h_20_raw - h_water_raw, 1);
m_prv_raw = m_steam_to_prv_raw + m_w_raw;

p_prv5_raw = Get(data, 'KW_921PICA021_XQ01');
t_prv5_raw = Get(data, 'KW_921TICA021_XQ01');
p_prv5   = mean(p_prv5_raw(active_idx), 'omitnan');
t_prv5   = mean(t_prv5_raw(active_idx), 'omitnan');
h_prv   = coolprop('H', 'P', p_prv5 * 1e5, 'T', t_prv5 + 273.15, 'Water') * 1e-3;
s_prv    = coolprop('S', 'P', p_prv5 * 1e5, 'T', t_prv5 + 273.15, 'Water') * 1e-3;

% Mass through 20 bar header
m_20 = m_prv + m_k15;

% Steam drum
m_drum = m_20 - m_mp_users;

% 2.5 bar header
m_25 = m_turb + m_drum - m_lp_users - m_Lvent_in - m_Svent_in - m_dead - m_soot;

%% Boiler 14 (Time-Series Vectors & 80% Capacity Window)
m_14_time = Get(data, 'KW_821_14FE_0015') / 3.6;
T_14_time = Get(data, 'KW_821_14TI0015');
P_14_time = Get(data, 'KW_821_14PI0015');
T14_fw_time = Get(data, 'KW_836T008_XQ01');
m14_chem_time = Get(data, 'KW_821_14FIT7301') / 3.6; % Anonymized chemical/additive flow
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
X14_fg = m14_flue * 1.08 * ((T14_fgeco + 273.15) - (T_amb)) - (T_amb + 273.15) * log((T14_fgeco + 273.15)/(T_amb));
e14_water = (h14_fw - h_amb) - (T_amb) * (s14_fw - s_amb);
e14_steam = (h14_s - h_amb) - (T_amb) * (s14_s - s_amb);

k14_eff = 0.9; % Assumed Boiler Efficiency
HHV_solid_fuel = 11000; % KJ/kg (HHV value of solid biomass/fuel chips)
X14_fw = e14_water * m14_fw;
X14 = e14_steam * m_14;
m14_fuel = (m_14 * (h14_s - h14_fw)) / (k14_eff * HHV_solid_fuel);
k14_2eff = (e14_steam * m_14 - e14_water * m14_fw) / (m14_fuel * HHV_solid_fuel);

%% Boiler 15 (Filtered for Active Operation & Time-Series Plotting)
fuel_raw  = Get(data, 'KW_821_15_FITQ5001');
steam_raw = Get(data, 'KW_821_15_FIQ0206');
fw_raw    = Get(data, 'KW_821_15_FIQ0202');
T15_raw   = Get(data, 'KW_921T022_XQ01');
T15fw_raw  = Get(data, 'KW_821_15TT5004');
P15_raw   = Get(data, 'KW_921_00P203');
T15_fw_raw = Get(data, 'KW_921_00P203');
P15_fw_raw = Get(data, 'KW_836_00PICA0205');

% Mean calculations for Active Steady-State
m15_fuel = (mean(fuel_raw(active_idx), 'omitnan') * 0.8) / 3600;
m_15     = mean(steam_raw(active_idx), 'omitnan') / 3.6;
m15_fw   = mean(fw_raw(active_idx), 'omitnan') / 3.6;
T_15     = mean(T15_raw(active_idx), 'omitnan');
P_15     = mean(P15_raw(active_idx), 'omitnan');
T15_fw   = mean(T15_fw_raw(active_idx), 'omitnan');
P15_fw   = mean(P15_fw_raw(active_idx), 'omitnan');

% Thermodynamic Properties (Mean values)
h15_fw = coolprop('H', 'P', P15_fw * 1e5, 'T', T15_fw + 273.15, 'Water') * 1e-3;
h15_s  = coolprop('H', 'P', P_15 * 1e5, 'T', T_15 + 273.15, 'Water') * 1e-3;
s15_fw = coolprop('S', 'P', P15_fw * 1e5, 'T', T15_fw + 273.15, 'Water') * 1e-3;
s15_s  = coolprop('S', 'P', P_15 * 1e5, 'T', T_15 + 273.15, 'Water') * 1e-3;
e15_water = (h15_fw - h_amb) - (T_amb)*(s15_fw - s_amb);
e15_steam = (h15_s - h_amb) - (T_amb)*(s15_s - s_amb);
e15_fuel  = 51.5 * 1e3;

% Steady-State Efficiencies
HHV_gas_fuel = 54.4 * 1e3; % Anonymized gas high-heating value
k15_eff  = (m_15 * (h15_s - h15_fw)) / (m15_fuel * HHV_gas_fuel);
k15_2eff = ((e15_steam * m_15) - (e15_water * m15_fw)) / (e15_fuel * m15_fuel);

%% Condensation volumetric flow return from clients (m3/h)
% Unable to verify units. Use the degasser inlet flow instead
condensate_cl1_raw = Get(data, 'KW_934F001_XQ01');   % FLOW CONDENSATE CLIENT 01
condensate_cl2_raw = Get(data, 'KW_934FIQ006_XQ01'); % FLOW CONDENSATE CLIENT 02
condensate_cl3_raw = Get(data, 'KW_934FIQ021_XQ01'); % FLOW CONDENSATE CLIENT 03
condensate_cl4_raw = Get(data, 'KW_934FIQ012');      % FLOW CONDENSATE CLIENT 04
temp_cl_02         = Get(data, 'KW_934T002_XQ01');   % TEMPERATURE CONDENSATE CLIENT 02 (°C)
temp_cl_03         = Get(data, 'KW_934T021_XQ01');   % TEMPERATURE CONDENSATE CLIENT 03 (°C)
conductivity_cl_01 = Get(data, 'KW_934QIA001_XQ01'); % CONDUCTIVITY CONDENSATE CLIENT 01 (µS/cm)

% Condensate volumetric flow return from buildings (m3/h)
condensate_b2_raw = Get(data, 'KW_934FIQ004_XQ01'); % FLOW CONDENSATE BLDG 02
condensate_b3_raw = Get(data, 'KW_934FIQ005_XQ01'); % FLOW CONDENSATE BLDG 03
condensate_b4_raw = Get(data, 'KW_934FIQ007_XQ01'); % FLOW CONDENSATE BLDG 04
condensate_b5_raw = Get(data, 'KW_934FIQ008_XQ01'); % FLOW CONDENSATE BLDG 05
condensate_b6_raw = Get(data, 'KW_934FIQ009_XQ01'); % FLOW CONDENSATE BLDG 06

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
p_cond_raw = Get(data, 'KW_836PISA013_XQ01');
t_cond = mean(t_cond_raw(active_idx), 'omitnan');
p_cond = mean(p_cond_raw(active_idx),'omitnan');
h_cond = coolprop('H', 'P', p_cond * 1e5, 'T', t_cond + 273.15, 'Water') * 1e-3;
s_cond = coolprop('S', 'P', p_cond * 1e5, 'T', t_cond + 273.15, 'Water') * 1e-3;

% --- Degasser / Deaerator Tank ---
mcond1_raw  = Get(data, 'KW_836FIQ011_XQ01'); % Flow of condensate into the tanks
mcond2_raw  = Get(data, 'KW_836FIQ012_XQ01');
mcond_raw       = mcond1_raw(:) + mcond2_raw(:); 
mcond   = mean(mcond_raw(active_idx), 'omitnan') / 3.6;
mcond_out   = m14_fw + m15_fw + m_w; 
mcond_out_raw= m14_fw_time + fw_raw + m_w_raw;

% m_dead is the flow of steam into the tanks 
t_degasser_raw = Get(data, 'KW_836TI002_XQ01'); 
p_degasser_raw = Get(data, 'KW_836PICA002_XQ01'); 
t_degasser = mean(t_degasser_raw(active_idx), 'omitnan');
p_degasser = mean(p_degasser_raw(active_idx), 'omitnan');
h_degasser   = coolprop('H', 'P', p_degasser * 1e5, 'T', t_degasser + 273.15, 'Water') * 1e-3;
s_degasser   = coolprop('S', 'P', p_degasser * 1e5, 'T', t_degasser + 273.15, 'Water') * 1e-3;
e_degasser_in = (h_degasser - h_amb) - (s_degasser - s_amb)*T_amb;

% Demi water is added to the feedwater tanks
m_demi_raw = Get(data, 'KW_817FIQ101_XQ01'); 
m_demi = mean(m_demi_raw(active_idx), 'omitnan');

% --- Steam Drum ---
% Steam drum is the remains from the 20 bar header that does not get sent
% to the medium pressure users. It hides the losses from the 20 bar header.
% Spray water is added as well so the complete picture is unclear, the
% state of the steam when it returns is unknown as well.
m_drum_in = m_20 - m_mp_users;
p_drum = 15; % System outputs pressure at 15 bars
m_w_drum = mcond_out - m_cond;
m_w_drum_raw = mcond_out_raw - mcond_raw;
m_drum = m_drum_in + m_w_drum;

% Outlet conditions
h_drum = (h_20 * m_drum_in + h_water * m_w_drum)/m_drum;
s_drum = coolprop('S','H',h_drum *1e3, 'P', p_drum * 1e5, 'Water') * 1e-3;

%% Exergy calculations
% --- HP Header (50 bar) ---
e_50 = (h_50 - h_amb) - (s_50 - s_amb)*T_amb;
X_50 = e_50 * m_50;

% --- LD Header (2.5 bar) ---
e_25 = (h_25 - h_amb) - (s_25 - s_amb)*T_amb;
X_25 = e_25 * m_25;

% --- Turbine ---
% Useful work
e_turb = (h_turb - h_amb) - (s_turb - s_amb)*T_amb;
e_turb_out = (h_turb_out - h_amb) - (s_turb_out - s_amb)*T_amb;
X_turb = e_turb * m_turb;
X_turb_out = e_turb_out * m_turb;
therm_eff = 1 - ((t_turb_out+273.15) ./ (t_turb +273.15));     % Carnot Efficiency
secnd_eff = (h_turb - h_turb_out) ./ (e_turb - e_turb_out);    % Second Law / Exergetic Efficiency
turb_eff = ((h_turb-h_turb_out)/(h_turb-h_turb_ideal));        % First Law Efficiency

fprintf('\n=================== Turbine (Mean Values) ===================\n');
fprintf('Carnot Eff:             %.2f %%\n', therm_eff * 100);
fprintf('Isentropic Eff:         %.2f %%\n', turb_eff * 100);
fprintf('Second Law Efficiency:  %.2f %%\n', secnd_eff * 100);
fprintf('Work Out:  %.2f %%\n', secnd_eff * 100);
fprintf('Inlet Temperature:   %.2f C', t_turb);
fprintf(', Pressure: %.2f Bar\n' ,p_turb);
fprintf('Outlet Temperature:  %.2f C', t_turb_out);
fprintf(', Pressure: %.2f  Bar\n' ,p_turb_out);
fprintf('=========================================================\n');

% --- Injection / Desuperheating Water ---
% Water added to pressure reducing valve
e_water = (h_water - h_amb) - (s_water - s_amb)*T_amb;

% --- Boiler 15 ---
e_k15 = (h_k15 - h_amb) - (s_k15 - s_amb)*T_amb;
X_k15 = m_k15 * e_k15;

% --- MD Header (20 bar) ---
e_20 = (h_20 - h_amb) - (s_20 - s_amb)*T_amb;
X_20 = e_20 * m_20;

% --- City Heating & Vent ---
e_city_in = (h_city_in - h_amb) - (s_city_in - s_amb)*T_amb;
e_city_out = (h_city_out - h_amb) - (s_city_out - s_amb)*T_amb;
X_city = m_steam_city * e_25;
X_Lvent_loss = (m_Lvent_in - m_steam_city) * e_25;
X_Svent_loss = e_25 * m_Svent_in;

% --- Deaerator ---
X_dead = m_dead * e_25;

% --- Sootblower ---
X_soot = m_soot * e_25;

% --- Low pressure steam clients ---
X_lp_users = e_25 * m_lp_users;

% --- OUT FLOWS (MD Steam - 20 bar) ---
m_mp_users = MD_Client_01 + MD_Client_02 + MD_Client_03 + MD_Client_04 + MD_Client_05;
X_mp_users = e_20 * m_mp_users;

% --- PRV 5 ---
e_prv = (h_prv - h_amb) - (s_prv - s_amb)*T_amb;
X_water = m_w * e_water;
X_prv_in = m_steam_to_prv * e_50;
X_prv_out = (m_w + m_steam_to_prv) * e_prv;
eff2_prv = (m_w*(e_prv-e_water))/((m_steam_to_prv*(e_50-e_prv)));

% --- Steam Drum ---
e_drum_in = e_20;
e_w_drum = e_water;
e_drum = (h_drum - h_amb) - (s_drum - s_amb)*T_amb;
X_drum_in = e_drum_in * m_drum_in;
X_w_drum = e_w_drum * m_w_drum;
X_drum = e_drum * m_drum;
eff2_drum = (m_w_drum*(e_drum-e_w_drum))/(m_drum_in*(e_drum_in - e_drum));

%% Condensate exergy
m_dg1_raw = Get(data, 'KW_836FIQ011_XQ01');
m_dg1   = mean(m_dg1_raw(active_idx), 'omitnan') / 3.6;
m_dg2_raw = Get(data, 'KW_836FIQ012_XQ01');
m_dg2   = mean(m_dg2_raw(active_idx), 'omitnan') / 3.6;
m_dg = m_dg1_raw + m_dg2_raw;

p_dg1_raw = Get(data, 'KW_836PICA003_XQ01');
p_dg1   = mean(p_dg1_raw(active_idx), 'omitnan');
p_dg2_raw = Get(data, 'KW_836PICA002_XQ01');
p_dg2   = mean(p_dg2_raw(active_idx), 'omitnan');
t_dg1_raw = Get(data, 'KW_836TI002_XQ01');
t_dg1   = mean(t_dg1_raw(active_idx), 'omitnan');

h_dg1   = coolprop('H', 'P', p_dg1 * 1e5, 'T', t_dg1 + 273.15, 'Water') * 1e-3;
s_dg1    = coolprop('S', 'P', p_dg1 * 1e5, 'T', t_dg1 + 273.15, 'Water') * 1e-3;
h_dg2   = coolprop('H', 'P', p_dg2 * 1e5, 'T', t_dg1 + 273.15, 'Water') * 1e-3;
s_dg2    = coolprop('S', 'P', p_dg2 * 1e5, 'T', t_dg1 + 273.15, 'Water') * 1e-3;

e_dg1 = (h_dg1 - h_amb) - (s_dg1 - s_amb)*T_amb;
e_dg2 = (h_dg2 - h_amb) - (s_dg2 - s_amb)*T_amb;
X_dg1 = m_dg1 * e_dg1;
X_dg2 = m_dg2 * e_dg2;
X_dg = X_dg1 + X_dg2;

X_degasser_in = e_degasser_in * mcond;
X_degasser_out = mcond_out * e_water;
eff2_degasser = (m_cond*(X_degasser_out - X_degasser_in))/(m_dead*(X_dead - X_degasser_out));

%% Graph Boiler 14 Flow & Moving Average
figure('Name', 'Boiler 14 Steam Flow Analysis', 'Color', 'w');
hold on;
plot(time_raw, m_14_time, 'Color', [0.7, 0.85, 1], 'LineWidth', 1, 'DisplayName', 'Steam Flow');

% Calculate and overlay moving average on the matching full timeline
window_size = 200;
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
fprintf('\n=================== k-14 Boiler ===================\n');
fprintf('Steam Flow (m_14):         %.2f kg/s\n', m_14);
fprintf('Steam Temp (T_14):         %.2f °C\n', T_14);
fprintf('Steam Press (P_14):        %.2f bar\n', P_14);
fprintf('Fuel flow (m14_fuel):      %.2f kg/s\n', m14_fuel);
fprintf('Feedwater Flow (m14_fw):   %.2f kg/s\n', m14_fw);
fprintf('Flue Gas Temp (T14_fg):    %.2f °C\n', T14_fg);
fprintf('Eco Flue Gas Temp:         %.2f °C\n', T14_fgeco);
fprintf('Second Law Efficiency:     %.2f %%\n', k14_2eff * 100);
fprintf('Available work from flue gas: %.2f kW \n', X14_fg );
fprintf('=========================================================\n');

fprintf('\n=================== k-15 Boiler (Active) =================\n');
fprintf('Steam Flow (m_15):         %.2f kg/s\n', m_15);
fprintf('Steam Temp (T_15):         %.2f °C\n', T_15);
fprintf('Steam Press (P_15):        %.2f bar\n', P_15);
fprintf('Fuel flow (m15_fuel):      %.2f kg/s\n', m15_fuel);
fprintf('Feedwater Flow (m15_fw):   %.2f kg/s\n', m15_fw);
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
h15_fw_t  = coolprop('H', 'P', P15_fw * 1e5, 'T', T15_fw + 273.15, 'Water') * 1e-3;
s15_fw_t  = coolprop('S', 'P', P15_fw * 1e5, 'T', T15_fw + 273.15, 'Water') * 1e-3;

e15_steam_t = (h15_s_t - h_amb) - (T_amb + 273.15) .* (s15_s_t - s_amb);
e15_fw = (h15_fw_t - h_amb) - (T_amb + 273.15) .* (s15_fw_t - s_amb);
X15_fw = e15_water * m15_fw;
X15 = e15_steam_t * m_15;

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

%% Degasser mass flow and component comparison
m_dg_time = (m_dg1_raw + m_dg2_raw) / 3.6;
m_dg_boilerPRV = m14_fw_time + (fw_raw / 3.6) + (m_w_raw / 3.6) + (m_cond_raw/ 3.6);

% Plot comparison over the datetime timeline
figure('Name', 'Degasser Mass Flow Balance Analysis', 'Color', 'w');
hold on;
plot(time_raw, m_dg_time, 'Color', [0.7, 0.85, 1.0], 'LineWidth', 0.8, 'DisplayName', 'Raw Flow out of Degasser');
plot(time_raw, m_dg_boilerPRV, 'Color', [1.0, 0.85, 0.7], 'LineWidth', 0.8, 'DisplayName', 'Raw Flow into Boilers & PRV');

% Calculate and overlay moving averages
window_size = 200;
mdg_out_MA = movmean(m_dg_time, window_size, 'omitnan');
mdg_s_MA = movmean(m_dg_boilerPRV, window_size, 'omitnan');
plot(time_raw, mdg_out_MA, 'Color', [0.0, 0.4, 0.8], 'LineWidth', 2.5, 'DisplayName', 'MA Flow out of Degasser');
plot(time_raw, mdg_s_MA, 'Color', [0.8, 0.3, 0.0], 'LineWidth', 2.5, 'DisplayName', 'MA Flow into Boilers & PRV');
grid on; box on;
title('Degasser Outflow vs. Boiler/PRV Inflow Over Time');
xlabel('Time');
ylabel('Mass Flow Rate (kg/s)');
legend('Location', 'best');
xtickformat('dd-MM HH:mm');
xtickangle(45);
hold off;

% Compute and display mass balance differences during active operation
flow_diff = m_dg_time - m_dg_boilerPRV;
mean_diff = mean(flow_diff(active_idx), 'omitnan');
std_diff  = std(flow_diff(active_idx), 'omitnan');
rmse_diff = sqrt(mean(flow_diff(active_idx).^2, 'omitnan'));

fprintf('\n=================== Degasser Flow Comparison ===================\n');
fprintf('Mean Flow leaving Degasser:          %.2f kg/s\n', mean(m_dg_time(active_idx), 'omitnan'));
fprintf('Mean Flow into Boilers & PRV:        %.2f kg/s\n', mean(m_dg_boilerPRV(active_idx), 'omitnan'));
fprintf('Mean Difference (Out - In):          %.2f kg/s\n', mean_diff);
fprintf('Standard Deviation of Difference:    %.2f kg/s\n', std_diff);
fprintf('RMSE of Difference:                  %.2f kg/s\n', rmse_diff);
fprintf('=================================================================\n');

% Calculate turbine power and exergy destructions for reporting
W_turb     = m_turb * (h_turb - h_turb_out);
X_turb_dest = X_turb - X_turb_out - W_turb;
X_prv_dest  = (X_prv_in + X_water) - X_prv_out;
eta_turb_ex = W_turb / max(X_turb - X_turb_out, 1e-6) * 100;

fprintf('\n');
fprintf('================================================================================\n');
fprintf('                SYSTEM COMPONENT EXERGY SUMMARY (Mean Values)                  \n');
fprintf('================================================================================\n');
fprintf('%-34s %18s %16s %18s\n', 'Component / Stream', 'Spec. Exergy (kJ/kg)', 'Mass Flow (kg/s)', 'Total Exergy (kW)');
fprintf('--------------------------------------------------------------------------------\n');
% --- Steam Headers ---
fprintf('STEAM HEADERS:\n');
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'HP Header (50 bar)',   e_50,  m_50,  X_50);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'MD Header (20 bar)',   e_20,  m_20,  X_20);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'LD Header (2.5 bar)',  e_25,  m_25,  X_25);
% --- Boilers ---
fprintf('\nBOILERS:\n');
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'K14 Feedwater In',  e14_water, m14_fw,   X14_fw);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'K14 Steam Out',     e14_steam, m_14,     X14);
fprintf('  %-32s %18s %16.4f %18.2f\n',   'K14 Fuel (HHV)',    '11000',       m14_fuel, m14_fuel * HHV_solid_fuel);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'K15 Feedwater In',  e15_water, m15_fw,   X15_fw);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'K15 Steam Out',     e15_steam, m_15,     X_k15);
fprintf('  %-32s %18s %16.4f %18.2f\n',   'K15 Fuel (HHV)',    '51500',       m15_fuel, m15_fuel * HHV_gas_fuel);
% --- Turbine ---
fprintf('\nTURBINE:\n');
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Inlet Steam',              e_turb,     m_turb, X_turb);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Outlet Steam',             e_turb_out, m_turb, X_turb_out);
fprintf('  %-32s %18s %16s %18.2f\n',     'Power Output (kW)',        '-',         '-',    W_turb);
fprintf('  %-32s %18s %16s %18.2f\n',     'Exergy Destruction',       '-',         '-',    X_turb_dest);
fprintf('  %-32s %18.2f %16s %18s\n',     'Second Law Efficiency (%)', eta_turb_ex, '-',    '-');
% --- PRV ---
fprintf('\nPRV (50 bar -> 20 bar):\n');
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Inlet Steam',        e_50,    m_steam_to_prv, X_prv_in);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Injection Water',    e_water, m_w,            X_water);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Outlet Mixed',       e_prv,   m_prv,          X_prv_out);
fprintf('  %-32s %18s %16s %18.2f\n',     'Exergy Destruction', '-',     '-',             X_prv_dest);
fprintf('  %-32s %18.2f % %16s %18s\n',   'Second Law Efficiency (%)', eff2_prv * 100 , '-',    '-');
% --- Steam Drum ---
fprintf('\nSteam Drum:\n');
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Inlet Steam',    e_drum_in ,   m_drum_in ,   X_drum_in );
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Injection Water', e_w_drum, m_w_drum, X_w_drum);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Outlet Steam',    e_drum, m_drum, X_drum);
fprintf('  %-32s %18.2f %%\n', 'Second Law Efficiency',    eff2_drum *100);
% --- Degasser ---
fprintf('\nDEGASSER:\n');
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Condensate In', e_degasser_in, mcond,           '-');
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Steam In', e_25, m_dead,           X_dead);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Line 1 Outflow', e_dg1, m_dg1,           X_dg1);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Line 2 Outflow', e_dg2, m_dg2,           X_dg2);
fprintf('  %-32s %18s %16.4f %18.2f\n',   'Total Outflow',  '-',   mcond_out,   '-');
fprintf('  %-32s %18.2f %%\n', 'Second Law Efficiency',    eff2_degasser *100);

% --- MP Users (individual) ---
fprintf('\nMP USERS (individual):\n');
mp_names_ea = {'Client 01', 'Client 02', 'Client 03', 'Client 04', 'Client 05'};
mp_flows_ea = [MD_Client_01, MD_Client_02, MD_Client_03, MD_Client_04, MD_Client_05];
for k = 1:numel(mp_names_ea)
    X_mp_k = e_20 * mp_flows_ea(k);
    fprintf('  %-32s %18.2f %16.4f %18.2f\n', mp_names_ea{k}, e_20, mp_flows_ea(k), X_mp_k);
end
fprintf('  %-32s %18s %16.4f %18.2f\n', 'TOTAL MP Users', '-', m_mp_users, X_mp_users);

% --- LP Users (individual) ---
fprintf('\nLP USERS (individual):\n');
lp_names_ea = {'Client 01','Client 02','Client 03','Client 04','Client 05','Client 06','Client 07','Client 08','Client 09','Client 10','Client 11','Client 12','Client 13','Client 14'};
lp_flows_ea = [LD_Client_01, LD_Client_02, LD_Client_03, LD_Client_04, LD_Client_05, LD_Client_06, ...
               LD_Client_07, LD_Client_08, LD_Client_09, LD_Client_10, LD_Client_11, ...
               LD_Client_12, LD_Client_13, LD_Client_14];
for k = 1:numel(lp_names_ea)
    X_lp_k = e_25 * lp_flows_ea(k);
    fprintf('  %-32s %18.2f %16.4f %18.2f\n', lp_names_ea{k}, e_25, lp_flows_ea(k), X_lp_k);
end
fprintf('  %-32s %18s %16.4f %18.2f\n', 'TOTAL LP Users', '-', m_lp_users, X_lp_users);

% --- Other Sinks ---
fprintf('\nOTHER SINKS:\n');
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'City Heating',      e_25, m_steam_city, X_city);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Sootblower',        e_25, m_soot,       X_soot);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Deaerator (to Dg)', e_25, m_dead,       X_dead);
fprintf('\nVENT LOSSES:\n');
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Large Vent Loss', e_25, m_Lvent_in, X_Lvent_loss);
fprintf('  %-32s %18.2f %16.4f %18.2f\n', 'Small Vent Loss', e_25, m_Svent_in, X_Svent_loss);
fprintf('================================================================================\n');

%% 4. GRAPHS
% -------------------------------------------------------------------------
% Define Overall Mass In and Mass Out
Mass_In   = m_14_time + (m_k15_raw / 3.6) + (m_w_raw / 3.6); 
Mass_Out  = (m_Lvent_in_raw + m_Svent_in_raw + m_lp_users_raw + ...
             m_mp_users_raw + m_dead_raw + m_soot_raw) / 3.6; 
Mass_Diff = Mass_In - Mass_Out;

% --- MOVING AVERAGE CONFIGURATION ---
window_size = 600; 
Mass_In_MA   = movmean(Mass_In, window_size);
Mass_Out_MA  = movmean(Mass_Out, window_size);
Mass_Diff_MA = movmean(Mass_Diff, window_size);

% --- FIGURE 1: Mass In, Mass Out, and Difference ---
figure('Name', 'System Mass Balance', 'Position', [100, 100, 800, 600]);
subplot(3, 1, 1);
plot(Mass_In, 'Color', [0.6, 0.8, 1], 'LineWidth', 1);
hold on;
plot(Mass_In_MA, 'b', 'LineWidth', 2);
ylabel('Mass Flow (kg/s)');
title('Total Mass In (HP Steam + Boiler 15 + Desuperheating Water)');
legend('Raw Data', ['Moving Average (', num2str(window_size), ')'], 'Location', 'best');
grid on;

subplot(3, 1, 2);
plot(Mass_Out, 'Color', [1, 0.6, 0.6], 'LineWidth', 1);
hold on;
plot(Mass_Out_MA, 'r', 'LineWidth', 2);
ylabel('Mass Flow (kg/s)');
title('Total Mass Out (Flow to Vent, City & Users)');
legend('Raw Data', 'Moving Average', 'Location', 'best');
grid on;

mean_MassDiff = mean(Mass_Diff_MA, 'omitnan');
subplot(3, 1, 3);
plot(Mass_Diff, 'Color', [0.4, 0.8, 0.66], 'LineWidth', 1);
hold on;
plot(Mass_Diff_MA, 'Color', [0, 0.4, 0], 'LineWidth', 2);
xlabel('Time (s)');
ylabel('Mass Flow (kg/s)');
title(sprintf('Average Mass Difference: %.2f kg/s', mean_MassDiff));
legend('Raw Data', 'Moving Average', 'Location', 'best');
grid on;

% --- FIGURE 2: Mass Flow to Vent vs City ---
figure('Name', 'Vent vs City Mass Flow', 'Position', [150, 150, 800, 400]);
plot(m_steam_city_raw, 'Color', [0, 0.5, 0], 'LineWidth', 1.5, 'DisplayName', 'Mass Flow to City (Heating)');
hold on;
plot((m_Lvent_in_raw - m_steam_city_raw), 'r', 'LineWidth', 1.5, 'DisplayName', 'Mass Flow Vented (Loss)');
plot( m_Lvent_in_raw, 'b', 'LineWidth', 1.5, 'DisplayName', 'Mass Flow in');
xlabel('Samples (Time)'); 
ylabel('Mass Flow (kg/s)');
title('Mass Flow Allocation: Vent Losses vs City Heating');
legend('Location', 'best'); 
grid on;

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