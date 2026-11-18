********************************************************************************
* Matched county-year DiD regressions -- UPDATED WEATHER CONTROLS
* Tables 2, 2B, 3, 4, 4B, 4C
*
* Reads outcome variables already created in 002 process_data.do.
* No dependent variables are generated, replaced, renamed, or rescaled here.
*
* Matching: pre-insurance / groundwater / joint matching (1:1 logit PSM)
* Estimation: reghdfe with county FE, state-specific linear trends, clustered by county
* Estimates three specifications per outcome; exports full-control spec (1).
* Common complete-case sample for Tables 2-4C; yield exempt.
* PDSI controls: March bins and previous-5-full-year bin counts (neutral reference).
* Table 5 is not estimated and its outcome variables do not restrict the sample.
* Verify identical effective reghdfe samples for all non-yield models.
********************************************************************************
version 18.0
clear all
set more off

local match_nn 1
global DIDPSM_OUTDIR "${estpath}nov19_2026/DiD"
cap mkdir "${estpath}nov19_2026"
cap mkdir "$DIDPSM_OUTDIR"

* Remove any Table 5 LaTeX files left by earlier versions of this do-file.
foreach match in psm_preinsurance psm_groundwater psm_both {
    capture erase "$DIDPSM_OUTDIR/DID_table5_`match'.tex"
}

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
    irr_corn_ins_acres irr_corn_yield irr_corn_ln_liab irr_corn_liab ///
    irr_corn_mean_rp irr_corn_cpl irr_corn_ppl irr_corn_spl ///
    irr_corn_total_cost irr_corn_prem irr_corn_sub ///
    irr_corn_ln_total_cost irr_corn_ln_prem irr_corn_ln_sub ///
    irr_corn_cost_pia irr_corn_prem_pia irr_corn_sub_pia

foreach v of local outcome_vars {
    confirm numeric variable `v'
}

********************************************************************************
* 2. Controls from original county-year setup
********************************************************************************
* PDSI bins from 001_01B_extract_weather_cropland_prior5_pdsi_bins.R.
* March bins are five mutually exclusive indicators; omit -1 to 1 as baseline.
* Historical bins count the preceding five FULL-YEAR PDSI values (not March).
* Their five counts sum to 5 for complete histories, so omit -1 to 1 as
* the reference category to avoid perfect collinearity with the intercept.
* The omitted middle-bin variables remain in the underlying dataset.
local pdsi_march_controls ///
    pdsi_march_lt_neg3 pdsi_march_neg3_to_neg1 ///
    pdsi_march_pos1_to_3 pdsi_march_gt_3
local pdsi_prior5_controls ///
    pdsi_prev5_n_lt_neg3 pdsi_prev5_n_neg3_to_neg1 ///
    pdsi_prev5_n_pos1_to_3 pdsi_prev5_n_gt_3

* Give an explicit error if the revised weather panel has not yet been merged
* into nrd_data_cleaned by the upstream data-processing do-file.
foreach v in `pdsi_march_controls' `pdsi_prior5_controls' {
    capture confirm numeric variable `v'
    if _rc {
        display as error "Missing PDSI bin variable: `v'. Merge the revised 001_01B weather panel into nrd_data_cleaned before running this do-file."
        exit 111
    }
}

local weather_controls precip_lag1 precip_5yr_avg maxtemp_lag1 maxtemp_5yr_avg ///
    `pdsi_march_controls' `pdsi_prior5_controls' gdd_lag1 gdd_5yr_avg
local controls_irr_corn_ac allocation drill_mor irr_acres_mor `weather_controls' sat_thick sat_thick_sq i.state_fips##year
local controls_irr_corn_no_st allocation drill_mor irr_acres_mor `weather_controls' i.state_fips##year

global controls_irr_corn_ac `controls_irr_corn_ac'
global controls_irr_corn_no_st `controls_irr_corn_no_st'

********************************************************************************
* 2A. Define common complete-case sample for Tables 2-4C only
*
* Table 5 outcomes are deliberately NOT in outcome_vars or the restriction.
* Yield outcomes are excluded from sample selection, so their N can be lower.
* Restrict rows AFTER matching, preserving the original matching process.
********************************************************************************
local yield_outcomes irr_corn_ln_yield irr_corn_yield
local main_outcomes : list outcome_vars - yield_outcomes
local common_regressors allocation drill_mor irr_acres_mor `weather_controls' ///
    sat_thick sat_thick_sq fips state_fips year

egen byte main_sample_missing = rowmiss(`main_outcomes' `common_regressors')
gen byte common_sample = (main_sample_missing == 0)
label var common_sample "Complete data for Tables 2-4C, excluding yields"
drop main_sample_missing

