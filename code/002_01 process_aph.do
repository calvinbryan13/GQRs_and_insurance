*** Irrigated Corn yield

	import delimited "${rawpath}irr_corn_yield.csv", clear
	
	keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_corn_yield
		la var irr_corn_yield "Irrigated Corn Yield (Bushels per Acre)"
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (sum) irr_corn_yield, by(fips year)
	
	save "${rawpath}irr_corn_yield", replace
	
*** Irrigated Soybean yield
preserve
	import delimited "${rawpath}irr_sb_yield.csv", clear
	
	keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_sb_yield
		la var irr_sb_yield "Irrigated Soybean Yield (Bushels per Acre)"
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (sum) irr_sb_yield, by(fips year)
	
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
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (sum) irr_sorghum_yield, by(fips year)
	
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
	
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (sum) corn_yield, by(fips year)
		
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
	
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (sum) sb_yield, by(fips year)
		
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
	
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (sum) sorghum_yield, by(fips year)
		
	gen commodity_rma = 51
	
	save "${rawpath}sorghum_yield", replace
restore

	merge m:1 fips year using "${rawpath}sorghum_yield"
		drop _merge
			
*** REPLACING MISSING VALUES

	replace corn_yield = 0 if corn_yield == .
	replace sorghum_yield = 0 if sorghum_yield == .
	replace sb_yield = 0 if sb_yield == .
	replace irr_corn_yield = 0 if irr_corn_yield == .
	replace irr_sorghum_yield = 0 if irr_sorghum_yield == .
	replace irr_sb_yield = 0 if irr_sb_yield == .
	
************************* NOW ACTUALLY CALCULATING APH *************************
	
*********************** Calculating APH for Irrigated Corn
preserve
	forval i=1/10 {
		gen irr_corn_yield_lag`i' = irr_corn_yield[_n-`i']
	}
	
		egen irr_corn_aph10year = rowtotal(irr_corn_yield_lag1 irr_corn_yield_lag2 ///
			irr_corn_yield_lag3 irr_corn_yield_lag4 irr_corn_yield_lag5 ///
			irr_corn_yield_lag6 irr_corn_yield_lag7 irr_corn_yield_lag8 ///
			irr_corn_yield_lag9 irr_corn_yield_lag10)
			
		replace irr_corn_aph10year = irr_corn_aph10year/10
			la var irr_corn_aph10year "10 year APH (irr corn yield)"

	drop if fips == .
	keep if year > 2001
	
	save "${datapath}aph_10year_irr_corn", replace
restore

*********************** Calculating APH for Corn
preserve
	forval i=1/10 {
		gen corn_yield_lag`i' = corn_yield[_n-`i']
	}
	
		egen corn_aph10year = rowtotal(corn_yield_lag1 corn_yield_lag2 ///
			corn_yield_lag3 corn_yield_lag4 corn_yield_lag5 ///
			corn_yield_lag6 corn_yield_lag7 corn_yield_lag8 ///
			corn_yield_lag9 corn_yield_lag10)
			
		replace corn_aph10year = corn_aph10year/10
			la var corn_aph10year "10 year APH (corn yield)"

	drop if fips == .
	keep if year > 2001
	
	save "${datapath}aph_10year_corn", replace
restore
	
*********************** Calculating APH for Irrigated Soybean
preserve
	forval i=1/10 {
		gen irr_sb_yield_lag`i' = irr_sb_yield[_n-`i']
	}
	
		egen irr_sb_aph10year = rowtotal(irr_sb_yield_lag1 irr_sb_yield_lag2 ///
			irr_sb_yield_lag3 irr_sb_yield_lag4 irr_sb_yield_lag5 ///
			irr_sb_yield_lag6 irr_sb_yield_lag7 irr_sb_yield_lag8 ///
			irr_sb_yield_lag9 irr_sb_yield_lag10)
			
		replace irr_sb_aph10year = irr_sb_aph10year/10
			la var irr_sb_aph10year "10 year APH (irr soybean yield)"

	drop if fips == .
	keep if year > 2001
	
	save "${datapath}aph_10year_irr_sb", replace
restore	
	
*********************** Calculating APH for Soybean
preserve
	forval i=1/10 {
		gen sb_yield_lag`i' = sb_yield[_n-`i']
	}
	
		egen sb_aph10year = rowtotal(sb_yield_lag1 sb_yield_lag2 ///
			sb_yield_lag3 sb_yield_lag4 sb_yield_lag5 ///
			sb_yield_lag6 sb_yield_lag7 sb_yield_lag8 ///
			sb_yield_lag9 sb_yield_lag10)
			
		replace sb_aph10year = sb_aph10year/10
			la var sb_aph10year "10 year APH (soybean yield)"

	drop if fips == .
	keep if year > 2001
	
	save "${datapath}aph_10year_sb", replace
restore	
	
*********************** Calculating APH for Irrigated Sorghum
preserve
	forval i=1/10 {
		gen irr_sorghum_yield_lag`i' = irr_sorghum_yield[_n-`i']
	}
	
		egen irr_sorghum_aph10year = rowtotal(irr_sorghum_yield_lag1 irr_sorghum_yield_lag2 ///
			irr_sorghum_yield_lag3 irr_sorghum_yield_lag4 irr_sorghum_yield_lag5 ///
			irr_sorghum_yield_lag6 irr_sorghum_yield_lag7 irr_sorghum_yield_lag8 ///
			irr_sorghum_yield_lag9 irr_sorghum_yield_lag10)
			
		replace irr_sorghum_aph10year = irr_sorghum_aph10year/10
			la var irr_sorghum_aph10year "10 year APH (irr sorghum yield)"

	drop if fips == .
	keep if year > 2001
	
	save "${datapath}aph_10year_irr_sorghum", replace
restore
	
*********************** Calculating APH for Sorghum
preserve
	forval i=1/10 {
		gen sorghum_yield_lag`i' = sorghum_yield[_n-`i']
	}
	
		egen sorghum_aph10year = rowtotal(sorghum_yield_lag1 sorghum_yield_lag2 ///
			sorghum_yield_lag3 sorghum_yield_lag4 sorghum_yield_lag5 ///
			sorghum_yield_lag6 sorghum_yield_lag7 sorghum_yield_lag8 ///
			sorghum_yield_lag9 sorghum_yield_lag10)
			
		replace sorghum_aph10year = sorghum_aph10year/10
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
