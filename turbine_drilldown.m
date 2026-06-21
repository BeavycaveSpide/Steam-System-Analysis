%% =========================================================================
%  TURBINE DRILL-DOWN ANALYSIS  —  28 May → 1 Jun 2026
%  =========================================================================
%  Scope  : Deep dive into the Tuthill Nadrowski B5 turbine for a 5-day
%            window (00:00 May 28 to 23:59 Jun 1 2026).
%  Outputs: Time-series of mass flow, inlet/outlet T & P, computed power,
%            isentropic efficiency, second-law efficiency, and exergy
%            destruction — all as vectors and as summary statistics.
%
%  Dependencies: same CSV and CoolProp wrapper used by ExergyAnalysis.m
% =========================================================================
clear; clc; close all;
%% ── 1. CONFIGURATION ─────────────────────────────────────────────────────
filename = 'Cleaned_OneWeekData.csv';
fprintf('Loading data from %s ...\n', filename);
opts = detectImportOptions(filename);
opts.VariableNamingRule = 'preserve';
data = readtable(filename, opts);
% Reference ambient state (same as ExergyAnalysis.m)
T_amb = 25 + 273.15;   % [K]
P_amb = 1.01325;       % [bar]
h_amb = coolprop('H', 'P', P_amb * 1e5, 'T', T_amb, 'Water') * 1e-3;  % [kJ/kg]
s_amb = coolprop('S', 'P', P_amb * 1e5, 'T', T_amb, 'Water') * 1e-3;  % [kJ/(kg·K)]
%% ── 2. BUILD FULL TIMELINE ────────────────────────────────────────────────
% Dataset starts at 2026-05-25 08:01 with 1-minute resolution
N          = height(data);
time_raw   = datetime(2026, 5, 25, 8, 1, 0) + minutes(0:N-1)';
%% ── 3. EXTRACT TURBINE RAW VECTORS (full week) ────────────────────────────
m_turb_raw     = Get(data, 'KW_921_01FE0101');   % [t/h]
p_turb_raw     = Get(data, 'KW_921_00PI0101');   % [bar]
t_turb_raw     = Get(data, 'KW_921_00TI0101');   % [°C]
t_turb_out_raw = Get(data, 'KW_923_00TI0201');   % [°C]
p_turb_out_raw = Get(data, 'KW_923_00PI0201');   % [bar]
% Also pull the feedwater temperature tag used as the global active mask
% in ExergyAnalysis.m  (Tfw_in > 50 °C  →  system operational)
Tfw_in_raw = Get(data, 'KW_836TI002_XQ01');
%% ── 4. DEFINE ANALYSIS WINDOW  (May 28 00:00 → Jun 1 23:59) ──────────────
t_start = datetime(2026, 5, 28,  0, 0, 0);
t_end   = datetime(2026, 6, 1, 23, 59, 0);
window_idx = time_raw >= t_start & time_raw <= t_end;  % logical index
% Also apply the same operational mask as ExergyAnalysis.m so we only
% evaluate turbine state when the system is actually running.
active_full = Tfw_in_raw > 50;
combined_idx = window_idx & active_full;
if sum(window_idx) == 0
    error('No data falls within the May 28 – Jun 1 window. Check the dataset start date.');
end
fprintf('\nWindow  : %s  →  %s\n', datestr(t_start), datestr(t_end));
fprintf('Total samples in window   : %d\n', sum(window_idx));
fprintf('Active (Tfw > 50°C) samples: %d\n', sum(combined_idx));
%% ── 5. SLICE VECTORS TO THE WINDOW ───────────────────────────────────────
time_win       = time_raw(window_idx);
% Raw (all window samples — for plotting)
m_t_win        = m_turb_raw(window_idx)     / 3.6;   % [kg/s]
p_in_win       = p_turb_raw(window_idx);              % [bar]
t_in_win       = t_turb_raw(window_idx);              % [°C]
t_out_win      = t_turb_out_raw(window_idx);          % [°C]
p_out_win      = p_turb_out_raw(window_idx);          % [bar]
% Active-only index (within the window slice)
act_win        = combined_idx(window_idx);            % logical, same length as time_win
%% ── 6. SAFE THERMODYNAMIC PROPERTY CALCULATION ───────────────────────────
% Guard against CoolProp out-of-range inputs (sensor dropouts → 0 bar / 0 °C)
p_in_safe  = max(p_in_win,  0.05);
t_in_safe  = max(t_in_win,  100);
p_out_safe = max(p_out_win, 0.05);
t_out_safe = max(t_out_win, 100);
h_in  = coolprop('H', 'P', p_in_safe  * 1e5, 'T', t_in_safe  + 273.15, 'Water') * 1e-3;
s_in  = coolprop('S', 'P', p_in_safe  * 1e5, 'T', t_in_safe  + 273.15, 'Water') * 1e-3;
h_out = coolprop('H', 'P', p_out_safe * 1e5, 'T', t_out_safe + 273.15, 'Water') * 1e-3;
s_out = coolprop('S', 'P', p_out_safe * 1e5, 'T', t_out_safe + 273.15, 'Water') * 1e-3;
% Isentropic outlet enthalpy (ideal expansion at constant entropy)
h_ideal = coolprop('H', 'S', s_in * 1e3, 'P', p_out_safe * 1e5, 'Water') * 1e-3;
%% ── 7. PERFORMANCE METRICS (time-series vectors) ─────────────────────────
% Power output  [kW]
W_turb = m_t_win .* (h_in - h_out);
% Specific exergy at inlet and outlet  [kJ/kg]
e_in  = (h_in  - h_amb) - T_amb .* (s_in  - s_amb);
e_out = (h_out - h_amb) - T_amb .* (s_out - s_amb);
% Total exergy flow rates  [kW]
X_in  = e_in  .* m_t_win;
X_out = e_out .* m_t_win;
% Exergy destruction  [kW]
X_dest = X_in - X_out - W_turb;
% Isentropic (first-law) efficiency  [%]
eta_is = (h_in - h_out) ./ max(h_in - h_ideal, 1e-6) * 100;
% Second-law (exergetic) efficiency  [%]
eta_2L = W_turb ./ max(X_in - X_out, 1e-6) * 100;
% Carnot efficiency proxy  [%]
eta_carnot = (1 - (t_out_win + 273.15) ./ (t_in_win + 273.15)) * 100;
% Clip physically implausible values (sensor dropouts, startup transients)
eta_is(eta_is > 100 | eta_is < 0) = NaN;
eta_2L(eta_2L > 100 | eta_2L < 0) = NaN;
W_turb(W_turb < 0)                 = NaN;
X_dest(X_dest < 0)                 = NaN;
% Zero mass-flow instants → all derived metrics NaN
no_flow = m_t_win < 0.05;
eta_is(no_flow) = NaN;
eta_2L(no_flow) = NaN;
W_turb(no_flow) = NaN;
X_dest(no_flow) = NaN;
%% ── 8. MOVING AVERAGES ────────────────────────────────────────────────────
win_MA = 240;   % 4-hour rolling window (240 samples × 1 min/sample)
m_MA      = movmean(m_t_win,   win_MA, 'omitnan');
W_MA      = movmean(W_turb,    win_MA, 'omitnan');
eta_is_MA = movmean(eta_is,    win_MA, 'omitnan');
eta_2L_MA = movmean(eta_2L,    win_MA, 'omitnan');
X_dest_MA = movmean(X_dest,    win_MA, 'omitnan');
%% ── 9. CONSOLE SUMMARY ────────────────────────────────────────────────────
m_mean     = mean(m_t_win(act_win),  'omitnan');
p_in_mean  = mean(p_in_win(act_win), 'omitnan');
t_in_mean  = mean(t_in_win(act_win), 'omitnan');
p_out_mean = mean(p_out_win(act_win),'omitnan');
t_out_mean = mean(t_out_win(act_win),'omitnan');
W_mean     = mean(W_turb(act_win),   'omitnan');
W_peak     = max(W_turb(act_win),    [],         'omitnan');
eta_is_mean= mean(eta_is(act_win),   'omitnan');
eta_2L_mean= mean(eta_2L(act_win),   'omitnan');
Xd_mean    = mean(X_dest(act_win),   'omitnan');
fprintf('\n');
fprintf('==========================================================\n');
fprintf('   TURBINE DRILL-DOWN  —  28 May – 1 Jun 2026  (Active Only)\n');
fprintf('==========================================================\n');
fprintf('  Inlet temperature   (mean):  %7.2f  °C\n',  t_in_mean);
fprintf('  Inlet pressure      (mean):  %7.2f  bar\n', p_in_mean);
fprintf('  Outlet temperature  (mean):  %7.2f  °C\n',  t_out_mean);
fprintf('  Outlet pressure     (mean):  %7.2f  bar\n', p_out_mean);
fprintf('----------------------------------------------------------\n');
fprintf('  Mass flow           (mean):  %7.3f  kg/s\n', m_mean);
fprintf('  Power output        (mean):  %7.1f  kW\n',  W_mean);
fprintf('  Power output        (peak):  %7.1f  kW\n',  W_peak);
fprintf('----------------------------------------------------------\n');
fprintf('  Isentropic eff.     (mean):  %7.2f  %%\n',  eta_is_mean);
fprintf('  Second-law eff.     (mean):  %7.2f  %%\n',  eta_2L_mean);
fprintf('  Exergy destruction  (mean):  %7.1f  kW\n',  Xd_mean);
fprintf('==========================================================\n\n');

