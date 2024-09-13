
# gcam-china-postCO2emiss

Author: Rui Wang and Yang Ou

Contact:  
Rui Wang - ruiwang.rr@gmail.com
Yang Ou  - yang.ou@pku.edu.cn

## Usage note

(1) Download the package into GCAM-China folder

(2) Run gcamdata system to generate CSV files in the output folders, as the code requires reading the markets in the output folder

(3) Run your GCAM-China scenario to generate the following:

* Input by tech (or energy consumpy by tech)
* Output by tech
* Carbon emission by tech

Save these results into the csv folder and save the with the following names:

* EnergyConsumpByTech.csv
* OutputByTech.csv
* CO2byTech.csv

Tempelates are provided in this package.

(4) Use Rstudio to run the CO2_process_China.R. script. Some packages may need to be installed by following the prompts indicated by RStudio.

(5) In the end, the script will generate the P_co2_sector.csv file, which contains the corrected carbon emissions for each sector. A validation table will also appear if the code runs successfully.
