*** Irrigated Corn yield

	import delimited "${rawpath}irr_corn_yield.csv", clear
	
	keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_corn_yield
		la var irr_corn_yield "Irrigated Corn Yield (Bushels per Acre)"
		
	* County-level panel requires a valid state, county, and year.
    * Retain missing YIELD values; only exclude unidentified observations.
    count if missing(state_fips, county_fips, year)
    if r(N) > 0 {
        di as text "Dropping " r(N) " records lacking state/county/year identifiers"
        drop if missing(state_fips, county_fips, year)
    }

    gen fips = (state_fips * 1000) + county_fips
	
	collapse (mean) irr_corn_yield, by(fips year)
	
	save "${rawpath}irr_corn_yield", replace
	
*** Irrigated Soybean yield
preserve
	import delimited "${rawpath}irr_sb_yield.csv", clear
	
	keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_sb_yield
		la var irr_sb_yield "Irrigated Soybean Yield (Bushels per Acre)"
		
	* County-level panel requires a valid state, county, and year.
    * Retain missing YIELD values; only exclude unidentified observations.
    count if missing(state_fips, county_fips, year)
    if r(N) > 0 {
        di as text "Dropping " r(N) " records lacking state/county/year identifiers"
        drop if missing(state_fips, county_fips, year)
    }

    gen fips = (state_fips * 1000) + county_fips
	
	collapse (mean) irr_sb_yield, by(fips year)
	
	save "${rawpath}irr_sb_yield", replace
restore
	
	merge m:1 fips year using "${rawpath}irr_sb_yield"
		drop _merge	
	
*** Irrigated Sorghum yield
preserve
	import delimited "${rawpath}irr_sorghum_yield.csv", clear
	
	keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_sorghum_yield
		la var irr_sorghum_yield "Irrigated sorghum Yield (Bushels per Acre)"
		
	* County-level panel requires a valid state, county, and year.
    * Retain missing YIELD values; only exclude unidentified observations.
    count if missing(state_fips, county_fips, year)
    if r(N) > 0 {
        di as text "Dropping " r(N) " records lacking state/county/year identifiers"
        drop if missing(state_fips, county_fips, year)
    }

    gen fips = (state_fips * 1000) + county_fips
	
	collapse (mean) irr_sorghum_yield, by(fips year)
	
	save "${rawpath}irr_sorghum_yield", replace	
restore
	
	merge m:1 fips year using "${rawpath}irr_sorghum_yield"
		drop _merge
	
*** Corn Yield
preserve
	import delimited "${rawpath}corn_yield.csv", clear 

	drop program period weekending geolevel agdistrict agdistrictcode zipcode ///
		region watershed_code watershed domain domaincategory cv state county commodity
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value corn_yield
		la var corn_yield "Corn Yield (Bushels per Acre)"
	
	* County-level panel requires a valid state, county, and year.
    * Retain missing YIELD values; only exclude unidentified observations.
    count if missing(state_fips, county_fips, year)
    if r(N) > 0 {
        di as text "Dropping " r(N) " records lacking state/county/year identifiers"
        drop if missing(state_fips, county_fips, year)
    }

    gen fips = (state_fips * 1000) + county_fips
	
	collapse (mean) corn_yield, by(fips year)
		
	gen commodity_rma = 81
	
	save "${rawpath}corn_yield", replace
restore

	merge m:1 fips year using "${rawpath}corn_yield"
		drop _merge
	
*** Soybean Yield
preserve
	import delimited "${rawpath}NASS_soybean_yield.csv", clear 

	drop program period weekending geolevel agdistrict agdistrictcode zipcode ///
		region watershed_code watershed domain domaincategory cv state county commodity
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value sb_yield
		la var sb_yield "Soybean Yield (Bushels per Acre)"
	
	* County-level panel requires a valid state, county, and year.
    * Retain missing YIELD values; only exclude unidentified observations.
    count if missing(state_fips, county_fips, year)
    if r(N) > 0 {
        di as text "Dropping " r(N) " records lacking state/county/year identifiers"
        drop if missing(state_fips, county_fips, year)
    }

    gen fips = (state_fips * 1000) + county_fips
	
	collapse (mean) sb_yield, by(fips year)
		
	gen commodity_rma = 81
	
	save "${rawpath}sb_yield", replace
restore

	merge m:1 fips year using "${rawpath}sb_yield"
		drop _merge
		
*** Sorghum Yield
preserve
	import delimited "${rawpath}NASS_sorghum_yield.csv", clear

	drop program period weekending geolevel agdistrict agdistrictcode zipcode ///
		region watershed_code watershed domain domaincategory cv state county commodity
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value sorghum_yield
		destring sorghum_yield, force replace
		la var sorghum_yield "Sorghum Yield (Bushels per Acre)"
	
	* County-level panel requires a valid state, county, and year.
    * Retain missing YIELD values; only exclude unidentified observations.
    count if missing(state_fips, county_fips, year)
    if r(N) > 0 {
        di as text "Dropping " r(N) " records lacking state/county/year identifiers"
        drop if missing(state_fips, county_fips, year)
    }

    gen fips = (state_fips * 1000) + county_fips
	
	collapse (mean) sorghum_yield, by(fips year)
		
	gen commodity_rma = 51
	
	save "${rawpath}sorghum_yield", replace
restore

	merge m:1 fips year using "${rawpath}sorghum_yield"
		drop _merge
			
