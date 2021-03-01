
/*-------------------------------------------------------------------------------------------------------------------------------   
DOCUMENTATION AND REVISION HISTORY SECTION (required):

       Author &
Ver# Validator               Code History Description
---- ----------------     -----------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------*/  


/*******************************************************************************************/
/* CCI.sas                                                                                 */                                                                        
/* INCLUDE Module to calculate Truven CCI                                                  */  
/* Notes:                                                                                  */
/* . Your program will set the parameters/macro variables, see example in pgm/My_CCI_pgm   */
/* . Call this program from your program                                                   */
/* . Must have CCI spreadsheet in folder cci_codes                                         */
/* . Output is SAS file with variables enrolid, w1-w17, weight_tot, &indexvar              */ 
/* . Typically runs under 3 minutes                                                        */                                                                   
/*                                                                                         */
/*******************************************************************************************/

/*******************************************************************************************/
/*                                                                                         */                                                                        
/* CCI-1.  Input CCI control data set                                                      */                                                                      
/*                                                                                         */
/*******************************************************************************************/

 proc import datafile = "&cci_codein"
     out = cci_weights
     dbms=xlsx replace;
     sheet="Weights";
     getnames=yes;
 run;

 data cci_weights;
   set cci_weights;
   cci_wght = &weightvar;
   if condition ^= ' ' then output;
   keep condition condition_Nbr cci_wght;
 run;

 proc sort data = cci_weights;
   by condition;
 run;

 proc import datafile = "&cci_codein"
     out = cci_codes (rename=('CODE TYPE'n=CODE_TYPE))
     dbms=xlsx replace;
     sheet="ICD Codes";
     getnames=yes;
 run;

 data cci_codes;
   set cci_codes;
   length cci_code $21;
   cci_code = upcase(left(code)); 
   if cci_code ^= ' ' then output;
   keep cci_code code_type condition;
 run;

 proc sort data = cci_codes nodupkey;
    by condition code_type cci_code;
 run;

 data cci_codes issue;
   merge cci_codes (in=cod)
         cci_weights (in=wgh);
   by condition;
   if cod & wgh then output cci_codes;
   else if cod & ^wgh then output issue;
   keep cci_code code_type condition condition_Nbr cci_wght;
 run;

 proc print data = issue;
   title 'No Weight Associated with these codes';
 run;

/*******************************************************************************************/
/*                                                                                         */
/* CCI-2.  Enrolids and date range for claims extract                                      */
/*                                                                                         */
/*******************************************************************************************/

 data pat_in;
   set &inds;
   if &premths = 0 then cci_start = &indexvar;
   else cci_start = intnx('month',&indexvar,-&premths,'beginning');
   if &postmths = 0 then cci_end = &indexvar;
   else cci_end = intnx('month',&indexvar,&postmths,'ending');
   format cci_start cci_end yymmdd10.;
 run;

/*******************************************************************************************/
/*                                                                                         */
/* CCI-3.  Extract claims                                                                  */
/*                                                                                         */
/*******************************************************************************************/

 %macro claims;

 * remove cci conditions if specified in parameter ;
  %if &delflag = 1 %then %do;
      data cci_codes;
        set cci_codes;
        &delcond;  
       run;
 %end;

 proc sql;
   create table RWE_WRK.cci_codes as
  	  select condition, code_type, cci_code, condition_Nbr, cci_wght from cci_codes;

   create table RWE_WRK.pat_in as
          select enrolid, cci_start, cci_end from pat_in;

   create table RWE_WRK.cci_dx as 
	select distinct a.enrolid, c.condition_Nbr, c.cci_wght, c.condition 
	from RWE_TF.AFS_TRVN_MKTSCN_CLM_DIAG a, RWE_WRK.pat_in b, RWE_WRK.cci_codes c
	where a.enrolid=b.enrolid and AFS_DLVRY_STAGE = 'O' and (&dataver.) and 
              AFS_CLM_REC_SRC in (&recsrc.) and AFS_CLM_REC_PAY_TYP in (&paytype.) and
	      svcdate > cci_start and svcdate < cci_end and
	      ((a.svcdate<'01OCT2015'd and upper(a.dx)=c.cci_code and c.code_type='ICD-9-CM DX') or 
               (a.svcdate>='01OCT2015'd and upper(a.dx)=c.cci_code and c.code_type='ICD-10-CM DX'));

   create table RWE_WRK.cci_proc as 
	select distinct a.enrolid, c.condition_Nbr, c.cci_wght, c.condition  
	from RWE_TF.AFS_TRVN_MKTSCN_CLM_PROC a, RWE_WRK.pat_in b, RWE_WRK.cci_codes c
	where a.enrolid=b.enrolid and AFS_DLVRY_STAGE = 'O' and (&dataver.) and 
              AFS_CLM_REC_SRC in (&recsrc.) and AFS_CLM_REC_PAY_TYP in (&paytype.) and
	      svcdate > cci_start and svcdate < cci_end and
	      ((a.svcdate<'01OCT2015'd and upper(a.PROC)=c.cci_code and PROCTYP='*' and c.code_type='ICD-9-PCS') or
               (a.svcdate>='01OCT2015'd and upper(a.PROC)=c.cci_code and PROCTYP='0' and c.code_type='ICD-10-PCS'));

  %if &primary = 1 %then %do;

   create table RWE_WRK.cci_pdx as 
	select distinct a.enrolid, c.condition_Nbr, c.cci_wght, c.condition  
	from RWE_TF.AFS_TRVN_MKTSCN_CLM_DIAG a, RWE_WRK.pat_in b, RWE_WRK.cci_codes c
	where a.enrolid=b.enrolid and AFS_DLVRY_STAGE = 'O' and (&dataver.) and 
              AFS_CLM_REC_SRC in (&recsrc.) and AFS_CLM_REC_PAY_TYP in (&paytype.) and
	      svcdate > cci_start and svcdate < cci_end and
	      ((a.svcdate<'01OCT2015'd and upper(a.pdx)=c.cci_code and c.code_type='ICD-9-CM DX') or 
               (a.svcdate>='01OCT2015'd and upper(a.pdx)=c.cci_code and c.code_type='ICD-10-CM DX'));

   create table RWE_WRK.cci_pproc as 
	select distinct a.enrolid, c.condition_Nbr, c.cci_wght, c.condition 
	from RWE_TF.AFS_TRVN_MKTSCN_CLM_PROC a, RWE_WRK.pat_in b, RWE_WRK.cci_codes c
	where a.enrolid=b.enrolid and AFS_DLVRY_STAGE = 'O' and (&dataver.) and 
              AFS_CLM_REC_SRC in (&recsrc.) and AFS_CLM_REC_PAY_TYP in (&paytype.) and
	      svcdate > cci_start and svcdate < cci_end and
	      ((a.svcdate<'01OCT2015'd and upper(a.pPROC)=c.cci_code and PROCTYP='*' and c.code_type='ICD-9-PCS') or
               (a.svcdate>='01OCT2015'd and upper(a.pPROC)=c.cci_code and PROCTYP='0' and c.code_type='ICD-10-PCS'));

   create table cci_claims as 
	select * from RWE_WRK.cci_dx
	union
	select * from RWE_WRK.cci_pdx
	union
        select * from RWE_WRK.cci_proc
        union
        select * from RWE_WRK.cci_pproc
	order by enrolid;

 %end;
 
 %else %do;

   create table cci_claims as 
	select * from RWE_WRK.cci_dx
	union
	select * from RWE_WRK.cci_proc
	order by enrolid;

 %end;

   create table condition_Nbr as
      select distinct enrolid, condition_Nbr, cci_wght, condition 
      from cci_claims;

 quit;

 %mend claims;

 %claims;

