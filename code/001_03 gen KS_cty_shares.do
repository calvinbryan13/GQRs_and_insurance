import delimited "${mappath}KS_lema_cty_intersection.csv", clear

	rename geoid fips
	
	keep if statefp == 20
	
	rename statefp state_fips
	rename countyfp county_fips
	rename name county_name
	
	gen lema_share = 0
			replace lema_share = (lema_area/cty_area)
	
	collapse (sum) lema_share, by(fips)
	
save "${datapath}KS_lema_shares", replace
