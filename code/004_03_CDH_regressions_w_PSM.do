********************************************************************************
* CDH matched county-year DiD: Tables 2, 2B, 3, 4, 4B, 4C, 5
*
* Based on 006_03 CDH_regressions_w_PSM(7).do.
* Uses did_multiplegt_stat with continuous allocation, switchers vs stayers,
* county clustering, a one-period placebo, and 1:1 PSM samples.
* Both specifications are estimated: nocontrols and controls.
* Outcomes are READ from the processing script; never recreated or rescaled.
*
* Tables and run logs: ${estpath}oct21_2026/CDH/
* Figure exports are not included: the source uses graph_off and does not
* estimate a dynamic event-study specification.
********************************************************************************
version 18.0
clear all
set more off
local match_nn 1
local treatvar allocation
local cdh_controls drill_mor irr_acres_mor precip_lag1 maxtemp_lag1 pdsi sat_thick sat_thick_sq
local cdh_outcomes ///
    irr_corn_ln_ins_acres irr_corn_ln_yield irr_corn_cov_level ///
    irr_corn_ins_acres irr_corn_yield ///
    irr_corn_mean_rp irr_corn_cpl irr_corn_ppl irr_corn_spl ///
    irr_corn_total_cost irr_corn_prem irr_corn_sub ///
    irr_corn_ln_total_cost irr_corn_ln_prem irr_corn_ln_sub ///
    irr_corn_cost_pia irr_corn_prem_pia irr_corn_sub_pia ///
    irr_corn_prod irr_corn_ln_prod irr_corn_prod_per_ins_acre ///
    irr_corn_prod_ppa irr_corn_ins_minus_harv irr_corn_plant_minus_harv

global CDH_OUTDIR "${estpath}oct21_2026/CDH"
capture mkdir "${estpath}oct21_2026"
capture mkdir "$CDH_OUTDIR"

capture which psmatch2
if _rc ssc install psmatch2, replace
capture which did_multiplegt_stat
if _rc {
    net install did_multiplegt_stat, ///
        from("https://raw.githubusercontent.com/chaisemartinPackages/did_multiplegt_stat/main/STATA") replace
}

