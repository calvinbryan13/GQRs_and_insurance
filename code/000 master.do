set more off
clear all
macro drop _all
set checksum off
capture log close

global initialpath "C:\Users\cbryan\Box\Cal's Personal Laptop Files\git_projects\GQRs_and_insurance"
*global initialpath "" \\ Others can set their filepaths here
*global initialpath ""

cd "${initialpath}"

log using ".\logs\policy_ins_oct13_2026.log", replace

* Cal's paths

global rawpath     ".\data\raw data\"
global datapath    ".\data\processed data\"
global mappath		".\data\map data\"
global dopath      "./code/"
global estpath     "./estimates/"
global tabpath     "./tables/"
global figpath     "./figures/"
global outputpath	"./outputs/"

*do "${dopath}001 import_data"

*do "${dopath}001_01 gen NRD_county_shares"

*do "${dopath}001_02 gen KS_cty_shares"

*do "${dopath}001_03 import_SOB"

*do "${dopath}001_04 gen_rp"

*do "${dopath}002 process_data"


log close
