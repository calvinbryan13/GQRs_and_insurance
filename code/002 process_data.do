import delimited "${datapath}paneled_weather_2000_2020.csv", clear
	
	************ Include Ogallala Aquifer shares ******************
	
	merge m:1 fips using "${rawpath}ogal_share.dta"
		keep if _merge == 3
		drop _merge
	
	**** Calculating APH and merging that data in here
preserve	
	do "${dopath}002_01 process_aph"
restore

	merge m:1 fips year using "${datapath}aph_10year"
		drop if _merge == 2
		drop _merge
		
	drop if fips == .
	
preserve	
	do "${dopath}002_02 process_crop_var"
restore	

	
	merge m:1 fips year using "${datapath}corn_var_10year"
		drop if _merge == 2
		drop _merge
			
	merge m:1 fips year using "${datapath}nonirr_corn_yield"
		drop if _merge == 2
		drop _merge
	
	merge m:1 fips year using "${datapath}irr_corn_var_10year"
		drop if _merge == 2
		drop _merge	

	merge m:1 fips year using "${datapath}soybean_var_10year"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}irr_soybean_var_10year"
		drop if _merge == 2
		drop _merge	

	merge m:1 fips year using "${datapath}sorghum_var_10year"
		drop if _merge == 2
		drop _merge

	merge m:1 fips year using "${datapath}irr_sorghum_var_10year"
		drop if _merge == 2
		drop _merge	

	merge m:1 fips year using "${datapath}wheat_var_10year"
		drop if _merge == 2
		drop _merge	

	merge m:1 fips year using "${datapath}irr_wheat_var_10year"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}irr_corn_prod"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}irr_corn_acres_harvested"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}irr_sb_prod"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}irr_sorghum_prod"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}irr_wheat_prod"
		drop if _merge == 2
		drop _merge
		

		
*** Creating a state code to pull in county names		
	gen state_code = "."
		replace state_code = "CO" if state_fips == 8
		replace state_code = "IA" if state_fips == 19
		replace state_code = "KS" if state_fips == 20
		replace state_code = "NE" if state_fips == 31
		replace state_code = "NM" if state_fips == 35
		replace state_code = "OK" if state_fips == 40
		replace state_code = "SD" if state_fips == 46
		replace state_code = "TX" if state_fips == 48
		replace state_code = "WY" if state_fips == 56	
		
	merge m:1 fips using "${rawpath}county_crosswalk.dta"
		keep if _merge == 3
		drop _merge
		
		drop ORI fcounty

********** Including NRD county-shares ******************
	merge m:1 fips year using "${datapath}nrd_cty_shares"
		drop if _merge == 2
		drop _merge
		
	drop nrd_share_9	
	
********** Generating a rate parameter difference **************
	
	merge m:1 fips year using "${datapath}USDA_rate_parameters"
		drop if _merge == 2
		drop _merge
		
**************** Lagging weather variables *********************
sort fips year
by fips: gen maxtemp_lag1 = maxtemp[_n-1]
		la var maxtemp_lag1 "Max. Temperature One-Year Lag"
		
by fips: gen precip_lag1 = precip[_n-1]
		la var precip_lag1 "Precipitation One-Year Lag"		
		
*** Merging in Kansas Lema shares now
	
	merge m:1 fips using "${datapath}KS_lema_shares"
		drop if _merge == 2
		drop _merge
		
	replace lema_share = 0 if lema_share == .
		
*** Merging in "mean saturated thickness" of Ogallala by county

preserve
	import delimited "${rawpath}mean_sat_thick.csv", clear
	
	rename saturated_thickness sat_thick
	
	save "${datapath}mean_sat_thick", replace
restore

	merge m:1 fips year using "${datapath}mean_sat_thick", force
		drop if _merge == 2
		drop _merge
		
	destring sat_thick, replace force
	
	gen sat_thick_sq = (sat_thick)^2
		
* ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ *		
************************* Merging in acreage data ******************************
* _____________________________________________________________________________*
	
*!!!!!!!! Corn
preserve
	import delimited "${rawpath}corn_acres_all.csv", clear

	rename stateansi state_fips
	rename countyansi county_fips
	rename value corn_acres
		replace corn_acres=subinstr(corn_acres,",","",.)
		destring corn_acres, force replace
		la var corn_acres "Corn Acres Planted"
		
	keep state_fips county_fips corn_acres year
		drop if county_fips == .
	
	duplicates tag year state_fips county_fips, gen(flag)
	
	save "${rawpath}corn_planted_acres", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}corn_planted_acres"
		drop if _merge == 2
		drop _merge
		
*!!!!!!!! Irrigated Corn
preserve
	import delimited "${rawpath}irr_corn_acres_planted.csv", clear
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_corn_acres
		replace irr_corn_acres = subinstr(irr_corn_acres,",","",.)
		destring irr_corn_acres, force replace
		la var irr_corn_acres "Irrigated Corn Acres Planted"
		
	keep state_fips county_fips irr_corn_acres year
		drop if county_fips == .
		
	save "${rawpath}irr_corn_planted_acres", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}irr_corn_planted_acres"
		drop if _merge == 2
		drop _merge	
		
*!!!!!!!! Non-Irrigated Corn
preserve
	import delimited "${rawpath}corn_acres_nonirrigated.csv", clear
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value nonirr_corn_acres
		replace nonirr_corn_acres = subinstr(nonirr_corn_acres,",","",.)
		destring nonirr_corn_acres, force replace
		la var nonirr_corn_acres "Non-Irrigated Corn Acres Planted"
		
	keep state_fips county_fips nonirr_corn_acres year
		drop if county_fips == .
		
	save "${rawpath}nonirr_corn_planted_acres", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}nonirr_corn_planted_acres"
		drop if _merge == 2
		drop _merge
	
*!!!!!!!! Soybean
preserve
	import delimited "${rawpath}soybean_planted_acres.csv", clear

	rename stateansi state_fips
	rename countyansi county_fips
	rename value sb_acres
		replace sb_acres=subinstr(sb_acres,",","",.)
		destring sb_acres, force replace
		la var sb_acres "Soybean Acres Planted"
		
	keep state_fips county_fips sb_acres year
		drop if county_fips == .
	
	duplicates tag year state_fips county_fips, gen(flag)
	
	save "${rawpath}soybean_planted_acres", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}soybean_planted_acres"
		drop if _merge == 2
		drop _merge
		
*!!!!!!!! Irrigated Soybean
preserve
	import delimited "${rawpath}soybean_acres_irrigated.csv", clear

	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_sb_acres
		replace irr_sb_acres=subinstr(irr_sb_acres,",","",.)
		destring irr_sb_acres, force replace
		la var irr_sb_acres "Irrigated Soybean Acres Planted"
		
	keep state_fips county_fips irr_sb_acres year
		drop if county_fips == .
	
	duplicates tag year state_fips county_fips, gen(flag)
	
	save "${rawpath}soybean_acres_irrigated", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}soybean_acres_irrigated"
		drop if _merge == 2
		drop _merge
		
*!!!!!!!! Non-Irrigated Soybean
preserve
	import delimited "${rawpath}soybean_acres_nonirrigated.csv", clear

	rename stateansi state_fips
	rename countyansi county_fips
	rename value nonirr_sb_acres
		replace nonirr_sb_acres=subinstr(nonirr_sb_acres,",","",.)
		destring nonirr_sb_acres, force replace
		la var nonirr_sb_acres "Non-Irrigated Soybean Acres Planted"
		
	keep state_fips county_fips nonirr_sb_acres year
		drop if county_fips == .
	
	duplicates tag year state_fips county_fips, gen(flag)
	
	save "${rawpath}soybean_acres_nonirrigated", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}soybean_acres_nonirrigated"
		drop if _merge == 2
		drop _merge		
		
*!!!!!!!!! Sorghum
preserve
	import delimited "${rawpath}sorghum_planted_acres.csv", clear

	rename stateansi state_fips
	rename countyansi county_fips
	rename value sorghum_acres
		replace sorghum_acres=subinstr(sorghum_acres,",","",.)
		destring sorghum_acres, force replace
		la var sorghum_acres "Sorghum Acres Planted"
		
	keep state_fips county_fips sorghum_acres year
		drop if county_fips == .
	
	save "${rawpath}sorghum_planted_acres", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}sorghum_planted_acres"
		drop if _merge == 2
		drop _merge
		
*!!!!!!!!! Irrigated Sorghum
preserve
	import delimited "${rawpath}sorghum_acres_irrigated.csv", clear

	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_sorghum_acres
		replace irr_sorghum_acres=subinstr(irr_sorghum_acres,",","",.)
		destring irr_sorghum_acres, force replace
		la var irr_sorghum_acres "Irrigated Sorghum Acres Planted"
		
	keep state_fips county_fips irr_sorghum_acres year
		drop if county_fips == .
	
	save "${rawpath}sorghum_acres_irrigated", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}sorghum_acres_irrigated"
		drop if _merge == 2
		drop _merge		
		
*!!!!!!!!! Non-Irrigated Sorghum
preserve
	import delimited "${rawpath}sorghum_acres_nonirrigated.csv", clear

	rename stateansi state_fips
	rename countyansi county_fips
	rename value nonirr_sorghum_acres
		replace nonirr_sorghum_acres=subinstr(nonirr_sorghum_acres,",","",.)
		destring nonirr_sorghum_acres, force replace
		la var nonirr_sorghum_acres "Non-Irrigated Sorghum Acres Planted"
		
	keep state_fips county_fips nonirr_sorghum_acres year
		drop if county_fips == .
	
	save "${rawpath}sorghum_acres_nonirrigated", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}sorghum_acres_nonirrigated"
		drop if _merge == 2
		drop _merge	
		
*!!!!!!!!!!! Wheat
* Winter Acres (Wheat) 
preserve
	import delimited "${rawpath}wheat_winter_acres.csv", clear
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value wint_wheat_acres
		replace wint_wheat_acres=subinstr(wint_wheat_acres,",","",.)
		destring wint_wheat_acres, force replace
		la var wint_wheat_acres "Wheat Acres Planted (Winter)"
		
	keep state_fips county_fips wint_wheat_acres year
		drop if county_fips == .
		
	save "${rawpath}wheat_winter_acres", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}wheat_winter_acres"
		drop if _merge == 2
		drop _merge
		
