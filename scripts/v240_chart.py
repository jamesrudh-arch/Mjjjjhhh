#!/usr/bin/env python3
"""Suite growth chart for the v2.4.0 report (matplotlib, palette colors)."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt

fm.fontManager.addfont("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
plt.rcParams["font.sans-serif"] = ["DejaVu Sans"]
plt.rcParams["axes.unicode_minus"] = False

versions = ["v1.0", "v2.0", "v2.1", "v2.2", "v2.3", "v2.3.2", "v2.4.0"]
checks = [238, 257, 257, 257, 288, 334, 379]

ACCENT = "#8b7226"
TEXT = "#191817"
MUTED = "#7b7972"
BORDER = "#c9c5b9"

fig, ax = plt.subplots(figsize=(8.4, 4.6), constrained_layout=True)
ax.plot(versions, checks, color=ACCENT, linewidth=2.2, marker="o",
        markersize=6, markerfacecolor=ACCENT, markeredgecolor="white",
        markeredgewidth=1.2, zorder=3)
ax.fill_between(versions, checks, 200, color=ACCENT, alpha=0.08, zorder=1)

for x, y in zip(versions, checks):
    ax.annotate(str(y), (x, y), textcoords="offset points", xytext=(0, 9),
                ha="center", fontsize=9.5, color=TEXT, fontweight="bold")

ax.set_ylabel("Automated checks", fontsize=10.5, color=TEXT)
ax.set_ylim(200, 410)
ax.grid(axis="y", color=BORDER, linewidth=0.6, alpha=0.8)
ax.set_axisbelow(True)
for spine in ["top", "right"]:
    ax.spines[spine].set_visible(False)
for spine in ["left", "bottom"]:
    ax.spines[spine].set_color(MUTED)
ax.tick_params(colors=TEXT, labelsize=9.5)
ax.annotate("Alive City block\n(+45 checks)", xy=("v2.4.0", 379), xytext=(-118, -6),
            textcoords="offset points", fontsize=9, color=MUTED,
            va="top", ha="left")
fig.savefig("/home/z/my-project/scripts/v240_suite_growth.png", dpi=200)
print("chart written")
