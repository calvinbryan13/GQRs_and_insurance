* * * * * * * * * * * * * * * * CORN * * * * * * * * * * * * * *
import delimited "${rawpath}corn_yield.csv", clear

		keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value corn_yield
		la var corn_yield "Corn Yield (Bushels per Acre)"
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (mean) corn_yield, by(fips year)

* Calculating the 10-year variance in county yield
	xtset fips year
		tsegen corn_10yr_sd = rowsd(L(1/10).corn_yield)
		
		gen corn_10yr_var = corn_10yr_sd^2
			la var corn_10yr_var "10-year corn variance"
			
* Calculating the 5-year variance in county yield
	xtset fips year
		tsegen corn_5yr_sd = rowsd(L(1/5).corn_yield)
		
		gen corn_5yr_var = corn_5yr_sd^2
			la var corn_5yr_var "5-year corn variance"
			
* Calculating the 3-year variance in county yield
	xtset fips year
		tsegen corn_3yr_sd = rowsd(L(1/3).corn_yield)
		
		gen corn_3yr_var = corn_3yr_sd^2
			la var corn_3yr_var "3-year corn variance"
			
save "${datapath}corn_var_10year", replace


* * * * * * * * * * * * NON-IRRIGATED CORN YIELD * * * * * * * * * * * *
import delimited "${rawpath}nonirr_corn_yield.csv", clear

		keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value nonirr_corn_yield
		la var nonirr_corn_yield "Non-irrigated Corn Yield (Bushels per Acre)"
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (mean) nonirr_corn_yield, by(fips year)
	
save "${datapath}nonirr_corn_yield", replace

* * * * * * * * * * * * * IRRIGATED CORN * * * * * * * * * * * *
import delimited "${rawpath}irr_corn_yield.csv", clear

		keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_corn_yield
		la var irr_corn_yield "Irrigated Corn Yield (Bushels per Acre)"
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (mean) irr_corn_yield, by(fips year)

* Calculating the 10-year variance in county yield
	xtset fips year
		tsegen irr_corn_10yr_sd = rowsd(L(1/10).irr_corn_yield)
		
		gen irr_corn_10yr_var = irr_corn_10yr_sd^2
			la var irr_corn_10yr_var "10-year irrigated corn variance"

* Calculating the 5-year variance in county yield
	xtset fips year
		tsegen irr_corn_5yr_sd = rowsd(L(1/5).irr_corn_yield)
		
		gen irr_corn_5yr_var = irr_corn_5yr_sd^2
			la var irr_corn_5yr_var "5-year irrigated corn variance"

* Calculating the 3-year variance in county yield
	xtset fips year
		tsegen irr_corn_3yr_sd = rowsd(L(1/3).irr_corn_yield)
		
		gen irr_corn_3yr_var = irr_corn_3yr_sd^2
			la var irr_corn_3yr_var "3-year irrigated corn variance"
			
save "${datapath}irr_corn_var_10year", replace

* Irrigated Corn Production
import delimited "${rawpath}irr_corn_production.csv", clear

	keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_corn_prod
		la var irr_corn_prod "Irrigated Corn Production (Bushels)"
		replace irr_corn_prod = subinstr(irr_corn_prod,",","",.)
		destring irr_corn_prod, force replace
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (sum) irr_corn_prod, by(fips year)
	
	save "${datapath}irr_corn_prod", replace
	
* Irrigated Corn Acres Harvested
import delimited "${rawpath}irr_corn_acres_harvested.csv", clear

	keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_corn_acres_harvested
		la var irr_corn_acres_harvested "Irrigated Corn Acres Harvested"
		replace irr_corn_acres_harvested = subinstr(irr_corn_acres_harvested,",","",.)
		destring irr_corn_acres_harvested, force replace
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (sum) irr_corn_acres_harvested, by(fips year)
	
	save "${datapath}irr_corn_acres_harvested", replace

* * * * * * * * * * * * * * * * SOYBEAN * * * * * * * * * * * * * *
import delimited "${rawpath}NASS_soybean_yield.csv", clear

		keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value sb_yield
		la var sb_yield "Soybean Yield (Bushels per Acre)"
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (mean) sb_yield, by(fips year)

* Calculating the 10-year variance in county yield
	xtset fips year
		tsegen sb_10yr_sd = rowsd(L(1/10).sb_yield)
		
		gen sb_10yr_var = sb_10yr_sd^2
			la var sb_10yr_var "10-year soybean variance"

* Calculating the 5-year variance in county yield
	xtset fips year
		tsegen sb_5yr_sd = rowsd(L(1/5).sb_yield)
		
		gen sb_5yr_var = sb_5yr_sd^2
			la var sb_5yr_var "5-year soybean variance"

* Calculating the 3-year variance in county yield
	xtset fips year
		tsegen sb_3yr_sd = rowsd(L(1/3).sb_yield)
		
		gen sb_3yr_var = sb_3yr_sd^2
			la var sb_3yr_var "3-year soybean variance"
			
save "${datapath}soybean_var_10year", replace

