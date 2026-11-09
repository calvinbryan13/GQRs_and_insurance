* Updated summary statistics: November 8, 2026
* Weather controls must already exist in the processed panel.
* Export tables and figures without overwriting earlier versions.
local table_dir "${estpath}nov8_2026"
local figure_dir "`figure_dir'/nov8_2026"
cap mkdir "`table_dir'"
cap mkdir "`figure_dir'"

use "${datapath}nrd_data_cleaned", clear

* Check that the eight requested weather variables are available.
foreach v in precip_lag1 precip_5yr_avg maxtemp_lag1 maxtemp_5yr_avg ///
    pdsi_march_final pdsi_5yr_avg gdd_lag1 gdd_5yr_avg {
    capture confirm numeric variable `v'
    if _rc {
        display as error "Required numeric weather control missing: `v'"
        exit 111
    }
}



*** Creating a graph which compares the mean planted acres for a crop
*** with the max planted acres by year

preserve
	collapse (mean) irr_corn_acres irr_sb_acres irr_sorghum_acres, ///
		by (year)
		
	rename irr_corn_acres mean_corn_ia
	rename irr_sb_acres mean_sb_ia
	rename irr_sorghum_acres mean_sorghum_ia
	
	tempfile irr_means
	save `irr_means', replace
restore

preserve
	collapse (max) irr_corn_acres irr_sb_acres irr_sorghum_acres, ///
		by (year)
		
	rename irr_corn_acres max_corn_ia
	rename irr_sb_acres max_sb_ia
	rename irr_sorghum_acres max_sorghum_ia
	
	tempfile irr_max
	
	merge 1:1 year using `irr_means', nogen

* Corn	
	graph twoway line mean_corn_ia max_corn_ia year, ///
	title("Comparing mean vs. max" ///
		"annual irrigated corn acres" )					  ///
		color(black black)				  ///
		lpattern(solid shortdash)         ///
		xscale(range(2002 2020))           ///
		xlabel(2002(2)2020)               ///
		ylabel(0(100000)300000)
		
		graph save "`figure_dir'/mean_v_max_corn_ia.gph", replace

* Soybean		
	graph twoway line mean_sb_ia max_sb_ia year, ///
	title("Comparing mean vs. max"  ///
		"annual irrigated soybean acres")					  ///
		color(black black)				  ///
		lpattern(solid shortdash)         ///
		xscale(range(2002 2020))           ///
		xlabel(2002(2)2020)               ///
		ylabel(0(50000)150000)
		
		graph save "`figure_dir'/mean_v_max_sb_ia.gph", replace	
		
* Wheat		
	graph twoway line mean_sorghum_ia max_sorghum_ia year, ///
	title("Comparing mean vs. max"  ///
		"annual irrigated sorghum acres")					  ///
		color(black black)				  ///
		lpattern(solid shortdash)         ///
		xscale(range(2002 2020))           ///
		xlabel(2002(2)2020)               ///
		ylabel(0(50000)120000)
		
		graph save "`figure_dir'/mean_v_max_sorghum_ia.gph", replace			
restore	

*** Repeating this exercise ONLY for Nebraska

preserve
	keep if state_fips == 31

	collapse (mean) irr_corn_acres irr_sb_acres irr_sorghum_acres, ///
		by (year)
		
	rename irr_corn_acres mean_corn_ia
	rename irr_sb_acres mean_sb_ia
	rename irr_sorghum_acres mean_sorghum_ia
	
	tempfile irr_means
	save `irr_means', replace
restore

preserve
	keep if state_fips == 31

	collapse (max) irr_corn_acres irr_sb_acres irr_sorghum_acres, ///
		by (year)
		
	rename irr_corn_acres max_corn_ia
	rename irr_sb_acres max_sb_ia
	rename irr_sorghum_acres max_sorghum_ia
	
	tempfile irr_max
	
	merge 1:1 year using `irr_means', nogen

* Corn	
	graph twoway line mean_corn_ia max_corn_ia year, ///
	title("Comparing mean vs. max" ///
		"annual irrigated corn acres" )					  ///
		color(black black)				  ///
		lpattern(solid shortdash)         ///
		xscale(range(2002 2020))           ///
		xlabel(2002(2)2020)               ///
		ylabel(0(100000)300000)
		
		graph save "`figure_dir'/neb_mean_v_max_corn_ia.gph", replace

* Soybean		
	graph twoway line mean_sb_ia max_sb_ia year, ///
	title("Comparing mean vs. max"  ///
		"annual irrigated soybean acres")					  ///
		color(black black)				  ///
		lpattern(solid shortdash)         ///
		xscale(range(2002 2020))           ///
		xlabel(2002(2)2020)               ///
		ylabel(0(50000)150000)
		
		graph save "`figure_dir'/neb_mean_v_max_sb_ia.gph", replace	

* Wheat		
	graph twoway line mean_sorghum_ia max_sorghum_ia year, ///
	title("Comparing mean vs. max"  ///
		"annual irrigated sorghum acres")					  ///
		color(black black)				  ///
		lpattern(solid shortdash)         ///
		xscale(range(2002 2020))           ///
		xlabel(2002(2)2020)               ///
		ylabel(0(20000)50000)
		
		graph save "`figure_dir'/neb_mean_v_max_sorghum_ia.gph", replace			
restore			
	
****************** CREATING SUMMARY STATISTICS *********************************

keep if corn_sample == 1

	gen sb_sample_of_corn = 1 if irr_sb_acres > 0
	
	* Table 1: Primary Analysis variables
	eststo sumstats_levels: estpost sum irr_corn_mean_rp irr_corn_cpl ///
	irr_corn_ppl irr_corn_spl irr_corn_cov_level ///
	irr_corn_acres irr_corn_prem irr_corn_sub irr_corn_total_cost ///
	irr_corn_prem_pia irr_corn_sub_pia irr_corn_cost_pia ///
	irr_corn_yield allocation irr_acres_mor drill_mor sat_thick ///
    precip_lag1 precip_5yr_avg maxtemp_lag1 maxtemp_5yr_avg ///
    pdsi_march_final pdsi_5yr_avg gdd gdd_5yr_avg ///
    if corn_sample == 1, detail
		
		esttab sumstats_levels using "`table_dir'/sumstats_main_vars.tex", booktabs ///
		label nonumbers cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) p50(fmt(2)) max(fmt(2)) count") replace ///
		title(Summary statistics for irrigated practice types\label{tab2}) ///
		collabels("Mean" "Std. Dev." "Minimum" "Median"  "Maximum" "Obs.", ///
			prefix(\multicolumn{1}{c}{)	///
			suffix(})) ///
		compress ///
		alignment(D{.}{.}{-1} D{.}{.}{-1} D{.}{.}{-1} D{.}{.}{-1} ///
		D{.}{.}{-1} D{.}{.}{-1}) ///
		nogaps
		
