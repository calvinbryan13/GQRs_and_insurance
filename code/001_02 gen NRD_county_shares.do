import delimited "${mappath}NRD_county_intersection.csv", clear

	rename geoid fips
	
	* calculating area as a function of combined land and water area
	gen county_area = aland + awater
	
forval i = 1/24 {

	gen nrd_share_`i' = 0
		replace nrd_share_`i' = (area_intersect/county_area) if nrd_num == `i'
}

*** Creating a very simple county-year panel to merge NRD shares into
preserve
	import delimited "${datapath}paneled_weather_2000_2020.csv", clear
	
	keep year fips
	
	save "${datapath}county_panel.dta", replace
restore

	* collapsing data down to county level, where each county contains info
	* on the share of land that is within a certain NRD. Then merging into the 
	* panel data with counties and years.
	
	collapse (sum) nrd_share_*, by(fips)
	
	merge 1:m fips using "${datapath}county_panel"
		drop if _merge == 2
		drop _merge	
		
	drop if year == .
	
	la var nrd_share_1 "Share of County in Upper Big Blue NRD"		
	la var nrd_share_2 "Share of County in Lower Big Blue NRD"
	la var nrd_share_3 "Share of County in Upper Elkhorn NRD"		
	la var nrd_share_4 "Share of County in Lower Elkhorn NRD"
	la var nrd_share_5 "Share of County in Little Blue NRD"		
	la var nrd_share_6 "Share of County in Upper Loup NRD"
	la var nrd_share_7 "Share of County in Lower Loup NRD"		
	la var nrd_share_8 "Share of County in Lewis & Clark NRD"
	la var nrd_share_10 "Share of County in Papio-Missouri River NRD"		
	la var nrd_share_11 "Share of County in Nemaha NRD"
	la var nrd_share_12 "Share of County in Upper Niobrara-White NRD"		
	la var nrd_share_13 "Share of County in Middle Niobrara NRD"
	la var nrd_share_14 "Share of County in Lower Niobrara NRD"		
	la var nrd_share_15 "Share of County in North Platte NRD"		
	la var nrd_share_16 "Share of County in South Platte NRD"
	la var nrd_share_17 "Share of County in Twin Platte NRD"		
	la var nrd_share_18 "Share of County in Central Platte NRD"
	la var nrd_share_19 "Share of County in Lower Platte North NRD"
	la var nrd_share_20 "Share of County in Lower Platte South NRD"
	la var nrd_share_21 "Share of County in Upper Republican NRD"
	la var nrd_share_22 "Share of County in Middle Republican NRD"		
	la var nrd_share_23 "Share of County in Lower Republican NRD"
	la var nrd_share_24 "Share of County in Tri-Basin NRD"
	
save "${datapath}nrd_cty_shares", replace