********************************************************************************
* 1. Load outcomes processed in 002 process_data.do
********************************************************************************
use "${datapath}nrd_data_cleaned", clear
keep if ogal_share >= 0.01
foreach v of local cdh_outcomes {
    confirm numeric variable `v'
}
foreach v in fips year state_fips ogal_share allocation irr_corn_mean_rp ///
    sat_thick sat_thick_sq `cdh_controls' {
    confirm numeric variable `v'
}
xtset fips year

********************************************************************************
* 2. Build county-level matching variables, as in 006_01
********************************************************************************
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
********************************************************************************
tempname statuspost
postfile `statuspost' str30 matchslug str40 outcome str15 spec int rc double estimate double se double pval double N double N_switchers double placebo double placebo_se str180 logfile using "$CDH_OUTDIR/CDH_run_status.dta", replace

cap program drop run_cdh_one
program define run_cdh_one
    syntax , DV(string) MATCHSLUG(string) SPEC(string) TREATVAR(string) ///
        STATUSPOST(name) [CONTROLS(string)]

    local logstub "CDH_`matchslug'_`spec'_`dv'"
    local logfile "$CDH_OUTDIR/`logstub'.smcl"

    capture confirm variable `dv'
    if _rc {
        di as error "Skipping `dv': variable not found."
        post `statuspost' ("`matchslug'") ("`dv'") ("`spec'") (111) (.) (.) (.) (.) (.) (.) (.) ("`logfile'")
        exit
    }

    preserve
        keep if !missing(`dv', `treatvar', fips, year)
        sort fips year

        capture log close _all
        log using "`logfile'", replace name(cdhlog)

        di as text "============================================================"
        di as text "CDH matched DiD / switcher-stayer model"
        di as text "Matched sample: `matchslug'"
        di as text "Outcome: `dv'"
        di as text "Treatment: `treatvar'"
        di as text "Specification: `spec'"
        di as text "============================================================"

        quietly count
        local N_enter = r(N)
        di as text "Observations entering command before internal restrictions: " `N_enter'
        quietly levelsof fips, local(groups)
        local G_enter = wordcount("`groups'")
        di as text "Number of counties before internal restrictions: " `G_enter'

        * Fallback switcher count for the LaTeX tables. This is the number of
        * county-year cells in the estimation sample whose treatment changed
        * relative to the prior observed year. did_multiplegt_stat may impose
        * additional internal restrictions, so package-reported counts below
        * still take priority when they are available.
        tempvar __cdh_lag_treat __cdh_lag_year __cdh_switch
        by fips (year): gen double `__cdh_lag_treat' = `treatvar'[_n-1]
        by fips (year): gen double `__cdh_lag_year'  = year[_n-1]
        gen byte `__cdh_switch' = !missing(`treatvar', `__cdh_lag_treat') & ///
            year == `__cdh_lag_year' + 1 & `treatvar' != `__cdh_lag_treat'
        quietly count if `__cdh_switch' == 1
        local N_switch_enter = r(N)
        di as text "Switcher county-years before internal restrictions: " `N_switch_enter'

        if "`controls'" == "" {
            capture noisily did_multiplegt_stat `dv' fips year `treatvar', ///
                estimator(was) estimation_method(dr) order(1) placebo(1) ///
                noextrapolation cluster(fips) graph_off
            local rc = _rc
            if `rc' != 0 {
                di as error "First attempt with estimator(was) failed; trying estimator(waoss)."
                capture noisily did_multiplegt_stat `dv' fips year `treatvar', ///
                    estimator(waoss) estimation_method(dr) order(1) placebo(1) ///
                    noextrapolation cluster(fips) graph_off
                local rc = _rc
            }
        }
        else {
            capture noisily did_multiplegt_stat `dv' fips year `treatvar', ///
                estimator(was) estimation_method(dr) order(1) placebo(1) ///
                noextrapolation controls(`controls') cluster(fips) graph_off
            local rc = _rc
            if `rc' != 0 {
                di as error "First attempt with estimator(was) failed; trying estimator(waoss)."
                capture noisily did_multiplegt_stat `dv' fips year `treatvar', ///
                    estimator(waoss) estimation_method(dr) order(1) placebo(1) ///
                    noextrapolation controls(`controls') cluster(fips) graph_off
                local rc = _rc
            }
        }

        di as text "Return code: `rc'"

        * Try to harvest the main effect, standard error, p-value, observations,
        * and placebo estimate from common did_multiplegt_stat return locations.
        * Different package versions store results under different names; if a
        * field remains missing, the full output is still available in the SMCL log.
        local estimate = .
        local se = .
        local pval = .
        local Nobs = .
        local Nswitch = .
        local placebo = .
        local placebo_se = .

        if `rc' == 0 {
            capture local estimate = e(effect)
            capture local estimate = e(estimate)
            capture local estimate = e(att)
            capture local estimate = e(ATT)
            capture local estimate = e(WAS)
            capture local estimate = e(was)
            capture local estimate = r(effect)
            capture local estimate = r(estimate)

            capture local se = e(se)
            capture local se = e(se_effect)
            capture local se = e(se_att)
            capture local se = e(se_ATT)
            capture local se = r(se)

            capture local pval = e(p)
            capture local pval = e(pvalue)
            capture local pval = r(p)
            capture local pval = r(pvalue)

            capture local Nobs = e(N)
            capture local Nobs = e(N_obs)
            capture local Nobs = e(N_effective)
            capture local Nobs = r(N)
            capture local Nobs = r(N_obs)
            capture local Nobs = r(N_effective)
            capture local Nswitch = e(N_switchers)
            capture local Nswitch = e(N_switch)
            capture local Nswitch = e(N_switcher)
            capture local Nswitch = r(N_switchers)
            capture local Nswitch = r(N_switch)
            capture local Nswitch = r(N_switcher)

            capture local placebo = e(placebo_1)
            capture local placebo = e(Placebo_1)
            capture local placebo = r(placebo_1)
            capture local placebo_se = e(se_placebo_1)
            capture local placebo_se = e(Placebo_1_se)
            capture local placebo_se = r(se_placebo_1)

            capture matrix __cdh_tab = r(table)
            if !_rc {
                if missing(`estimate') capture local estimate = __cdh_tab[1,1]
                if missing(`se')       capture local se       = __cdh_tab[2,1]
                if missing(`pval')     capture local pval     = __cdh_tab[4,1]
                capture matrix drop __cdh_tab
            }

            capture matrix __cdh_b = e(b)
            if !_rc {
                if missing(`estimate') capture local estimate = __cdh_b[1,1]
                capture matrix __cdh_V = e(V)
                if !_rc {
                    if missing(`se') capture local se = sqrt(__cdh_V[1,1])
                    if missing(`pval') & !missing(`estimate') & !missing(`se') & `se' > 0 {
                        local pval = 2*normal(-abs(`estimate'/`se'))
                    }
                    capture matrix drop __cdh_V
                }
                capture matrix drop __cdh_b
            }

            * If the package version does not return observation/switcher counts,
            * use the transparent pre-command counts computed above so the LaTeX
            * tables are not left blank.
            if missing(`Nobs') local Nobs = `N_enter'
            if missing(`Nswitch') local Nswitch = `N_switch_enter'

            di as text "Harvested effect: `estimate'"
            di as text "Harvested standard error: `se'"
            di as text "Harvested p-value: `pval'"
            di as text "Recorded observations: `Nobs'"
            di as text "Recorded switcher county-years: `Nswitch'"
        }

        log close cdhlog
    restore

    post `statuspost' ("`matchslug'") ("`dv'") ("`spec'") (`rc') (`estimate') (`se') (`pval') (`Nobs') (`Nswitch') (`placebo') (`placebo_se') ("`logfile'")
