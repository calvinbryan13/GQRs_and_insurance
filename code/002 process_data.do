import delimited "${datapath}paneled_weather_2000_2020.csv", clear

	destring maxtemp pdsi precip, replace force
	
	************ Include Ogallala Aquifer shares ******************
	
	merge m:1 fips using "${rawpath}ogal_share.dta"
		keep if _merge == 3
		drop _merge
		
	keep if ogal_share > 0
	
********************************************************************************	
		**** Calculating APH and merging that data in here ***
preserve	
	do "${dopath}002_01 process_aph"
restore

	merge m:1 fips year using "${datapath}aph_10year"
		drop if _merge == 2
		drop _merge
		
	drop if fips == .
	
********************************************************************************
		*** Calculation production, area harvested, and variances ***	
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

******************************************************************
********** Including NRD and LEMA county-shares ******************

*** Merging in NRD shares
	merge m:1 fips year using "${datapath}nrd_cty_shares"
		drop if _merge == 2
		drop _merge
		
	drop nrd_share_9	
		
*** Merging in Kansas Lema shares
	
	merge m:1 fips using "${datapath}KS_lema_shares"
		drop if _merge == 2
		drop _merge
		
	replace lema_share = 0 if lema_share == .

****************************************************************
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

* Coding missing acreage variables as 0's
	
	replace irr_corn_acres = 0 if irr_corn_acres == .
	replace irr_sb_acres = 0 if irr_sb_acres == .
	replace irr_sorghum_acres = 0 if irr_sorghum_acres == .
	replace corn_acres = 0 if corn_acres == .
	replace sb_acres = 0 if sb_acres == .
	replace sorghum_acres = 0 if sorghum_acres == .
	replace nonirr_corn_acres = 0 if nonirr_corn_acres == .
	replace nonirr_sb_acres = 0 if nonirr_sb_acres == .
	replace nonirr_sorghum_acres = 0 if nonirr_sorghum_acres == .
		
		
********************************************************************************	
* Creating a new yield variable, defined as production/planted acres

	gen irr_corn_ppa = irr_corn_prod/irr_corn_acres
		la var irr_corn_ppa "Irrigated Corn Production per Acre"
		
	gen irr_sb_ppa = irr_sb_prod/irr_sb_acres
		la var irr_sb_ppa "Irrigated Soybean Production per Acre"
		
	gen irr_sorghum_ppa = irr_sorghum_prod/irr_sorghum_acres
		la var irr_sorghum_ppa "Irrigated Sorghum Production per Acre"		

********************************************************************************
	**** Merging Summary of Business data created in 001_04 script ***
********************************************************************************
		
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
		
		
********************************************************************************
* 					CROP INSURANCE OUTCOME CONSTRUCTION
********************************************************************************

* Assumption: *_prem is the PRODUCER-PAID premium, net of subsidy.
* Hence total premium / policy cost = *_prem + *_sub.
********************************************************************************

* Construct variables for each crop and irrigation category