*** PRESERVE MISSING YIELDS: missing is not equivalent to zero production
* Verify panel uniqueness and establish calendar-year lags within county
* Final validation after merging all six crop yield series
count if missing(fips, year)
assert r(N) == 0
isid fips year
xtset fips year

	
************************* NOW ACTUALLY CALCULATING APH *************************
	
*********************** Calculating APH for Irrigated Corn
preserve
	forval i=1/10 {
        gen double irr_corn_yield_lag`i' = L`i'.irr_corn_yield
    }

    * Average only nonmissing yields in the prior ten CALENDAR years.
    * A count is retained so sample restrictions can be imposed downstream.
    egen irr_corn_aph10year = rowmean(irr_corn_yield_lag1-irr_corn_yield_lag10)
    egen irr_corn_aph_nyears = rownonmiss(irr_corn_yield_lag1-irr_corn_yield_lag10)
			la var irr_corn_aph10year "10 year APH (irr corn yield)"

	drop if fips == .
	keep if year > 2001
	
	save "${datapath}aph_10year_irr_corn", replace
restore

*********************** Calculating APH for Corn
preserve
	forval i=1/10 {
        gen double corn_yield_lag`i' = L`i'.corn_yield
    }

    * Average only nonmissing yields in the prior ten CALENDAR years.
    * A count is retained so sample restrictions can be imposed downstream.
    egen corn_aph10year = rowmean(corn_yield_lag1-corn_yield_lag10)
    egen corn_aph_nyears = rownonmiss(corn_yield_lag1-corn_yield_lag10)
			la var corn_aph10year "10 year APH (corn yield)"

	drop if fips == .
	keep if year > 2001
	
	save "${datapath}aph_10year_corn", replace
restore
	
*********************** Calculating APH for Irrigated Soybean
preserve
	forval i=1/10 {
        gen double irr_sb_yield_lag`i' = L`i'.irr_sb_yield
    }

    * Average only nonmissing yields in the prior ten CALENDAR years.
    * A count is retained so sample restrictions can be imposed downstream.
    egen irr_sb_aph10year = rowmean(irr_sb_yield_lag1-irr_sb_yield_lag10)
    egen irr_sb_aph_nyears = rownonmiss(irr_sb_yield_lag1-irr_sb_yield_lag10)
			la var irr_sb_aph10year "10 year APH (irr soybean yield)"

	drop if fips == .
	keep if year > 2001
	
	save "${datapath}aph_10year_irr_sb", replace
restore	
	
*********************** Calculating APH for Soybean
preserve
	forval i=1/10 {
        gen double sb_yield_lag`i' = L`i'.sb_yield
    }

    * Average only nonmissing yields in the prior ten CALENDAR years.
    * A count is retained so sample restrictions can be imposed downstream.
    egen sb_aph10year = rowmean(sb_yield_lag1-sb_yield_lag10)
    egen sb_aph_nyears = rownonmiss(sb_yield_lag1-sb_yield_lag10)
			la var sb_aph10year "10 year APH (soybean yield)"

	drop if fips == .
	keep if year > 2001
	
	save "${datapath}aph_10year_sb", replace
restore	
	
*********************** Calculating APH for Irrigated Sorghum
preserve
	forval i=1/10 {
        gen double irr_sorghum_yield_lag`i' = L`i'.irr_sorghum_yield
    }

    * Average only nonmissing yields in the prior ten CALENDAR years.
    * A count is retained so sample restrictions can be imposed downstream.
    egen irr_sorghum_aph10year = rowmean(irr_sorghum_yield_lag1-irr_sorghum_yield_lag10)
    egen irr_sorghum_aph_nyears = rownonmiss(irr_sorghum_yield_lag1-irr_sorghum_yield_lag10)
			la var irr_sorghum_aph10year "10 year APH (irr sorghum yield)"

	drop if fips == .
	keep if year > 2001
	
	save "${datapath}aph_10year_irr_sorghum", replace
restore
	
*********************** Calculating APH for Sorghum
preserve
	forval i=1/10 {
        gen double sorghum_yield_lag`i' = L`i'.sorghum_yield
    }

    * Average only nonmissing yields in the prior ten CALENDAR years.
    * A count is retained so sample restrictions can be imposed downstream.
    egen sorghum_aph10year = rowmean(sorghum_yield_lag1-sorghum_yield_lag10)
    egen sorghum_aph_nyears = rownonmiss(sorghum_yield_lag1-sorghum_yield_lag10)
			la var sorghum_aph10year "10 year APH (sorghum yield)"

	drop if fips == .
	keep if year > 2001
	
	save "${datapath}aph_10year_sorghum", replace
restore

		
********************************************************************************		
use "${datapath}aph_10year_corn", clear

	merge m:1 fips year using "${datapath}aph_10year_irr_corn"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}aph_10year_irr_sb"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}aph_10year_sb"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}aph_10year_irr_sorghum"
		drop if _merge == 2
		drop _merge
		
	merge m:1 fips year using "${datapath}aph_10year_sorghum"
		drop if _merge == 2
		drop _merge
		
********************************************************************************
* Recovering state and county FIPS codes

gen state_fips = floor(fips / 1000)
gen county_fips = mod(fips, 1000)

order state_fips county_fips, after(fips)

sleep 1000
save "${datapath}aph_10year", replace
		
sleep 1000		
save "${datapath}aph_10year", replace
