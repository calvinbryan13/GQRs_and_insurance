********************************************************************************
* 		Importing the Summary of Business (SOB) reports	from 2002-2020		   *
*		to do a crop-specific analysis (starting with irrigated corn)		   *						   *
********************************************************************************	
clear all

* Import all years using a consistent 27-column layout and storage types.
* RMA code/name fields remain strings until after appending where needed;
* numerical IDs and outcomes are explicitly converted to numeric.
forval i = 2002/2020 {
    import delimited "${rawpath}Summary of Business Reports\SOBSCCTPU`i'.TXT", ///
        delimiter("|") varnames(non) stringcols(_all) clear

    * Stop rather than silently shifting fields if the file layout differs.
    capture confirm variable v27
    if _rc {
        di as error "SOB `i': expected all 27 RMA fields."
        exit 459
    }
    capture confirm variable v28
    if !_rc {
        di as error "SOB `i': more than 27 fields; inspect file layout."
        exit 459
    }

    * Consistent numeric types across years; destring errors are intentional.
    * Do NOT use destring, force: unexpected codes should be investigated.
    foreach v in 1 2 5 7 9 12 14 16 20 22 23 24 25 26 27 {
        replace v`v' = strtrim(v`v')
        destring v`v', replace
    }
    * Monetary totals may exceed float precision.
    recast double v20 v22 v23 v24 v25 v27

    keep if inlist(v7, 41, 81, 11, 51)

    if `i' == 2002 {
        save "${datapath}SOB_2002_2020", replace
    }
    else {
        append using "${datapath}SOB_2002_2020"
        save "${datapath}SOB_2002_2020", replace
    }
}

* Historical import complete; no append, force used.

rename v1 year
rename v2 state_fips
rename v3 state_name
rename v4 state_code
rename v5 county_fips
rename v6 county_name
rename v7 commodity_rma
rename v8 commodity_name
rename v9 insurance_rma
rename v10 insurance_type
rename v11 coverage_type
rename v12 coverage_pct
rename v13 delivery_id
rename v14 type_code
rename v15 type_name
rename v16 practice_code
rename v17 practice_name
rename v18 unit_code
rename v19 unit_name
rename v20 ins_acres
rename v21 report_type
rename v22 liability_amt
rename v23 premium_amt
rename v24 subsidy_amt
rename v25 indemnity_amt_SOB
rename v26 loss_ratio
rename v27 endorsement_acres

	replace county_fips = . if county_fips == 999
	gen fips = (state_fips * 1000) + county_fips
		la var fips "FIPS code"
		
* determining if a practice would be classified as "irrigated" or "non-irrigated"		
gen irrigated = 0
	replace irrigated = 1 if practice_code == 2
	replace irrigated = 1 if practice_code == 94
	replace irrigated = 1 if practice_code == 95
	replace irrigated = 1 if practice_code == 154
	replace irrigated = 1 if practice_code == 702
	replace irrigated = 1 if practice_code == 712
	replace irrigated = 1 if practice_code == 739
	replace irrigated = 1 if practice_code == 740
	replace irrigated = 1 if practice_code == 741
	replace irrigated = 1 if practice_code == 742
	replace irrigated = 1 if practice_code == 156
	replace irrigated = 1 if practice_code == 157
	replace irrigated = 1 if practice_code == 4
	replace irrigated = 1 if practice_code == 5
	replace irrigated = 1 if practice_code == 6
	replace irrigated = 1 if practice_code == 45
	replace irrigated = 1 if practice_code == 108
	replace irrigated = 1 if practice_code == 715
	replace irrigated = 1 if practice_code == 716
	replace irrigated = 1 if practice_code == 717
	replace irrigated = 1 if practice_code == 718
	replace irrigated = 1 if practice_code == 721
	
