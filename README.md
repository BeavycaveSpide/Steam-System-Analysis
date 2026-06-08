# Industrial Steam & Condensate Utility Network: Thermodynamic Modeling & Exergy Analysis

This repository contains a suite of MATLAB frameworks designed to perform mass, energy, and exergy balance diagnostics on an industrial steam distribution network. The codebase processes high-resolution time-series data, filters out transient upsets via operational masking, and computes localized efficiencies to map energy degradation across plant components.

These models provide the core analytical verification layer for the asset's technical performance report.

---

## 🏭 Network Architecture

The underlying network maps a multi-tier utility framework operating across three distinct pressure thresholds:
* **High-Pressure (HP) Tier (50 bar):** Supplied by Boiler 14 (Biomass / Wood Chips) to drive a backpressure steam turbine and feed primary distribution lines.
* **Medium-Pressure (MP) Tier (20 bar):** Co-supplied by Boiler 15 (Natural Gas) and automated Pressure Reducing Valves (PRVs) with desuperheating spray loops.
* **Low-Pressure (LP) Tier (2.5 bar):** Fed via steam turbine exhaust and steam drum let-down lines to supply industrial clients, deaerators, and district city heating networks.

---

## 🗂️ Module Directory

| Module | Core Function | Primary Output |
| :--- | :--- | :--- |
| **`ExergyAnalysis.m`** | Main Thermodynamic computations | Calculates specific exergy flows and computes Carnot, Isentropic, and Second-Law efficiencies for the turbine. |
| **`mass_balance.m`** | Plant Flow Diagnostics | Validates conservation of mass across headers and calculates how much steam is lost via vents versus utilized for city heating. |
| **`Prv_injw_massflow.m`** | Valve & Pressure Diagnostics | Generates a multi-tab dashboard tracking valve positions, automated pressure drops, and desuperheating spray water flows. |
| **`condensate.m`** | Condensate Return Diagnostics | Sums up the total volumetric return lines from industrial clients and isolates inventory errors in the degasser. |
| **`Clinet_condensateBalance.m`** | Supply vs. Return Diagnostics | Plots the real-time moving average trends of steam supply against returned condensate during active plant windows. |
| **`Digraph.m`** | Network Topology | Renders a directed flowchart mapping the pipeline pathways from intake water to end-user sinks. |

---

## 📐 Governing Equations

The runtime engines solve steady-state fluid equations at each data interval:

### 1. Flow Exergy Rate
Specific physical exergy ($e$) is calculated relative to the dead state ambient conditions ($T_{\text{amb}} = \text{25°C}$, $P_{\text{amb}} = \text{1.01325 bar}$):
$$e = (h - h_{\text{amb}}) - T_{\text{amb}}(s - s_{\text{amb}})$$

The total exergy rate ($X$) for any stream translates mass flow rate ($\dot{m}$) to available work potential:
$$X = \dot{m} \cdot e$$

### 2. Turbine Efficiency Formulations
First-law isentropic efficiency ($\eta_{\text{is}}$) and second-law exergetic efficiency ($\eta_{\text{II}}$) characterize the work extraction process:
$$\eta_{\text{is}} = \frac{h_{\text{in}} - h_{\text{out}}}{h_{\text{in}} - h_{\text{ideal}}}$$

$$\eta_{\text{II}} = \frac{h_{\text{in}} - h_{\text{out}}}{e_{\text{in}} - e_{\text{out}}}$$

---

## 🔧 Operational Filtering & Data Integrity

To avoid miscalculations during transient states or system shutdowns, the framework enforces strict cleaning boundaries:
* **Active Status Masking:** A logical data mask (`active_idx`) isolates timeframes where the main feedwater temperature is strictly above **50°C**.
* **Anomaly Suppression:** Unphysical sensor spikes or telemetry drops (e.g., calculated efficiencies exceeding 100% or falling below 0%) are automatically wiped and assigned as `NaN`.
* **Signal Attenuation:** High-frequency noise is smoothed out via local moving window averages (`movmean`), exposing clean baseline trends.

---

## 🚀 Execution & Deployment

### Dependencies
1. **MATLAB Workspace:** Compatible with MATLAB R2020a or newer (requires the Signal Processing and Optimization toolboxes for moving averages and network graphing).
2. **CoolProp Library:** Thermodynamic calculations rely on high-fidelity properties evaluated via the CoolProp interface. Ensure `coolprop.m` is configured on your local MATLAB search path.
3. **Local Assets:** Ensure `Cleaned_OneWeekData.csv` and `H_map_data.mat` populate the working directory before running the scripts.

### Run Protocol
Execute the primary framework script to compile the complete exergy performance table:
```matlab
>> ExergyAnalysis