% 
% % ── Figure 5a: Isentropic Efficiency (30-31 May) ──────────────────────────
% figure('Name', 'Turbine Isentropic Efficiency — 28 May – 1 Jun', 'Color', 'w');
% hold on;
% plot(time_win, eta_is,    'Color', [0.70 0.85 1.00], 'LineWidth', 0.8, ...
%      'DisplayName', 'η_{is} (raw)');
% plot(time_win, eta_is_MA, 'Color', [0.00 0.35 0.75], 'LineWidth', 2.5, ...
%      'DisplayName', sprintf('η_{is} MA (%d min)', win_MA));
% yline(eta_is_mean, '--', 'Color', [0.00 0.35 0.75], 'LineWidth', 1.2, ...
%       'DisplayName', sprintf('Mean = %.1f %%', eta_is_mean));
% grid on; box on;
% 
% title('Turbine Isentropic Efficiency (\eta_{is}) — 28 May – 1 Jun 2026');
% xlabel('Time'); 
% ylabel('η_{is} (%)');
% legend('Location', 'best');
% xtickformat('dd-MM HH:mm'); 
% xtickangle(45);
% ylim([0 110]);
% hold off;
% 
% % ── Figure 5b: Second-Law (Exergetic) Efficiency (30-31 May) ──────────────
% figure('Name', 'Turbine Second-Law Efficiency — 28 May – 1 Jun', 'Color', 'w');
% hold on;
% plot(time_win, eta_2L,    'Color', [1.00 0.80 0.65], 'LineWidth', 0.8, ...
%      'DisplayName', 'η_{II} (raw)');
% plot(time_win, eta_2L_MA, 'Color', [0.75 0.20 0.00], 'LineWidth', 2.5, ...
%      'DisplayName', sprintf('η_{II} MA (%d min)', win_MA));
% yline(eta_2L_mean, '--', 'Color', [0.75 0.20 0.00], 'LineWidth', 1.2, ...
%       'DisplayName', sprintf('Mean = %.1f %%', eta_2L_mean));
% grid on; box on;
% 
% title('Turbine Second-Law (Exergetic) Efficiency (\eta_{II}) — 28 May – 1 Jun 2026');
% xlabel('Time'); 
% ylabel('η_{II} (%)');
% legend('Location', 'best');
% xtickformat('dd-MM HH:mm'); 
% xtickangle(45);
% ylim([0 110]);
% hold off;
% 
% % ── Fig 6 : Exergy destruction ───────────────────────────────────────────
% figure('Name', 'Turbine Exergy Destruction — 28 May – 1 Jun', 'Color', 'w');
% hold on;
% plot(time_win, X_dest,    'Color', [1.00 0.65 0.65], 'LineWidth', 0.8, ...
%      'DisplayName', 'X_{dest} (raw)');
% plot(time_win, X_dest_MA, 'Color', [0.80 0.00 0.00], 'LineWidth', 2.5, ...
%      'DisplayName', sprintf('MA (%d min)', win_MA));
% yline(Xd_mean, '--', 'Color', [0.80 0.00 0.00], 'LineWidth', 1.2, ...
%       'DisplayName', sprintf('Mean = %.1f kW', Xd_mean));
% grid on; box on;
% title('Turbine: Exergy Destruction — 28 May – 1 Jun 2026');
% xlabel('Time');
% ylabel('Exergy Destruction (kW)');
% legend('Location', 'best');
% xtickformat('dd-MM HH:mm');
% xtickangle(45);
% hold off;
% 
% % ── Fig 7 : Four-panel overview dashboard ────────────────────────────────
% figure('Name', 'Turbine Overview Dashboard — 28 May – 1 Jun', ...
%        'Color', 'w', 'Position', [50 50 1400 900]);
% 
% ax1 = subplot(2, 2, 1);
% hold on;
% plot(time_win, m_t_win, 'Color', [0.70 0.85 1.00], 'LineWidth', 0.8);
% plot(time_win, m_MA,    'Color', [0.00 0.35 0.75], 'LineWidth', 2.5);
% yline(m_mean, '--', 'Color', [0.00 0.35 0.75], 'LineWidth', 1.0);
% title('Mass Flow (kg/s)'); xlabel('Time'); ylabel('kg/s');
% grid on; box on; xtickformat('dd-MM HH:mm'); xtickangle(45);
% hold off;
% 
% ax2 = subplot(2, 2, 2);
% hold on;
% plot(time_win, W_turb, 'Color', [0.85 0.85 0.40], 'LineWidth', 0.8);
% plot(time_win, W_MA,   'Color', [0.55 0.45 0.00], 'LineWidth', 2.5);
% yline(W_mean, '--', 'Color', [0.55 0.45 0.00], 'LineWidth', 1.0);
% title('Power Output (kW)'); xlabel('Time'); ylabel('kW');
% grid on; box on; xtickformat('dd-MM HH:mm'); xtickangle(45);
% hold off;
% 
% ax3 = subplot(2, 2, 3);
% hold on;
% plot(time_win, t_in_win,  'Color', [1.00 0.50 0.20], 'LineWidth', 1.2, 'DisplayName', 'T_{in}');
% plot(time_win, t_out_win, 'Color', [0.20 0.60 0.95], 'LineWidth', 1.2, 'DisplayName', 'T_{out}');
% title('Temperature (°C)'); xlabel('Time'); ylabel('°C');
% legend('Location', 'best');
% grid on; box on; xtickformat('dd-MM HH:mm'); xtickangle(45);
% hold off;
% 
% ax4 = subplot(2, 2, 4);
% hold on;
% plot(time_win, eta_is,    'Color', [0.70 0.85 1.00], 'LineWidth', 0.8, 'DisplayName', 'η_{is} raw');
% plot(time_win, eta_is_MA, 'Color', [0.00 0.35 0.75], 'LineWidth', 2.5, 'DisplayName', 'η_{is} MA');
% plot(time_win, eta_2L_MA, 'Color', [0.75 0.20 0.00], 'LineWidth', 2.5, 'DisplayName', 'η_{II} MA');
% yline(eta_is_mean, '--', 'Color', [0.00 0.35 0.75], 'LineWidth', 1.0);
% yline(eta_2L_mean, '--', 'Color', [0.75 0.20 0.00], 'LineWidth', 1.0);
% title('Efficiency (%)'); xlabel('Time'); ylabel('%');
% ylim([0 110]); legend('Location', 'best');
% grid on; box on; xtickformat('dd-MM HH:mm'); xtickangle(45);
% hold off;
% 
% linkaxes([ax1 ax2 ax3 ax4], 'x');
% sgtitle('Turbine Overview Dashboard — 28 May – 1 Jun 2026', 'FontSize', 14, 'FontWeight', 'bold');
% 
% fprintf('All figures generated. Analysis complete.\n');
%% ── 11. CONSTANT MASS FLOW SCENARIO ────────────────────────────────────────
%  Purpose: Evaluate power output and exergetic behaviour when forced to
%           run at a fixed, constant mass flow rate.
% ─────────────────────────────────────────────────────────────────────────────
m_setpoint_kg =1.7;  % [kg/s] Define your set mass flow rate here
% 1. Time-series vectors based on the set mass flow
W_turb_set   = m_setpoint_kg .* (h_in - h_out);          % Power output [kW]
X_in_set     = e_in  .* m_setpoint_kg;                   % Inlet exergy flow [kW]
X_out_set    = e_out .* m_setpoint_kg;                   % Outlet exergy flow [kW]
X_dest_set   = X_in_set - X_out_set - W_turb_set;        % Exergy destruction [kW]
% 2. Clean transients and sensor drops using your logic
W_turb_set(W_turb_set < 0) = NaN;
X_dest_set(X_dest_set < 0) = NaN;
% 3. Integrate over active operational periods to find total kWh yields
valid_set = act_win & ~isnan(W_turb_set) & ~isnan(X_dest_set);
if any(valid_set)
    t_s_set = seconds(time_win(valid_set) - time_win(1)); % Time vector in seconds
    
    E_total_set_kWh  = trapz(t_s_set, W_turb_set(valid_set)) / 3600;
    Xd_total_set_kWh = trapz(t_s_set, X_dest_set(valid_set)) / 3600;
    X_drop_set_kWh   = trapz(t_s_set, X_in_set(valid_set) - X_out_set(valid_set)) / 3600;
    
    W_mean_set = mean(W_turb_set(valid_set), 'omitnan');
    Xd_mean_set = mean(X_dest_set(valid_set), 'omitnan');