* Winter Acres (Irrigated Wheat)
preserve
	import delimited "${rawpath}wheat_winter_acres_irrigated.csv", clear
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_wint_wheat_acres
		replace irr_wint_wheat_acres=subinstr(irr_wint_wheat_acres,",","",.)
		destring irr_wint_wheat_acres, force replace
		la var irr_wint_wheat_acres "Irrigated Wheat Acres Planted (Winter)"
		
	keep state_fips county_fips irr_wint_wheat_acres year
		drop if county_fips == .
		
	save "${rawpath}irr_wheat_winter_acres", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}irr_wheat_winter_acres"
		drop if _merge == 2
		drop _merge
		
* Winter Acres (Non-Irrigated Wheat)
preserve
	import delimited "${rawpath}wheat_winter_acres_nonirrigated.csv", clear
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value nonirr_wint_wheat_acres
		replace nonirr_wint_wheat_acres=subinstr(nonirr_wint_wheat_acres,",","",.)
		destring nonirr_wint_wheat_acres, force replace
		la var nonirr_wint_wheat_acres "Non-Irrigated Wheat Acres Planted (Winter)"
		
	keep state_fips county_fips nonirr_wint_wheat_acres year
		drop if county_fips == .
		
	save "${rawpath}nonirr_wheat_winter_acres", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}nonirr_wheat_winter_acres"
		drop if _merge == 2
		drop _merge		
		
* Spring Wheat (Dulum) Acres
preserve
	import delimited "${rawpath}wheat_dulum_acres.csv", clear
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value sprdul_wheat_acres
		replace sprdul_wheat_acres=subinstr(sprdul_wheat_acres,",","",.)
		destring sprdul_wheat_acres, force replace
		la var sprdul_wheat_acres "Wheat Acres Planted (Spring - Dulum)"
		
	keep state_fips county_fips sprdul_wheat_acres year
		drop if county_fips == .
		
	save "${rawpath}wheat_dulum_spring_acres", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}wheat_dulum_spring_acres"
		drop if _merge == 2
		drop _merge
		
* Spring Irrigated Wheat (Dulum) Acres
preserve
	import delimited "${rawpath}wheat_dulum_acres_irrigated.csv", clear
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_sprdul_wheat_acres
		replace irr_sprdul_wheat_acres=subinstr(irr_sprdul_wheat_acres,",","",.)
		destring irr_sprdul_wheat_acres, force replace
		la var irr_sprdul_wheat_acres "Irrigated Wheat Acres Planted (Spring - Dulum)"
		
	keep state_fips county_fips irr_sprdul_wheat_acres year
		drop if county_fips == .
		
	save "${rawpath}irr_wheat_dulum_spring_acres", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}irr_wheat_dulum_spring_acres"
		drop if _merge == 2
		drop _merge
		
* Spring Non-Irrigated Wheat (Dulum) Acres
preserve
	import delimited "${rawpath}wheat_dulum_acres_nonirrigated.csv", clear
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value nonirr_sprdul_wheat_acres
		replace nonirr_sprdul_wheat_acres=subinstr(nonirr_sprdul_wheat_acres,",","",.)
		destring nonirr_sprdul_wheat_acres, force replace
		la var nonirr_sprdul_wheat_acres "Non-Irrigated Wheat Acres Planted (Spring - Dulum)"
		
	keep state_fips county_fips nonirr_sprdul_wheat_acres year
		drop if county_fips == .
		
	save "${rawpath}nonirr_wheat_dulum_spring_acres", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}nonirr_wheat_dulum_spring_acres"
		drop if _merge == 2
		drop _merge
		
* Spring (Non-Dulum) Acres
preserve
	import delimited "${rawpath}wheat_nondul_acres.csv", clear
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value sprnd_wheat_acres
		replace sprnd_wheat_acres=subinstr(sprnd_wheat_acres,",","",.)
		destring sprnd_wheat_acres, force replace
		la var sprnd_wheat_acres "Wheat Acres Planted (Spring - Non-Dulum)"
		
	keep state_fips county_fips sprnd_wheat_acres year
		drop if county_fips == .
		
	save "${rawpath}wheat_nondulum_acres", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}wheat_nondulum_acres"
		drop if _merge == 2
		drop _merge
		
* Spring Irrigated Wheat (Non-Dulum) Acres
preserve
	import delimited "${rawpath}wheat_nondul_acres_irrigated.csv", clear
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_sprnd_wheat_acres
		replace irr_sprnd_wheat_acres=subinstr(irr_sprnd_wheat_acres,",","",.)
		destring irr_sprnd_wheat_acres, force replace
		la var irr_sprnd_wheat_acres "Irrigated Wheat Acres Planted (Spring - Non-Dulum)"
		
	keep state_fips county_fips irr_sprnd_wheat_acres year
		drop if county_fips == .
		
	save "${rawpath}wheat_nondulum_acres_irrigated", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}wheat_dulum_acres_irrigated"
		drop if _merge == 2
		drop _merge
		
* Spring Non-Irrigated Wheat (Non-Dulum) Acres
preserve
	import delimited "${rawpath}wheat_nondul_acres_nonirrigated.csv", clear
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value nonirr_sprnd_wheat_acres
		replace nonirr_sprnd_wheat_acres=subinstr(nonirr_sprnd_wheat_acres,",","",.)
		destring nonirr_sprnd_wheat_acres, force replace
		la var nonirr_sprnd_wheat_acres "Non-Irrigated Wheat Acres Planted (Spring - Non-Dulum)"
		
	keep state_fips county_fips nonirr_sprnd_wheat_acres year
		drop if county_fips == .
		
	save "${rawpath}wheat_nondulum_acres_nonirrigated", replace
restore

	merge m:1 state_fips county_fips year using "${rawpath}wheat_dulum_acres_nonirrigated"
		drop if _merge == 2
		drop _merge
	
*** Aggregating all wheat acres in a county-year	
	egen wheat_acres = rowtotal(wint_wheat_acres sprdul_wheat_acres sprnd_wheat_acres)
		la var wheat_acres "Total Wheat Planted Acres (Winter and Spring)"
		
	replace wheat_acres = 0 if wheat_acres == .
	
	egen irr_wheat_acres = rowtotal(irr_wint_wheat_acres irr_sprdul_wheat_acres irr_sprnd_wheat_acres)
		la var irr_wheat_acres "Total Irrigated Wheat Planted Acres (Winter and Spring)"
	
	replace irr_wheat_acres = 0 if irr_wheat_acres == .
	
	egen nonirr_wheat_acres = rowtotal(nonirr_wint_wheat_acres nonirr_sprdul_wheat_acres nonirr_sprnd_wheat_acres)
		la var irr_wheat_acres "Total Non-Irrigated Wheat Planted Acres (Winter and Spring)"
	
	replace nonirr_wheat_acres = 0 if nonirr_wheat_acres == .
*_______________________________________________________________________________	
* Aggregating Planted Acres across all "Top Five" crop types
	egen total_t5_acres = rowtotal(corn_acres sb_acres sorghum_acres wheat_acres)
		replace total_t5_acres = 0 if total_t5_acres == .
		
* Creating the "Insured Acre Ratio" variable
	gen ins_acre_ratio = insured_acres/total_t5_acres
	
* Creating a new yield variable, with production/planted acres

	gen irr_corn_ppa = irr_corn_prod/irr_corn_acres
		la var irr_corn_ppa "Irrigated Corn Production per Acre"
		
	gen irr_sb_ppa = irr_sb_prod/irr_sb_acres
		la var irr_sb_ppa "Irrigated Soybean Production per Acre"
		
	gen irr_sorghum_ppa = irr_sorghum_prod/irr_sorghum_acres
		la var irr_sorghum_ppa "Irrigated Sorghum Production per Acre"
		
	gen irr_wheat_ppa = irr_wheat_prod/irr_wint_wheat_acres
		la var irr_wheat_ppa "Irrigated Wheat Production per Acre"
		

**** Merging in corn-specific variables and insurance policy variables

	merge m:1 fips year using "${datapath}ins_policies_agg"
		drop if _merge == 2
		drop _merge		
		
	merge m:1 fips year using "${datapath}corn_ins_policies"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}sb_ins_policies"
		drop if _merge == 2
		drop _merge	
		
	merge m:1 fips year using "${datapath}sorghum_ins_policies"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}wheat_ins_policies"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}SOB_corn"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}SOB_irrcorn"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}SOB_nonirrcorn"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}SOB_sb"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}SOB_irrsb"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}SOB_nonirrsb"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}SOB_sorghum"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}SOB_irrsorghum"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}SOB_nonirrsorghum"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}SOB_wheat"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}SOB_irrwheat"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}SOB_nonirrwheat"
		drop if _merge == 2
		drop _merge	
		
	merge m:1 fips year using "${datapath}corn_lr_collapsed"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}irr_corn_lr_collapsed"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}nonirr_corn_lr_collapsed"
		drop if _merge == 2
		drop _merge	
		
	merge m:1 fips year using "${datapath}sb_lr_collapsed"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}irr_sb_lr_collapsed"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}nonirr_sb_lr_collapsed"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}sorghum_lr_collapsed"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}irr_sorghum_lr_collapsed"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}nonirr_sorghum_lr_collapsed"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}wheat_lr_collapsed"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}irr_wheat_lr_collapsed"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}nonirr_wheat_lr_collapsed"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}SOB_corn_policy_shares"
		drop if _merge == 2
		drop _merge
		
* Importing the price of corn
preserve
	import delimited "${rawpath}NASS_corn.csv", clear
	
	keep year period geolevel state stateansi commodity dataitem value
	
	rename value corn_price
		destring corn_price, replace force
	rename stateansi state_fips
	
	collapse (mean) corn_price, by (state_fips year)
	
	save "${rawpath}NASS_corn", replace
restore

	merge m:1 year state_fips using "${rawpath}NASS_corn"
		drop if _merge == 2
		drop _merge
		
