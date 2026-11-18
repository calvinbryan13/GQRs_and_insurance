********************************************************************************
* CALLAWAY-SANT'ANNA ESTIMATION (PDSI BIN WEATHER CONTROLS)
* Uses 002 process_data outcomes without constructing or rescaling them.
* Tables: 2, 2B, 3, 4, 4B, 4C (Table 5 removed)
* PSM: preinsurance, groundwater, combined; 1:1 logit NN without replacement
* Models: never-treated (default) and not-yet-treated (method(ipw))
* Tables contain overall ATT from estat simple; PNG event studies from estat event.
* Common complete-case sample for Tables 2-4C; yield outcomes exempt.
* March PDSI bins and prior-five-year FULL-YEAR PDSI bin counts.
* Neutral (-1 to 1) PDSI bins are excluded as reference categories.
********************************************************************************
version 18.0
clear all
set more off

local gvar cs_did2
local preL -5
local postL 10
local match_nn 1

global CS_ESTDIR "${estpath}nov19_2026/CS"
global CS_FIGDIR "${figpath}nov19_2026/CS"
cap mkdir "${estpath}nov19_2026"
cap mkdir "$CS_ESTDIR"
cap mkdir "${figpath}nov19_2026"
cap mkdir "${figpath}nov19_2026/CS"
cap mkdir "$CS_FIGDIR"

* Remove any Table 5 exports left by older runs in the target directories.
foreach m in psm_preinsurance psm_groundwater psm_both {
    foreach d in never notyet {
        capture erase "$CS_ESTDIR/CS_table5_`m'_`d'.tex"
    }
}

foreach package in csdid psmatch2 drdid {
    capture which `package'
    if _rc ssc install `package', replace
}

use "${datapath}nrd_data_cleaned", clear
keep if ogal_share >= 0.01
drop if allocation > 0 & allocation < 0.25

* Weather measures: lagged/previous-five-year precip, Tmax, and GDD,
* plus March PDSI indicators and prior-five-year annual PDSI bin counts.
* Both groups use the neutral (-1 to 1) PDSI category as reference.

local pdsi_march_controls ///
    pdsi_march_lt_neg3 pdsi_march_neg3_to_neg1 ///
    pdsi_march_pos1_to_3 pdsi_march_gt_3
local pdsi_prior5_controls ///
    pdsi_prev5_n_lt_neg3 pdsi_prev5_n_neg3_to_neg1 ///
    pdsi_prev5_n_pos1_to_3 pdsi_prev5_n_gt_3

* The new variables must have been merged into nrd_data_cleaned upstream.
foreach v in `pdsi_march_controls' `pdsi_prior5_controls' {
    capture confirm numeric variable `v'
    if _rc {
        di as error "Missing PDSI bin variable: `v'. Merge the revised 001_01B weather panel into nrd_data_cleaned."
        exit 111
    }
}


* Fail early rather than silently regenerating missing dependent variables.
local outcomes ///
    irr_corn_ln_ins_acres irr_corn_ln_yield irr_corn_cov_level ///
    irr_corn_ins_acres irr_corn_yield irr_corn_ln_liab irr_corn_liab ///
    irr_corn_mean_rp irr_corn_cpl irr_corn_ppl irr_corn_spl ///
    irr_corn_total_cost irr_corn_prem irr_corn_sub ///
    irr_corn_ln_total_cost irr_corn_ln_prem irr_corn_ln_sub ///
    irr_corn_cost_pia irr_corn_prem_pia irr_corn_sub_pia
foreach v of local outcomes {
    confirm numeric variable `v'
}
confirm numeric variable `gvar'

* Updated weather controls, matching 004_01B DiD (without DiD-only FE/trends).
* csdid handles its own group-time comparisons; no i.fips/i.year terms.
global controls_irr_corn_ac ///
    drill_mor irr_acres_mor ///
    precip_lag1 precip_5yr_avg maxtemp_lag1 maxtemp_5yr_avg ///
    `pdsi_march_controls' `pdsi_prior5_controls' gdd_lag1 gdd_5yr_avg ///
    sat_thick sat_thick_sq
global psm_gvar `gvar'
global psm_preL `preL'
global psm_postL `postL'

********************************************************************************
* Common complete-case estimation sample for Tables 2-4C only.
* Do not let either yield outcome restrict other outcomes' samples.
* Matching is constructed from the original, unrestricted pre-treatment panel.
********************************************************************************
local yield_outcomes irr_corn_ln_yield irr_corn_yield
local main_outcomes : list outcomes - yield_outcomes
local sample_regressors drill_mor irr_acres_mor ///
    precip_lag1 precip_5yr_avg maxtemp_lag1 maxtemp_5yr_avg ///
    `pdsi_march_controls' `pdsi_prior5_controls' gdd_lag1 gdd_5yr_avg ///
    sat_thick sat_thick_sq fips year `gvar'
egen byte __missing_main = rowmiss(`main_outcomes' `sample_regressors')
gen byte common_sample = (__missing_main == 0)
drop __missing_main
label var common_sample "Complete data for Tables 2-4C, excluding yields"
quietly count if common_sample
noi di as text "CS complete-case county-year observations before matching: " ///
    as result %12.0fc r(N)