end

cap program drop run_cdh_sample
program define run_cdh_sample
    syntax , MATCHSLUG(string) TREATVAR(string) OUTCOMES(string) CONTROLS(string) STATUSPOST(name)

    foreach y of local outcomes {
        run_cdh_one, dv(`y') matchslug(`matchslug') spec(nocontrols) ///
            treatvar(`treatvar') statuspost(`statuspost')

        run_cdh_one, dv(`y') matchslug(`matchslug') spec(controls) ///
            treatvar(`treatvar') controls("`controls'") statuspost(`statuspost')
    }
end

********************************************************************************
********************************************************************************
* 4. Run CDH estimator on each matched sample
********************************************************************************
use `panel_master', clear
merge m:1 fips using `county_match_rp', keep(3) nogen
run_cdh_sample, matchslug(psm_preinsurance) treatvar(`treatvar') ///
    outcomes("`cdh_outcomes'") controls("`cdh_controls'") statuspost(`statuspost')

use `panel_master', clear
merge m:1 fips using `county_match_st', keep(3) nogen
run_cdh_sample, matchslug(psm_groundwater) treatvar(`treatvar') ///
    outcomes("`cdh_outcomes'") controls("`cdh_controls'") statuspost(`statuspost')

use `panel_master', clear
merge m:1 fips using `county_match_both', keep(3) nogen
run_cdh_sample, matchslug(psm_both) treatvar(`treatvar') ///
    outcomes("`cdh_outcomes'") controls("`cdh_controls'") statuspost(`statuspost')

postclose `statuspost'

********************************************************************************
********************************************************************************
* 5. Export run-status file and LaTeX tables
********************************************************************************
use "$CDH_OUTDIR/CDH_run_status.dta", clear
label var matchslug "Matched sample"
label var outcome "Outcome"
label var spec "Specification"
label var rc "Stata return code; 0 means the command ran"
label var estimate "CDH estimate"
label var se "Standard error"
label var pval "P-value"
label var N "Observations"
label var N_switchers "Switchers"
label var placebo "One-period placebo estimate"
label var placebo_se "One-period placebo standard error"
label var logfile "SMCL log file with full output"
export delimited using "$CDH_OUTDIR/CDH_run_status.csv", replace

cap program drop export_cdh_table
program define export_cdh_table
    syntax , OUTCOMES(string) MTITLES(string asis) USING(string) TITLE(string asis) MATCHLAB(string asis) SPEC(string)

    local ncols : word count `outcomes'
    local BS = char(92)

    tempfile cdh_current
    save `cdh_current', replace

    file open fh using `"`using'"', write replace

    file write fh `"`BS'begin{sidewaystable}[htbp]"' _n
    file write fh `"`BS'centering"' _n
    file write fh `"`BS'caption{`title'}"' _n
    file write fh `"`BS'scalebox{0.8}{"' _n
    file write fh `"`BS'begin{tabular}{l*{`ncols'}{c}}"' _n
    file write fh `"`BS'toprule"' _n

    local header ""
    local rest `"`mtitles'"'
    foreach y of local outcomes {
        gettoken mt rest : rest, bind
        local header `"`header' & `mt'"'
    }
    file write fh `"`header' `BS'`BS'"' _n
    file write fh `"`BS'midrule"' _n

    local coefrow "CDH estimate"
    local serow ""
    local plrow "One-period placebo"
    local plserow ""
    local nrow "Observations"
    local swrow "Switchers"

    foreach y of local outcomes {
        use `cdh_current', clear
        keep if outcome == `"`y'"'
        quietly count
        if r(N) == 0 {
            local cstr "--"
            local sestr ""
            local plstr "--"
            local plsestr ""
            local nstr "--"
            local swstr "--"
        }
        else {
            quietly summarize estimate, meanonly
            if r(N) == 0 | missing(r(mean)) local cstr "--"
            else {
                local cstr : display %9.3f r(mean)
                local cstr = strtrim("`cstr'")
                quietly summarize pval, meanonly
                if r(N) > 0 & !missing(r(mean)) {
                    if r(mean) < 0.01 local cstr `"`cstr'$^{***}$"'
                    else if r(mean) < 0.05 local cstr `"`cstr'$^{**}$"'
                    else if r(mean) < 0.10 local cstr `"`cstr'$^{*}$"'
                }
            }

            quietly summarize se, meanonly
            if r(N) == 0 | missing(r(mean)) local sestr ""
            else {
                local sestr : display %9.3f r(mean)
                local sestr = strtrim("`sestr'")
                local sestr `"(`sestr')"'
            }

            quietly summarize placebo, meanonly
            if r(N) == 0 | missing(r(mean)) local plstr "--"
            else {
                local plstr : display %9.3f r(mean)
                local plstr = strtrim("`plstr'")
            }

            quietly summarize placebo_se, meanonly
            if r(N) == 0 | missing(r(mean)) local plsestr ""
            else {
                local plsestr : display %9.3f r(mean)
                local plsestr = strtrim("`plsestr'")
                local plsestr `"(`plsestr')"'
            }

            quietly summarize N, meanonly
            if r(N) == 0 | missing(r(mean)) local nstr "--"
            else {
                local nstr : display %9.0fc r(mean)
                local nstr = strtrim("`nstr'")
            }

            quietly summarize N_switchers, meanonly
            if r(N) == 0 | missing(r(mean)) local swstr "--"
            else {
                local swstr : display %9.0fc r(mean)
                local swstr = strtrim("`swstr'")
            }
        }
        local coefrow `"`coefrow' & `cstr'"'
        local serow   `"`serow' & `sestr'"'
        local plrow   `"`plrow' & `plstr'"'
        local plserow `"`plserow' & `plsestr'"'
        local nrow    `"`nrow' & `nstr'"'
        local swrow   `"`swrow' & `swstr'"'
    }

    file write fh `"`coefrow' `BS'`BS'"' _n
    file write fh `"`serow' `BS'`BS'"' _n
    file write fh `"`BS'addlinespace"' _n
    file write fh `"`plrow' `BS'`BS'"' _n
    file write fh `"`plserow' `BS'`BS'"' _n
    file write fh `"`BS'addlinespace"' _n
    file write fh `"`nrow' `BS'`BS'"' _n
    file write fh `"`swrow' `BS'`BS'"' _n
    file write fh `"`BS'bottomrule"' _n
    file write fh `"`BS'end{tabular}}"' _n
    file write fh `"`BS'vspace{0.15cm}"' _n
    file write fh `"`BS'parbox{0.95`BS'textwidth}{`BS'footnotesize Notes: Standard errors clustered at the county level in parentheses. The treatment is the continuous GQR allocation share. Estimates are from did`BS'_multiplegt`BS'_stat and use the `spec' specification in the `matchlab' matched sample. The one-period placebo compares pre-switch trends for switchers and stable counties when available. $^{*}$ p$<$0.10, $^{**}$ p$<$0.05, $^{***}$ p$<$0.01.}"' _n
    file write fh `"`BS'end{sidewaystable}"' _n
    file close fh

    use `cdh_current', clear
end

cap program drop export_cdh_family_tables
program define export_cdh_family_tables
    syntax , MATCHSLUG(string) MATCHLAB(string asis) SPEC(string)

    preserve
        keep if matchslug == `"`matchslug'"' & spec == `"`spec'"' & rc == 0
        export_cdh_table, ///
            outcomes("irr_corn_ln_ins_acres irr_corn_ln_yield irr_corn_cov_level") ///
            mtitles(`"Ln(Insured acres)"' `"Ln(Yield)"' `"Coverage level"') ///
            using("$CDH_OUTDIR/CDH_table2_`matchslug'_`spec'.tex") ///
            title(`"CDH matched DiD: Logged acreage and yield; coverage in levels"') ///
            matchlab(`"`matchlab'"') spec("`spec'")
        export_cdh_table, ///
            outcomes("irr_corn_ins_acres irr_corn_yield irr_corn_cov_level") ///
            mtitles(`"Insured acres"' `"Yield"' `"Coverage level"') ///
            using("$CDH_OUTDIR/CDH_table2B_`matchslug'_`spec'.tex") ///
            title(`"CDH matched DiD: Agricultural outcomes in levels"') ///
            matchlab(`"`matchlab'"') spec("`spec'")
        export_cdh_table, ///
            outcomes("irr_corn_mean_rp irr_corn_cpl irr_corn_ppl irr_corn_spl") ///
            mtitles(`"Unsubsidized rate"' `"Cost/liability"' `"Premium/liability"' `"Subsidy/liability"') ///
            using("$CDH_OUTDIR/CDH_table3_`matchslug'_`spec'.tex") ///
            title(`"CDH matched DiD: Rates and liability-adjusted insurance costs"') ///
            matchlab(`"`matchlab'"') spec("`spec'")
        export_cdh_table, ///
            outcomes("irr_corn_total_cost irr_corn_prem irr_corn_sub") ///
            mtitles(`"Total cost"' `"Producer premium"' `"Government subsidy"') ///
            using("$CDH_OUTDIR/CDH_table4_`matchslug'_`spec'.tex") ///
            title(`"CDH matched DiD: Total insurance expenditures"') ///
            matchlab(`"`matchlab'"') spec("`spec'")
        export_cdh_table, ///
            outcomes("irr_corn_ln_total_cost irr_corn_ln_prem irr_corn_ln_sub") ///
            mtitles(`"Ln(Total cost)"' `"Ln(Premium)"' `"Ln(Subsidy)"') ///
            using("$CDH_OUTDIR/CDH_table4B_`matchslug'_`spec'.tex") ///
            title(`"CDH matched DiD: Logged total insurance expenditures"') ///
            matchlab(`"`matchlab'"') spec("`spec'")
        export_cdh_table, ///
            outcomes("irr_corn_cost_pia irr_corn_prem_pia irr_corn_sub_pia") ///
            mtitles(`"Cost/insured acre"' `"Premium/insured acre"' `"Subsidy/insured acre"') ///
            using("$CDH_OUTDIR/CDH_table4C_`matchslug'_`spec'.tex") ///
            title(`"CDH matched DiD: Insurance expenditure per insured acre"') ///
            matchlab(`"`matchlab'"') spec("`spec'")
        export_cdh_table, ///
            outcomes("irr_corn_prod irr_corn_ln_prod irr_corn_prod_per_ins_acre irr_corn_prod_ppa irr_corn_ins_minus_harv irr_corn_plant_minus_harv") ///
            mtitles(`"Corn production"' `"Ln(Production)"' `"Production/insured acre"' `"Production/planted acre"' `"Insured - harvested acres"' `"Planted - harvested acres"') ///
            using("$CDH_OUTDIR/CDH_table5_`matchslug'_`spec'.tex") ///
            title(`"CDH matched DiD: Production and acreage differences"') ///
            matchlab(`"`matchlab'"') spec("`spec'")
    restore
end

foreach s in nocontrols controls {
    export_cdh_family_tables, matchslug(psm_preinsurance) matchlab("Pre-treatment insurance") spec(`s')
    export_cdh_family_tables, matchslug(psm_groundwater) matchlab("Groundwater") spec(`s')
    export_cdh_family_tables, matchslug(psm_both) matchlab("Pre-treatment insurance and groundwater") spec(`s')
}
********************************************************************************
* End
********************************************************************************