quietly count if common_sample == 1
display as text "Tables 2-4C complete-case rows (before matching): " ///
    as result %12.0fc r(N)

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

    * Every non-yield regression must retain exactly the pre-established
    * post-matching sample. Yield models are allowed to have a smaller N.
    local is_yield = inlist("`dv'", "irr_corn_ln_yield", "irr_corn_yield")

    eststo `prefix'1: reghdfe `dv' $controls_irr_corn_ac, vce(cluster fips) absorb(fips)
    if !`is_yield' {
        if e(N) != $DIDPSM_EXPECT_N {
            di as error "Sample mismatch: `dv' spec 1; N=" e(N) ///
                "; expected " $DIDPSM_EXPECT_N
            exit 459
        }
        quietly count if !e(sample)
        if r(N) != 0 {
            di as error "Sample mismatch: `dv' spec 1 excludes " r(N) " panel rows"
            exit 459
        }
    }

    eststo `prefix'2: reghdfe `dv' allocation i.state_fips##year, vce(cluster fips) absorb(fips)
    if !`is_yield' {
        if e(N) != $DIDPSM_EXPECT_N {
            di as error "Sample mismatch: `dv' spec 2; N=" e(N) ///
                "; expected " $DIDPSM_EXPECT_N
            exit 459
        }
        quietly count if !e(sample)
        if r(N) != 0 {
            di as error "Sample mismatch: `dv' spec 2 excludes " r(N) " panel rows"
            exit 459
        }
    }

    eststo `prefix'3: reghdfe `dv' $controls_irr_corn_no_st, vce(cluster fips) absorb(fips)
    if !`is_yield' {
        if e(N) != $DIDPSM_EXPECT_N {
            di as error "Sample mismatch: `dv' spec 3; N=" e(N) ///
                "; expected " $DIDPSM_EXPECT_N
            exit 459
        }
        quietly count if !e(sample)
        if r(N) != 0 {
            di as error "Sample mismatch: `dv' spec 3 excludes " r(N) " panel rows"
            exit 459
        }
    }
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
                 "Includes county fixed effects and state-specific linear trends." ///
                 "Matching algorithm: `matchlab'.") ///
        substitute({table} {sidewaystable})
end

cap program drop run_didpsm_tables
program define run_didpsm_tables
    syntax , MATCHSLUG(string) MATCHLAB(string)

    * Lock down the effective sample for this matching design, including
    * reghdfe's singleton exclusion. The main common flag alone does not
    * necessarily guarantee the same effective e(sample) in every regression.
    quietly reghdfe irr_corn_ln_ins_acres $controls_irr_corn_ac, ///
        vce(cluster fips) absorb(fips)
    gen byte __common_esample = e(sample)
    keep if __common_esample == 1
    drop __common_esample
    quietly count
    global DIDPSM_EXPECT_N = r(N)
    display as text "`matchslug': fixed non-yield sample N = " ///
        as result %12.0fc $DIDPSM_EXPECT_N

    * TABLE 2: Agricultural outcomes: logged acreage and yield, coverage in levels
    eststo clear
    didpsm_reg3, dv(irr_corn_ln_ins_acres) prefix(a)
    didpsm_reg3, dv(irr_corn_ln_yield) prefix(b)
    didpsm_reg3, dv(irr_corn_cov_level) prefix(c)
    didpsm_reg3, dv(irr_corn_ln_liab) prefix(d)
    export_didpsm_table ///
        a1 b1 c1 d1, ///
        using("$DIDPSM_OUTDIR/DID_table2_`matchslug'.tex") ///
        title("Matched DiD: Agricultural outcomes: logged acreage and yield, coverage in levels") ///
        matchlab("`matchlab'") ///
        mtitles(`"Ln(Insured acres)"' `"Ln(Yield)"' `"Coverage level"' `"Ln(Liability)"')

    * TABLE 2B: Agricultural outcomes: all levels
    eststo clear
    didpsm_reg3, dv(irr_corn_ins_acres) prefix(a)
    didpsm_reg3, dv(irr_corn_yield) prefix(b)
    didpsm_reg3, dv(irr_corn_cov_level) prefix(c)
    didpsm_reg3, dv(irr_corn_liab) prefix(d)
    export_didpsm_table ///
        a1 b1 c1 d1, ///
        using("$DIDPSM_OUTDIR/DID_table2B_`matchslug'.tex") ///
        title("Matched DiD: Agricultural outcomes: all levels") ///
        matchlab("`matchlab'") ///
        mtitles(`"Insured acres"' `"Yield"' `"Coverage level"' `"Liability"')

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


end

********************************************************************************
* 5. Run three matched DiD designs on county-year data only
********************************************************************************
use `panel_master', clear
merge m:1 fips using `county_match_rp', keep(3) nogen
keep if common_sample == 1
run_didpsm_tables, matchslug(psm_preinsurance) matchlab("Pre-treatment insurance")

use `panel_master', clear
merge m:1 fips using `county_match_st', keep(3) nogen
keep if common_sample == 1
run_didpsm_tables, matchslug(psm_groundwater) matchlab("Groundwater")

use `panel_master', clear
merge m:1 fips using `county_match_both', keep(3) nogen
keep if common_sample == 1
run_didpsm_tables, matchslug(psm_both) matchlab("Pre-treatment insurance and groundwater")

********************************************************************************
* End of file
********************************************************************************