********************************************************************************
* County-level matching: retained from the uploaded CS do-file
********************************************************************************
xtset fips year
* Covariates are expected to exist in the processed data.
confirm numeric variable sat_thick_sq

*-----------------------------*
* 2. Build county-level match *
*-----------------------------*
bys fips: egen first_treat = min(cond(`gvar' > 0, `gvar', .))
gen ever_treated = !missing(first_treat)
label var ever_treated "County ever treated"

gen untreated_for_match = year < first_treat if ever_treated == 1
replace untreated_for_match = 1 if ever_treated == 0
label var untreated_for_match "Obs used to build pre-treatment matching covariates"

tempfile county_base rpcoef stcoef county_matchvars county_match_rp county_match_st county_match_both panel_master
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

*-----------------------------*
* 3. Create matched samples   *
*-----------------------------*
use `county_matchvars', clear
psmatch2 ever_treated z_rp_pre_mean z_rp_pre_slope z_ogal_share, ///
    neighbor(`match_nn') noreplacement logit common

gen in_match_rp = (ever_treated == 1 | _weight > 0)
keep if in_match_rp == 1
keep fips
duplicates drop fips, force
save `county_match_rp', replace

use `county_matchvars', clear
psmatch2 ever_treated z_st_pre_mean z_st_pre_slope z_ogal_share, ///
    neighbor(`match_nn') noreplacement logit common

gen in_match_st = (ever_treated == 1 | _weight > 0)
keep if in_match_st == 1
keep fips
duplicates drop fips, force
save `county_match_st', replace

use `county_matchvars', clear
psmatch2 ever_treated z_rp_pre_mean z_rp_pre_slope z_st_pre_mean z_st_pre_slope z_ogal_share, ///
    neighbor(`match_nn') noreplacement logit common

gen in_match_both = (ever_treated == 1 | _weight > 0)
keep if in_match_both == 1
keep fips
duplicates drop fips, force
save `county_match_both', replace


********************************************************************************
* CS estimation + event-study exports + ATT collection
********************************************************************************
cap program drop cs_run_one
program define cs_run_one, rclass
    syntax , DV(name) TABLE(string) MATCHSLUG(string) MATCHLAB(string) DESIGN(string)

    local ny ""
    local comp "Never-treated controls"
    if "`design'" == "notyet" {
        local ny "notyet method(ipw)"
        local comp "Not-yet-treated controls (IPW)"
    }

    quietly csdid `dv' $controls_irr_corn_ac, ///
        ivar(fips) time(year) gvar($psm_gvar) `ny' vce(cluster fips)
    local N = e(N)
    * CS-DiD can exclude observations internally; verify the effective N.
    * This reference is reset separately for each comparison-group variant.
    local is_yield = inlist("`dv'", "irr_corn_ln_yield", "irr_corn_yield")
    if !`is_yield' {
        if $CS_EXPECT_N < 0 {
            global CS_EXPECT_N = `N'
            noi di as result "Fixed CS sample: `matchslug', `design', N = " %12.0fc `N'
        }
        else if `N' != $CS_EXPECT_N {
            di as error "Non-yield CS sample mismatch: `matchslug', `design', Table `table', `dv'"
            di as error "Observed N = `N'; expected N = " $CS_EXPECT_N
            exit 459
        }
    }

    * ATT averaged over treated groups and post-treatment periods.
    quietly estat simple
    matrix CS_T = r(table)
    local att = el(CS_T,1,1)
    local se  = el(CS_T,2,1)
    local p   = el(CS_T,4,1)

    * Event-study graph including pre-treatment estimates.
    quietly estat event, window($psm_preL $psm_postL)
    csdid_plot, ///
        title("`dv'", size(medsmall)) ///
        subtitle("`matchlab' | `comp'", size(small)) ///
        xtitle("Years relative to first GQR") ///
        ytitle("ATT") ///
        yline(0, lpattern(dash)) ///
        name(csplot, replace)
    graph export "$CS_FIGDIR/CS_table`table'_`dv'_`matchslug'_`design'.png", ///
        as(png) replace width(1800)

    return scalar att = `att'
    return scalar se  = `se'
    return scalar p   = `p'
    return scalar N   = `N'
end