else
    E_total_set_kWh = 0; Xd_total_set_kWh = 0; X_drop_set_kWh = 0;
    W_mean_set = 0; Xd_mean_set = 0;
end
%% ── 12. CONSTANT MASS FLOW SUMMARY ─────────────────────────────────────────
fprintf('==========================================================\n');
fprintf('   FIXED MASS FLOW SIMULATION (m = %.2f kg/s)             \n', m_setpoint_kg);
fprintf('==========================================================\n');
fprintf('  Simulated Power     (mean):  %7.1f  kW\n',  W_mean_set);
fprintf('  Exergy Destruction  (mean):  %7.1f  kW\n',  Xd_mean_set);
fprintf('----------------------------------------------------------\n');
fprintf('  Total Energy Yield        :  %7.1f  kWh\n',  E_total_set_kWh);
fprintf('  Total Exergy Converted    :  %7.1f  kWh (Fluid stream drop)\n', X_drop_set_kWh);
fprintf('  Total Exergy Destroyed    :  %7.1f  kWh\n',  Xd_total_set_kWh);
fprintf('==========================================================\n\n');
%% ── 13. BIDIRECTIONAL AREA ANALYSIS — CONFIGURATION ────────────────────────
analysis_type = 'energy';
switch lower(analysis_type)
    case 'mass'
        y_signal        = m_t_win;
        threshold_value = m_setpoint_kg;
        %threshold_value = 3.27;
        var_label       = 'Mass Flow';
        var_unit        = 'kg';
        y_unit_label    = 'kg/s';
        scale_factor    = 1;
    case 'energy'
        y_signal        = W_turb;
        threshold_value = W_mean_set;
        %threshold_value = 1063.4;
        var_label       = 'Power Output';
        var_unit        = 'kWh';
        y_unit_label    = 'kW';
        scale_factor    = 1 / 3600;
    case 'exergy'
        y_signal        = X_dest;
        threshold_value = Xd_mean_set;
        var_label       = 'Exergy Destruction';
        var_unit        = 'kWh';
        y_unit_label    = 'kW';
        scale_factor    = 1 / 3600;
    otherwise
        error('Invalid analysis_type. Choose ''mass'', ''energy'', or ''exergy''.');
end
%% ── 14. DATA CLEANING & VALIDATION ──────────────────────────────────────────
valid_mask = combined_idx(window_idx) & ~isnan(y_signal);
t_valid    = time_win(valid_mask);
y_valid    = y_signal(valid_mask);
t_valid = t_valid(:);
y_valid = y_valid(:);
t_sec   = seconds(t_valid - t_valid(1));
%% ── 14b. SMOOTHING — moving average to suppress sensor jitter ───────────────
% Tune sg_window (must be odd) to taste:
%   larger  → smoother curve, more peak attenuation
%   smaller → preserves transients better
sg_window = 80;  % samples
y_smooth = movmean(y_valid, sg_window, 'omitnan');
%% ── 15. SIMULTANEOUS BIDIRECTIONAL SEGMENTATION ────────────────────────────
% Segmentation and integration operate on the SMOOTHED signal.
% The raw signal is retained only for the background plot overlay.
is_above = y_smooth > threshold_value;
start_above  = find(diff([0; is_above])  ==  1);
end_above    = find(diff([is_above; 0])  == -1);
labels_above = repmat({'Above'}, length(start_above), 1);
is_below = y_smooth < threshold_value;
start_below  = find(diff([0; is_below])  ==  1);
end_below    = find(diff([is_below; 0])  == -1);
labels_below = repmat({'Below'}, length(start_below), 1);
all_starts   = [start_above;  start_below];
all_ends     = [end_above;    end_below];
all_types    = [labels_above; labels_below];
num_segments = length(all_starts);
segment_areas     = zeros(num_segments, 1);
segment_durations = zeros(num_segments, 1);
%% ── 16. GEOMETRIC INTEGRATION LOOP ──────────────────────────────────────────
for i = 1:num_segments
    s = all_starts(i);
    e = all_ends(i);
    seg_t_sec  = t_sec(s:e);
    seg_y      = y_smooth(s:e);
    seg_height = abs(seg_y - threshold_value);
    if length(seg_t_sec) > 1
        segment_areas(i) = trapz(seg_t_sec, seg_height) * scale_factor;
    else
        segment_areas(i) = 0;
    end
    segment_durations(i) = minutes(t_valid(e) - t_valid(s));
end
[max_area, max_idx] = max(segment_areas);

%% ── 17. BIDIRECTIONAL AREA REPORT ───────────────────────────────────────────
fprintf('\n');
fprintf('==========================================================\n');
fprintf('   GLOBAL BIDIRECTIONAL AREA SUMMARY (%s)             \n', upper(analysis_type));
fprintf('==========================================================\n');
fprintf('  Baseline Threshold   : %7.2f  %s\n', threshold_value, y_unit_label);
fprintf('  Smoothing            : moving avg, window %d samples\n', sg_window);
fprintf('  Total Regions Found  : %7d  (Above: %d, Below: %d)\n', ...
    num_segments, length(start_above), length(start_below));