gen non_irrigated = 0
	replace non_irrigated = 1 if practice_code == 3
	replace non_irrigated = 1 if practice_code == 14
	replace non_irrigated = 1 if practice_code == 15
	replace non_irrigated = 1 if practice_code == 43
	replace non_irrigated = 1 if practice_code == 53
	replace non_irrigated = 1 if practice_code == 63
	replace non_irrigated = 1 if practice_code == 73
	replace non_irrigated = 1 if practice_code == 83
	replace non_irrigated = 1 if practice_code == 86
	replace non_irrigated = 1 if practice_code == 88
	replace non_irrigated = 1 if practice_code == 89
	replace non_irrigated = 1 if practice_code == 90
	replace non_irrigated = 1 if practice_code == 91
	replace non_irrigated = 1 if practice_code == 93
	replace non_irrigated = 1 if practice_code == 155
	replace non_irrigated = 1 if practice_code == 158
	replace non_irrigated = 1 if practice_code == 159
	replace non_irrigated = 1 if practice_code == 713
	replace non_irrigated = 1 if practice_code == 714
	replace non_irrigated = 1 if practice_code == 725
	replace non_irrigated = 1 if practice_code == 726
	replace non_irrigated = 1 if practice_code == 727
	replace non_irrigated = 1 if practice_code == 728
	replace non_irrigated = 1 if practice_code == 729
	replace non_irrigated = 1 if practice_code == 730
	replace non_irrigated = 1 if practice_code == 731
	replace non_irrigated = 1 if practice_code == 732
	replace non_irrigated = 1 if practice_code == 733
	replace non_irrigated = 1 if practice_code == 734
	replace non_irrigated = 1 if practice_code == 735
	replace non_irrigated = 1 if practice_code == 736
	replace non_irrigated = 1 if practice_code == 737
	replace non_irrigated = 1 if practice_code == 738
	
*** Making an "Irrigation" variable for collapsing, then merging later ***
gen irrigation = .
	replace irrigation = 1 if irrigated == 1
	replace irrigation = 2 if non_irrigated == 1
	
	label define irrigation_labels 1 "Irrigated", add
	label define irrigation_labels 2 "Non-Irrigated", add
	label values irrigation irrigation_labels
	
*** Generating a unique state-year-crop-irrigation ID
	egen SOB_id = group(fips year commodity_rma irrigation)
		la var SOB_id "Crop-FIPS identifier"

save "${datapath}SOB_2002_2020", replace

* Now we're collapsing the data to the county-year-crop-irrigation level 
preserve
	collapse (sum) liability_amt premium_amt subsidy_amt ins_acres ///
	endorsement_acres indemnity_amt_SOB, by(fips year commodity_rma irrigation)
	
	* netting out subsidies from premiums
	replace premium_amt = premium_amt - subsidy_amt
	
	save "${datapath}SOB_2002_2020_collapsed", replace
restore

* Ingredients for acreage-weighted mean coverage percentages.
* Loss ratios are NOT acreage-weighted; they are derived from gross
* premium and indemnity totals in each aggregation block below.
gen double cov_numerator = coverage_pct * ins_acres ///
    if !missing(coverage_pct, ins_acres) & ins_acres > 0
gen double cov_denominator = ins_acres ///
    if !missing(coverage_pct, ins_acres) & ins_acres > 0

*_______________________________________________________________________________
* First, variables for CORN
*_______________________________________________________________________________
preserve
	use "${datapath}SOB_2002_2020_collapsed", clear
	
	collapse (sum) liability_amt premium_amt subsidy_amt ins_acres ///
	endorsement_acres indemnity_amt_SOB, by(fips year commodity_rma)
	* ^Here I collapse again because I'm aggregating across irrigation status
	
	keep if commodity_rma == 41
	
	rename liability_amt corn_liab
		la var corn_liab "Corn Liability Amount"
		
	rename premium_amt corn_prem
		la var corn_prem "Corn Premium Amount"
		
	rename subsidy_amt corn_sub
		la var corn_sub "Corn Subsidy Amount"
		
	rename indemnity_amt_SOB corn_indem
		la var corn_indem "Corn Indemnity Amount"

	rename endorsement_acres corn_end_acres
		la var corn_end_acres "Corn Endorsement Acres"
		
	rename ins_acres corn_ins_acres
		la var corn_ins_acres "Corn Insured Acres"
		
	tempfile SOB_corn
	save "${datapath}SOB_corn", replace
restore

