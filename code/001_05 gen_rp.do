clear
gen variable = .
save "${datapath}USDA_rps", replace

**************************************************************
*------------------------------------------------------------*
* 	 Import USDA Continuous Rating Parameters, 2002-2010	 *
*------------------------------------------------------------*
**************************************************************

capture erase "${datapath}USDA_rps.dta"

forval i = 2002/2010 {

    import delimited ///
        "${rawpath}USDA_rate_parameters\R1`i'YTD.txt", ///
        clear varnames(non) stringcols(_all)

    *--------------------------------------------------------*
    * Identify record type and retain Continuous Rating data
    *--------------------------------------------------------*

    gen RTC = substr(v1,1,1)       // Record type code
    gen RTS = substr(v1,2,1)       // Record type suffix

    keep if RTC == "1" & RTS == "C"

    *--------------------------------------------------------*
    * Geographic, crop, and insurance identifiers
    *--------------------------------------------------------*

    gen year = substr(v1,3,4)
    gen state_fips = substr(v1,7,2)
    gen county_fips = substr(v1,9,3)
    gen commodity_rma = substr(v1,12,4)

    destring commodity_rma, replace force

    * Keep selected crops
    keep if inlist(commodity_rma,11,41,51,81)

    gen insurance_plan_code = substr(v1,16,2)
    gen practice_code = substr(v1,18,3)
    gen type_code = substr(v1,21,3)

    *--------------------------------------------------------*
    * Current-year continuous rating parameters
    *--------------------------------------------------------*

    gen ref_amt = substr(v1,24,7)       // Reference yield
    gen ref_rate = substr(v1,31,4)      // Reference rate
    gen exp_value = substr(v1,35,5)     // Exponent
    gen exp_sign = substr(v1,40,1)      // Exponent sign
    gen fixed_rate = substr(v1,41,4)    // Fixed rate load

    *--------------------------------------------------------*
    * Prior-year continuous rating parameters
    *--------------------------------------------------------*

    gen pyrefy = substr(v1,188,7)       // Prior-year reference yield
    gen pyrefrate = substr(v1,195,4)    // Prior-year reference rate
    gen pyexp = substr(v1,199,5)        // Prior-year exponent
    gen pyexpsign = substr(v1,204,1)    // Prior-year exponent sign
    gen pyfrl = substr(v1,205,4)        // Prior-year fixed rate load

    *--------------------------------------------------------*
    * Convert numeric variables
    *--------------------------------------------------------*

    destring RTC year state_fips county_fips ///
        insurance_plan_code practice_code type_code ///
        ref_amt ref_rate exp_value fixed_rate ///
        pyrefy pyrefrate pyexp pyfrl, replace force

    *--------------------------------------------------------*
    * Apply implied decimal places from USDA documentation
    *--------------------------------------------------------*

    replace ref_amt = ref_amt / 100
    replace ref_rate = ref_rate / 1000
    replace exp_value = exp_value / 1000
    replace fixed_rate = fixed_rate / 1000

    replace pyrefy = pyrefy / 100
    replace pyrefrate = pyrefrate / 1000
    replace pyexp = pyexp / 1000
    replace pyfrl = pyfrl / 1000

    * Apply exponent signs
    replace exp_value = -exp_value if exp_sign == "-"
    replace pyexp = -pyexp if pyexpsign == "-"

    *--------------------------------------------------------*
    * Keep only the variables of interest
    *--------------------------------------------------------*

    drop v1

    order RTC RTS year state_fips county_fips ///
        commodity_rma insurance_plan_code practice_code ///
        type_code ref_amt ref_rate exp_value exp_sign ///
        fixed_rate pyrefy pyrefrate pyexp pyexpsign pyfrl

    * Save individual year
    save "${datapath}rp`i'.dta", replace

    *--------------------------------------------------------*
    * Append to cumulative dataset
    *--------------------------------------------------------*

    if `i' > 2002 {
        append using "${datapath}USDA_rps.dta"
    }

    * Recode insurance plan codes
    replace insurance_plan_code = 1 if insurance_plan_code == 90
    replace insurance_plan_code = 2 if inlist(insurance_plan_code, ///
        44,42,45,25)

    sort year state_fips county_fips commodity_rma

    save "${datapath}USDA_rps.dta", replace

    display "Completed USDA rate parameters for `i'"

}

