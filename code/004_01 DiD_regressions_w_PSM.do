********************************************************************************
* Matched county-year DiD regressions -- tables 2, 2B, 3, 4, 4B, 4C, 5
*
* Reads outcome variables already created in 002 process_data.do.
* No dependent variables are generated, replaced, renamed, or rescaled here.
*
* Matching: pre-insurance / groundwater / joint matching (1:1 logit PSM)
* Estimation: reghdfe with county FE, state-by-year FE, clustered by county
* Estimates three specifications per outcome; exports full-control spec (1).
********************************************************************************
version 18.0
clear all
set more off

local match_nn 1
global DIDPSM_OUTDIR "${estpath}oct21_2026/DiD"
cap mkdir "${estpath}oct21_2026"
cap mkdir "$DIDPSM_OUTDIR"

foreach package in reghdfe ftools psmatch2 estout avar {
    capture which `package'
    if _rc ssc install `package', replace
}

********************************************************************************
* 1. Load pre-processed county-year data -- DO NOT construct outcomes here
********************************************************************************
use "${datapath}nrd_data_cleaned", clear
keep if ogal_share >= 0.01

* Fail early if a required processed outcome is absent. Missing outcomes must
* be produced in the processing script, not re-created in the regression script.
local outcome_vars ///
    irr_corn_ln_ins_acres irr_corn_ln_yield irr_corn_cov_level ///
    irr_corn_ins_acres irr_corn_yield ///
    irr_corn_mean_rp irr_corn_cpl irr_corn_ppl irr_corn_spl ///
    irr_corn_total_cost irr_corn_prem irr_corn_sub ///
    irr_corn_ln_total_cost irr_corn_ln_prem irr_corn_ln_sub ///
    irr_corn_cost_pia irr_corn_prem_pia irr_corn_sub_pia ///
    irr_corn_prod irr_corn_ln_prod irr_corn_prod_per_ins_acre ///
    irr_corn_prod_ppa irr_corn_ins_minus_harv irr_corn_plant_minus_harv

foreach v of local outcome_vars {
    confirm numeric variable `v'
}

********************************************************************************
* 2. Controls from original county-year setup
********************************************************************************
local controls_irr_corn_ac allocation drill_mor irr_acres_mor precip_lag1 maxtemp_lag1 pdsi sat_thick sat_thick_sq i.state_fips##year
local controls_irr_corn_no_st allocation drill_mor irr_acres_mor precip_lag1 maxtemp_lag1 pdsi i.state_fips##year

global controls_irr_corn_ac `controls_irr_corn_ac'
global controls_irr_corn_no_st `controls_irr_corn_no_st'

********************************************************************************
* 3. Build county-level matching variables
********************************************************************************
xtset fips year

bys fips: egen first_treat = min(cond(allocation > 0, year, .))
gen ever_treated = !missing(first_treat)
label var ever_treated "County ever treated by allocation policy"

gen untreated_for_match = year < first_treat if ever_treated == 1
replace untreated_for_match = 1 if ever_treated == 0
label var untreated_for_match "Obs used to build pre-treatment matching covariates"

tempfile panel_master county_base rpcoef stcoef county_matchvars county_match_rp county_match_st county_match_both
save `panel_master', replace

preserve
    keep if untreated_for_match == 1
    keep fips state_fips ogal_share ever_treated year irr_corn_mean_rp sat_thick
    collapse (mean) rp_pre_mean=irr_corn_mean_rp st_pre_mean=sat_thick ogal_share state_fips (count) n_pre=year, by(fips ever_treated)
    save `county_base', replace
restore

preserve
    keep if untreated_for_match == 1
    keep fips year irr_corn_mean_rp
    drop if missing(irr_corn_mean_rp)
    statsby rp_pre_slope=_b[year], by(fips) clear: regress irr_corn_mean_rp year
    save `rpcoef', replace
restore

preserve
    keep if untreated_for_match == 1
    keep fips year sat_thick
    drop if missing(sat_thick)
    statsby st_pre_slope=_b[year], by(fips) clear: regress sat_thick year
    save `stcoef', replace
restore

use `county_base', clear
merge 1:1 fips using `rpcoef', nogen
merge 1:1 fips using `stcoef', nogen

drop if missing(ever_treated)
drop if missing(rp_pre_mean, rp_pre_slope, st_pre_mean, st_pre_slope)

foreach v in rp_pre_mean rp_pre_slope st_pre_mean st_pre_slope ogal_share {
    quietly summarize `v'
    gen z_`v' = (`v' - r(mean))/r(sd)
}