* Irrigated Corn variables collapsed to county-year level
preserve
	use "${datapath}SOB_2002_2020_collapsed", clear
	
	keep if irrigation == 1
	keep if commodity_rma == 41
	
	rename liability_amt irr_corn_liab
		la var irr_corn_liab "Irrigated Corn Liability Amount"
		
	rename premium_amt irr_corn_prem
		la var irr_corn_prem "Irrigated Corn Premium Amount"
		
	rename subsidy_amt irr_corn_sub
		la var irr_corn_sub "Irrigated Corn Subsidy Amount"
		
	rename indemnity_amt_SOB irr_corn_indem
		la var irr_corn_indem "Irrigated Corn Indemnity Amount"

	rename endorsement_acres irr_corn_end_acres
		la var irr_corn_end_acres "Irrigated Corn Endorsement Acres"
	
	rename ins_acres irr_corn_ins_acres
		la var irr_corn_ins_acres "Irrigated Corn Insured Acres"
		
	tempfile SOB_irrcorn
	save "${datapath}SOB_irrcorn", replace
restore

* Non-Irrigated Corn variables collapsed to county-year level
preserve
	use "${datapath}SOB_2002_2020_collapsed", clear
	
	keep if irrigation == 2
	keep if commodity_rma == 41
	
	rename liability_amt nonirr_corn_liab
		la var nonirr_corn_liab "Non-Irrigated Corn Liability Amount"
		
	rename premium_amt nonirr_corn_prem
		la var nonirr_corn_prem "Non-Irrigated Corn Premium Amount"
		
	rename subsidy_amt nonirr_corn_sub
		la var nonirr_corn_sub "Non-Irrigated Corn Subsidy Amount"
		
	rename indemnity_amt_SOB nonirr_corn_indem
		la var nonirr_corn_indem "Non-Irrigated Corn Indemnity Amount"

	rename endorsement_acres nonirr_corn_end_acres
		la var nonirr_corn_end_acres "Non-Irrigated Corn Endorsement Acres"
	
	rename ins_acres nonirr_corn_ins_acres
		la var nonirr_corn_ins_acres "Non-Irrigated Corn Insured Acres"
					
	tempfile SOB_nonirrcorn
	save "${datapath}SOB_nonirrcorn", replace
restore
	
* Aggregate loss ratio (indemnity / gross premium) and acreage-weighted
* average coverage percentage
preserve
	* RMA aggregate loss ratio = total indemnity / gross total premium.
    * Maintain acreage-weighted coverage level as in the original script.
    collapse (sum) indemnity_amt_SOB premium_amt cov_numerator cov_denominator, ///
        by(fips year commodity_rma)
    gen double loss_ratio = indemnity_amt_SOB / premium_amt if premium_amt > 0
    gen double coverage_pct = cov_numerator / cov_denominator if cov_denominator > 0
    drop indemnity_amt_SOB premium_amt cov_numerator cov_denominator
	
	keep if commodity_rma == 41
	
	rename loss_ratio corn_loss_ratio
	rename coverage_pct corn_cov_level
	
	tempfile corn_lr_collapsed
	save "${datapath}corn_lr_collapsed", replace
restore

preserve
	* RMA aggregate loss ratio = total indemnity / gross total premium.
    * Maintain acreage-weighted coverage level as in the original script.
    collapse (sum) indemnity_amt_SOB premium_amt cov_numerator cov_denominator, ///
        by(fips year commodity_rma irrigation)
    gen double loss_ratio = indemnity_amt_SOB / premium_amt if premium_amt > 0
    gen double coverage_pct = cov_numerator / cov_denominator if cov_denominator > 0
    drop indemnity_amt_SOB premium_amt cov_numerator cov_denominator
	
	keep if commodity_rma == 41
	keep if irrigation == 1
	
	rename loss_ratio irr_corn_loss_ratio
	rename coverage_pct irr_corn_cov_level
	
	tempfile irr_corn_lr_collapsed
	save "${datapath}irr_corn_lr_collapsed", replace
restore

preserve
	* RMA aggregate loss ratio = total indemnity / gross total premium.
    * Maintain acreage-weighted coverage level as in the original script.
    collapse (sum) indemnity_amt_SOB premium_amt cov_numerator cov_denominator, ///
        by(fips year commodity_rma irrigation)
    gen double loss_ratio = indemnity_amt_SOB / premium_amt if premium_amt > 0
    gen double coverage_pct = cov_numerator / cov_denominator if cov_denominator > 0
    drop indemnity_amt_SOB premium_amt cov_numerator cov_denominator
	
	keep if commodity_rma == 41
	keep if irrigation == 2
	
	rename loss_ratio nonirr_corn_loss_ratio
	rename coverage_pct nonirr_corn_cov_level
	
	tempfile nonirr_corn_lr_collapsed
	save "${datapath}nonirr_corn_lr_collapsed", replace