/*******************************************************************************************/
/*                                                                                         */
/* CCI-4. Sum weights by enrolid with conditions:                                          */
/* • a weight of 2 is added for ‘any malignancy’ as long as ‘metastatic tumor’ (which has  */
/*   a weight of 6) does not exist/is false                                                */
/* • a weight of 1 is added for ‘diabetes without complications’ as long as ‘diabetes with */
/*   complications’ (which has a weight of 2) does not exist/is false                      */
/* • a weight of 1 is added for ‘mild liver disease’ as long as ‘moderate or severe liver  */
/*   disease’ (which has a weight of 3) does not exist/is false                            */
/*                                                                                         */
/*******************************************************************************************/

%macro ccisum;

 %if &cond_count = 1 %then %do;

 data cond_check;
   set condition_Nbr;
   by enrolid;
   retain tumor_flag diab_flag liver_flag;
   if first.enrolid then do;
      tumor_flag = 0;
      diab_flag = 0;
      liver_flag = 0;
   end;
   if condition_Nbr = 16 then tumor_flag = 1;
   if condition_Nbr = 11 then diab_flag = 1;
   if condition_Nbr = 15 then liver_flag = 1;
   if last.enrolid;
   keep enrolid tumor_flag diab_flag liver_flag;
 run;

 data condition_Nbr;
   merge condition_Nbr cond_check;
   by enrolid;
   if tumor_flag = 1 and condition_Nbr = 14 then delete;
   if diab_flag = 1 and condition_Nbr = 10 then delete;
   if liver_flag = 1 and condition_Nbr = 9 then delete;
   keep enrolid condition_Nbr cci_wght condition tumor_flag diab_flag liver_flag;
 run;

 %end;

 %mend ccisum;

 %ccisum;

 data cci_sum;
   set condition_Nbr;
   by enrolid;
   if first.enrolid then weight_tot = 0;
   weight_tot + cci_wght;
   if last.enrolid;
   keep enrolid weight_tot;
 run;

/*******************************************************************************************/
/*                                                                                         */
/* CCI-5. Build CCI and save SAS data set                                                  */
/*                                                                                         */
/*******************************************************************************************/

 proc transpose data = condition_Nbr out = enr_wght (drop=_name_ _label_) prefix = w;
   by enrolid;
   id condition_Nbr;
   var cci_wght;
   idlabel condition;
 run;

 data &outds;
   retain enrolid w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12 w13 w14 w15 w16 w17 weight_tot &indexvar;
   merge enr_wght (in=wgh)
         cci_sum (in=tot)
         &inds (in=coh keep=enrolid &indexvar);
   by enrolid;
   if coh & ^wgh & ^tot then weight_tot = 0;
   array wght[*] $ 3. w1 - w17;
   do i=1 to dim(wght);
      if wght[i] = . then wght[i] = 0;  
   end;
   drop i;
 run;
 
/*******************************************************************************************/
/*                                                                                         */
/* CCI-6. Delete temporary tables                                                          */
/*                                                                                         */
/*******************************************************************************************/

 proc datasets library = work kill;
 run;
 quit;

 proc sql;
   connect to ODBC
    (dsn=Access_Redshift password="&rspw" user=&sysuserid);
      execute (drop table if exists RWE_STRADA_WRK.cci_codes) by odbc;
      execute (drop table if exists RWE_STRADA_WRK.pat_in) by odbc;
      execute (drop table if exists RWE_STRADA_WRK.cci_dx) by odbc;
      execute (drop table if exists RWE_STRADA_WRK.cci_proc) by odbc;
      execute (drop table if exists RWE_STRADA_WRK.cci_pdx) by odbc;
      execute (drop table if exists RWE_STRADA_WRK.cci_pproc) by odbc;
quit;