* * * * * * * * * * * * * IRRIGATED SOYBEAN * * * * * * * * * * * *
import delimited "${rawpath}irr_sb_yield.csv", clear

		keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_sb_yield
		la var irr_sb_yield "Irrigated Soybean Yield (Bushels per Acre)"
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (mean) irr_sb_yield, by(fips year)

* Calculating the 10-year variance in county yield
	xtset fips year
		tsegen irr_sb_10yr_sd = rowsd(L(1/10).irr_sb_yield)
		
		gen irr_sb_10yr_var = irr_sb_10yr_sd^2
			la var irr_sb_10yr_var "10-year irrigated soybean variance"

* Calculating the 5-year variance in county yield
	xtset fips year
		tsegen irr_sb_5yr_sd = rowsd(L(1/5).irr_sb_yield)
		
		gen irr_sb_5yr_var = irr_sb_5yr_sd^2
			la var irr_sb_5yr_var "5-year irrigated soybean variance"

* Calculating the 3-year variance in county yield
	xtset fips year
		tsegen irr_sb_3yr_sd = rowsd(L(1/3).irr_sb_yield)
		
		gen irr_sb_3yr_var = irr_sb_3yr_sd^2
			la var irr_sb_3yr_var "3-year irrigated soybean variance"
			
save "${datapath}irr_soybean_var_10year", replace

* Irrigated Soybean Production
import delimited "${rawpath}irr_sb_production.csv", clear

	keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_sb_prod
		la var irr_sb_prod "Irrigated Soybean Production (Bushels)"
		replace irr_sb_prod = subinstr(irr_sb_prod,",","",.)
		destring irr_sb_prod, force replace
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (sum) irr_sb_prod, by(fips year)
	
	save "${datapath}irr_sb_prod", replace

* * * * * * * * * * * * * * * * SORGHUM * * * * * * * * * * * * * * *
import delimited "${rawpath}NASS_sorghum_yield.csv", clear

		keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value sorghum_yield
		la var sorghum_yield "Sorghum Yield (Bushels per Acre)"
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (mean) sorghum_yield, by(fips year)

* Calculating the 10-year variance in county yield
	xtset fips year
		tsegen sorghum_10yr_sd = rowsd(L(1/10).sorghum_yield)
		
		gen sorghum_10yr_var = sorghum_10yr_sd^2
			la var sorghum_10yr_var "10-year sorghum variance"

* Calculating the 5-year variance in county yield
	xtset fips year
		tsegen sorghum_5yr_sd = rowsd(L(1/5).sorghum_yield)
		
		gen sorghum_5yr_var = sorghum_5yr_sd^2
			la var sorghum_5yr_var "5-year sorghum variance"

* Calculating the 3-year variance in county yield
	xtset fips year
		tsegen sorghum_3yr_sd = rowsd(L(1/3).sorghum_yield)
		
		gen sorghum_3yr_var = sorghum_3yr_sd^2
			la var sorghum_3yr_var "3-year sorghum variance"
			
save "${datapath}sorghum_var_10year", replace

* * * * * * * * * * * * * IRRIGATED SORGHUM * * * * * * * * * * * *
import delimited "${rawpath}irr_sorghum_yield.csv", clear

		keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_sorghum_yield
		la var irr_sorghum_yield "Irrigated Sorghum Yield (Bushels per Acre)"
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (mean) irr_sorghum_yield, by(fips year)
	
* Calculating the 10-year variance in county yield
	xtset fips year
		tsegen irr_sorghum_10yr_sd = rowsd(L(1/10).irr_sorghum_yield)
		
		gen irr_sorghum_10yr_var = irr_sorghum_10yr_sd^2
			la var irr_sorghum_10yr_var "10-year irrigated sorghum variance"

* Calculating the 5-year variance in county yield
	xtset fips year
		tsegen irr_sorghum_5yr_sd = rowsd(L(1/5).irr_sorghum_yield)
		
		gen irr_sorghum_5yr_var = irr_sorghum_5yr_sd^2
			la var irr_sorghum_5yr_var "5-year irrigated sorghum variance"

* Calculating the 3-year variance in county yield
	xtset fips year
		tsegen irr_sorghum_3yr_sd = rowsd(L(1/3).irr_sorghum_yield)
		
		gen irr_sorghum_3yr_var = irr_sorghum_3yr_sd^2
			la var irr_sorghum_3yr_var "3-year irrigated sorghum variance"
			
save "${datapath}irr_sorghum_var_10year", replace			
			
* Irrigated Sorghum Production
import delimited "${rawpath}irr_sorghum_production.csv", clear

	keep year stateansi countyansi value
	
	rename stateansi state_fips
	rename countyansi county_fips
	rename value irr_sorghum_prod
		la var irr_sorghum_prod "Irrigated Sorghum Production (Bushels)"
		replace irr_sorghum_prod = subinstr(irr_sorghum_prod,",","",.)
		destring irr_sorghum_prod, force replace
		
	gen fips = (state_fips * 1000) + county_fips
	
	collapse (sum) irr_sorghum_prod, by(fips year)
	
	save "${datapath}irr_sorghum_prod", replace


