
/*soh***************************************************************************************

--------------------------------------------------------------------------------
CHANGE HISTORY:

**eoh***************************************************************************************/

/*******************************************************************************************/
/*                                                                                         */                                                                        
/* 1.  Set operational options                                                             */                                                                      
/*                                                                                         */
/*******************************************************************************************/

options source source2 mlogic mprint symbolgen; 

%let usr = %lowcase(&sysuserid);
%include "/home/&sysuserid/Pswd/MyEncryptedPwd.sas" / nosource2;
     
libname projlib '/YOURLOCATIONHERE/ProjectX/sasout';

filename inclsas  '/YOURLOCATIONHERE/CCI';

libname RWE_TF YOURINCOMINGDATAHERE;

libname RWE_WRK YOURTEMPLOCATIONHERE;

/*******************************************************************************************/
/*                                                                                         */                                                                        
/* 2.  Set macro variables                                                                 */                                                                      
/*                                                                                         */
/*******************************************************************************************/

* Truven Tables;
%let paytype=1, 2; /* 1 = Commercial Claims, 2 = Medicare, 3 = Medicaid */
%let recsrc=2, 4, 6; /* 2=Facility Header 4=Inpatient Service, 6=Outpatient Service */
%let dataver=AFS_DLVRY_PERIOD='A' and year in(2015,2016,2017,2018) ;

* Project Cohort;
%let inds = projlib.ProjectX; /* cohort enrolids with index */
%let indexvar = index; /* index variable on inds data set */

* CCI related;
%let cci_codein = /YOURLOCATIONHERE/CCI/NONTA_STANDARD_DX_Charlson_V3_Wght.xlsx;
                  /* CCI spreadsheet */
%let cond_count = 1; /* 1=count only most severe (diabetes, liver, tumor) 0=count all */
%let premths = 6; /* months pre index for claim extract */
%let postmths = 0; /* months post index for claim extract */
%let weightvar = weight; /* weight variable on cci_codein data set */
%let primary = 1; /* 1=use primary (pdx, pproc), 0=do not use primary */
%let delflag = 1; /* 1=use following delcond, 0=no delete condition */
%let delcond = if condition_Nbr=14 then delete /* specify condition or list of conditions to remove from cci calculation */
%let outds = projlib.YOUROUTPUT; /* output sas data set */

/*******************************************************************************************/
/*                                                                                         */                                                                        
/* 3.  Call CCI module                                                                     */                                                                      
/*                                                                                         */
/*******************************************************************************************/

%include inclsas (CCI.sas);

 proc print data = &outds (obs=10);
   title "&outds sample";
 run;

 proc datasets library = work kill;
 run;
quit;
run;
