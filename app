import streamlit as st
import numpy as np
import plotly.graph_objects as go

st.set_page_config(page_title="Poleni Wehr-Rechner", layout="wide")

st.title("🌊 Wehr-Überfallhöhe Rechner & 3D-Analyse")
st.markdown("Berechnung der Überfallhöhe nach der **Poleni-Formel** für rechteckige Wehre.")

# --- INITIALISIERUNG & SETUP ---
unit_system = st.radio("Einheitensystem / Unit System:", ("Metrisch (m³/h, m)", "US Imperial (MGD, ft)"))

st.sidebar.header("Parameter")

# Grenzwerte für das visuelle Limit
H_LIMIT_METRIC = 0.2
H_LIMIT_IMPERIAL = H_LIMIT_METRIC * 3.28084

if unit_system == "Metrisch (m³/h, m)":
    # Max Durchsatz auf 2000 angepasst
    q_input = st.sidebar.slider("Durchsatz Q (m³/h)", 0, 2000, 500, step=10)
    b = st.sidebar.slider("Wehrbreite b (m)", 0.1, 20.0, 1.0, step=0.1)
    g = 9.81
    q_ms = q_input / 3600 
    h_limit = H_LIMIT_METRIC
    label_h, unit_z, unit_q = "Überfallhöhe", "m", "m³/h"
else:
    q_input = st.sidebar.slider("Flow Rate Q (MGD)", 0.0, 20.0, 5.0, step=0.1)
    b = st.sidebar.slider("Weir Width b (ft)", 0.5, 60.0, 3.0, step=0.5)
    g = 32.174
    q_ms = q_input * 1.54723 
    h_limit = H_LIMIT_IMPERIAL
    label_h, unit_z, unit_q = "Head (h)", "ft", "MGD"

mu = st.sidebar.slider("Poleni-Beiwert / Discharge Coeff. μ", 0.40, 0.80, 0.58, step=0.01)

# --- BERECHNUNG ---
if q_ms > 0 and b > 0:
    h_real = (q_ms / (mu * b * (2 * g)**0.5))**(2/3)
else:
    h_real = 0.0

# --- ERGEBNISANZEIGE ---
st.subheader("Ergebnis / Result")
col1, col2 = st.columns(2)

with col1:
    delta_val = h_real - h_limit
    st.metric(
        label=f"{label_h} ({unit_z})", 
        value=f"{h_real:.3f} {unit_z}", 
        delta=f"{delta_val:.3f} {unit_z} über Limit" if h_real > h_limit else None,
        delta_color="inverse"
    )

with col2:
    alt_unit = "cm" if unit_system == "Metrisch (m³/h, m)" else "inch"
    alt_val = h_real * 100 if unit_system == "Metrisch (m³/h, m)" else h_real * 12
    st.metric(label=f"{label_h} ({alt_unit})", value=f"{alt_val:.2f} {alt_unit}")

if h_real > h_limit:
    st.error(f"⚠️ Warnung: Das Limit von {h_limit:.2f} {unit_z} ist überschritten!")

# --- 3D ANALYSE ---
st.divider()
st.subheader(f"3D-Analyse [{unit_z} & {unit_q}]")

# Meshgrid erstellen
b_min = max(0.1, b * 0.5)
q_min = max(1.0, q_input * 0.5)
b_range = np.linspace(b_min, b * 2.0, 40)
q_range = np.linspace(q_min, q_input * 2.0, 40)
B, Q = np.meshgrid(b_range, q_range)

Q_calc = Q / 3600 if unit_system == "Metrisch (m³/h, m)" else Q * 1.54723
H_mesh = (Q_calc / (mu * B * (2 * g)**0.5))**(2/3)

fig = go.Figure(data=[go.Surface(
    z=H_mesh, x=B, y=Q, 
    colorscale='Viridis',
    hovertemplate=f"Breite: %{{x:.2f}} {unit_z}<br>Flow: %{{y:.1f}} {unit_q}<br>Höhe: %{{z:.3f}} {unit_z}<extra></extra>"
)])

fig.add_trace(go.Scatter3d(
    x=[b], y=[q_input], z=[h_real],
    mode='markers',
    marker=dict(size=8, color='red', symbol='diamond', line=dict(color='white', width=2)),
    name='Auslegung'
))

fig.update_layout(
    scene=dict(
        xaxis_title=f"Breite ({unit_z})",
        yaxis_title=f"Durchfluss ({unit_q})",
        zaxis_title=f"Höhe ({unit_z})"
    ),
    margin=dict(l=0, r=0, b=0, t=30),
    height=700
)

st.plotly_chart(fig, use_container_width=True)