* Importing the price of soybean
preserve
	import delimited "${rawpath}NASS_soybeans.csv", clear
	
	keep year period geolevel state stateansi commodity dataitem value
	
	rename value sb_price
		destring sb_price, replace force
	rename stateansi state_fips
	
	collapse (mean) sb_price, by (state_fips year)
	
	save "${rawpath}NASS_sb", replace
restore

	merge m:1 year state_fips using "${rawpath}NASS_sb"
		drop if _merge == 2
		drop _merge
		
* Importing the price of sorghum
preserve
	import delimited "${rawpath}NASS_sorghum.csv", clear
	
	keep year period geolevel state stateansi commodity dataitem value
	
	rename value sorghum_price
		destring sorghum_price, replace force
	rename stateansi state_fips
	
	collapse (mean) sorghum_price, by (state_fips year)
	
	save "${rawpath}NASS_sorghum", replace
restore

	merge m:1 year state_fips using "${rawpath}NASS_sorghum"
		drop if _merge == 2
		drop _merge
		
* Importing the price of wheat
preserve
	import delimited "${rawpath}NASS_wheat.csv", clear
	
	keep year period geolevel state stateansi commodity dataitem value
	
	rename value wheat_price
		destring wheat_price, replace force
	rename stateansi state_fips
	
	collapse (mean) wheat_price, by (state_fips year)
	
	save "${rawpath}NASS_wheat", replace
restore

	merge m:1 year state_fips using "${rawpath}NASS_wheat"
		drop if _merge == 2
		drop _merge
		
********* CREATING A "Irrigated crop price" and "Non-Irrigated crop price" variable
********* to make the loop easier when I run regressions later.

	gen irr_corn_price = corn_price
	gen nonirr_corn_price = corn_price
	gen irr_sb_price = sb_price
	gen nonirr_sb_price = sb_price
	gen irr_sorghum_price = sorghum_price
	gen nonirr_sorghum_price = sorghum_price
	gen irr_wheat_price = wheat_price
	gen nonirr_wheat_price = wheat_price
		
************* CLEANING CORN AND IRRIGATED/NON-IRRIGATED CORN VAR'S *************

	gen corn_rate_parameter = (corn_prem - corn_sub)/corn_liab
		la var corn_rate_parameter "Premium per Liability for corn"
		
	gen irr_corn_rate_parameter = (irr_corn_prem - irr_corn_sub)/irr_corn_liab
		la var irr_corn_rate_parameter "Premium per Liability for irrigated corn"
		
	gen nonirr_corn_rate_parameter = (nonirr_corn_prem - nonirr_corn_sub)/nonirr_corn_liab
		la var nonirr_corn_rate_parameter "Premium per Liability for non-irrigated corn"
		
	gen corn_ln_ia = ln(corn_ins_acres)
		la var corn_ln_ia "Ln(Corn Insured Acres)"
	
	gen irr_corn_ln_ia = ln(irr_corn_ins_acres)
		la var irr_corn_ln_ia "Ln(Irrigated Corn Insured Acres)"
		
	gen nonirr_corn_ln_ia = ln(nonirr_corn_ins_acres)
		la var nonirr_corn_ln_ia "Ln(Non-Irrigated Corn Insured Acres)"
		
	gen irr_corn_ln_pa = ln(irr_corn_acres)
		la var irr_corn_ln_pa "Ln(Irrigated Corn Planted Acres)"
		
	gen nonirr_corn_ln_pa = ln(nonirr_corn_acres)
		la var nonirr_corn_ln_pa "Ln(Non-Irrigated Corn Planted Acres)"
	
	gen corn_ln_pa = ln(corn_acres)
		la var corn_ln_pa "Ln(Corn Planted Acres)"
		
	gen corn_iar = corn_ins_acres/corn_acres
		la var corn_iar "Insured Acre Ratio for corn"
		
	gen irr_corn_iar = irr_corn_ins_acres/irr_corn_acres
		la var irr_corn_iar "Insured Acre Ratio for irrigated corn"
		
	gen nonirr_corn_iar = nonirr_corn_ins_acres/nonirr_corn_acres
		la var nonirr_corn_iar "Insured Acre Ratio for non-irrigated corn"
		
	gen corn_ipa = corn_indem/corn_acres
		la var corn_ipa "Indemnity per Ins. Acre for corn"
		
	gen irr_corn_ipa = irr_corn_indem/irr_corn_acres
		la var irr_corn_ipa "Indemnity per Ins. Acre for irrigated corn"
		
	gen nonirr_corn_ipa = nonirr_corn_indem/nonirr_corn_acres
		la var nonirr_corn_ipa "Indemnity per Ins. Acre for non-irrigated corn"
		
	gen corn_liab_acre = corn_liab/corn_acres
		la var corn_liab_acre "Liability per planted acre for corn"
		
	gen corn_liab_ia = corn_liab/corn_ins_acres
		la var corn_liab_ia "Liability per insured acre for corn"
		
	gen irr_corn_liab_acre = irr_corn_liab/irr_corn_acres
		la var irr_corn_liab_acre "Liability per planted acre for irr. corn"
		
	gen irr_corn_liab_ia = irr_corn_liab/irr_corn_ins_acres
		la var irr_corn_liab_acre "Liability per insured acre for irr. corn"
		
	gen nonirr_corn_liab_acre = nonirr_corn_liab/nonirr_corn_acres
		la var nonirr_corn_liab_acre "Liability per planted acre for non-irr. corn"
		
	gen nonirr_corn_liab_ia = nonirr_corn_liab/nonirr_corn_ins_acres
		la var nonirr_corn_liab_acre "Liability per insured acre for non-irr. corn"
		
	gen corn_ln_liab = ln(corn_liab)
		la var corn_ln_liab "Logged Total Liability for Corn"
		
	gen irr_corn_ln_liab = ln(irr_corn_liab)
		la var irr_corn_ln_liab "Logged Total Liability for Irr. Corn"
		
	gen nonirr_corn_ln_liab = ln(nonirr_corn_liab)
		la var nonirr_corn_ln_liab "Logged Total Liability for Non-irr. Corn"	

	gen corn_sub_per_liab = corn_sub/corn_liab
		la var corn_sub_per_liab "Subsidy per Liability for Corn"
		
	gen irr_corn_sub_per_liab = irr_corn_sub/irr_corn_liab
		la var irr_corn_sub_per_liab "Subsidy per Liability for Irrigated Corn"
		
	gen nonirr_corn_sub_per_liab = nonirr_corn_sub/nonirr_corn_liab
		la var nonirr_corn_sub_per_liab "Subsidy per Liability for Non-Irrigated Corn"
	
	gen corn_ln_indem = ln(corn_indem)
		la var corn_ln_indem "Ln(Indemnity payment for corn)"
		
	gen irr_corn_ln_indem = ln(irr_corn_indem)
		la var irr_corn_ln_indem "Ln(Indemnity payment for irrigated corn"
		
	gen nonirr_corn_ln_indem = ln(nonirr_corn_indem)
		la var nonirr_corn_ln_indem "Ln(Indemnity payment for non-irrigated corn"	

	gen corn_ln_cov = ln(corn_cov_level)
		la var corn_ln_cov "Ln(Coverage level for corn)"
		
	gen irr_corn_ln_cov = ln(irr_corn_cov_level)
		la var irr_corn_ln_cov "Ln(Coverage level for irrigated corn"
		
	gen nonirr_corn_ln_cov = ln(nonirr_corn_cov_level)
		la var nonirr_corn_ln_cov "Ln(Coverage level for non-irrigated corn"
		
	gen corn_ln_sub = ln(corn_sub)
		la var corn_ln_sub "Ln(Insurance subsidy for corn)"
		
	gen irr_corn_ln_sub = ln(irr_corn_sub)
		la var irr_corn_ln_sub "Ln(Insurance subsidy for irrigated corn)"
		
	gen nonirr_corn_ln_sub = ln(nonirr_corn_sub)
		la var nonirr_corn_ln_sub "Ln(Insurance susbidy for irrigated corn)"
		
	gen corn_ln_prem = ln(corn_prem)
		la var corn_ln_prem "Ln(Insurance premium for corn)"
		
	gen irr_corn_ln_prem = ln(irr_corn_prem)
		la var irr_corn_ln_prem "Ln(Insurance premium for irrigated corn)"
		
	gen nonirr_corn_ln_prem = ln(nonirr_corn_prem)
		la var nonirr_corn_ln_prem "Ln(Insurance premium for irrigated corn)"
		
	gen corn_spl = corn_sub/corn_liab
		la var corn_spl "Corn Subsidy per Liability"
		
	gen irr_corn_spl = irr_corn_sub/irr_corn_liab
		la var irr_corn_spl "Irrigated Corn Subsidy per Liability"
		
	gen nonirr_corn_spl = nonirr_corn_sub/nonirr_corn_liab
		la var nonirr_corn_spl "Non-Irrigated Corn Subsidy per Liability"
		
	gen corn_spp = corn_sub/corn_prem
		la var corn_spp "Corn Subsidy per Premium"
		
	gen irr_corn_spp = irr_corn_sub/irr_corn_prem
		la var irr_corn_spp "Irrigated Corn Subsidy per Premium"
		
	gen nonirr_corn_spp = nonirr_corn_sub/nonirr_corn_prem
		la var nonirr_corn_spp "Non-Irrigated Corn Subsidy per Premium"
		
	gen corn_liab_per_policy = corn_liab/corn_policies
		la var corn_liab_per_policy "Liability per policy (corn)"
	
	gen corn_prem_pa = corn_prem/corn_acres
		la var corn_prem_pa "Corn Insurance Premium per Acre (county-wide)"
 	
	gen irr_corn_prem_pa = irr_corn_prem/irr_corn_acres
		la var irr_corn_prem_pa "Irr. Corn Insurance Premium per Acre (county-wide)"
 	
	gen nonirr_corn_prem_pa = nonirr_corn_prem/nonirr_corn_acres
		la var nonirr_corn_prem_pa "Non-Irr. Corn Insurance Premium per Acre (county-wide)"
 
 	gen corn_prem_pia = corn_prem/corn_ins_acres
		la var corn_prem_pia "Corn Insurance Premium per Insured Acre (county-wide)"
 	
	gen irr_corn_prem_pia = irr_corn_prem/irr_corn_ins_acres
		la var irr_corn_prem_pia "Irr. Corn Insurance Premium per Insured Acre (county-wide)"
 	
	gen nonirr_corn_prem_pia = nonirr_corn_prem/nonirr_corn_ins_acres
		la var nonirr_corn_prem_pia "Non-Irr. Corn Insurance Premium per Insured Acre (county-wide)"
  	
	gen corn_sub_pia = corn_sub/corn_ins_acres
		la var corn_sub_pia "Corn Insurance Subsidy per Insured Acre (county-wide)"
 	
	gen irr_corn_sub_pia = irr_corn_sub/irr_corn_ins_acres
		la var irr_corn_sub_pia "Irr. Corn Insurance Subsidy per Insured Acre (county-wide)"
 	
	gen nonirr_corn_sub_pia = nonirr_corn_sub/nonirr_corn_ins_acres
		la var nonirr_corn_sub_pia "Non-Irr. Corn Insurance Subsidy per Insured Acre (county-wide)"
 
	gen corn_ln_yield = ln(corn_yield)
		la var corn_ln_yield "Ln(Corn Yield)"
		
	gen irr_corn_ln_yield = ln(irr_corn_yield)
		la var irr_corn_ln_yield "Ln(Irr. Corn Yield)"
		
	gen nonirr_corn_ln_yield = ln(nonirr_corn_yield)
		la var nonirr_corn_ln_yield "Ln(Non-Irr. Corn Yield)"
		