if num_segments > 0
    fprintf('----------------------------------------------------------\n');
    fprintf('  ABSOLUTE MAXIMUM INTEGRATED AREA SECTOR:\n');
    fprintf('  Region Direction     : %s Baseline\n', upper(all_types{max_idx}));
    fprintf('  Segment Unique ID    : #%d\n', max_idx);
    fprintf('  Total Net Quantity   : %7.2f  %s\n', max_area, var_unit);
    fprintf('  Uninterrupted Runtime: %7.1f  minutes\n', segment_durations(max_idx));
    fprintf('  Incident Start Time  : %s\n', string(t_valid(all_starts(max_idx)), 'dd-MMM HH:mm'));
    fprintf('  Incident End Time    : %s\n', string(t_valid(all_ends(max_idx)),   'dd-MMM HH:mm'));
else
    fprintf('  No valid transients found.\n');
end
fprintf('==========================================================\n\n');
%% ── 18. GRAPHICAL VISUALIZATION OVERVIEW ────────────────────────────────────
figure('Name', sprintf('%s - Combined Bidirectional Areas', var_label), 'Color', 'w');
hold on;
% Raw signal as faint background reference
plot(t_valid, y_valid, 'Color', [0.75 0.75 0.75], 'LineWidth', 0.8, ...
     'DisplayName', [var_label, ' (Raw)']);
% Smoothed signal as primary trace
plot(t_valid, y_smooth, 'Color', [0.15 0.15 0.15], 'LineWidth', 1.4, ...
     'DisplayName', sprintf('%s (SG smooth, w=%d)', var_label, sg_window));
yline(threshold_value, 'k--', 'LineWidth', 1.5, ...
      'DisplayName', sprintf('Baseline = %.2f %s', threshold_value, y_unit_label));
