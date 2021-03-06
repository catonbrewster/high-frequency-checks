*! version 1.0.0 Christopher Boyer 04may2016

program ipachecksummary, rclass
    /* Add a summary sheet to the output excel file detailing
       progress towards survey targets and the number of check 
       violations. */
  version 13

  #d ;
  syntax using/, 
    /* target number of surveys */ 
    TARGet(integer) 
    /* other options */ 
    [MODify REPlace]; 
  #d cr

  * test for fatal conditions
  if "`modify'" != "" & "`replace'" != "" {
    di as err "May specify either {op: modify} or {op: replace}, not both."
  }

  * get the current date
  local today = date(c(current_date), "DMY")
  local today_f : di %tdnn/dd/YY `today'
  
  * get total number of interviews
  local nmaster = _N  

  * confirm file exists
  cap confirm file "`using'"
  if _rc {
    * write the headers
    headers using "`using'"

    * set the first line
    local i = 2
    local nlast = 0
  }
  else {
    * if modify option was specified
    if "`modify'" != "" {
      preserve

      * read the existing summary sheet
      import excel using "`using'", sheet("0. summary") firstrow clear

      * get the number of lines 
      local nusing = _N

      /* Note: often users will run HFCs multiple times
         per day to debug errors or to update as additional 
         survey submissions arrive. However, allocating a 
         summary line for each of these runs is undesirable. 
         Therefore, if the last entry is for the same date, 
         we'll simply overwrite it. */
      if Date[`nusing'] == "`today_f'" {
        local i = `nusing' + 1
        if `nusing' > 1 {
          local nlast = CumulativeFrequency[`nusing' - 1]
        } 
        else {
          local nlast = 0
        }
      }
      else {
        local i = `nusing' + 2
        local nlast = CumulativeFrequency[`nusing']
      }

      restore

      * set the output
      putexcel set "`using'", sheet("0. summary") modify
    }

    if "`replace'" != "" {
      * write the headers
      headers using "`using'", replace

      * set the first line
      local i = 2
      local nlast = 0
    }
  }

  * calculate stats
  local freq = `nmaster' - `nlast'
  local ptarget : di %9.2f 100 * `freq' / `target'
  local cptarget : di %9.2f 100 * `nmaster' / `target'

  * output statistics
  putexcel ///
      A`i'=("`today_f'") ///
  	  B`i'=(`freq')    ///
      C`i'=(`nmaster') ///
      D`i'=(`ptarget') ///
      E`i'=(`cptarget') 

    return scalar i = `i'
end

program headers, rclass
    /* this program writes the column headers
       to the output worksheet. */

    syntax using/, [replace]

    * set the output sheet
    putexcel set "`using'", sheet("0. summary") `replace'

    * write the column headers
    putexcel A1=("Date") ///
      B1=("Frequency") ///
      C1=("Cumulative Frequency") ///
      D1=("Percent Target") ///
      E1=("Cumulative Percent Target") ///
      F1=("HFC 1") ///
      G1=("HFC 2") ///
      H1=("HFC 3") ///
      I1=("HFC 4") ///
      J1=("HFC 5") ///
      K1=("HFC 6") ///
      L1=("HFC 7") ///
      M1=("HFC 8") ///
      N1=("HFC 9") ///
      O1=("HFC 10") ///
      P1=("HFC 11") 
end