*********** CLEANING SOYBEAN AND IRRIGATED/NON-IRRIGATED SB VAR'S **************

	gen sb_rate_parameter = (sb_prem - sb_sub)/sb_liab
		la var sb_rate_parameter "Premium per Liability for soybean"
		
	gen irr_sb_rate_parameter = (irr_sb_prem - irr_sb_sub)/irr_sb_liab
		la var irr_sb_rate_parameter "Premium per Liability for irrigated soybean"
		
	gen nonirr_sb_rate_parameter = (nonirr_sb_prem - nonirr_sb_prem)/nonirr_sb_liab
		la var nonirr_sb_rate_parameter "Premium per Liability for non-irrigated soybean"
		
	gen sb_ln_ia = ln(sb_ins_acres)
		la var sb_ln_ia "Ln(soybean Insured Acres)"
	
	gen irr_sb_ln_ia = ln(irr_sb_ins_acres)
		la var irr_sb_ln_ia "Ln(Irrigated soybean Insured Acres)"
		
	gen nonirr_sb_ln_ia = ln(nonirr_sb_ins_acres)
		la var nonirr_sb_ln_ia "Ln(Non-Irrigated soybean Insured Acres)"
		
	gen irr_sb_ln_pa = ln(irr_sb_acres)
		la var irr_sb_ln_pa "Ln(Irrigated Soybean Planted Acres)"
		
	gen nonirr_sb_ln_pa = ln(nonirr_sb_acres)
		la var nonirr_sb_ln_pa "Ln(Non-Irrigated Soybean Planted Acres)"
	
	gen sb_ln_pa = ln(sb_acres)
		la var sb_ln_pa "Ln(Soybean Planted Acres)"
		
	gen sb_iar = sb_ins_acres/sb_acres
		la var sb_iar "Insured Acre Ratio for soybean"
		
	gen irr_sb_iar = irr_sb_ins_acres/irr_sb_acres
		la var irr_sb_iar "Insured Acre Ratio for irrigated soybean"
		
	gen nonirr_sb_iar = nonirr_sb_ins_acres/nonirr_sb_acres
		la var nonirr_sb_iar "Insured Acre Ratio for non-irrigated soybean"
		
	gen sb_ipa = sb_indem/sb_acres
		la var sb_ipa "Indemnity per Ins. Acre for soybean"
		
	gen irr_sb_ipa = irr_sb_indem/irr_sb_acres
		la var irr_sb_ipa "Indemnity per Ins. Acre for irrigated soybean"
		
	gen nonirr_sb_ipa = nonirr_sb_indem/nonirr_sb_acres
		la var nonirr_sb_ipa "Indemnity per Ins. Acre for non-irrigated soybean"
		
	gen sb_liab_acre = sb_liab/sb_acres
		la var sb_liab_acre "Liability per planted acre for soybean"
		
	gen sb_liab_ia = sb_liab/sb_ins_acres
		la var sb_liab_ia "Liability per insured acre for soybean"
		
	gen irr_sb_liab_acre = irr_sb_liab/irr_sb_acres
		la var irr_sb_liab_acre "Liability per planted acre for irr. soybean"
		
	gen irr_sb_liab_ia = irr_sb_liab/irr_sb_ins_acres
		la var irr_sb_liab_acre "Liability per insured acre for irr. soybean"
		
	gen nonirr_sb_liab_acre = nonirr_sb_liab/nonirr_sb_acres
		la var nonirr_sb_liab_acre "Liability per planted acre for non-irr. soybean"
		
	gen nonirr_sb_liab_ia = nonirr_sb_liab/nonirr_sb_ins_acres
		la var nonirr_sb_liab_acre "Liability per insured acre for non-irr. soybean"	
		
	gen sb_ln_liab = ln(sb_liab)
		la var sb_ln_liab "Logged Total Liability for Soybean"
		
	gen irr_sb_ln_liab = ln(irr_sb_liab)
		la var irr_sb_ln_liab "Logged Total Liability for Irr. Soybean"
		
	gen nonirr_sb_ln_liab = ln(nonirr_sb_liab)
		la var nonirr_sb_ln_liab "Logged Total Liability for Non-irr. Soybean"	

	gen sb_sub_per_liab = sb_sub/sb_liab
		la var sb_sub_per_liab "Subsidy per Liability for Soybean"
		
	gen irr_sb_sub_per_liab = irr_sb_sub/irr_sb_liab
		la var irr_sb_sub_per_liab "Subsidy per Liability for Irrigated Soybean"
		
	gen nonirr_sb_sub_per_liab = nonirr_sb_sub/nonirr_sb_liab
		la var nonirr_sb_sub_per_liab "Subsidy per Liability for Non-Irrigated Soybean"

	gen sb_ln_indem = ln(sb_indem)
		la var sb_ln_indem "Ln(Indemnity payment for soybean)"
		
	gen irr_sb_ln_indem = ln(irr_sb_indem)
		la var irr_sb_ln_indem "Ln(Indemnity payment for irrigated soybean"
		
	gen nonirr_sb_ln_indem = ln(nonirr_sb_indem)
		la var nonirr_sb_ln_indem "Ln(Indemnity payment for non-irrigated soybean"	

	gen sb_ln_sub = ln(sb_sub)
		la var sb_ln_sub "Ln(Insurance subsidy for soybean)"
		
	gen irr_sb_ln_sub = ln(irr_sb_sub)
		la var irr_sb_ln_sub "Ln(Insurance subsidy for irrigated soybean)"
		
	gen nonirr_sb_ln_sub = ln(nonirr_sb_sub)
		la var nonirr_sb_ln_sub "Ln(Insurance susbidy for irrigated soybean)"
		
	gen sb_ln_prem = ln(sb_prem)
		la var sb_ln_prem "Ln(Insurance premium for soybean)"
		
	gen irr_sb_ln_prem = ln(irr_sb_prem)
		la var irr_sb_ln_prem "Ln(Insurance premium for irrigated soybean)"
		
	gen nonirr_sb_ln_prem = ln(nonirr_sb_prem)
		la var nonirr_sb_ln_prem "Ln(Insurance premium for irrigated soybean)"
	
	gen sb_spl = sb_sub/sb_liab
		la var sb_spl "Soybean Subsidy per Liability"
		
	gen irr_sb_spl = irr_sb_sub/irr_sb_liab
		la var irr_sb_spl "Irrigated Soybean Subsidy per Liability"
		
	gen nonirr_sb_spl = nonirr_sb_sub/nonirr_sb_liab
		la var nonirr_sb_spl "Non-Irrigated Soybean Subsidy per Liability"
		
	gen sb_spp = sb_sub/sb_prem
		la var sb_spp "Soybean Subsidy per Premium"
		
	gen irr_sb_spp = irr_sb_sub/irr_sb_prem
		la var irr_sb_spp "Irrigated Soybean Subsidy per Premium"
		
	gen nonirr_sb_spp = nonirr_sb_sub/nonirr_sb_prem
		la var nonirr_sb_spp "Non-Irrigated Soybean Subsidy per Premium"
				
	gen sb_liab_per_policy = sb_liab/sb_policies
		la var sb_liab_per_policy "Liability per policy (soybean)"		
				