foreach crop in corn sb sorghum {
    foreach system in all irr nonirr {

        local prefix "`crop'"
        if "`system'" != "all" local prefix "`system'_`crop'"

        * Create readable labels for each crop and irrigation category
        if "`crop'" == "corn"    local crop_label "Corn"
        if "`crop'" == "sb"      local crop_label "Soybeans"
        if "`crop'" == "sorghum" local crop_label "Sorghum"

        if "`system'" == "all"    local system_label "All"
        if "`system'" == "irr"    local system_label "Irrigated"
        if "`system'" == "nonirr" local system_label "Non-irrigated"

        local desc "`system_label' `crop_label'"

        * Verify required insurance variables exist
        foreach v in prem sub liab ins_acres indem {
            confirm numeric variable `prefix'_`v'
        }

        ***********************************************************************
        * 1. INSURANCE COSTS AND RATES
        ***********************************************************************

        * Total insurance cost (producer premium + subsidy)
        gen double `prefix'_total_cost = ///
            `prefix'_prem + `prefix'_sub
        label var `prefix'_total_cost "`desc': Total insurance cost ($)"

        * Premium per dollar of liability
        gen double `prefix'_ppl = ///
            `prefix'_prem / `prefix'_liab if `prefix'_liab > 0
        label var `prefix'_ppl "`desc': Producer premium per $ liability"

        * Subsidy per dollar of liability
        gen double `prefix'_spl = ///
            `prefix'_sub / `prefix'_liab if `prefix'_liab > 0
        label var `prefix'_spl "`desc': Subsidy per $ liability"

        * Total cost per dollar of liability
        gen double `prefix'_cpl = ///
            `prefix'_total_cost / `prefix'_liab if `prefix'_liab > 0
        label var `prefix'_cpl "`desc': Total cost per $ liability"

        ***********************************************************************
        * 2. INSURANCE COSTS PER INSURED ACRE
        ***********************************************************************

        * Premium per insured acre
        gen double `prefix'_prem_pia = ///
            `prefix'_prem / `prefix'_ins_acres if `prefix'_ins_acres > 0
        label var `prefix'_prem_pia "`desc': Premium per insured acre ($)"

        * Subsidy per insured acre
        gen double `prefix'_sub_pia = ///
            `prefix'_sub / `prefix'_ins_acres if `prefix'_ins_acres > 0
        label var `prefix'_sub_pia "`desc': Subsidy per insured acre ($)"

        * Total cost per insured acre
        gen double `prefix'_cost_pia = ///
            `prefix'_total_cost / `prefix'_ins_acres if `prefix'_ins_acres > 0
        label var `prefix'_cost_pia "`desc': Total cost per insured acre ($)"

        * Liability per insured acre
        gen double `prefix'_liab_pia = ///
            `prefix'_liab / `prefix'_ins_acres if `prefix'_ins_acres > 0
        label var `prefix'_liab_pia "`desc': Liability per insured acre ($)"

        ***********************************************************************
        * 3. LOG-TRANSFORMED INSURANCE VARIABLES
        ***********************************************************************

        * Log of producer premiums
        gen double `prefix'_ln_prem = ///
            ln(`prefix'_prem) if `prefix'_prem > 0
        label var `prefix'_ln_prem "`desc': Log producer premiums"

        * Log of government subsidies
        gen double `prefix'_ln_sub = ///
            ln(`prefix'_sub) if `prefix'_sub > 0
        label var `prefix'_ln_sub "`desc': Log government subsidies"

        * Log of total insurance costs
        gen double `prefix'_ln_total_cost = ///
            ln(`prefix'_total_cost) if `prefix'_total_cost > 0
        label var `prefix'_ln_total_cost "`desc': Log total insurance cost"

        * Log of indemnity payments
        gen double `prefix'_ln_indem = ///
            ln(`prefix'_indem) if `prefix'_indem > 0
        label var `prefix'_ln_indem "`desc': Log indemnity payments"

        * Log of total insured liability
        gen double `prefix'_ln_liab = ///
            ln(`prefix'_liab) if `prefix'_liab > 0
        label var `prefix'_ln_liab "`desc': Log insured liability"

        * Log of insured acreage
        gen double `prefix'_ln_ins_acres = ///
            ln(`prefix'_ins_acres) if `prefix'_ins_acres > 0
        label var `prefix'_ln_ins_acres "`desc': Log insured acres"

        * Log of crop yield (if available)
        capture confirm numeric variable `prefix'_yield
        if !_rc {
            gen double `prefix'_ln_yield = ///
                ln(`prefix'_yield) if `prefix'_yield > 0
            label var `prefix'_ln_yield "`desc': Log crop yield"
        }

        ***********************************************************************
        * 4. PRODUCTION AND HARVESTED ACREAGE VARIABLES
        ***********************************************************************

        * Log of total crop production
        capture confirm numeric variable `prefix'_prod
        if !_rc {

            gen double `prefix'_ln_prod = ///
                ln(`prefix'_prod) if `prefix'_prod > 0
            label var `prefix'_ln_prod "`desc': Log crop production"

            * Production per insured acre
            gen double `prefix'_prod_per_ins_acre = ///
                `prefix'_prod / `prefix'_ins_acres ///
                if `prefix'_ins_acres > 0
            label var `prefix'_prod_per_ins_acre ///
                "`desc': Production per insured acre"

            * Production per planted acre
            capture confirm numeric variable `prefix'_acres
            if !_rc {
                gen double `prefix'_prod_ppa = ///
                    `prefix'_prod / `prefix'_acres ///
                    if `prefix'_acres > 0
                label var `prefix'_prod_ppa ///
                    "`desc': Production per planted acre"
            }
        }

        * Differences between insured, planted, and harvested acreage
        capture confirm numeric variable `prefix'_acres_harvested
        if !_rc {

            * Insured acreage minus harvested acreage
            gen double `prefix'_ins_minus_harv = ///
                `prefix'_ins_acres - `prefix'_acres_harvested
            label var `prefix'_ins_minus_harv ///
                "`desc': Insured minus harvested acres"

            * Planted acreage minus harvested acreage
            capture confirm numeric variable `prefix'_acres
            if !_rc {
                gen double `prefix'_plant_minus_harv = ///
                    `prefix'_acres - `prefix'_acres_harvested
                label var `prefix'_plant_minus_harv ///
                    "`desc': Planted minus harvested acres"
            }
        }

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
**** Creating a DiD variable to potentially use in Callaway-Sant'Anna models ***
********************************************************************************

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

********************************************************************************
*******************		 CREATING A CONSISTENT SAMPLE		********************
********************************************************************************

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
local crops corn sb sorghum

foreach crop of local crops {

	gen `crop'_irr_rate_diff = nonirr_`crop'_mean_rp - irr_`crop'_mean_rp
		la var `crop'_irr_rate_diff "C.I. rate difference between irrigated and dryland"
	
	gen `crop'_irr_cpl_rate_diff = nonirr_`crop'_cpl - irr_`crop'_cpl
		la var `crop'_irr_cpl_rate_diff "Total premium rate difference between irrigated and dryland"
	
	gen `crop'_irr_ppl_rate_diff = nonirr_`crop'_ppl - irr_`crop'_ppl
		la var `crop'_irr_ppl_rate_diff "Subsidized premium rate difference between irrigated and dryland"

	gen `crop'_irr_spl_diff = nonirr_`crop'_spl - irr_`crop'_spl
		la var `crop'_irr_spl_diff "Subsidy difference between irrigated and dryland"
		
	gen `crop'_irr_cov_lvl_diff = nonirr_`crop'_cov_level - irr_`crop'_cov_level
		la var `crop'_irr_cov_lvl_diff "Coverage Level difference between irrigated and dryland"
		
}

save "${datapath}nrd_policy_data", replace