**************************************************************
*------------------------------------------------------------*
* 	 Import USDA Continuous Rating Parameters, 20011-2020	 *
*	Files changed structure a decent amount over this period *
*------------------------------------------------------------*
**************************************************************

forval i = 2011/2020 {

    import delimited "${rawpath}USDA_rate_parameters\R1`i'YTD.txt", ///
        delimiter("|") varnames(1) encoding(utf8) clear

    * Harmonize variable types across years
    capture confirm variable rangeclasscode
    if !_rc {
        tostring rangeclasscode, replace
    }

    rename recordtypecode RTC
    rename commodityyear year

    * Retain additional ADM identifiers
    capture rename reinsuranceyear reinsurance_year
    capture rename referenceamountcode ref_amt_code

    rename commoditycode commodity_rma
        destring commodity_rma, replace force
        keep if inlist(commodity_rma,11,21,41,51,81) // Top 5 crops

    rename insuranceplancode insurance_plan_code
    rename statecode state_fips
    rename countycode county_fips
    rename typecode type_code
    rename practicecode practice_code
    rename commoditytypecode comm_type_code

    * Original rate parameters
    rename referenceamount ref_amt
    rename referencerate ref_rate
    rename exponentvalue exp_value
    rename fixedrate fixed_rate
    rename prioryearreferenceamount pyrefy
    rename prioryearreferencerate pyrefrate
    rename prioryearexponentvalue pyexp
    rename prioryearfixedrate pyfr1

    * Additional ADM rate variables
    capture rename baserate base_rate
    capture rename prioryearbaserate py_base_rate

    * Retain original organic practice restriction
    destring organicpracticecode, replace force
        drop if inlist(organicpracticecode,1,2)

    * Save individual year
    save "${datapath}rp`i'", replace

    * Append to cumulative dataset
    if `i' == 2011 {
        save "${datapath}USDA_rps", replace
    }
    else {
        append using "${datapath}USDA_rps"
        save "${datapath}USDA_rps", replace
    }

    sleep 1000
}

****
* Subsetting to just the insurance products we want
	
	*keep if insurance_plan_code == 2
	*keep if type_code == 16

* The following variables should be up-to-date, and are the only ones which we
* are using for this analysis, so they're the only ones that we will keep. If
* we want to use any additional variables from this dataset, we'd need to make 
* sure they are sufficiently cleaned.

	keep year state_fips county_fips commodity_rma practice_code ref_rate pyrefrate
	
	duplicates tag state_fips county_fips year practice_code commodity_rma, generate(dup_flag)
		tab dup_flag
	
	keep if inlist(practice_code,2,3) /// Keeping only "Irrigated" and "Non-Irrigated"
	
	*drop if ref_rate > 1

	* Taking the mean, since there were some identifiers in the "junk" we dropped
preserve
	collapse (mean) ref_rate pyrefrate, by(state_fips county_fips commodity_rma practice_code year)
	
	rename ref_rate mean_rp
		la var mean_rp "Average Rate Parameter"
	rename pyrefrate mean_py_rr
		la var mean_py_rr "Average Rate Parameter (Last year)"
	
	save "${datapath}USDA_rate_parameters", replace
restore

	* Now the maximum
preserve
	collapse (max) ref_rate pyrefrate, by(state_fips county_fips commodity_rma practice_code year)
	
	rename ref_rate max_rp
		la var max_rp "Maximum Rate Parameter"
	rename pyrefrate max_py_rr
		la var max_py_rr "Maximum Rate Parameter (Last year)"
	
	tempfile max_ins_rate
	save max_ins_rate, replace
restore

	* Now the minimum
preserve
	collapse (min) ref_rate pyrefrate, by(state_fips county_fips commodity_rma practice_code year)
	
	rename ref_rate min_rp
		la var min_rp "Minimum Rate Parameter"
	rename pyrefrate min_py_rr
		la var min_py_rr "Minimum Rate Parameter (Last year)"
	
	tempfile min_ins_rate
	save min_ins_rate, replace
restore

	* Now the median
preserve
	collapse (median) ref_rate pyrefrate, by(state_fips county_fips commodity_rma practice_code year)
	
	rename ref_rate med_rp
		la var med_rp "Median Rate Parameter"
	rename pyrefrate med_py_rr
		la var med_py_rr "Median Rate Parameter (Last year)"
	
	tempfile med_ins_rate
	save med_ins_rate, replace
restore

* Now merging all of these data together on different estimations of the rate parameter
use "${datapath}USDA_rate_parameters", clear
	
	merge 1:1 year state_fips county_fips practice_code commodity_rma using max_ins_rate
		drop if _merge == 2
		drop _merge
		
	merge 1:1 year state_fips county_fips practice_code commodity_rma using min_ins_rate
		drop if _merge == 2
		drop _merge	
		
	merge 1:1 year state_fips county_fips practice_code commodity_rma using med_ins_rate
		drop if _merge == 2
		drop _merge

* Seperate rates for irrigated
	gen irr_mean_rp = .
		replace irr_mean_rp = mean_rp if practice_code == 2
		
	gen irr_max_rp = .
		replace irr_max_rp = max_rp if practice_code == 2
		
	gen irr_min_rp = .
		replace irr_min_rp = min_rp if practice_code == 2
	
	gen irr_med_rp = .
		replace irr_med_rp = med_rp if practice_code == 2

* Seperate rates for non-irrigated
	gen nonirr_mean_rp = .
		replace nonirr_mean_rp = mean_rp if practice_code == 3
		
	gen nonirr_max_rp = .
		replace nonirr_max_rp = max_rp if practice_code == 3
		
	gen nonirr_min_rp = .
		replace nonirr_min_rp = min_rp if practice_code == 3
	
	gen nonirr_med_rp = .
		replace nonirr_med_rp = med_rp if practice_code == 3

********************************************************************************
*******  Creating rate parameter measurements for mean, median, max, ad min    *
********************************************************************************

preserve
	collapse (mean) irr_mean_rp nonirr_mean_rp, by(county_fips state_fips year commodity_rma)
	
	save "${rawpath}mean_rps", replace
restore	
	
preserve	
	collapse (max) irr_max_rp nonirr_max_rp, by(county_fips state_fips year commodity_rma)
	
	save "${rawpath}max_rps", replace
restore	
	
preserve	
	collapse (min) irr_min_rp nonirr_min_rp, by(county_fips state_fips year commodity_rma)
	
	save "${rawpath}min_rps", replace
restore	
	
preserve	
	collapse (median) irr_med_rp nonirr_med_rp, by(county_fips state_fips year commodity_rma)

	save "${rawpath}med_rps", replace
restore

* Combining into all rate parameter measurements into one data frame
use "${rawpath}mean_rps", clear
	
		merge m:1 county_fips state_fips commodity_rma year using "${rawpath}max_rps"
			drop if _merge == 2
			drop _merge
			
		merge m:1 county_fips state_fips commodity_rma year using "${rawpath}min_rps"
			drop if _merge == 2
			drop _merge			
	
		merge m:1 county_fips state_fips commodity_rma year using "${rawpath}med_rps"
			drop if _merge == 2
			drop _merge
	
* Now keeping rate parameters for each specific crop
preserve
	keep if commodity_rma == 41
	
	rename irr_mean_rp irr_corn_mean_rp
		la var irr_corn_mean_rp "Mean USDA ins. rate parameter for irrigated corn"
		
	rename nonirr_mean_rp nonirr_corn_mean_rp
		la var nonirr_corn_mean_rp "Mean USDA ins. rate parameter for non-irrigated corn"
	
	rename irr_max_rp irr_corn_max_rp
		la var irr_corn_max_rp "Max USDA ins. rate parameter for irrigated corn"
		
	rename nonirr_max_rp nonirr_corn_max_rp
		la var nonirr_corn_max_rp "Max USDA ins. rate parameter for non-irrigated corn"
		
	rename irr_min_rp irr_corn_min_rp
		la var irr_corn_min_rp "Min USDA ins. rate parameter for irrigated corn"
		
	rename nonirr_min_rp nonirr_corn_min_rp
		la var nonirr_corn_min_rp "Min USDA ins. rate parameter for non-irrigated corn"
	
	rename irr_med_rp irr_corn_med_rp
		la var irr_corn_med_rp "Median USDA ins. rate parameter for irrigated corn"
		
	rename nonirr_med_rp nonirr_corn_med_rp
		la var nonirr_corn_med_rp "Median USDA ins. rate parameter for non-irrigated corn"
	
	gen fips = (state_fips * 1000) + county_fips
	
	save "${datapath}USDA_corn_rps", replace
restore

preserve
	keep if commodity_rma == 81
	
	rename irr_mean_rp irr_sb_mean_rp
		la var irr_sb_mean_rp "Mean USDA ins. rate parameter for irrigated soybean"
		
	rename nonirr_mean_rp nonirr_sb_mean_rp
		la var nonirr_sb_mean_rp "Mean USDA ins. rate parameter for non-irrigated soybean"
	
	rename irr_max_rp irr_sb_max_rp
		la var irr_sb_max_rp "Max USDA ins. rate parameter for irrigated soybean"
		
	rename nonirr_max_rp nonirr_sb_max_rp
		la var nonirr_sb_max_rp "Max USDA ins. rate parameter for non-irrigated soybean"
		
	rename irr_min_rp irr_sb_min_rp
		la var irr_sb_min_rp "Min USDA ins. rate parameter for irrigated soybean"
		
	rename nonirr_min_rp nonirr_sb_min_rp
		la var nonirr_sb_min_rp "Min USDA ins. rate parameter for non-irrigated soybean"
	
	rename irr_med_rp irr_sb_med_rp
		la var irr_sb_med_rp "Median USDA ins. rate parameter for irrigated soybean"
		
	rename nonirr_med_rp nonirr_sb_med_rp
		la var nonirr_sb_med_rp "Median USDA ins. rate parameter for non-irrigated soybean"
	
	gen fips = (state_fips * 1000) + county_fips
	
	save "${datapath}USDA_soybean_rps", replace
restore

preserve
	keep if commodity_rma == 51
	
	rename irr_mean_rp irr_sorghum_mean_rp
		la var irr_sorghum_mean_rp "Mean USDA ins. rate parameter for irrigated sorghum"
		
	rename nonirr_mean_rp nonirr_sorghum_mean_rp
		la var nonirr_sorghum_mean_rp "Mean USDA ins. rate parameter for non-irrigated sorghum"
	
	rename irr_max_rp irr_sorghum_max_rp
		la var irr_sorghum_max_rp "Max USDA ins. rate parameter for irrigated sorghum"
		
	rename nonirr_max_rp nonirr_sorghum_max_rp
		la var nonirr_sorghum_max_rp "Max USDA ins. rate parameter for non-irrigated sorghum"
		
	rename irr_min_rp irr_sorghum_min_rp
		la var irr_sorghum_min_rp "Min USDA ins. rate parameter for irrigated sorghum"
		
	rename nonirr_min_rp nonirr_sorghum_min_rp
		la var nonirr_sorghum_min_rp "Min USDA ins. rate parameter for non-irrigated sorghum"
	
	rename irr_med_rp irr_sorghum_med_rp
		la var irr_sorghum_med_rp "Median USDA ins. rate parameter for irrigated sorghum"

	rename nonirr_med_rp nonirr_sorghum_med_rp
		la var nonirr_sorghum_med_rp "Median USDA ins. rate parameter for non-irrigated sorghum"
	
	gen fips = (state_fips * 1000) + county_fips

	save "${datapath}USDA_sorghum_rps", replace
restore

* Merging all rate parameter measurements together
*** Note: I'm building this data frame wide, rather than long due to they
*** way we merge for the NRD data set later. There are now going to 
*** multiple crops with rate parameter measurements for the county-year-crop
*** combinations in this panel. In the end, we will end up keeping only one of 
*** the four crops to have data that is at the county-year combo.
use "${datapath}USDA_corn_rps", clear
		
	merge m:1 fips year using "${datapath}USDA_soybean_rps"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}USDA_sorghum_rps"
		drop if _merge == 2
		drop _merge
		
save "${datapath}USDA_rate_parameters", replace
	

