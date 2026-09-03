# Radiophobia Atmospherics Compatibility Patch

This is a compatibility overlay for **Atmospherics 2.69 RC6.5 OGSR Edition**
for Radiophobia 3 1.20 with the Radiophobia OGSR 3.548 Engine Upgrade RC3 or
newer. It is not a standalone copy of Atmospherics.

Install the engine upgrade first, install the original Atmospherics package,
then place this compatibility overlay after Atmospherics so this add-on wins
all file conflicts.

Install Atmospherics normally then place the contents of this patch over it.

Back up saves before changing the weather stack. 
Downgrading a save after writing it with a newer engine/add-on combination is not guaranteed.

## Weather balance

The compatibility controller selects logical weather families before choosing
an Atmospherics visual variant. Extra rain and storm visuals therefore no
longer increase their starting probability or reset the family duration timer.

Clear forecasts use the three genuinely clear, dry cycles. The four partly or
overcast cycles are classified as cloudy; `w_partly4` retains Atmospherics'
authored light drizzle. New/reset forecasts start with a 45% clear, 30% cloudy,
10% rain, 5% storm, and 10% fog family mix. Wet cycles are shorter and their
transition weights are reduced relative to stock Radiophobia.

This revision advances the weather save version from 2 to 3. The next load
discards only the saved forecast and rebuilds it with the corrected model; it
does not invalidate the game save.