*********** CLEANING WHEAT AND IRRIGATED/NON-IRRIGATED WHEAT VAR'S *************

	gen wheat_rate_parameter = (wheat_prem - wheat_sub)/wheat_liab
		la var wheat_rate_parameter "Premium per Liability for wheat"
		
	gen irr_wheat_rate_parameter = (irr_wheat_prem - irr_wheat_sub)/irr_wheat_liab
		la var irr_wheat_rate_parameter "Premium per Liability for irrigated wheat"
		
	gen nonirr_wheat_rate_parameter = (nonirr_wheat_prem - nonirr_wheat_sub)/nonirr_wheat_liab
		la var nonirr_wheat_rate_parameter "Premium per Liability for non-irrigated wheat"
		
	gen wheat_ln_ia = ln(wheat_ins_acres)
		la var wheat_ln_ia "Ln(wheat Insured Acres)"
	
	gen irr_wheat_ln_ia = ln(irr_wheat_ins_acres)
		la var irr_wheat_ln_ia "Ln(Irrigated wheat Insured Acres)"
		
	gen nonirr_wheat_ln_ia = ln(nonirr_wheat_ins_acres)
		la var nonirr_wheat_ln_ia "Ln(Non-Irrigated wheat Insured Acres)"
		
	gen irr_wheat_ln_pa = ln(irr_wheat_acres)
		la var irr_wheat_ln_pa "Ln(Irrigated Wheat Planted Acres)"
		
	gen nonirr_wheat_ln_pa = ln(nonirr_wheat_acres)
		la var nonirr_wheat_ln_pa "Ln(Non-Irrigated Wheat Planted Acres)"
	
	gen wheat_ln_pa = ln(wheat_acres)
		la var wheat_ln_pa "Ln(Wheat Planted Acres)"
		
	gen wheat_iar = wheat_ins_acres/wheat_acres
		la var wheat_iar "Insured Acre Ratio for wheat"
		
	gen irr_wheat_iar = irr_wheat_ins_acres/irr_wheat_acres
		la var irr_wheat_iar "Insured Acre Ratio for irrigated wheat"
		
	gen nonirr_wheat_iar = nonirr_wheat_ins_acres/nonirr_wheat_acres
		la var nonirr_wheat_iar "Insured Acre Ratio for non-irrigated wheat"
		
	gen wheat_ipa = wheat_indem/wheat_acres
		la var wheat_ipa "Indemnity per Ins. Acre for wheat"
		
	gen irr_wheat_ipa = irr_wheat_indem/irr_wheat_acres
		la var irr_wheat_ipa "Indemnity per Ins. Acre for irrigated wheat"
		
	gen nonirr_wheat_ipa = nonirr_wheat_indem/nonirr_wheat_acres
		la var nonirr_wheat_ipa "Indemnity per Ins. Acre for non-irrigated wheat"
		
	gen wheat_liab_acre = wheat_liab/wheat_acres
		la var wheat_liab_acre "Liability per planted acre for wheat"
		
	gen wheat_liab_ia = wheat_liab/wheat_ins_acres
		la var wheat_liab_ia "Liability per insured acre for wheat"
		
	gen irr_wheat_liab_acre = irr_wheat_liab/irr_wheat_acres
		la var irr_wheat_liab_acre "Liability per planted acre for irr. wheat"
		
	gen irr_wheat_liab_ia = irr_wheat_liab/irr_wheat_ins_acres
		la var irr_wheat_liab_acre "Liability per insured acre for irr. wheat"
		
	gen nonirr_wheat_liab_acre = nonirr_wheat_liab/nonirr_wheat_acres
		la var nonirr_wheat_liab_acre "Liability per planted acre for non-irr. wheat"
		
	gen nonirr_wheat_liab_ia = nonirr_wheat_liab/nonirr_wheat_ins_acres
		la var nonirr_wheat_liab_acre "Liability per insured acre for non-irr. wheat"	
		
	gen wheat_ln_liab = ln(wheat_liab)
		la var wheat_ln_liab "Logged Total Liability for Wheat"
		
	gen irr_wheat_ln_liab = ln(irr_wheat_liab)
		la var irr_wheat_ln_liab "Logged Total Liability for Irr. Wheat"
		
	gen nonirr_wheat_ln_liab = ln(nonirr_wheat_liab)
		la var nonirr_wheat_ln_liab "Logged Total Liability for Non-irr. Wheat"	
			
	gen wheat_sub_per_liab = wheat_sub/wheat_liab
		la var wheat_sub_per_liab "Subsidy per Liability for Wheat"
		
	gen irr_wheat_sub_per_liab = irr_wheat_sub/irr_wheat_liab
		la var irr_wheat_sub_per_liab "Subsidy per Liability for Irrigated Wheat"
		
	gen nonirr_wheat_sub_per_liab = nonirr_wheat_sub/nonirr_wheat_liab
		la var nonirr_wheat_sub_per_liab "Subsidy per Liability for Non-Irrigated Wheat"
	
	gen wheat_ln_indem = ln(wheat_indem)
		la var wheat_ln_indem "Ln(Indemnity payment for wheat)"
		
	gen irr_wheat_ln_indem = ln(irr_wheat_indem)
		la var irr_wheat_ln_indem "Ln(Indemnity payment for irrigated wheat"
		
	gen nonirr_wheat_ln_indem = ln(nonirr_wheat_indem)
		la var nonirr_wheat_ln_indem "Ln(Indemnity payment for non-irrigated wheat"	

	gen wheat_ln_sub = ln(wheat_sub)
		la var wheat_ln_sub "Ln(Insurance subsidy for wheat)"
		
	gen irr_wheat_ln_sub = ln(irr_wheat_sub)
		la var irr_wheat_ln_sub "Ln(Insurance subsidy for irrigated wheat)"
		
	gen nonirr_wheat_ln_sub = ln(nonirr_wheat_sub)
		la var nonirr_wheat_ln_sub "Ln(Insurance susbidy for irrigated wheat)"

	gen wheat_ln_prem = ln(wheat_prem)
		la var wheat_ln_prem "Ln(Insurance premium for wheat)"
		
	gen irr_wheat_ln_prem = ln(irr_wheat_prem)
		la var irr_wheat_ln_prem "Ln(Insurance premium for irrigated wheat)"
		
	gen nonirr_wheat_ln_prem = ln(nonirr_wheat_prem)
		la var nonirr_wheat_ln_prem "Ln(Insurance premium for irrigated wheat)"

	gen wheat_spl = wheat_sub/wheat_liab
		la var wheat_spl "Wheat Subsidy per Liability"
		
	gen irr_wheat_spl = irr_wheat_sub/irr_wheat_liab
		la var irr_wheat_spl "Irrigated Wheat Subsidy per Liability"
		
	gen nonirr_wheat_spl = nonirr_wheat_sub/nonirr_wheat_liab
		la var nonirr_wheat_spl "Non-Irrigated Wheat Subsidy per Liability"
		
	gen wheat_spp = wheat_sub/wheat_prem
		la var wheat_spp "Wheat Subsidy per Premium"
		
	gen irr_wheat_spp = irr_wheat_sub/irr_wheat_prem
		la var irr_wheat_spp "Irrigated Wheat Subsidy per Premium"
		
	gen nonirr_wheat_spp = nonirr_wheat_sub/nonirr_wheat_prem
		la var nonirr_wheat_spp "Non-Irrigated Wheat Subsidy per Premium"

		
local crop irr_corn
local crops irr_corn irr_sb irr_wheat

local dv spl
local dvs spl spp