% Fill areas
for i = 1:num_segments
    s = all_starts(i);
    e = all_ends(i);
    seg_t = t_valid(s:e);
    seg_y = y_smooth(s:e);
    fill_t = [seg_t(1); seg_t; seg_t(end)];
    fill_y = [threshold_value; seg_y; threshold_value];
    if i == max_idx
        fill(fill_t, fill_y, [0.85 0.10 0.10], 'FaceAlpha', 0.65, ...
             'EdgeColor', [0.5 0 0], 'LineWidth', 2.0, ...
             'DisplayName', sprintf('MAX GLOBAL REGION (#%d %s: %.1f %s)', ...
             i, all_types{i}, max_area, var_unit));
    else
        if strcmp(all_types{i}, 'Above')
            fill(fill_t, fill_y, [1.00 0.60 0.20], 'FaceAlpha', 0.25, ...
                 'EdgeColor', 'none', 'HandleVisibility', 'off');
        else
            fill(fill_t, fill_y, [0.20 0.60 1.00], 'FaceAlpha', 0.25, ...
                 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
    end
    if segment_areas(i) > 0.03 * max_area || i == max_idx
        text_t = seg_t(round(length(seg_t) / 2));
        text_y = (mean(seg_y) + threshold_value) / 2;
        str_label = {sprintf('#%d', i), sprintf('%.1f %s', segment_areas(i), var_unit)};
        text(text_t, text_y, str_label, ...
             'Interpreter', 'none', ...
             'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold', ...
             'Color', [0.1 0.1 0.1], 'BackgroundColor', [1 1 1 0.75], 'EdgeColor', 'none');
    end
end  % <-- FIX: end of for-loop (was missing, causing all formatting commands
     %          to execute inside the loop on every iteration)
grid on; box on;
title(sprintf('%s Absolute Bidirectional Integration (%s Baseline)', ...
      var_label, sprintf('%.2f %s', threshold_value, y_unit_label)));
xlabel('Time');
ylabel(sprintf('%s (%s)', var_label, y_unit_label));
legend('Location', 'best');
xtickformat('dd-MM HH:mm');
xtickangle(45);
hold off;
%% ── 19. BUFFER ANALYSIS — RIGOROUS EXERGY GAIN ──────────────────────────────
%  COMPARISON:
%    ACTUAL  — turbine as measured: power and exergy destruction vary
%              minute-by-minute with the real inlet/outlet conditions.
%    IDEAL   — turbine held at constant W_setpoint [kW] by an electrical
%              buffer. The buffer absorbs/delivers the difference so the
%              turbine never deviates from the target operating point.
% ─────────────────────────────────────────────────────────────────────────────
W_setpoint = threshold_value;          % [kW]  your target constant output
%% ── 19a. VALID SAMPLE MASK ───────────────────────────────────────────────────
valid = act_win & ~isnan(W_turb) & ~isnan(X_dest) ...
               & ~isnan(h_in)   & ~isnan(h_out)   ...
               & ~isnan(s_in)   & ~isnan(s_out)   ...
               & ~isnan(m_t_win);
t_s = seconds(time_win(valid) - time_win(1));   % [s]
W_actual   = W_turb(valid);            % [kW]  measured shaft power
X_dest_act = X_dest(valid);            % [kW]  measured exergy destruction





%% ── 20. EMPIRICAL PERFORMANCE MAP:  w_spec(m)  and  x_dest_spec(m) ─────────
%  Delegates to build_perf_map(); map vectors travel as one perf_map struct.
m_data     = m_t_win(valid);                        % [kg/s]
w_data     = h_in(valid) - h_out(valid);             % [kJ/kg]
xdest_data = (e_in(valid) - e_out(valid)) - w_data;  % [kJ/kg]
perf_map   = build_perf_map(m_data, w_data, xdest_data);

%% ── 21. SELF-CONSISTENT SOLVE FOR THE SETPOINT OPERATING POINT ──────────────
%  Delegates to solve_setpoint(); explicit I/O prevents unrecognized-variable errors.
[m_nom, w_nom, X_dest_nom_kW, x_dest_nom_spec] = solve_setpoint(W_setpoint, perf_map);

% Nominal thermodynamic state for downstream exergy calculations
h_in_nom  = mean(h_in(valid),  'omitnan');
s_in_nom  = mean(s_in(valid),  'omitnan');
h_out_nom = h_in_nom - w_nom;
p_out_nom_est = mean(p_out_win(valid), 'omitnan');
s_out_nom = coolprop('S', 'P', p_out_nom_est * 1e5, 'H', h_out_nom * 1e3, 'Water') * 1e-3;
e_in_nom  = (h_in_nom  - h_amb) - T_amb * (s_in_nom  - s_amb);
e_out_nom = (h_out_nom - h_amb) - T_amb * (s_out_nom - s_amb);
h_ideal_nom = coolprop('H', 'S', s_in_nom * 1e3, 'P', p_out_nom_est * 1e5, 'Water') * 1e-3;
eta_is_nom  = w_nom / max(h_in_nom - h_ideal_nom, 1e-6) * 100;

fprintf('--- Self-consistent nominal state @ setpoint (from performance map) ---\n');
fprintf('  W_setpoint        = %8.2f  kW\n',     W_setpoint);
fprintf('  m_nom (solved)    = %8.4f  kg/s\n',    m_nom);
fprintf('  w_nom (map)       = %8.3f  kJ/kg\n',   w_nom);
fprintf('  eta_is @ m_nom    = %8.2f  %%   (map-based, NOT global mean)\n', eta_is_nom);
fprintf('  x_dest_spec (map) = %8.4f  kJ/kg\n',   x_dest_nom_spec);
fprintf('  X_dest_nom        = %8.2f  kW\n\n',    X_dest_nom_kW);

%% ── 22. SANITY CHECK PLOT — SPECIFIC WORK vs MASS FLOW ─────────────────────
fig = figure('Name', 'Specific Work vs Mass Flow', ...
    'Color', 'w', 'Units', 'inches', 'Position', [1 1 8 5.5]);
ax = axes('Parent', fig);
hold(ax, 'on');

% --- Color palette ---
colRaw    = [0.13 0.40 0.78];   % darker grey so dots read clearly
colMap    = [0.78 0.18 0.16];   % deep red for binned map
colNom    = [0.20 0.20 0.22];   % near-black for nominal line

% --- Raw data (background layer) ---
scatter(ax, m_data, w_data, 16, colRaw, 'filled', ...
    'MarkerFaceAlpha', 0.45, 'MarkerEdgeColor', 'none', ...
    'DisplayName', 'Raw valid samples');

% --- Binned + smoothed map (hero series, line only, no markers) ---
plot(ax, perf_map.m, perf_map.w, '-', 'Color', colMap, 'LineWidth', 2.6, ...
    'DisplayName', 'Distribution Trend');

% --- Nominal operating point ---
xline(ax, m_nom, '--', 'Color', colNom, 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Solved m_{nom} = %.3f kg/s', m_nom));

% --- Axes cosmetics ---
ax.FontName = 'Helvetica';
ax.FontSize = 10.5;
ax.Box = 'on';
ax.LineWidth = 1.0;
ax.TickDir = 'out';
ax.XColor = [0.25 0.25 0.25];
ax.YColor = [0.25 0.25 0.25];
grid(ax, 'on');
ax.GridColor = [0.85 0.85 0.85];
ax.GridAlpha = 0.6;
ax.GridLineStyle = '-';

xlabel(ax, 'Mass Flow (kg/s)', 'FontSize', 11.5);
ylabel(ax, 'Specific Work (kJ/kg)', 'FontSize', 11.5);
title(ax, 'Relative Performance', 'FontSize', 13.5, 'FontWeight', 'bold');
subtitle(ax, 'Specific Work vs. Mass Flow', 'FontSize', 10.5, ...
    'Color', [0.4 0.4 0.4], 'FontAngle', 'italic');

lgd = legend(ax, 'Location', 'best');
lgd.Box = 'off';
lgd.FontSize = 9.5;
lgd.ItemTokenSize = [18 18];

hold(ax, 'off');

exportgraphics(fig, 'turbine_map_validity_check.png', 'Resolution', 300);



%% ── 23. INTEGRATE OVER ANALYSIS WINDOW ──────────────────────────────────────
duration_s   = t_s(end) - t_s(1);          % [s]
duration_h   = duration_s / 3600;          % [h]
% ACTUAL: trapz over measured vectors
E_actual_kWh  = trapz(t_s, W_actual)    / 3600;   % [kWh]
Xd_actual_kWh = trapz(t_s, X_dest_act) / 3600;   % [kWh]
% IDEAL: constant rate × duration
E_ideal_kWh   = W_setpoint      * duration_h;     % [kWh]
Xd_ideal_kWh  = X_dest_nom_kW   * duration_h;     % [kWh]
%% ── 24. BUFFER GAIN REPORT ───────────────────────────────────────────────────
dE  = E_ideal_kWh  - E_actual_kWh;     % + means buffer produced more net energy
dXd = Xd_actual_kWh - Xd_ideal_kWh;   % + means buffer destroyed less exergy
fprintf('==========================================================\n');
fprintf('   ELECTRICAL BUFFER GAIN ANALYSIS — RIGOROUS\n');
fprintf('==========================================================\n');
fprintf('  ACTUAL  : turbine as measured (varying W and X_dest)\n');
fprintf('  IDEAL   : turbine locked at %.1f kW via electrical buffer\n', W_setpoint);
fprintf('            → fixed thermodynamic state, constant mass flow\n');
fprintf('              of %.4f kg/s, X_dest fixed at %.2f kW\n', m_nom, X_dest_nom_kW);
fprintf('----------------------------------------------------------\n');
fprintf('  Analysis window duration     : %7.1f  h\n',   duration_h);
fprintf('----------------------------------------------------------\n');
fprintf('                                 ACTUAL      IDEAL\n');
fprintf('  Energy generated    [kWh]  : %7.1f    %7.1f\n', E_actual_kWh,  E_ideal_kWh);
fprintf('  Exergy destroyed    [kWh]  : %7.1f    %7.1f\n', Xd_actual_kWh, Xd_ideal_kWh);
fprintf('----------------------------------------------------------\n');
fprintf('  Energy delta        [kWh]  : %+7.1f  (+ = buffer gains)\n',  dE);
fprintf('  Exergy saving       [kWh]  : %+7.1f  (+ = less destroyed)\n', dXd);
fprintf('  Exergy improvement  [%%]    : %+7.1f\n', dXd / Xd_actual_kWh * 100);
fprintf('==========================================================\n\n');
%% ── 25. EFFICIENCY vs POWER SCATTER ─────────────────────────────────────────
figure('Name', 'Efficiency vs Power during Operation', 'Color', 'w');
hold on;
colormap("turbo")
scatter(W_actual, eta_is(valid), 4, t_s/3600, 'filled', 'MarkerFaceAlpha', 0.3);
xline(W_setpoint, 'r--', 'LineWidth', 2, ...
      'DisplayName', sprintf('Setpoint = %.1f kW', W_setpoint));
xline(mean(W_actual,'omitnan'), 'b--', 'LineWidth', 1.5, ...
      'DisplayName', sprintf('Mean W = %.1f kW', mean(W_actual,'omitnan')));
colorbar; clabel = colorbar; clabel.Label.String = 'Time (h)';
xlabel('Power Output (kW)');
ylabel('Isentropic Efficiency (%)');
title('η_{is} vs Power during Operation');
legend('Location','best');
grid on; box on;
hold off;
% Find the power level that maximises isentropic efficiency
eta_is_filtered = eta_is(valid);
[~, peak_idx] = max(eta_is_filtered);
W_optimal = W_actual(peak_idx);
fprintf('Efficiency-maximising setpoint: %.1f kW  (η_is = %.1f%%)\n', ...
        W_optimal, eta_is_filtered(peak_idx));
%% ── 26. THERMAL & EXERGETIC EFFICIENCY — ACTUAL vs IDEAL ───────────────────

% --- Exergy inflow/outflow rates, ACTUAL (mean over valid samples) ---
X_in_act_mean  = mean(X_in(valid),  'omitnan');   % [kW]
X_out_act_mean = mean(X_out(valid), 'omitnan');   % [kW]

% --- Exergy inflow/outflow rates, IDEAL (fixed nominal state) ---
X_in_nom_kW  = m_nom * e_in_nom;    % [kW]
X_out_nom_kW = m_nom * e_out_nom;   % [kW]

% --- Thermal (first-law / isentropic) efficiency ---
% Benchmark = isentropic work at the SAME inlet state, expanded to the
% SAME outlet pressure (NOT to ambient — the turbine never expands that far).
p_out_nom   = mean(p_out_win(valid), 'omitnan');
h_ideal_nom = coolprop('H', 'S', s_in_nom * 1e3, 'P', p_out_nom * 1e5, 'Water') * 1e-3; % [kJ/kg]

eta_th_actual = eta_is_mean;                                              % [%]  already computed, actual mean
eta_th_ideal  = (h_in_nom - h_out_nom) / max(h_in_nom - h_ideal_nom, 1e-6) * 100;  % [%]

% --- Exergetic (second-law) efficiency ---
eta_ex_actual = W_mean     / max(X_in_act_mean - X_out_act_mean, 1e-6) * 100;   % [%]
eta_ex_ideal  = W_setpoint / max(X_in_nom_kW  - X_out_nom_kW,  1e-6) * 100;     % [%]

% --- Mean exergy destroyed [kW] ---
Xd_actual_mean_kW = Xd_actual_kWh / duration_h;
Xd_ideal_mean_kW  = X_dest_nom_kW;

% --- Mean & overall exergy saved ---
Xd_saved_mean_kW   = Xd_actual_mean_kW - Xd_ideal_mean_kW;   % [kW]
Xd_saved_total_kWh = dXd;                                    % [kWh]

fprintf('==========================================================\n');
fprintf('   THERMAL & EXERGETIC EFFICIENCY — ACTUAL vs IDEAL\n');
fprintf('==========================================================\n');
fprintf('                                 ACTUAL      IDEAL\n');
fprintf('  Thermal (isentropic) eff [%%] : %7.2f    %7.2f\n', eta_th_actual, eta_th_ideal);
fprintf('  Exergetic efficiency     [%%] : %7.2f    %7.2f\n', eta_ex_actual, eta_ex_ideal);
fprintf('----------------------------------------------------------\n');
fprintf('  Mean exergy destroyed [kW]  : %7.2f    %7.2f\n', Xd_actual_mean_kW, Xd_ideal_mean_kW);
fprintf('----------------------------------------------------------\n');
fprintf('  Mean exergy saved    [kW]   : %+7.2f\n', Xd_saved_mean_kW);
fprintf('  Overall exergy saved [kWh]  : %+7.2f\n', Xd_saved_total_kWh);
fprintf('==========================================================\n\n');

%% ── 27. OPERATING REGIME DENSITY HEATMAP (MASS FLOW vs η_is) ───────────────
%  Purpose: Visualizes the joint frequency distribution to show exactly where 
%           the turbine spends most of its operational life and at what efficiency.
% =========================================================================

% 1. Extract clean, synchronized vectors using your existing 'valid' mask
m_operational      = m_t_win(valid);
eta_is_operational = eta_is(valid);

if isempty(m_operational)
    warning('No valid operational data found to plot the heatmap.');
else
    figure('Name', 'Turbine Operating Regime Density', 'Color', 'w', 'Position', [100 100 800 600]);

    % 2. Generate the 2D binned scatter plot (40x40 grid grid for clean resolution)
    %    Adjust [40 40] up or down to change the bin size grouping.
    hHeatmap = binscatter(m_operational, eta_is_operational, [40 40]);

    % 3. Styling and Aesthetics
    colormap(turbo); % 'jet' or 'parula' works great for highlighting high-density hot spots
    ax = gca;
    ax.GridColor = [0.3 0.3 0.3];
    ax.GridAlpha = 0.2;
    grid on; box on;

   % Identify the 3 most common mass flow rates (by bin density)
    [N, Xedges] = histcounts(m_operational, 40);
    [~, sortIdx] = sort(N, 'descend');
    topBinCenters = Xedges(sortIdx(1:3)) + diff(Xedges(1:2))/2;

    cb = colorbar;
    cb.Label.String = sprintf('Sample Count  |  Top flows: %.1f, %.1f, %.1f kg/s', ...
        topBinCenters(1), topBinCenters(2), topBinCenters(3));
    cb.Label.FontWeight = 'bold';

    % 4. Labels and Title
    xlabel('Mass Flow Rate (kg/s)', 'FontWeight', 'bold');
    ylabel('Isentropic Efficiency (%)', 'FontWeight', 'bold');
    title({'Turbine Operating Regime  (28 May – 1 Jun 2026)'});

    % Overlay the average operating point for context
    hold on;
    xline(mean(m_operational), 'r--', 'LineWidth', 2, 'DisplayName', 'Mean Mass Flow');
    legend('Location', 'northwest');
    hold off;
end
%% ── 28. SWEEP: EXERGY SAVINGS & BATTERY SIZE vs MASS FLOW SETPOINT ─────────
%  For each candidate mass-flow setpoint, re-solve the nominal operating
%  point, recompute the exergy-saving (dXd) from forcing that setpoint,
%  and size the battery as the peak single continuous energy deviation
%  (maximal area sector) found via an identical geometric integration loop.
% ─────────────────────────────────────────────────────────────────────────────
m_sweep = linspace(min(perf_map.m), max(perf_map.m), 25);   % [kg/s]

Xd_savings_sweep = NaN(size(m_sweep));   % [kWh] total exergy saved over window
battery_kWh_sweep = NaN(size(m_sweep));  % [kWh] required battery capacity
E_supplied_sweep = NaN(size(m_sweep));   % [kWh] total energy supplied (ideal)

% ── 28a. RECREATE EXACT SECTION 14 POWER SIGNAL TIME-BASE ──────────────────
% This guarantees 100% parity with the standalone bidirectional area tool
y_signal_p = W_turb;
valid_mask_p = ~isnan(y_signal_p) & ~isnat(time_win);
t_valid_p    = time_win(valid_mask_p);
y_valid_p    = y_signal_p(valid_mask_p);
t_valid_p    = t_valid_p(:);
y_valid_p    = y_valid_p(:);
t_sec_p      = seconds(t_valid_p - t_valid_p(1));

% Apply matching moving average window filter
sg_window_p = 80;  
if numel(y_valid_p) >= sg_window_p
    kernel_p   = ones(sg_window_p, 1) / sg_window_p;
    W_smooth_p = conv(y_valid_p, kernel_p, 'same');
    half_p     = floor(sg_window_p / 2);
    W_smooth_p(1:half_p)         = y_valid_p(1:half_p);
    W_smooth_p(end-half_p+1:end) = y_valid_p(end-half_p+1:end);
else
    W_smooth_p = y_valid_p;
end

% ── 28b. RUN PARAMETRIC SWEEP LOOP ──────────────────────────────────────────
for k = 1:numel(m_sweep)
    m_k = m_sweep(k);

    % Map-based specific work / exergy destruction at this mass flow
    w_k       = interp1(perf_map.m, perf_map.w,     m_k, 'linear', 'extrap');
    xdest_k   = interp1(perf_map.m, perf_map.xdest, m_k, 'linear', 'extrap');
    W_k       = m_k * w_k;          % [kW]  ideal constant power at this setpoint
    Xdest_k   = m_k * xdest_k;      % [kW]  ideal constant exergy destruction

    % IDEAL energy & exergy destruction over the window
    E_ideal_k  = W_k     * duration_h;   % [kWh]
    Xd_ideal_k = Xdest_k * duration_h;   % [kWh]

    % Exergy savings relative to ACTUAL (already computed: Xd_actual_kWh)
    Xd_savings_sweep(k) = Xd_actual_kWh - Xd_ideal_k;   % [kWh], + = less destroyed
    E_supplied_sweep(k) = E_ideal_k;                    % [kWh]

    % ── GEOMETRIC INTEGRATION FOR BATTERY SIZING AT CURRENT SETPOINT ──
    is_above_k = W_smooth_p > W_k;
    start_above_k = find(diff([0; is_above_k]) == 1);
    end_above_k   = find(diff([is_above_k; 0]) == -1);
    
    is_below_k = W_smooth_p < W_k;
    start_below_k = find(diff([0; is_below_k]) == 1);
    end_below_k   = find(diff([is_below_k; 0]) == -1);
    
    all_starts_k   = [start_above_k; start_below_k];
    all_ends_k     = [end_above_k; end_below_k];
    num_segments_k = length(all_starts_k);
    
    segment_areas_k = zeros(num_segments_k, 1);
    for i = 1:num_segments_k
        s = all_starts_k(i);
        e = all_ends_k(i);
        
        seg_t_sec  = t_sec_p(s:e);
        seg_y      = W_smooth_p(s:e);
        seg_height = abs(seg_y - W_k);
        
        if length(seg_t_sec) > 1
            segment_areas_k(i) = trapz(seg_t_sec, seg_height) * (1 / 3600);
        else
            segment_areas_k(i) = 0;
        end
    end
    
    % Track maximum standalone contiguous transient area for this setpoint
    if num_segments_k > 0
        battery_kWh_sweep(k) = max(segment_areas_k);
    else
        battery_kWh_sweep(k) = 0;
    end
end

%% ── 28a. GRAPH 1: Exergy Savings & Battery Size vs Mass Flow ───────────────
figure('Name', 'Exergy Savings & Battery Size vs Mass Flow', 'Color', 'w');
yyaxis left
plot(m_sweep, Xd_savings_sweep, '-o', 'Color', [0.80 0.10 0.10], ...
     'LineWidth', 2, 'MarkerFaceColor', [0.80 0.10 0.10], 'DisplayName', 'Exergy Savings');
ylabel('Exergy Savings (kWh)');
ax = gca; ax.YColor = [0.80 0.10 0.10];

yyaxis right
plot(m_sweep, battery_kWh_sweep, '-s', 'Color', [0.10 0.35 0.80], ...
     'LineWidth', 2, 'MarkerFaceColor', [0.10 0.35 0.80], 'DisplayName', 'Required Battery Size');
ylabel('Battery Size (kWh)');
ax = gca; ax.YColor = [0.10 0.35 0.80];

xlabel('Mass Flow Setpoint (kg/s)');
title('Exergy Savings & Required Battery Size vs Mass Flow Setpoint');
legend('Location', 'best');
grid on; box on;
%% ── 28b. GRAPH 2: Exergy Savings & Battery Size vs Energy Supplied ──────────
%  Same structure as Graph 1, but the x-axis is Energy Supplied instead of
%  the mass flow setpoint. Sort by energy supplied so the lines are clean.
[E_supplied_sorted, sort_idx] = sort(E_supplied_sweep);
Xd_savings_sorted  = Xd_savings_sweep(sort_idx);
battery_sorted     = battery_kWh_sweep(sort_idx);

figure('Name', 'Exergy Savings & Battery Size vs Energy Supplied', 'Color', 'w');
yyaxis left
plot(E_supplied_sorted, Xd_savings_sorted, '-o', 'Color', [0.80 0.10 0.10], ...
     'LineWidth', 2, 'MarkerFaceColor', [0.80 0.10 0.10], 'DisplayName', 'Exergy Savings');
ylabel('Exergy Savings (kWh)');
ax = gca; ax.YColor = [0.80 0.10 0.10];

yyaxis right
plot(E_supplied_sorted, battery_sorted, '-s', 'Color', [0.10 0.35 0.80], ...
     'LineWidth', 2, 'MarkerFaceColor', [0.10 0.35 0.80], 'DisplayName', 'Required Battery Size');
ylabel('Battery Size (kWh)');
ax = gca; ax.YColor = [0.10 0.35 0.80];

xlabel('Energy Supplied (kWh)');
title('Exergy Savings & Required Battery Size vs Energy Supplied');
legend('Location', 'best');
grid on; box on;

%% ── 28c. GRAPH 3: Specific Exergy Saved & Battery Size vs Mass Flow ────────
%  Specific exergy saved = (actual mean specific exergy destruction)
%                          − (map-based specific exergy destruction at m_k)
%  i.e. how much LESS exergy is destroyed per kg of steam at each setpoint,
%  relative to how the turbine actually destroys exergy on average.
% ─────────────────────────────────────────────────────────────────────────────
xdest_actual_spec_mean = mean(xdest_data, 'omitnan');   % [kJ/kg], actual mean

specific_Xd_saved_sweep = NaN(size(m_sweep));   % [kJ/kg]

for k = 1:numel(m_sweep)
    m_k     = m_sweep(k);
    xdest_k = interp1(perf_map.m, perf_map.xdest, m_k, 'linear', 'extrap');  % [kJ/kg]
    specific_Xd_saved_sweep(k) = xdest_actual_spec_mean - xdest_k;          % [kJ/kg], + = less destroyed
end

figure('Name', 'Specific Exergy Saved & Battery Size vs Mass Flow', 'Color', 'w');
yyaxis left
plot(m_sweep, specific_Xd_saved_sweep, '-o', 'Color', [0.80 0.10 0.10], ...
     'LineWidth', 2, 'MarkerFaceColor', [0.80 0.10 0.10], 'DisplayName', 'Specific Exergy Saved');
ylabel('Specific Exergy Saved (kJ/kg)');
ax = gca; ax.YColor = [0.80 0.10 0.10];

yyaxis right
plot(m_sweep, battery_kWh_sweep, '-s', 'Color', [0.10 0.35 0.80], ...
     'LineWidth', 2, 'MarkerFaceColor', [0.10 0.35 0.80], 'DisplayName', 'Required Battery Size');
ylabel('Battery Size (kWh)');
ax = gca; ax.YColor = [0.10 0.35 0.80];

xlabel('Mass Flow Setpoint (kg/s)');
title('Specific Exergy Saved & Required Battery Size vs Mass Flow Setpoint');
legend('Location', 'best');
grid on; box on;


%% ── 10. FIGURES ───────────────────────────────────────────────────────────

% ── Fig 1 : Mass flow over time ───────────────────────────────────────────
figure('Name', 'Turbine Mass Flow — 28 May – 1 Jun', 'Color', 'w');
hold on;
plot(t_valid, m_t_win, 'Color', [0.70 0.85 1.00], 'LineWidth', 0.8, ...
     'DisplayName', 'Mass flow (raw)');
plot(t_valid, m_MA,    'Color', [0.00 0.35 0.75], 'LineWidth', 2.5, ...
     'DisplayName', sprintf('MA (%d min)', win_MA));
yline(m_mean, '--', 'Color', [0.00 0.35 0.75], 'LineWidth', 1.2, ...
      'DisplayName', sprintf('Mean = %.3f kg/s', m_mean));
grid on; box on;
title('Turbine: Mass Flow — 28 May – 1 Jun 2026');
xlabel('Time');
ylabel('Mass Flow (kg/s)');
legend('Location', 'best');
xtickformat('dd-MM HH:mm');
xtickangle(45);
hold off;

% ── Fig 2 : Inlet & outlet temperature ───────────────────────────────────
figure('Name', 'Turbine Temperatures — 28 May – 1 Jun', 'Color', 'w');
hold on;
plot(t_valid, t_in_win,  'Color', [1.00 0.50 0.20], 'LineWidth', 1.2, ...
     'DisplayName', 'Inlet T (°C)');
plot(t_valid, t_out_win, 'Color', [0.20 0.60 0.95], 'LineWidth', 1.2, ...
     'DisplayName', 'Outlet T (°C)');
yline(t_in_mean,  '--', 'Color', [1.00 0.50 0.20], 'LineWidth', 1.0, ...
      'DisplayName', sprintf('Mean T_{in} = %.1f °C',  t_in_mean));
yline(t_out_mean, '--', 'Color', [0.20 0.60 0.95], 'LineWidth', 1.0, ...
      'DisplayName', sprintf('Mean T_{out} = %.1f °C', t_out_mean));
grid on; box on;
title('Turbine: Inlet & Outlet Temperature — 28 May – 1 Jun 2026');
xlabel('Time');
ylabel('Temperature (°C)');
legend('Location', 'best');
xtickformat('dd-MM HH:mm');
xtickangle(45);
hold off;

% ── Fig 3 : Inlet & outlet pressure ──────────────────────────────────────
figure('Name', 'Turbine Pressures — 28 May – 1 Jun', 'Color', 'w');
hold on;
plot(t_valid, p_in_win,  'Color', [0.85 0.20 0.20], 'LineWidth', 1.2, ...
     'DisplayName', 'Inlet P (bar)');
plot(t_valid, p_out_win, 'Color', [0.20 0.70 0.40], 'LineWidth', 1.2, ...
     'DisplayName', 'Outlet P (bar)');
yline(p_in_mean,  '--', 'Color', [0.85 0.20 0.20], 'LineWidth', 1.0, ...
      'DisplayName', sprintf('Mean P_{in} = %.2f bar',  p_in_mean));
yline(p_out_mean, '--', 'Color', [0.20 0.70 0.40], 'LineWidth', 1.0, ...
      'DisplayName', sprintf('Mean P_{out} = %.2f bar', p_out_mean));
grid on; box on;
title('Turbine: Inlet & Outlet Pressure — 28 May – 1 Jun 2026');
xlabel('Time');
ylabel('Pressure (bar)');
legend('Location', 'best');
xtickformat('dd-MM HH:mm');
xtickangle(45);
hold off;

% ── Fig 4 : Power output ─────────────────────────────────────────────────
figure('Name', 'Turbine Power Output — 28 May – 1 Jun', 'Color', 'w');
hold on;
plot(t_valid, W_turb, 'Color', [0.85 0.85 0.40], 'LineWidth', 0.8, ...
     'DisplayName', 'Power (raw)');
plot(t_valid, W_MA,   'Color', [0.55 0.45 0.00], 'LineWidth', 2.5, ...
     'DisplayName', sprintf('MA (%d min)', win_MA));
yline(W_mean, '--', 'Color', [0.55 0.45 0.00], 'LineWidth', 1.2, ...
      'DisplayName', sprintf('Mean = %.1f kW', W_mean));
yline(W_peak, ':',  'Color', [0.55 0.45 0.00], 'LineWidth', 1.0, ...
      'DisplayName', sprintf('Peak = %.1f kW', W_peak));
grid on; box on;
title('Turbine: Power Output — 28 May – 1 Jun 2026');
xlabel('Time');
ylabel('Power (kW)');
legend('Location', 'best');
xtickformat('dd-MM HH:mm');
xtickangle(45);
hold off;

%% ── HELPER FUNCTIONS ────────────────────────────────────────────────────────
function perf_map = build_perf_map(m_data, w_data, xdest_data)
% BUILD_PERF_MAP  Bin, sort, and smooth empirical (m, w_spec, xdest_spec) data.
%   Returns a struct with fields .m, .w, .xdest (all column vectors, sorted
%   by ascending mass flow and lightly 3-pt smoothed).
    n_bins = 40;
    edges   = linspace(min(m_data), max(m_data), n_bins + 1);
    bin_idx = discretize(m_data, edges);
    m_bin     = accumarray(bin_idx, m_data,     [n_bins,1], @mean, NaN);
    w_bin     = accumarray(bin_idx, w_data,     [n_bins,1], @mean, NaN);
    xd_bin    = accumarray(bin_idx, xdest_data, [n_bins,1], @mean, NaN);
    n_bin     = accumarray(bin_idx, ones(size(m_data)), [n_bins,1], @sum,  0);
    good = ~isnan(m_bin) & ~isnan(w_bin) & n_bin >= 5;
    if sum(good) < 4
        warning('Performance map: too few populated bins (%d), retrying with coarser grid.', sum(good));
        n_bins  = max(8, floor(n_bins / 2));
        edges   = linspace(min(m_data), max(m_data), n_bins + 1);
        bin_idx = discretize(m_data, edges);
        m_bin   = accumarray(bin_idx, m_data,     [n_bins,1], @mean, NaN);
        w_bin   = accumarray(bin_idx, w_data,     [n_bins,1], @mean, NaN);
        xd_bin  = accumarray(bin_idx, xdest_data, [n_bins,1], @mean, NaN);
        n_bin   = accumarray(bin_idx, ones(size(m_data)), [n_bins,1], @sum,  0);
        good    = ~isnan(m_bin) & ~isnan(w_bin) & n_bin >= 2;
    end
    [m_s, si] = sort(m_bin(good));
    tmp_w  = w_bin(good);   tmp_w  = tmp_w(si);
    tmp_xd = xd_bin(good);  tmp_xd = tmp_xd(si);
    if numel(m_s) >= 3
        tmp_w  = movmean(tmp_w,  3);
        tmp_xd = movmean(tmp_xd, 3);
    end
    perf_map.m     = m_s;
    perf_map.w     = tmp_w;
    perf_map.xdest = tmp_xd;
    fprintf('\n--- Empirical performance map (mass flow -> specific work) ---\n');
    fprintf('  Built from %d valid samples across %d populated bins\n', numel(m_data), sum(good));
    fprintf('  Mass-flow range covered: %.3f -- %.3f kg/s\n', min(m_s), max(m_s));
    fprintf('  (Extrapolation beyond this range uses linear extrapolation)\n\n');
end

function [m_nom, w_nom, X_dest_nom_kW, x_dest_nom_spec] = solve_setpoint(W_setpoint, perf_map)
% SOLVE_SETPOINT  Self-consistently find the mass flow that delivers W_setpoint [kW]
%   on the real empirical performance curve using fzero.
%   Inputs : W_setpoint [kW], perf_map struct (.m .w .xdest)
%   Outputs: m_nom [kg/s], w_nom [kJ/kg], X_dest_nom_kW [kW], x_dest_nom_spec [kJ/kg]
    w_fn    = @(m) interp1(perf_map.m, perf_map.w,     m, 'linear', 'extrap');
    xd_fn   = @(m) interp1(perf_map.m, perf_map.xdest, m, 'linear', 'extrap');
    residual = @(m) m .* w_fn(m) - W_setpoint;
    m_lo = max(1e-3, min(perf_map.m) * 0.5);
    m_hi = max(perf_map.m) * 1.5;
    f_lo = residual(m_lo);  f_hi = residual(m_hi);  k = 0;
    while sign(f_lo) == sign(f_hi) && k < 10
        m_hi = m_hi * 1.5;  f_hi = residual(m_hi);  k = k + 1;
    end
    if sign(f_lo) == sign(f_hi)
        warning('solve_setpoint: could not bracket root for W=%.1f kW; using nearest map point.', W_setpoint);
        [~, idx] = min(abs(perf_map.m .* perf_map.w - W_setpoint));
        m_nom = perf_map.m(idx);
    else
        m_nom = fzero(residual, [m_lo, m_hi]);
    end
    w_nom           = w_fn(m_nom);
    x_dest_nom_spec = xd_fn(m_nom);
    X_dest_nom_kW   = m_nom * x_dest_nom_spec;
end

%% ── HELPER FUNCTION ──────────────────────────────────────────────────────
function val = Get(dataTable, tag)
    if ismember(tag, dataTable.Properties.VariableNames)
        val = dataTable{:, tag};
        if iscell(val) || isstring(val)
            val = str2double(string(val));
        end
        is_nan_val  = isnan(val);
        is_zero_val = (val == 0);
        bad_indices = is_nan_val | is_zero_val;
        total_bad   = sum(bad_indices);
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