restore

*_______________________________________________________________________________
* Second, variables for SOYBEAN
*_______________________________________________________________________________
preserve
	use "${datapath}SOB_2002_2020_collapsed", clear
	
	collapse (sum) liability_amt premium_amt subsidy_amt ins_acres ///
	endorsement_acres indemnity_amt_SOB, by(fips year commodity_rma)
	* ^Here I collapse again because I'm aggregating across irrigation status
	
	keep if commodity_rma == 81
	
	rename liability_amt sb_liab
		la var sb_liab "Soybean Liability Amount"
		
	rename premium_amt sb_prem
		la var sb_prem "Soybean Premium Amount"
		
	rename subsidy_amt sb_sub
		la var sb_sub "Soybean Subsidy Amount"
		
	rename indemnity_amt_SOB sb_indem
		la var sb_indem "Soybean Indemnity Amount"

	rename endorsement_acres sb_end_acres
		la var sb_end_acres "Soybean Endorsement Acres"
	
	rename ins_acres sb_ins_acres
		la var sb_ins_acres "Soybean Insured Acres"
				
	tempfile SOB_sb
	save "${datapath}SOB_sb", replace
restore

* Irrigated soybean variables collapsed to county-year level
preserve
	use "${datapath}SOB_2002_2020_collapsed", clear
	
	keep if irrigation == 1
	keep if commodity_rma == 81
	
	rename liability_amt irr_sb_liab
		la var irr_sb_liab "Irrigated Soybean Liability Amount"
		
	rename premium_amt irr_sb_prem
		la var irr_sb_prem "Irrigated Soybean Premium Amount"
		
	rename subsidy_amt irr_sb_sub
		la var irr_sb_sub "Irrigated Soybean Subsidy Amount"
		
	rename indemnity_amt_SOB irr_sb_indem
		la var irr_sb_indem "Irrigated Soybean Indemnity Amount"

	rename endorsement_acres irr_sb_end_acres
		la var irr_sb_end_acres "Irrigated Soybean Endorsement Acres"
	
	rename ins_acres irr_sb_ins_acres
		la var irr_sb_ins_acres "Irrigated soybean Insured Acres"
				
	tempfile SOB_irrsb
	save "${datapath}SOB_irrsb", replace
restore

* Non-Irrigated Corn variables collapsed to county-year level
preserve
	use "${datapath}SOB_2002_2020_collapsed", clear
	
	keep if irrigation == 2
	keep if commodity_rma == 81
	
	rename liability_amt nonirr_sb_liab
		la var nonirr_sb_liab "Non-Irrigated Soybean Liability Amount"
		
	rename premium_amt nonirr_sb_prem
		la var nonirr_sb_prem "Non-Irrigated Soybean Premium Amount"
		
	rename subsidy_amt nonirr_sb_sub
		la var nonirr_sb_sub "Non-Irrigated Soybean Subsidy Amount"
		
	rename indemnity_amt_SOB nonirr_sb_indem
		la var nonirr_sb_indem "Non-Irrigated Soybean Indemnity Amount"
			
	rename endorsement_acres nonirr_sb_end_acres
		la var nonirr_sb_end_acres "Non-Irrigated Soybean Endorsement Acres"
	
	rename ins_acres nonirr_sb_ins_acres
		la var nonirr_sb_ins_acres "Non-Irrigated Soybean Insured Acres"
				
	tempfile SOB_nonirrsb
	save "${datapath}SOB_nonirrsb", replace
restore
	
* Aggregate loss ratio (indemnity / gross premium) and acreage-weighted
* average coverage percentage
preserve
	* RMA aggregate loss ratio = total indemnity / gross total premium.
    * Maintain acreage-weighted coverage level as in the original script.
    collapse (sum) indemnity_amt_SOB premium_amt cov_numerator cov_denominator, ///
        by(fips year commodity_rma)
    gen double loss_ratio = indemnity_amt_SOB / premium_amt if premium_amt > 0
    gen double coverage_pct = cov_numerator / cov_denominator if cov_denominator > 0
    drop indemnity_amt_SOB premium_amt cov_numerator cov_denominator
	
	keep if commodity_rma == 81
	
	rename loss_ratio sb_loss_ratio
	rename coverage_pct sb_cov_level
	
	tempfile sb_lr_collapsed
	save "${datapath}sb_lr_collapsed", replace