foreach crop of local crops {
		foreach dv of local dvs {
	
	gen `crop'_ln_`dv' = ln(`crop'_`dv')
}
}

********************************************************************************		
********************************************************************************
* 	Now, I'm actually creating which counties are covered under certain types  *
*	of allocation schemes, drilling moratoria, and irrigated acre moratoria.   *
*	On this first pass, purely calculating the shares since current policy.	   *
*	Look for file in raw data called "regulation_yrs.csv" for relevant years   *
********************************************************************************
********************************************************************************

	forval i = 1/24 {
		cap replace nrd_share_`i' = 0 if nrd_share_`i' == .
		cap replace nrd_cl_share`i' = 0 if nrd_cl_share`i' == .
	}
	
		cap replace lema_share = 0 if lema_share == .
		cap replace lema_cl_share = 0 if lema_cl_share == .

	gen drill_mor = 0
		replace drill_mor = nrd_share_21 + nrd_share_15 + nrd_share_16 + nrd_share_22
		replace drill_mor = drill_mor + nrd_share_12 + nrd_share_23 if year > 2002
		replace drill_mor = drill_mor + nrd_share_17 + nrd_share_24 if year > 2003
		replace drill_mor = drill_mor + nrd_share_5 + nrd_share_2 if year > 2005
		replace drill_mor = drill_mor + nrd_share_7 if year > 2006
		replace drill_mor = drill_mor + nrd_share_14 if year > 2013
		replace drill_mor = drill_mor + nrd_share_13 if year > 2014
		replace drill_mor = drill_mor + nrd_share_18 if year > 2017
		replace drill_mor = 1 if drill_mor > 1
		replace drill_mor = 0 if drill_mor < 0
			la var drill_mor "Share of county covered by 'Drilling Moratorium' policy"

	gen irr_acres_mor = 0
		replace irr_acres_mor = nrd_share_18 if year > 2002
		replace irr_acres_mor = irr_acres_mor + nrd_share_24 if year > 2003
		replace irr_acres_mor = irr_acres_mor + nrd_share_5 if year > 2005
		replace irr_acres_mor = irr_acres_mor + nrd_share_2 + nrd_share_21 if year > 2006
		replace irr_acres_mor = irr_acres_mor + nrd_share_7 if year > 2007
		replace irr_acres_mor = irr_acres_mor + nrd_share_20 if year > 2013
		replace irr_acres_mor = 1 if irr_acres_mor > 1
		replace irr_acres_mor = 0 if irr_acres_mor < 0
			la var irr_acres_mor "Share of county covered by 'Stay on Irrigated Acre' policy"

	gen drill_acre_mor = 0
		replace drill_acre_mor = nrd_share_21 + nrd_share_16 + nrd_share_22 
		replace drill_acre_mor = drill_acre_mor + nrd_share_18 + nrd_share_12 + nrd_share_23 if year > 2002
		replace drill_acre_mor = drill_acre_mor + nrd_share_17 + nrd_share_24 if year > 2003
		replace drill_acre_mor = drill_acre_mor + nrd_share_5 + nrd_share_2 if year > 2005
		replace drill_acre_mor = drill_acre_mor + nrd_share_21 if year > 2006
		replace drill_acre_mor = drill_acre_mor + nrd_share_7 if year > 2007
		replace drill_acre_mor = drill_acre_mor + nrd_share_14 + nrd_share_20 if year > 2013
		replace drill_acre_mor = drill_acre_mor + nrd_share_13 if year > 2014
			la var drill_acre_mor "Share of county covered by Well OR Irrigated Acre Moratorium"
	
	gen allocation = 0
		replace allocation = nrd_share_15
		replace allocation = allocation + nrd_share_22 if year > 2003
		replace allocation = allocation + nrd_share_16 + nrd_share_12 if year > 2006
		replace allocation = allocation + nrd_share_24 if year > 2007
		replace allocation = allocation + nrd_share_4 + lema_share if year > 2012
		replace allocation = allocation + nrd_share_20 if year > 2013
		replace allocation = allocation + nrd_share_19 if year > 2014
		replace allocation = 1 if allocation > 1
			la var allocation "Share of county covered 'Groundwater Quantity Restriction' policy"

********************************************************************************
*				REPEATING THE ABOVE USING NRD CROPLAND SHARES			
	
	gen drill_mor_cl = 0
		replace drill_mor_cl = nrd_cl_share21 + nrd_cl_share15 + nrd_cl_share16 + nrd_cl_share22
		replace drill_mor_cl = drill_mor + nrd_cl_share12 + nrd_cl_share23 if year > 2002
		replace drill_mor_cl = drill_mor + nrd_cl_share17 + nrd_cl_share24 if year > 2003
		replace drill_mor_cl = drill_mor + nrd_cl_share5 + nrd_cl_share2 if year > 2005
		replace drill_mor_cl = drill_mor + nrd_cl_share7 if year > 2006
		replace drill_mor_cl = drill_mor + nrd_cl_share14 if year > 2013
		replace drill_mor_cl = drill_mor + nrd_cl_share13 if year > 2014
		replace drill_mor_cl = drill_mor + nrd_cl_share18 if year > 2017
		replace drill_mor_cl = 1 if drill_mor > 1
		replace drill_mor_cl = 0 if drill_mor < 0
			la var drill_mor_cl "Share of county's crop land covered by 'Drilling Moratorium' policy"

	gen irr_acres_mor_cl = 0
		replace irr_acres_mor_cl = nrd_cl_share18 if year > 2002
		replace irr_acres_mor_cl = irr_acres_mor + nrd_cl_share24 if year > 2003
		replace irr_acres_mor_cl = irr_acres_mor + nrd_cl_share5 if year > 2005
		replace irr_acres_mor_cl = irr_acres_mor + nrd_cl_share2 + nrd_cl_share21 if year > 2006
		replace irr_acres_mor_cl = irr_acres_mor + nrd_cl_share7 if year > 2007
		replace irr_acres_mor_cl = irr_acres_mor + nrd_cl_share20 if year > 2013
		replace irr_acres_mor_cl = 1 if irr_acres_mor > 1
		replace irr_acres_mor_cl = 0 if irr_acres_mor < 0
			la var irr_acres_mor_cl "Share of county's crop land covered by 'Stay on Irrigated Acre' policy"

	gen drill_acre_mor_cl = 0
		replace drill_acre_mor_cl = nrd_cl_share21 + nrd_cl_share16 + nrd_cl_share22 
		replace drill_acre_mor_cl = drill_acre_mor + nrd_cl_share18 + nrd_cl_share12 + nrd_cl_share23 if year > 2002
		replace drill_acre_mor_cl = drill_acre_mor + nrd_cl_share17 + nrd_cl_share24 if year > 2003
		replace drill_acre_mor_cl = drill_acre_mor + nrd_cl_share5 + nrd_cl_share2 if year > 2005
		replace drill_acre_mor_cl = drill_acre_mor + nrd_cl_share21 if year > 2006
		replace drill_acre_mor_cl = drill_acre_mor + nrd_cl_share7 if year > 2007
		replace drill_acre_mor_cl = drill_acre_mor + nrd_cl_share14 + nrd_cl_share20 if year > 2013
		replace drill_acre_mor_cl = drill_acre_mor + nrd_cl_share13 if year > 2014
			la var drill_acre_mor_cl "Share of county's crop land covered by Well OR Irrigated Acre Moratorium"
	
	gen allocation_cl = 0
		replace allocation_cl = nrd_cl_share15
		replace allocation_cl = allocation + nrd_cl_share22 if year > 2003
		replace allocation_cl = allocation + nrd_cl_share16 + nrd_cl_share12 if year > 2006
		replace allocation_cl = allocation + nrd_cl_share24 if year > 2007
		replace allocation_cl = allocation + nrd_cl_share4 + lema_cl_share if year > 2012
		replace allocation_cl = allocation + nrd_cl_share20 if year > 2013
		replace allocation_cl = allocation + nrd_cl_share19 if year > 2014
		replace allocation_cl = 1 if allocation > 1
			la var allocation_cl "Share of county's crop land covered 'Pumping Restriction' policy"
		
	
********************************************************************************
*			Calculating the years that each policy has been in place			
********************************************************************************			

* Now, creating a variable which averages the number of years an irrigation
* restriction policy has been in place in counties which have land covered 
* by them. These averages are within each year. They are then interacted
* with the policy variables themselves to be used in regression analysis later.
* Will repeat for other policy var's.

	gen drill_mor_yrs = 0
		replace drill_mor_yrs = (year - 2001) if nrd_share_21 > 0 | nrd_share_15 > 0 | nrd_share_16 > 0 | nrd_share_22 > 0
		replace drill_mor_yrs = (year - 2002) if nrd_share_12 > 0 & drill_mor_yrs == 0 | nrd_share_23 > 0 & drill_mor_yrs == 0
		replace drill_mor_yrs = (year - 2003) if nrd_share_17 > 0 & drill_mor_yrs == 0 | nrd_share_24 > 0 & drill_mor_yrs == 0
		replace drill_mor_yrs = (year - 2005) if nrd_share_5 > 0 & drill_mor_yrs == 0 | nrd_share_2 > 0 & drill_mor_yrs == 0
		replace drill_mor_yrs = (year - 2006) if nrd_share_7 > 0 & drill_mor_yrs == 0
		replace drill_mor_yrs = (year - 2013) if nrd_share_14 > 0 & drill_mor_yrs == 0 
		replace drill_mor_yrs = (year - 2014) if nrd_share_13 > 0 & drill_mor_yrs == 0
		replace drill_mor_yrs = (year - 2017) if nrd_share_18 > 0 & drill_mor_yrs == 0
			la var drill_mor_yrs "Years with a Drilling Moratorium in place"
			replace drill_mor_yrs = 0 if drill_mor_yrs < -5
	
	gen drill_mor_yrs_nz = drill_mor_yrs if drill_mor_yrs > 0
		by year, sort: egen avg_drill_yrs = mean(drill_mor_yrs_nz) 
			la var avg_drill_yrs "Average number of years well-drilling moratorium has been in place"
			
		gen drill_yr_int = avg_drill_yrs * drill_mor
			la var drill_yr_int "Drilling Moratorium Share * Average Years in Place"
		

	gen ia_mor_yrs = 0
		replace ia_mor_yrs = (year - 2002) if nrd_share_18 > 0
		replace ia_mor_yrs = (year - 2003) if nrd_share_24 > 0 & ia_mor_yrs == 0
		replace ia_mor_yrs = (year - 2005) if nrd_share_5 > 0 & ia_mor_yrs == 0
		replace ia_mor_yrs = (year - 2006) if nrd_share_2 > 0 & ia_mor_yrs == 0
		replace ia_mor_yrs = (year - 2007) if nrd_share_7 > 0 & ia_mor_yrs == 0
		replace ia_mor_yrs = (year - 2013) if nrd_share_20 > 0 & ia_mor_yrs == 0
			la var ia_mor_yrs "Years with a Moratorium on Irrigated Acres"
			replace ia_mor_yrs = 0 if ia_mor_yrs < -5
			
	gen ia_mor_yrs_nz = ia_mor_yrs if ia_mor_yrs > 0
		by year, sort: egen avg_ia_mor_yrs = mean(ia_mor_yrs_nz) 
			la var avg_ia_mor_yrs "Average number of years irrigated acre stay has been in place"
			
		gen ia_mor_yr_int = avg_ia_mor_yrs * irr_acres_mor
			la var ia_mor_yr_int "Irrigated Acre Stay Share * Average Years in Place"	
	

	gen drill_acre_yrs = 0
		replace drill_acre_yrs = (year - 2001) if nrd_share_16 > 0 | nrd_share_22 > 0
		replace drill_acre_yrs = (year - 2002) if nrd_share_18 > 0 & drill_acre_yrs == 0 | nrd_share_12 > 0 & drill_acre_yrs == 0 | nrd_share_23 & drill_acre_yrs == 0
		replace drill_acre_yrs = (year - 2003) if nrd_share_17 > 0 & drill_acre_yrs == 0 | nrd_share_24 & drill_acre_yrs == 0
		replace drill_acre_yrs = (year - 2005) if nrd_share_5 > 0 & drill_acre_yrs == 0 | nrd_share_2 & drill_acre_yrs == 0
		replace drill_acre_yrs = (year - 2006) if nrd_share_21 > 0 & drill_acre_yrs == 0
		replace drill_acre_yrs = (year - 2007) if nrd_share_7 > 0 & drill_acre_yrs == 0
		replace drill_acre_yrs = (year - 2013) if nrd_share_14 > 0 & drill_acre_yrs == 0 | nrd_share_20 & drill_acre_yrs == 0
		replace drill_acre_yrs = (year - 2014) if nrd_share_13 > 0 & drill_acre_yrs == 0
			la var drill_acre_yrs "Years with a Moratorium on Well Drilling or New Irrigated Acres"
			replace drill_acre_yrs = 0 if drill_acre_yrs < -5
			
	gen drill_acre_yrs_nz = drill_acre_yrs if drill_acre_yrs > 0
		by year, sort: egen avg_drill_acre_yrs = mean(drill_acre_yrs_nz) 
			la var avg_drill_acre_yrs "Average number of years irrigation policies have been in place"
			
		gen drill_acre_yr_int = avg_drill_acre_yrs * drill_acre_mor
			la var drill_acre_yr_int "Irrigation Policy Share * Average Years in Place"		
	
			
	gen alloc_yrs = 0
		replace alloc_yrs = (year - 2003) if nrd_share_22 > 0 & alloc_yrs == 0
		replace alloc_yrs = (year - 2006) if nrd_share_16 > 0 & alloc_yrs == 0 | nrd_share_12 > 0 & alloc_yrs == 0
		replace alloc_yrs = (year - 2007) if nrd_share_24 > 0 & alloc_yrs == 0
		replace alloc_yrs = (year - 2012) if nrd_share_4 > 0 & alloc_yrs == 0 | lema_share > 0 & alloc_yrs == 0
		replace alloc_yrs = (year - 2013) if nrd_share_20 > 0 & alloc_yrs == 0
		replace alloc_yrs = (year - 2014) if nrd_share_19 > 0 & alloc_yrs == 0
		replace alloc_yrs = (year - 2017) if lema_share > 0 & alloc_yrs == 0
			la var alloc_yrs "Years with an pumping restriction"
			replace alloc_yrs = 0 if alloc_yrs < -5
			
	gen alloc_yrs_nz = alloc_yrs if alloc_yrs > 0
		by year, sort: egen avg_alloc_yrs = mean(alloc_yrs_nz) 
			la var avg_alloc_yrs "Average number of years pumping restriction has been in place"
			
		gen alloc_yr_int = avg_alloc_yrs * allocation
			la var alloc_yr_int "Pumping Restriction Share * Average Years in Place"		

********************************************************************************			
	* Liability per acre		
	gen liab_per_acre = liab_all/insured_acres

******************************************************************************** 
	*** Aggregating irr/non-irr planted acres all four crops commodity acres (TAKING SORGHUM OUT)
	egen irr_comm_acres = rowtotal(irr_corn_acres irr_sb_acres irr_wheat_acres)
		la var irr_comm_acres "Total Irrigated Acres Planted"
	
	egen nonirr_comm_acres = rowtotal(nonirr_corn_acres nonirr_sb_acres nonirr_wheat_acres)
		la var nonirr_comm_acres "Total Non-Irrigated Acres Planted"
		
	egen sub_total = rowtotal(corn_sub sb_sub wheat_sub)
		la var sub_total "Total Subsidy of Top 4 crops"
		
	egen total_irr_sub = rowtotal(irr_corn_sub irr_sb_sub irr_wheat_sub)
		la var total_irr_sub "Total Subsidy of Irrigated crops"
		
	egen total_nonirr_sub = rowtotal(nonirr_corn_sub nonirr_sb_sub nonirr_wheat_sub)
		la var total_irr_sub "Total Subsidy of Non-Irrigated crops"
		
	egen total_liab = rowtotal(corn_liab sb_liab wheat_liab)
		la var total_liab "Total Liability for Top 4 crops"
		
	egen total_irr_liab = rowtotal(irr_corn_liab irr_sb_liab irr_wheat_liab)
		la var total_irr_liab "Total Irrigated Liability"
		
	egen total_nonirr_liab = rowtotal(nonirr_corn_liab nonirr_sb_liab nonirr_wheat_liab)
		la var total_nonirr_liab "Total Non-Irrigated Liability"
		
	egen total_prem = rowtotal(corn_prem sb_prem wheat_prem)
		la var total_prem "Total Prmeium for Top 4 crops"
		
	egen total_irr_prem = rowtotal(irr_corn_prem irr_sb_prem irr_wheat_prem)
		la var total_irr_prem "Total Irrigated Premium"
		
	egen total_nonirr_prem = rowtotal(nonirr_corn_prem nonirr_sb_prem nonirr_wheat_prem)
		la var total_nonirr_prem "Total Non-Irrigated Premium"
		
	gen sub_per_liab = sub_total/total_liab
		la var sub_per_liab "Subsidy per Liability"
	
	gen irr_sub_per_liab = total_irr_sub/total_irr_liab
		la var irr_sub_per_liab "Irrigated Subsidy per Liability"
	
	gen nonirr_sub_per_liab = total_nonirr_sub/total_nonirr_liab
		la var nonirr_sub_per_liab "Non-Irrigated Subsidy per Liability"
		
	gen total_ln_pa = ln(total_t5_acres)
		la var total_ln_pa "Ln(Total Planted Acres of Top 5 crops)"
		
	gen total_irr_ln_pa = ln(irr_comm_acres)
		la var total_irr_ln_pa "Ln(Total Irrigated Planted Acres of Top 5 crops)"		

	gen total_ln_ia = ln(insured_acres)
		la var total_ln_ia "Ln(Total Insured Acres of Top 5 crops)"	
	
* Creating INSURED acreage share variable which will be used as a Dependent Variable
	egen total_ins_acres = rowtotal(corn_ins_acres sb_ins_acres wheat_ins_acres)
		la var total_ins_acres "Total Insured Acres"
		
	egen total_irr_ins_acres = rowtotal(irr_corn_ins_acres irr_sb_ins_acres irr_wheat_ins_acres)
		la var total_irr_ins_acres "Total Irrigated Insured Acres"
		
	egen total_nonirr_ins_acres = rowtotal(nonirr_corn_ins_acres nonirr_sb_ins_acres nonirr_wheat_ins_acres)
		la var total_nonirr_ins_acres "Total Non-Irrigated Insured Acres"
		
	gen irr_tot_ia_share = total_irr_ins_acres/total_ins_acres
		la var irr_tot_ia_share "Share of county's insured acres that are irrigated"
		
	gen nonirr_tot_ia_share = total_nonirr_ins_acres/total_ins_acres
		la var nonirr_tot_ia_share "Share of county's insured acres that are non-irrigated"
		
	gen corn_tot_ia_share = corn_ins_acres/total_ins_acres
		la var corn_tot_ia_share "Share of county's insured acres that are corn"
		
	gen sb_tot_ia_share = sb_ins_acres/total_ins_acres
		la var sb_tot_ia_share "Share of county's insured acres that are soybean"
		
	gen sorghum_tot_ia_share = sorghum_ins_acres/total_ins_acres
		la var sorghum_tot_ia_share "Share of county's insured acres that are sorghum"
		
	gen wheat_tot_ia_share = wheat_ins_acres/total_ins_acres
		la var wheat_tot_ia_share "Share of county's insured acres that are wheat"

* Coding missing acreage variables as 0's
	
	replace irr_corn_acres = 0 if irr_corn_acres == .
	replace irr_sb_acres = 0 if irr_sb_acres == .
	replace irr_wheat_acres = 0 if irr_wheat_acres == .
	replace corn_acres = 0 if corn_acres == .
	replace sb_acres = 0 if sb_acres == .
	replace wheat_acres = 0 if wheat_acres == .
	replace nonirr_corn_acres = 0 if nonirr_corn_acres == .
	replace nonirr_sb_acres = 0 if nonirr_sb_acres == .
	replace nonirr_wheat_acres = 0 if nonirr_wheat_acres == .
	
* Creating a variable that the share of a county's total insured acres that are 
* dedicated to the specific crop and irrigation status combination
		
local cropirr irr_corn		
local cropsirrs irr_corn nonirr_corn irr_sb nonirr_sb irr_wheat nonirr_wheat

foreach cropirr of local cropsirrs {
		gen `cropirr'_tot_ia_share = `cropirr'_ins_acres/total_ins_acres
			la var `cropirr'_tot_ia_share "Share of county's insured acres that are `crop'"
}

* Now creating a similar share, but the denominator is now Total Irrigated Acres

local crop corn
local crops corn sb wheat

foreach crop of local crops {
	
	gen `crop'_irr_ia_share = irr_`crop'_ins_acres/total_irr_ins_acres
		la var `crop'_irr_ia_share "Share of a county's irrigated insured acres that are `crop'"
	
	gen `crop'_nonirr_ia_share = nonirr_`crop'_ins_acres/total_nonirr_ins_acres
		la var `crop'_nonirr_ia_share "Share of a county's non-irrigated insured acres that are `crop'"
}	

* Now creating a similar share, but the denominator is now Total Acres to Corn,
* Soybean, Sorghum, and Wheat

foreach crop of local crops {
	
	gen irr_`crop'_ia_share = irr_`crop'_ins_acres/`crop'_ins_acres
		la var irr_`crop'_ia_share "Share of a county's insured `crop' acres that are irrigated"
		
	gen nonirr_`crop'_ia_share = nonirr_`crop'_ins_acres/`crop'_ins_acres
		la var nonirr_`crop'_ia_share "Share of a county's insured `crop' acres that are non-irrigated"
	
}

* Logit transformation of all of these shares

local prefix corn_tot_ia
local prefix_list corn_tot_ia sb_tot_ia wheat_tot_ia ///
	irr_tot_ia nonirr_tot_ia irr_corn_tot_ia nonirr_corn_tot_ia irr_sb_tot_ia ///
	nonirr_sb_tot_ia irr_wheat_tot_ia nonirr_wheat_tot_ia corn_irr_ia ///
	corn_nonirr_ia sb_irr_ia sb_nonirr_ia wheat_irr_ia wheat_nonirr_ia ///
	irr_corn_ia nonirr_corn_ia irr_sb_ia nonirr_sb_ia irr_wheat_ia nonirr_wheat_ia

foreach prefix of local prefix_list {

	replace `prefix'_share = 0.0001 if `prefix'_share == 0
	replace `prefix'_share = 0.9999 if `prefix'_share == 1

	gen `prefix'_odds = .
		replace `prefix'_odds = (`prefix'_share/(1 - `prefix'_share))
		la var `prefix'_odds "Ins Perc./(1 - Ins Perc.)"
		
	gen log_`prefix'_odds = .
		replace log_`prefix'_odds = ln(`prefix'_odds)
		la var log_`prefix'_odds "Ln(Ins Perc./(1 - `prefix' Perc.))"
		
	}
	
* Creating PLANTED acreage share variable which will be used as a Dependent Variable

	gen irr_tot_pa_share = irr_comm_acres/total_t5_acres
	replace irr_tot_pa_share = 0 if irr_comm_acres == 0
		la var irr_tot_pa_share "Share of county's planted acres that are irrigated"
		
	gen nonirr_tot_pa_share = nonirr_comm_acres/total_t5_acres
	replace nonirr_tot_pa_share = 0 if nonirr_comm_acres == 0
		la var nonirr_tot_pa_share "Share of county's planted acres that are non-irrigated"
		
	gen corn_tot_pa_share = corn_acres/total_t5_acres
	replace corn_tot_pa_share = 0 if corn_acres == 0
		la var corn_tot_pa_share "Share of county's planted acres that are corn"
		
	gen sb_tot_pa_share = sb_acres/total_t5_acres
	replace sb_tot_pa_share = 0 if sb_acres == 0
		la var sb_tot_pa_share "Share of county's planted acres that are soybean"
		
	gen wheat_tot_pa_share = wheat_acres/total_t5_acres
	replace wheat_tot_pa_share = 0 if wheat_acres == 0
		la var wheat_tot_pa_share "Share of county's planted acres that are wheat"

* Creating a variable that the share of a county's total insured acres that are 
* dedicated to the specific crop and irrigation status combination
		
local cropirr irr_corn		
local cropsirrs irr_corn nonirr_corn irr_sb nonirr_sb irr_wheat nonirr_wheat

foreach cropirr of local cropsirrs {
		gen `cropirr'_tot_pa_share = `cropirr'_acres/total_t5_acres
			la var `cropirr'_tot_pa_share "Share of county's planted acres that are `crop'"

		replace `cropirr'_tot_pa_share = 0 if `cropirr'_acres == 0
}

* Now creating a similar share, but the denominator is now Total Irrigated Acres

local crop irr_corn
local crops irr_corn irr_sb irr_wheat

foreach crop of local crops {
	
	gen `crop'_irr_pa_share = `crop'_acres/irr_comm_acres
		la var `crop'_irr_pa_share "Share of a county's irrigated planted acres that are `crop'"

	replace `crop'_irr_pa_share = 0 if `crop'_acres == 0
}

local crop2 nonirr_corn
local crops2 nonirr_corn nonirr_sb nonirr_wheat

foreach crop2 of local crops2 {	
	gen `crop2'_nonirr_pa_share = `crop2'_acres/nonirr_comm_acres
		la var `crop2'_nonirr_pa_share "Share of a county's non-irrigated planted acres that are `crop'"

	replace `crop2'_nonirr_pa_share = 0 if `crop2'_acres == 0
}	

* Now creating a similar share, but the denominator is now Total Acres to Corn,
* Soybean, Sorghum, and Wheat

local crop3 corn
local crops3 corn sb wheat

foreach crop3 of local crops3  {
	
	gen irr_`crop3'_pa_share = irr_`crop3'_acres/`crop3'_acres
		la var irr_`crop3'_pa_share "Share of a county's planted `crop' acres that are irrigated"
		
	gen nonirr_`crop3'_pa_share = nonirr_`crop3'_acres/`crop3'_acres
		la var nonirr_`crop3'_pa_share "Share of a county's planted `crop' acres that are non-irrigated"
	}

* Logit transformation of all of these shares

local prefix corn_tot_pa
local prefix_list corn_tot_pa sb_tot_pa wheat_tot_pa ///
	irr_tot_pa nonirr_tot_pa irr_corn_tot_pa nonirr_corn_tot_pa irr_sb_tot_pa ///
	nonirr_sb_tot_pa irr_wheat_tot_pa nonirr_wheat_tot_pa irr_corn_irr_pa ///
	nonirr_corn_nonirr_pa irr_sb_irr_pa nonirr_sb_nonirr_pa  ///
	irr_wheat_irr_pa nonirr_wheat_nonirr_pa irr_corn_pa ///
	nonirr_corn_pa irr_sb_pa nonirr_sb_pa ///
	irr_wheat_pa nonirr_wheat_pa

foreach prefix of local prefix_list {

	replace `prefix'_share = 0.0001 if `prefix'_share == 0
	replace `prefix'_share = 0.9999 if `prefix'_share == 1

	gen `prefix'_odds = .
		replace `prefix'_odds = (`prefix'_share/(1 - `prefix'_share))
		la var `prefix'_odds "Ins Perc./(1 - Ins Perc.)"
		
	gen log_`prefix'_odds = .
		replace log_`prefix'_odds = ln(`prefix'_odds)
		la var log_`prefix'_odds "Ln(Ins Perc./(1 - `prefix' Perc.))"
		
	}
	
* Creating a variable that is the share of irrigated acres that are insured
	gen irr_corn_ins_acre_share = irr_corn_ins_acres/irr_corn_acres
		replace irr_corn_ins_acre_share = . if irr_corn_ins_acre_share > 1
		la var irr_corn_ins_acre_share "Share of irr. corn acres that are insured"

	gen irr_wheat_ins_acre_share = irr_wheat_ins_acres/irr_wheat_acres
		replace irr_wheat_ins_acre_share = . if irr_wheat_ins_acre_share > 1
		la var irr_wheat_ins_acre_share "Share of irr. wheat acres that are insured"
		
********************************************************************************
* Merging in an indicator for an ethanol plant being present in 2016

/*
preserve
	import delimited "${rawpath}ethanol_plants_w_counties.csv", clear
	
	gen fips = state_fips * 1000 + county_fips
	
	gen one = 1
	
	collapse (count) one, by(fips)
	
	gen ethanol_county = 1
		la var ethanol_county "County with ethanol plant in 2016"
	
	drop one
	
	save "${datapath}ethanol_counties", replace
restore

	merge m:1 fips using "${datapath}ethanol_counties"
		drop if _merge == 2
		drop _merge
		
	replace ethanol_county = 0 if ethanol_county == .	


********************************************************************************	
*********** Creating a consistent county sample of counties by D.V. ************
*** In this particular sample, we're keeping only counties which produce all ***
***  four of the main crops in some point in time during our sampe period.   ***
********************************************************************************
 CURRENTLY CODING "corn_sample" DIFFERENT IN REG DO-FILE

preserve
	collapse (count) irr_corn_acres irr_sb_acres irr_wheat_acres, by(fips)

	keep if irr_corn_acres > 0 & irr_sb_acres > 0 & irr_wheat_acres > 0
		
	gen sample = 1
	
	drop irr_corn_acres irr_sb_acres irr_wheat_acres
	
	save "${datapath}allcrop_county_sample", replace
restore

	merge m:1 fips using "${datapath}allcrop_county_sample"
		drop if _merge == 2
		drop _merge
		
	replace sample = 0 if sample == .
	
*** Here we are repeating that exercise with only corn producing counties
preserve
	collapse (count) irr_corn_acres, by(fips)

	keep if irr_corn_acres > 0 
		
	gen corn_sample = 1
	
	drop irr_corn_acres
	
	save "${datapath}corn_county_sample", replace
restore

	merge m:1 fips using "${datapath}corn_county_sample"
		drop if _merge == 2
		drop _merge
		
	replace corn_sample = 0 if corn_sample == .
*/	

**** Creating a DiD variable

	* 25 percent threshold
	gen alloc_did = 0
		replace alloc_did = 1 if allocation > 0.25
		
	bysort fips: egen min_cs = min(year) if alloc_did == 1
	bysort fips: egen cs_did = max(min_cs)
	replace cs_did = 0 if cs_did == .
		
	* 10 percent threshold
	gen alloc_did2 = 0
		replace alloc_did2 = 1 if allocation > 0.1
		
	bysort fips: egen min_cs2 = min(year) if alloc_did2 == 1
	bysort fips: egen cs_did2 = max(min_cs2)
	replace cs_did2 = 0 if cs_did2 == .


******* CREATING A CONSISTENT SAMPLE
xtset fips year
*Creating the initial balanced panel
reg irr_corn_mean_rp allocation drill_mor irr_acres_mor precip_lag1 maxtemp_lag1 ///
 pdsi sat_thick sat_thick_sq i.state_fips##year, vce(cluster fips)

	generate corn_sample = e(sample)
	
	keep if corn_sample == 1


********************************************************************************
*	CREATING A DIFFERENCE VARIABLE BETWEEN IRRIGATED AND DRYLAND INSURANCE VARIABLES
********************************************************************************

local crop corn
local crops corn sb wheat

foreach crop of local crops {

	gen `crop'_irr_rate_diff = nonirr_`crop'_mean_rp - irr_`crop'_mean_rp
		la var `crop'_irr_rate_diff "C.I. rate difference between irrigated and dryland"
	
	gen `crop'_irr_subrate_diff = nonirr_`crop'_rate_parameter - irr_`crop'_rate_parameter
		la var `crop'_irr_subrate_diff "Subsidized C.I. rate difference between irrigated and dryland"

	gen `crop'_irr_spl_diff = nonirr_`crop'_spl - irr_`crop'_spl
		la var `crop'_irr_spl_diff "Subsidy difference between irrigated and dryland"
		
	gen `crop'_irr_cov_lvl_diff = nonirr_`crop'_cov_level - irr_`crop'_cov_level
		la var `crop'_irr_cov_lvl_diff "Coverage Level difference between irrigated and dryland"
		
}

********************************************************************************
********************************************************************************
*********
* Creating a total of these acre values by total insured and total insured-irrigated

	egen top4_ins_acres = rowtotal(corn_ins_acres sb_ins_acres sorghum_ins_acres wheat_ins_acres)
		la var top4_ins_acres "Total insured acres to Top 4 crops"
		
	egen top4_ins_irr_acres = rowtotal(irr_corn_ins_acres irr_sb_ins_acres irr_sorghum_ins_acres irr_wheat_ins_acres)	
		la var top4_ins_irr_acres "Total insured-Irrigated acres to Top 4 crops"

****************************************************
* Creating the actual share variables now

	* First, share of insured corn acres that get irrigated
	gen irr_share_of_ins_ca = irr_corn_ins_acres/corn_ins_acres
		la var irr_share_of_ins_ca "Share of insured corn acres that are irrigated"
	
	* Second, share of irrigated corn acres that get insured
	gen ins_share_of_irr_ca = irr_corn_ins_acres/irr_corn_acres if irr_corn_acres > irr_corn_ins_acres
		la var ins_share_of_irr_ca "Share of irrigated corn acres that are insured"
		
	* Third, share of planted corn acres that get insured AND irrigated
	gen ins_irr_share_of_ca = irr_corn_ins_acres/corn_acres if corn_acres > irr_corn_ins_acres
		la var ins_irr_share_of_ca "Share of total corn acres that are insured AND irrigated"
	
	* Fourth, share of irrigated-insured acres of Top 4 crops that are corn
	gen ins_ca_share_of_irr_top4 = irr_corn_ins_acres/top4_ins_irr_acres
		la var ins_ca_share_of_irr_top4 "Share of irrigated-insured acres (top 4 crops) that are corn"
		
	* Fifth, share of insured acres of Top 4 crops that are irrigated corn
	gen irr_ins_ca_share_of_top4 = irr_corn_ins_acres/top4_ins_acres
		la var irr_ins_ca_share_of_top4 "Share of insured acres (top 4) that are irr. corn"


save "${datapath}nrd_policy_data", replace