save `county_matchvars', replace

* Match A: pre-treatment insurance level + trend
use `county_matchvars', clear
psmatch2 ever_treated z_rp_pre_mean z_rp_pre_slope z_ogal_share, neighbor(`match_nn') noreplacement logit common

gen in_match_rp = (ever_treated == 1 | _weight > 0)
keep if in_match_rp == 1
keep fips
duplicates drop fips, force
save `county_match_rp', replace

* Match B: groundwater level + trend
use `county_matchvars', clear
psmatch2 ever_treated z_st_pre_mean z_st_pre_slope z_ogal_share, neighbor(`match_nn') noreplacement logit common

gen in_match_st = (ever_treated == 1 | _weight > 0)
keep if in_match_st == 1
keep fips
duplicates drop fips, force
save `county_match_st', replace

* Match C: both jointly
use `county_matchvars', clear
psmatch2 ever_treated z_rp_pre_mean z_rp_pre_slope z_st_pre_mean z_st_pre_slope z_ogal_share, neighbor(`match_nn') noreplacement logit common

gen in_match_both = (ever_treated == 1 | _weight > 0)
keep if in_match_both == 1
keep fips
duplicates drop fips, force
save `county_match_both', replace

********************************************************************************
* 4. Helper programs
********************************************************************************
cap program drop didpsm_reg3
program define didpsm_reg3
    syntax , DV(string) PREFIX(string)

    eststo `prefix'1: reghdfe `dv' $controls_irr_corn_ac, vce(cluster fips) absorb(fips)
    eststo `prefix'2: reghdfe `dv' allocation i.state_fips##year, vce(cluster fips) absorb(fips)
    eststo `prefix'3: reghdfe `dv' $controls_irr_corn_no_st, vce(cluster fips) absorb(fips)
end

cap program drop export_didpsm_table
program define export_didpsm_table
    syntax anything(name=mods) , USING(string) TITLE(string) MATCHLAB(string) MTITLES(string)

    esttab `mods' using "`using'", ///
        replace ///
        title("`title'") ///
        mtitle(`mtitles') ///
        eqlabels(none) ///
        collabels(none) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        compress nogaps booktabs label alignment(D{.}{.}{-1}) ///
        cells(b(fmt(3) star) se(fmt(3) par)) ///
        stats(N r2, fmt(%9.0fc 3) labels(`"Observations"' `"R-Squared"')) ///
        addnotes("Standard errors clustered at the county level in parentheses." ///
                 "Includes county fixed effects and state-by-year fixed effects." ///
                 "Matching algorithm: `matchlab'.") ///
        substitute({table} {sidewaystable})
end

cap program drop run_didpsm_tables
program define run_didpsm_tables
    syntax , MATCHSLUG(string) MATCHLAB(string)

    * TABLE 2: Agricultural outcomes: logged acreage and yield, coverage in levels
    eststo clear
    didpsm_reg3, dv(irr_corn_ln_ins_acres) prefix(a)
    didpsm_reg3, dv(irr_corn_ln_yield) prefix(b)
    didpsm_reg3, dv(irr_corn_cov_level) prefix(c)
    export_didpsm_table ///
        a1 b1 c1, ///
        using("$DIDPSM_OUTDIR/DID_table2_`matchslug'.tex") ///
        title("Matched DiD: Agricultural outcomes: logged acreage and yield, coverage in levels") ///
        matchlab("`matchlab'") ///
        mtitles(`"Ln(Insured acres)"' `"Ln(Yield)"' `"Coverage level"')

    * TABLE 2B: Agricultural outcomes: all levels
    eststo clear
    didpsm_reg3, dv(irr_corn_ins_acres) prefix(a)
    didpsm_reg3, dv(irr_corn_yield) prefix(b)
    didpsm_reg3, dv(irr_corn_cov_level) prefix(c)
    export_didpsm_table ///
        a1 b1 c1, ///
        using("$DIDPSM_OUTDIR/DID_table2B_`matchslug'.tex") ///
        title("Matched DiD: Agricultural outcomes: all levels") ///
        matchlab("`matchlab'") ///
        mtitles(`"Insured acres"' `"Yield"' `"Coverage level"')

    * TABLE 3: Insurance rates and liability-adjusted costs
    eststo clear
    didpsm_reg3, dv(irr_corn_mean_rp) prefix(a)
    didpsm_reg3, dv(irr_corn_cpl) prefix(b)
    didpsm_reg3, dv(irr_corn_ppl) prefix(c)
    didpsm_reg3, dv(irr_corn_spl) prefix(d)
    export_didpsm_table ///
        a1 b1 c1 d1, ///
        using("$DIDPSM_OUTDIR/DID_table3_`matchslug'.tex") ///
        title("Matched DiD: Insurance rates and liability-adjusted costs") ///
        matchlab("`matchlab'") ///
        mtitles(`"Unsubsidized rate"' `"Total cost per liability"' `"Premium per liability"' `"Subsidy per liability"')

    * TABLE 4: Total insurance expenditures (dollars)
    eststo clear
    didpsm_reg3, dv(irr_corn_total_cost) prefix(a)
    didpsm_reg3, dv(irr_corn_prem) prefix(b)
    didpsm_reg3, dv(irr_corn_sub) prefix(c)
    export_didpsm_table ///
        a1 b1 c1, ///
        using("$DIDPSM_OUTDIR/DID_table4_`matchslug'.tex") ///
        title("Matched DiD: Total insurance expenditures (dollars)") ///
        matchlab("`matchlab'") ///
        mtitles(`"Total policy cost"' `"Producer premium"' `"Government subsidy"')

    * TABLE 4B: Logged total insurance expenditures
    eststo clear
    didpsm_reg3, dv(irr_corn_ln_total_cost) prefix(a)
    didpsm_reg3, dv(irr_corn_ln_prem) prefix(b)
    didpsm_reg3, dv(irr_corn_ln_sub) prefix(c)
    export_didpsm_table ///
        a1 b1 c1, ///
        using("$DIDPSM_OUTDIR/DID_table4B_`matchslug'.tex") ///
        title("Matched DiD: Logged total insurance expenditures") ///
        matchlab("`matchlab'") ///
        mtitles(`"Ln(Total policy cost)"' `"Ln(Producer premium)"' `"Ln(Government subsidy)"')

    * TABLE 4C: Insurance expenditures per insured acre (dollars per acre)
    eststo clear
    didpsm_reg3, dv(irr_corn_cost_pia) prefix(a)
    didpsm_reg3, dv(irr_corn_prem_pia) prefix(b)
    didpsm_reg3, dv(irr_corn_sub_pia) prefix(c)
    export_didpsm_table ///
        a1 b1 c1, ///
        using("$DIDPSM_OUTDIR/DID_table4C_`matchslug'.tex") ///
        title("Matched DiD: Insurance expenditures per insured acre (dollars per acre)") ///
        matchlab("`matchlab'") ///
        mtitles(`"Total cost per insured acre"' `"Premium per insured acre"' `"Subsidy per insured acre"')

    * TABLE 5: Corn production and acreage differences
    eststo clear
    didpsm_reg3, dv(irr_corn_prod) prefix(a)
    didpsm_reg3, dv(irr_corn_ln_prod) prefix(b)
    didpsm_reg3, dv(irr_corn_prod_per_ins_acre) prefix(c)
    didpsm_reg3, dv(irr_corn_prod_ppa) prefix(d)
    didpsm_reg3, dv(irr_corn_ins_minus_harv) prefix(e)
    didpsm_reg3, dv(irr_corn_plant_minus_harv) prefix(f)
    export_didpsm_table ///
        a1 b1 c1 d1 e1 f1, ///
        using("$DIDPSM_OUTDIR/DID_table5_`matchslug'.tex") ///
        title("Matched DiD: Corn production and acreage differences") ///
        matchlab("`matchlab'") ///
        mtitles(`"Irr. corn production"' `"Ln(Irr. corn production)"' `"Production / insured acre"' `"Production / planted acre"' `"Insured - harvested acres"' `"Planted - harvested acres"')

end

********************************************************************************
* 5. Run three matched DiD designs on county-year data only
********************************************************************************
use `panel_master', clear
merge m:1 fips using `county_match_rp', keep(3) nogen
run_didpsm_tables, matchslug(psm_preinsurance) matchlab("Pre-treatment insurance")

use `panel_master', clear
merge m:1 fips using `county_match_st', keep(3) nogen
run_didpsm_tables, matchslug(psm_groundwater) matchlab("Groundwater")

use `panel_master', clear
merge m:1 fips using `county_match_both', keep(3) nogen
run_didpsm_tables, matchslug(psm_both) matchlab("Pre-treatment insurance and groundwater")

********************************************************************************
* End of file
********************************************************************************