restore

preserve
	* RMA aggregate loss ratio = total indemnity / gross total premium.
    * Maintain acreage-weighted coverage level as in the original script.
    collapse (sum) indemnity_amt_SOB premium_amt cov_numerator cov_denominator, ///
        by(fips year commodity_rma irrigation)
    gen double loss_ratio = indemnity_amt_SOB / premium_amt if premium_amt > 0
    gen double coverage_pct = cov_numerator / cov_denominator if cov_denominator > 0
    drop indemnity_amt_SOB premium_amt cov_numerator cov_denominator
	
	keep if commodity_rma == 81
	keep if irrigation == 1
	
	rename loss_ratio irr_sb_loss_ratio
	rename coverage_pct irr_sb_cov_level
	
	tempfile irr_sb_lr_collapsed
	save "${datapath}irr_sb_lr_collapsed", replace
restore

preserve
	* RMA aggregate loss ratio = total indemnity / gross total premium.
    * Maintain acreage-weighted coverage level as in the original script.
    collapse (sum) indemnity_amt_SOB premium_amt cov_numerator cov_denominator, ///
        by(fips year commodity_rma irrigation)
    gen double loss_ratio = indemnity_amt_SOB / premium_amt if premium_amt > 0
    gen double coverage_pct = cov_numerator / cov_denominator if cov_denominator > 0
    drop indemnity_amt_SOB premium_amt cov_numerator cov_denominator
	
	keep if commodity_rma == 81
	keep if irrigation == 2
	
	rename loss_ratio nonirr_sb_loss_ratio
	rename coverage_pct nonirr_sb_cov_level
	
	tempfile nonirr_sb_lr_collapsed
	save "${datapath}nonirr_sb_lr_collapsed", replace
restore

*_______________________________________________________________________________
* LAST, variables for SORGHUM
*_______________________________________________________________________________
preserve
	use "${datapath}SOB_2002_2020_collapsed", clear
	
	collapse (sum) liability_amt premium_amt subsidy_amt ins_acres ///
	endorsement_acres indemnity_amt_SOB, by(fips year commodity_rma)
	* ^Here I collapse again because I'm aggregating across irrigation status
	
	keep if commodity_rma == 51
	
	rename liability_amt sorghum_liab
		la var sorghum_liab "Sorghum Liability Amount"
		
	rename premium_amt sorghum_prem
		la var sorghum_prem "Sorghum Premium Amount"
		
	rename subsidy_amt sorghum_sub
		la var sorghum_sub "Sorghum Subsidy Amount"
		
	rename indemnity_amt_SOB sorghum_indem
		la var sorghum_indem "Sorghum Indemnity Amount"
		
	rename endorsement_acres sorghum_end_acres
		la var sorghum_end_acres "Sorghum Endorsement Acres"
	
	rename ins_acres sorghum_ins_acres
		la var sorghum_ins_acres "Sorghum Insured Acres"
				
	tempfile SOB_sorghum
	save "${datapath}SOB_sorghum", replace
restore

* Irrigated Corn variables collapsed to county-year level
preserve
	use "${datapath}SOB_2002_2020_collapsed", clear
	
	keep if irrigation == 1
	keep if commodity_rma == 51
	
	rename liability_amt irr_sorghum_liab
		la var irr_sorghum_liab "Irrigated Sorghum Liability Amount"
		
	rename premium_amt irr_sorghum_prem
		la var irr_sorghum_prem "Irrigated Sorghum Premium Amount"
		
	rename subsidy_amt irr_sorghum_sub
		la var irr_sorghum_sub "Irrigated Sorghum Subsidy Amount"
		
	rename indemnity_amt_SOB irr_sorghum_indem
		la var irr_sorghum_indem "Irrigated Sorghum Indemnity Amount"
		
	rename endorsement_acres irr_sorghum_end_acres
		la var irr_sorghum_end_acres "Irrigated Sorghum Endorsement Acres"
	
	rename ins_acres irr_sorghum_ins_acres
		la var irr_sorghum_ins_acres "Irrigated sorghum Insured Acres"
				
	tempfile SOB_irrsorghum
	save "${datapath}SOB_irrsorghum", replace
