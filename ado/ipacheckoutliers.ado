*! version 1.0.0 Christopher Boyer 04may2016

program ipacheckoutliers, rclass
	/* This program checks for outliers among 
	   unconstrained survey variables. */
	version 13

	#d ;
	syntax varlist, 
		/* consent options */
	    MULTIplier(numlist missingokay) [SD]
		/* output filename */
	    saving(string) 
	    /* output options */
        id(varname) ENUMerator(varname) [KEEPvars(string)] 
		/* other options */
		[SHEETMODify SHEETREPlace NOLabel];	
	#d cr
	
	* test for fatal conditions
	foreach var in `varlist' {
	    * check that all variables are numeric
		cap confirm numeric variable `var'
		if _rc {
			di as err "Variable `var' is not numeric."
			error 198
		}
	}

	di ""
	di "HFC 11 => Checking that unconstrained variables have no outliers..."
	qui {

	* count nvars
	unab vars : _all
	local nvars : word count `vars'

	* define temporary files 
	tempfile tmp org
	save `org'

	* define temporary variable
	tempvar outlier min max
	g `outlier' = .
	g `min' = .
	g `max' = .

	* define default output variable list
	unab admin : `id' `enumerator'
	local meta `"variable label value message"'

	* add user-specified keep vars to output list
    local lines : subinstr local keepvars ";" "", all
    local lines : subinstr local lines "." "", all

    local unique : list uniq lines
    local keeplist : list admin | unique
    local keeplist : list keeplist | meta

    * initialize local counters
	local noutliers = 0
	local i = 1

	* initialize meta data variables
	foreach var in `meta' {
		g `var' = ""
	}

	* initialize temporary output file
	touch `tmp', var(`keeplist')

	foreach var in `varlist' {
		* get current value of iqr
		local val : word `i' of `multiplier'
		
		* capture variable label
		local varl : variable label `var'

		* update values for additional variables
		replace variable = "`var'"
		replace label = "`varl'"
		replace value = string(`var')

		if "`sd'" == "" {
			* create temp stats variables
			tempvar sigma q1 q3

			* calculate iqr stats
			egen `sigma' = iqr(`var')
			egen `q1' = pctile(`var'), p(25)
			egen `q3' = pctile(`var'), p(75)
			replace `max' = `q3' + `val' * `sigma'
			replace `min' = `q1' - `val' * `sigma'

			* drop reused egen variables
			drop `sigma' `q1' `q3'

			replace message = "Potential outlier " + value + ///
			    " in variable `var' (`val' * IQR: " + ///
			    string(`min', "%2.0f") + " to " + string(`max', "%2.0f") + ")"
		}
		else {
			* create temp stats variables
			tempvar sigma  mu

			* calculate sd stats
			egen `sigma' = sd(`var')
			egen `mu' = mean(`var')
			replace `max' = `mu' + `val' * `sigma'
			replace `min' = `mu' - `val' * `sigma'

			* drop reused egen variables
			drop `sigma' `mu'

			replace message = "Potential outlier " + value + ///
			    " in variable `var' (`val' * SD: " + ///
			    string(`min', "%2.0f") + " to " + string(`max', "%2.0f") + ")"
		}

		* identify outliers 
		replace `outlier' = (`var' > `max' | `var' < `min') & !mi(`var')


		* count outliers
		count if `outlier' == 1
		local n = `r(N)'
		local noutliers = `noutliers' + `n'

		* append violations to the temporary data set
		saveappend using `tmp' if `outlier' == 1, ///
		    keep("`keeplist'") sort(`id')

		* alert user
		nois di "  Variable `var' has `n' potential outliers."
	}

	* import compiled list of violations
	use `tmp', clear

	* if there are no violations
	if `=_N' == 0 {
		set obs 1
	} 

	* create additional meta data for tracking
	g notes = ""
	g drop = ""
	g newvalue = ""	

	order `keeplist' notes drop newvalue

	* export compiled list to excel
	export excel using "`saving'" ,  ///
		sheet("11. outliers") `sheetreplace' `sheetmodify' ///
		firstrow(variables) `nolabel'

	* revert to original
	use `org', clear
	}

	* return scalars
	return scalar noutliers = `noutliers'

end

program saveappend
	/* this program appends the data in memory, or a subset 
	   of that data, to a stata file on disk. */
	syntax using/ [if] [in] [, keep(varlist) sort(varlist)]

	marksample touse 
	preserve

	keep if `touse'

	if "`keep'" != "" {
		keep `keep' `touse'
	}

	append using `using'

	if "`sort'" != "" {
		sort `sort'
	}

	drop `touse'
	save `using', replace

	restore
end

program touch
	syntax [anything], [var(varlist)] [replace] 

	* remove quotes from filename, if present
	local file = `"`=subinstr(`"`anything'"', `"""', "", .)'"'

	* test fatal conditions
	cap assert "`file'" != "" 
	if _rc {
		di as err "must specify valid filename."
		error 100
	}

	preserve 

	if "`var'" != "" {
		keep `var'
		drop if _n > 0
	}
	else {
		drop _all
		g var = 1
		drop var
	}
	* save 
	save "`file'", emptyok `replace'

	restore

end