* For each matching design produce six tables for both control-group variants.
cap program drop cs_run_tables
program define cs_run_tables
    syntax , MATCHSLUG(string) MATCHLAB(string)

    foreach design in never notyet {
        global CS_EXPECT_N = -1
        foreach table in 2 2B 3 4 4B 4C {
            local dvs ""
            if "`table'" == "2"  local dvs "irr_corn_ln_ins_acres irr_corn_ln_yield irr_corn_cov_level irr_corn_ln_liab"
            if "`table'" == "2B" local dvs "irr_corn_ins_acres irr_corn_yield irr_corn_cov_level irr_corn_liab"
            if "`table'" == "3"  local dvs "irr_corn_mean_rp irr_corn_cpl irr_corn_ppl irr_corn_spl"
            if "`table'" == "4"  local dvs "irr_corn_total_cost irr_corn_prem irr_corn_sub"
            if "`table'" == "4B" local dvs "irr_corn_ln_total_cost irr_corn_ln_prem irr_corn_ln_sub"
            if "`table'" == "4C" local dvs "irr_corn_cost_pia irr_corn_prem_pia irr_corn_sub_pia"

            local k : word count `dvs'
            local tablefile "$CS_ESTDIR/CS_table`table'_`matchslug'_`design'.tex"
            tempname fh
            file open `fh' using "`tablefile'", write text replace
            file write `fh' "\begin{table}[!htbp]" _n "\centering" _n
            file write `fh' "\caption{Callaway--Sant'Anna: Table `table' (`matchlab'; `design')}" _n
            file write `fh' "\begin{tabular}{l*{`k'}{c}}" _n "\hline\hline" _n
            file write `fh' "Outcome"
            foreach dv of local dvs {
                file write `fh' " & \scriptsize\detokenize{`dv'}"
            }
            file write `fh' " \\" _n "\hline" _n
            local attrow "Overall ATT"
            local serow  "SE"
            local nrow   "Observations"
            foreach dv of local dvs {
                di as txt "CS `matchslug' `design' Table `table': `dv'"
                cs_run_one, dv(`dv') table(`table') matchslug(`matchslug') ///
                    matchlab("`matchlab'") design(`design')
                local a : display %9.3f r(att)
                local s : display %9.3f r(se)
                local n : display %9.0fc r(N)
                local a = strtrim("`a'")
                local s = strtrim("`s'")
                local n = strtrim("`n'")
                local stars ""
                if r(p) < .01      local stars "***"
                else if r(p) < .05 local stars "**"
                else if r(p) < .10 local stars "*"
                local attrow `"`attrow' & `a'`stars'"'
                local serow  `"`serow' & (`s')"'
                local nrow   `"`nrow' & `n'"'
            }
            file write `fh' `"`attrow' \\"' _n
            file write `fh' `"`serow' \\"' _n
            file write `fh' "\hline" _n
            file write `fh' `"`nrow' \\"' _n
            file write `fh' "\hline\hline" _n "\end{tabular}" _n
            file write `fh' "\begin{minipage}{0.95\linewidth}\footnotesize" _n
            file write `fh' "Notes: Overall ATT from estat simple; county-clustered standard errors. "
            file write `fh' "Treatment cohort: cs_did2. Matched sample: `matchlab'. "
            file write `fh' "Comparison group: `design'. "
            file write `fh' "Controls: drilling, irrigated acres, lagged precipitation, "
            file write `fh' "five-year precipitation, lagged maximum temperature, "
            file write `fh' "five-year maximum temperature, March PDSI bin indicators, "
            file write `fh' "prior-five-year annual PDSI bin counts (neutral bin omitted), "
            file write `fh' "lagged GDD, five-year GDD, "
            file write `fh' "saturated thickness, and its square. "
            file write `fh' "*** p<0.01, ** p<0.05, * p<0.10." _n
            file write `fh' "\end{minipage}" _n "\end{table}" _n
            file close `fh'
        }
    }
end

********************************************************************************
* Matched samples: the same three PSM algorithms as the uploaded CS script
********************************************************************************
use `panel_master', clear
merge m:1 fips using `county_match_rp', keep(3) nogen
keep if common_sample == 1
quietly count
noi di as text "Matched CS common-sample panel rows (rp): " as result %12.0fc r(N)
cs_run_tables, matchslug(psm_preinsurance) matchlab("Pre-treatment insurance")

use `panel_master', clear
merge m:1 fips using `county_match_st', keep(3) nogen
keep if common_sample == 1
quietly count
noi di as text "Matched CS common-sample panel rows (st): " as result %12.0fc r(N)
cs_run_tables, matchslug(psm_groundwater) matchlab("Groundwater")

use `panel_master', clear
merge m:1 fips using `county_match_both', keep(3) nogen
keep if common_sample == 1
quietly count
noi di as text "Matched CS common-sample panel rows (both): " as result %12.0fc r(N)
cs_run_tables, matchslug(psm_both) matchlab("Pre-treatment insurance and groundwater")

di as result "CS tables saved to $CS_ESTDIR"
di as result "CS event-study PNGs saved to $CS_FIGDIR"