restore

* Non-Irrigated Corn variables collapsed to county-year level
preserve
	use "${datapath}SOB_2002_2020_collapsed", clear
	
	keep if irrigation == 2
	keep if commodity_rma == 51
	
	rename liability_amt nonirr_sorghum_liab
		la var nonirr_sorghum_liab "Non-Irrigated Sorghum Liability Amount"
		
	rename premium_amt nonirr_sorghum_prem
		la var nonirr_sorghum_prem "Non-Irrigated Sorghum Premium Amount"
		
	rename subsidy_amt nonirr_sorghum_sub
		la var nonirr_sorghum_sub "Non-Irrigated Sorghum Subsidy Amount"
		
	rename indemnity_amt_SOB nonirr_sorghum_indem
		la var nonirr_sorghum_indem "Non-Irrigated Sorghum Indemnity Amount"
		
	rename endorsement_acres nonirr_sorghum_end_acres
		la var nonirr_sorghum_end_acres "Non-Irrigated Sorghum Endorsement Acres"
	
	rename ins_acres nonirr_sorghum_ins_acres
		la var nonirr_sorghum_ins_acres "Non-Irrigated sorghum Insured Acres"
				
	tempfile SOB_nonirrsorghum
	save "${datapath}SOB_nonirrsorghum", replace
restore
	
* Aggregate loss ratio (indemnity / gross premium) and acreage-weighted
* average coverage percentage
preserve
	* RMA aggregate loss ratio = total indemnity / gross total premium.
    * Maintain acreage-weighted coverage level as in the original script.
    collapse (sum) indemnity_amt_SOB premium_amt cov_numerator cov_denominator, ///
        by(fips year commodity_rma)
    gen double loss_ratio = indemnity_amt_SOB / premium_amt if premium_amt > 0
    gen double coverage_pct = cov_numerator / cov_denominator if cov_denominator > 0
    drop indemnity_amt_SOB premium_amt cov_numerator cov_denominator
	
	keep if commodity_rma == 51
	
	rename loss_ratio sorghum_loss_ratio
	rename coverage_pct sorghum_cov_level
	
	tempfile sorghum_lr_collapsed
	save "${datapath}sorghum_lr_collapsed", replace
restore

preserve
	* RMA aggregate loss ratio = total indemnity / gross total premium.
    * Maintain acreage-weighted coverage level as in the original script.
    collapse (sum) indemnity_amt_SOB premium_amt cov_numerator cov_denominator, ///
        by(fips year commodity_rma irrigation)
    gen double loss_ratio = indemnity_amt_SOB / premium_amt if premium_amt > 0
    gen double coverage_pct = cov_numerator / cov_denominator if cov_denominator > 0
    drop indemnity_amt_SOB premium_amt cov_numerator cov_denominator
	
	keep if commodity_rma == 51
	keep if irrigation == 1
	
	rename loss_ratio irr_sorghum_loss_ratio
	rename coverage_pct irr_sorghum_cov_level
	
	tempfile irr_sorghum_lr_collapsed
	save "${datapath}irr_sorghum_lr_collapsed", replace
restore

preserve
	* RMA aggregate loss ratio = total indemnity / gross total premium.
    * Maintain acreage-weighted coverage level as in the original script.
    collapse (sum) indemnity_amt_SOB premium_amt cov_numerator cov_denominator, ///
        by(fips year commodity_rma irrigation)
    gen double loss_ratio = indemnity_amt_SOB / premium_amt if premium_amt > 0
    gen double coverage_pct = cov_numerator / cov_denominator if cov_denominator > 0
    drop indemnity_amt_SOB premium_amt cov_numerator cov_denominator
	
	keep if commodity_rma == 51
	keep if irrigation == 2
	
	rename loss_ratio nonirr_sorghum_loss_ratio
	rename coverage_pct nonirr_sorghum_cov_level
	
	tempfile nonirr_sorghum_lr_collapsed
	save "${datapath}nonirr_sorghum_lr_collapsed", replace
restore


	
	