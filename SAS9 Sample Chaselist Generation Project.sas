/*
	Project Title:				ACA Chart Project Target List CY2023
	Requesting Department:		Internal
	Requestor:					XXXXXXXXXX
	Origination Date:			12/5/2023
	Requested Completion Date:	12/11/2023
	Date received:				12/5/2023
	Assigned Priority:			High
	Assigned Delivery Date:		12/11/2023
	RDA_Project_number:			XXXXXXXXXX
	Assigned Analyst:			Meagan Windler	
	Assigned Days:				2
	Assigned Completion Date:	12/11/2023
*/

/*******************************************************************/
/*	Setup */
/*******************************************************************/
%Let rundate= %sysfunc(today(), YYMMDDN8.); *Date for file name;
%Let RDA=XXXXXXXXXX;
%Let Root=\\XXXXXXXXXX;
%Let Analyst=MW;
%Let Outpath=&Root\XXXXXXXXXX\ ACA Chart Project Target List CY2023\Output;
%Let reportdate = %sysfunc(today(), date9.);

/* Current time in HHMMSS format, removing colons */
%let timepart = %sysfunc(putn(%sysfunc(time()), time8.));
%let cleantimepart = %sysfunc(translate(&timepart, , :));

/* Concatenate the date and cleaned time parts for the timestamp */
%let timestamp = &rundate.%sysfunc(compress(&timepart,":"));

%put &timestamp;

 
/*******************************************************************/
/*	Import files from Change Healthcare */
/*******************************************************************/

*Import Chase List raw text file from Chase List Creator portal on 12/6/2023;
PROC IMPORT DATAFILE="&Root\XXXXXXXXXX\XXXXXXXXXX ACA Chart Project Target List CY2023\Data\1260-CHART_UI_OPTIMIZED-2023120615274085.txt"
    OUT=work.chaselistraw
    DBMS=DLM
    REPLACE;
    DELIMITER='|'; /* Set the delimiter as pipe */
    GETNAMES=YES; /* The first row contains variable names */
    GUESSINGROWS=32767; /* Increase the number of rows SAS scans to determine variable lengths */
RUN;


*Import All Members file with score and PCP infofrom Risk View Commercial;
PROC IMPORT OUT= work.memberlist
    DATAFILE= "&Root\XXXXXXXXXX\XXXXXXXXXX ACA Chart Project Target List CY2023\Data\members_20231206100007.xlsx"
    DBMS=EXCEL
    REPLACE;
    SHEET="Sheet0"; 
    GETNAMES=YES; /* The first row contains variable names */
    MIXED=NO; 
RUN;

*Add member list score and PCP information to chase list;
PROC SQL;
    CREATE TABLE chaselist2 AS
    SELECT DISTINCT a.*, 
           b.current_score,
           b.probable_score,
           b.max_potential_score,
           b.Diff_Probable___Current,
           b.Diff_Potential___Current,
           b.pcp_provider_Number,
           b.pcp_first_name,
           b.pcp_last_name
    FROM chaselistraw AS a
    INNER JOIN memberlist AS b ON a.member_Number = b.member_Number;
QUIT;

*Add strtdate column & Change PCP_Provider_Number to Aff_ to add Amisys IRS info *;
Data chaselist3;
	Set chaselist2;
	strtdate = today();
	format strtdate MMDDYY10.;
	AFF_ = PCP_Provider_Number; Run;

/*******************************************************************/
/*	Add IRS info from Amisys */
/*******************************************************************/

*Use attachaffinfo macro to add IRS_ info to chaselist3 table;
%attachaffinfo(chaselist3,irs_);

*Add IRSname info using IRSname format;
Data chaselist3;
	Set CHASELIST3_WITHINFO;
	IRS_Name= put(IRS_,$irsname.); Run;

*Drop empty fields and reorder;
Data chaselist_aca_2023;
	Set CHASELIST3_WITHINFO (Drop=LOB_Member_ID Member_CMS_County_Code Member_County Member_Population_Group Provider_Email cnt hit aff); Run;
	
*Save a copy of the final working chase list to outpath folder;
Libname outpath "&Outpath";

Data outpath.chaselist_aca_2023_&rundate;
    Set chaselist_aca_2023; Run;



/*******************************************************************/
/*	01/25/2024 Updates to final list 
	Include CCOK Flag in optional fields*/
/*******************************************************************/

*Import Chase List .txt file that was converted into .xlsx file from Chase List Creator portal on 01/25/24;
/* Import the Excel file */
PROC IMPORT DATAFILE="&Root\HDA\RDA\mwindler\RDA20231205006 ACA Chart Project Target List CY2023\Data\1260-CHART_OPTIMIZED_STANDARD-2024012519520012v2.xlsx"
    OUT=work.chaselistraw3 /* Specify the output SAS dataset name */
    DBMS=XLSX REPLACE; /* Specify the DBMS as XLSX for Excel files */

    /* Specify the sheet name or number from the Excel file */
    SHEET="1260-CHART_OPTIMIZED_STANDARD-2"; /* Replace with your sheet name or number */

    /* Specify options for the Excel file */
    GETNAMES=YES; /* The first row contains variable names */

    /* Specify the format and length for Provider_Number as character */
    INFORMAT Provider_Number $CHAR16.;
RUN;


*read in final list from Angela;
libname final '\\tXXXXXXXXXX\XXXXXXXXXX ACA Chart Project Target List CY2023\Output';

data final0;
	set final.finallist (Drop=Provider_Number); run;

*add in chase weight, CMS specialty code, and POS code from raw chaselist;
proc sql;
    create table final1 as
    select 	a.*, 
			b.chase_weight, 
			b.Provider_cms_specialty_code,
			b.Provider_First_Name,
			b.Provider_Last_Name,
			b.Provider_Number,
			b.pos as POS_CODE
    from final0 as a
    inner join chaselistraw3 as b
    on a.chart_id = b.chart_id;
quit;

data final2;
	Set final1 (Drop=POS); run;

*adding in project name & renaming columns;
data final3;
	set final2 (rename=(
		member_number=MEMBER
		Provider_Number=PROVIDER
		chase_weight=CHASE_WEIGHT
		provider_group_number=PROVIDER_GROUP
		Provider_First_Name=PROVIDER_FIRST_NAME
		Provider_Last_Name=PROVIDER_LAST_NAME
		Provider_cms_specialty_code=CMS_SPECIALTY_CODE
		chart_rank=CHASE_LIST_RANK
		provider_address_1=CHART_ADDRESS1
		provider_address_2=CHART_ADDRESS2
		provider_city=CHART_CITY
		provider_state=CHART_STATE
		provider_zip=CHART_ZIP
		provider_phone=PROVIDER_PHONE
		provider_fax=PROVIDER_FAX
		ccokflag=CCOK_FLAG
		POS_CODE=POS
));
	PROJECT_NAME= 'XXXXXXXXXX';
	CHART_IMAGE_NAME='';
	PROVIDER_EMAIL='';
	SPECIAL_HANDLING_CATEGORY='';
	SPECIAL_HANDLING_COMMENT='';
	CONTACT_NAME='';
	CONTACT_PHONE='';
	CONTACT_EXT='';
	CONTACT_FAX=''; 
	USER_FIELD_3='';

	If CCOK_FLAG = 0 then CHART_CHASE_METHOD = 'XXXXXXXXXX';
	else CHART_CHASE_METHOD = 'XXXXXXXXXX';

	If CCOK_FLAG = 0 then IS_ABSTRACT = 'N';
	else IS_ABSTRACT = 'Y';
	run;

data final4_&timestamp;
	retain PROJECT_NAME MEMBER PROVIDER IS_ABSTRACT CHART_IMAGE_NAME
				CHASE_WEIGHT PROVIDER_GROUP CHASE_LIST_RANK CCOK_FLAG CHART_CHASE_METHOD
				USER_FIELD_3 PROVIDER_FIRST_NAME PROVIDER_LAST_NAME CMS_SPECIALTY_CODE
				CHART_ADDRESS1 CHART_ADDRESS2 CHART_CITY CHART_STATE CHART_ZIP
				PROVIDER_PHONE PROVIDER_FAX PROVIDER_EMAIL POS SPECIAL_HANDLING_CATEGORY
				SPECIAL_HANDLING_COMMENT CONTACT_NAME CONTACT_PHONE CONTACT_EXT CONTACT_FAX;
	set final3 (Keep= PROJECT_NAME MEMBER PROVIDER IS_ABSTRACT CHART_IMAGE_NAME
				CHASE_WEIGHT PROVIDER_GROUP CHASE_LIST_RANK CCOK_FLAG CHART_CHASE_METHOD
				USER_FIELD_3 PROVIDER_FIRST_NAME PROVIDER_LAST_NAME CMS_SPECIALTY_CODE
				CHART_ADDRESS1 CHART_ADDRESS2 CHART_CITY CHART_STATE CHART_ZIP
				PROVIDER_PHONE PROVIDER_FAX PROVIDER_EMAIL POS SPECIAL_HANDLING_CATEGORY
				SPECIAL_HANDLING_COMMENT CONTACT_NAME CONTACT_PHONE CONTACT_EXT CONTACT_FAX);
	if member = 'XXXXXXXXXX' and chase_list_rank= 1904 then delete;
	if member = 'XXXXXXXXXX' and chase_list_rank= 3449 then delete; run;


*Save final SAS datasest to outpath;

%let Root=\\XXXXXXXXXX;
%let Outpath=&Root\XXXXXXXXXX\XXXXXXXXXX ACA Chart Project Target List CY2023\Output;
libname outlib "&Outpath";

/* Copy the dataset to the specified directory */
data outlib.FINAL4_20240131153531;
    set WORK.FINAL4_20240131153531;
run;

*export final file as a .csv;
%let Root=\\XXXXXXXXXX;
%let Outpath=&Root\XXXXXXXXXX\XXXXXXXXXX ACA Chart Project Target List CY2023\Output;
%let Filename=FINAL4_20240131153531.csv; /* Define the output filename */

/* Use a DATA step to write the dataset as a CSV file with | as the delimiter */
filename csvout "&Outpath.\&Filename.";

data _null_;
    set WORK.FINAL4_20240131153531;
    file csvout dlm='|' dsd lrecl=32767;
    put (_all_) (:);
run;

filename csvout clear;

*exporting as an Excel file;
proc export data=WORK.FINAL4_20240131153531
    outfile="&Outpath.\FINAL4_20240131153531.xlsx"
    dbms=xlsx
    replace;
run;


*Investigating duplicates;

data final0;
	set final.finallist; run;


/*proc freq data=final0;*/
/*  tables chart_ID*member_Number*Provider_NPI / noprint out=duplicate_records(keep=chart_ID member_Number Provider_NPI count);*/
/*run;*/
/**/
/*proc freq data=final0;*/
/*  tables member_Number*Provider_NPI / noprint out=duplicate_records2 (keep=chart_ID member_Number Provider_NPI count);*/
/*run;*/
/**/
/*proc print data=duplicate_records;*/
/*run;*/
/**/
/*proc print data= duplicate_records2;*/
/*run;*/

proc sort data=FINAL4_20240131153531;
	by member provider; run;


data duplicate_records3;
  set FINAL4_20240131153531;
  by member provider;
  if first.provider then count = 0;
  count + 1;
  if last.provider and count > 1 then output;
run;

proc sort data=duplicate_records3;
	by descending count;

proc print data=duplicate_records3;
run;

*identify duplicate record lines;
data duplicates_final;
	Set FINAL4_20240131111012;
	where member = 'XXXXXXXXXX' or member = 'XXXXXXXXXX'; run;

*exporting duplicates as an Excel file;
proc export data=WORK.duplicate_records3
    outfile="&Outpath.\duplicate_records3.xlsx"
    dbms=xlsx
    replace;
run;

proc export data=WORK.duplicate_records2
    outfile="&Outpath.\duplicate_records2.xlsx"
    dbms=xlsx
    replace;
run;



/*********************************************/
/**Checking final totals for Angela;*/
/*********************************************/

%let Root=\\XXXXXXXXXX;
%let Outpath=&Root\XXXXXXXXXX\XXXXXXXXXX ACA Chart Project Target List CY2023\Output;
libname outlib "&Outpath";

/* Copy the dataset to the specified directory */
data work.final4_20240131153531;
    set outlib.final4_20240131153531;
run;

/* Creating a dataset with unique members- Count should be 3860; Check shows 3862*/
proc sort data=work.final4_20240131153531 out=unique_members nodupkey;
   by MEMBER;
run;
/* Count unique members - Count should be 3860*/
proc sql;
   select count(*) as UniqueMemberCount from unique_members;
quit;

/* Creating a dataset with unique providers - Count should be 2636; check shows 2637*/
proc sort data=work.final4_20240131153531 out=unique_providers nodupkey;
   by PROVIDER;
run;
/* Count unique providers - Count should be 2636*/
proc sql;
   select count(*) as UniqueProviderCount from unique_providers;
quit;


/* Creating a dataset with unique addresses - Count should be 378; check shows 868*/
proc sort data=work.final4_20240131153531 out=unique_addresses nodupkey;
   by CHART_ADDRESS1 CHART_ADDRESS2 CHART_CITY CHART_STATE CHART_ZIP;
run;
/* Count unique addresses - Count should be 378 */
proc sql;
   select count(*) as UniqueAddressCount from unique_addresses;
quit;

*address count is off, trying something different;
/* Remove leading/trailing whitespace and standardize the case */
data work.cleaned_addresses;
    set work.final4_20240131153531;
    length Cleaned_Address $200.; /* Adjust the length accordingly */
    Cleaned_Address = catx(' ', 
        lowcase(strip(CHART_ADDRESS1)), 
        lowcase(strip(CHART_ADDRESS2)), 
        lowcase(strip(CHART_CITY)), 
        lowcase(strip(CHART_STATE)), 
        strip(CHART_ZIP)
    );
    /* Handle missing values as blanks to ensure they don't create artificial uniqueness */
    if Cleaned_Address = ' ' then Cleaned_Address = 'Missing';
run;

/* Deduplicate based on the cleaned and combined address */
proc sort data=work.cleaned_addresses out=unique_addresses nodupkey;
    by Cleaned_Address;
run;

/* Verify the count, count should be 378; check shows 867 */
proc sql;
    select count(*) as UniqueAddressCount
    from unique_addresses;
quit;


proc sql;
   /* Unique Member/Provider Count (combining MEMBER and PROVIDER)- Count should be 5635, check shows 5637*/
   select count(distinct catx(' ', MEMBER, PROVIDER)) as UniqueMemberProviderCount
   from work.final4_20240131153531;

   /* Unique Address/Provider Phone Count (combining CHART_ADDRESS1 and PROVIDER_PHONE)- Count should be 407, check shows 882*/
   select count(distinct catx(' ', CHART_ADDRESS1, PROVIDER_PHONE)) as UniqueAddressProviderPhoneCount
   from work.final4_20240131153531;

   /* Total Active Chases in Sample (total rows in the dataset)- Count should be 5635, check shows 5637 */
   select count(*) as TotalActiveChasesInSample
   from work.final4_20240131153531;

   /* Abs Only Chase Count (rows where IS_ABSTRACT = 'Y')- Count should be 2634, check shows 2635 */
   select count(*) as AbsOnlyChaseCountY
   from work.final4_20240131153531
   where IS_ABSTRACT = 'Y';

   /* Missing Provider First Name (count of missing or blank PROVIDER_FIRST_NAME) - Count should be 1046, check shows 1046*/
   select count(*) as MissingProviderFirstName
   from work.final4_20240131153531
   where PROVIDER_FIRST_NAME is missing or PROVIDER_FIRST_NAME = ' ';

   /* Missing Provider Group (count of missing or blank PROVIDER_GROUP) - Count should be 956, check shows 956 */
   select count(*) as MissingProviderGroup
   from work.final4_20240131153531
   where PROVIDER_GROUP is missing or PROVIDER_GROUP = ' ';

   
   /* Missing Provider Fax (count of missing or blank PROVIDER_Fax) - Count should be 8, check shows 10 */
   select count(*) as MissingProviderFax
   from work.final4_20240131153531
   where PROVIDER_FAX is missing;
quit;

*adding NPI to final chaselist;

PROC IMPORT DATAFILE="&Root\XXXXXXXXXX\XXXXXXXXXX ACA Chart Project Target List CY2023\Data\1260-CHART_OPTIMIZED_STANDARD-2024012519520012v2.xlsx"
    OUT=work.chaselistraw3 /* Specify the output SAS dataset name */
    DBMS=XLSX REPLACE; /* Specify the DBMS as XLSX for Excel files */

    /* Specify the sheet name or number from the Excel file */
    SHEET="1260-CHART_OPTIMIZED_STANDARD-2"; /* Replace with your sheet name or number */

    /* Specify options for the Excel file */
    GETNAMES=YES; /* The first row contains variable names */

    /* Specify the format and length for Provider_Number as character */
    INFORMAT Provider_Number $CHAR16.;
RUN;


*read in final list from Angela;
libname final '\\XXXXXXXXXX\XXXXXXXXXX ACA Chart Project Target List CY2023\Output';

data final0;
	set final.finallist (Drop=Provider_Number); run;


   /* Missing Provider_NPI (count of missing or blank PROVIDER_NPI) - Count should be 864,check shows 951 */
proc sql;
    create table work.final6 as
    select a.*, 
           b.Provider_NPI
    from work.final0 as a
    inner join work.chaselistraw3 as b
    on a.chart_id = b.chart_id
    where b.Provider_NPI is missing;
quit;

proc sql;
   /* Missing Provider_NPI (count of missing or blank PROVIDER_NPI) - Count should be 864, check shows 951*/
   select count(*) as MissingProviderNPI
   from work.final6
   where Provider_NPI is missing; quit;






   
/*******************************************************************/
/*	02/12/2024 Splitting the list & adding in crosswalked fields*/
/*******************************************************************/

%Let rundate= %sysfunc(today(), YYMMDDN8.); *Date for file name;
%Let RDA=XXXXXXXXXX;
%Let Root=\\XXXXXXXXXX;
%Let Analyst=MW;
%Let Outpath=&Root\XXXXXXXXXX\XXXXXXXXXX ACA Chart Project Target List CY2023\Output;
%Let reportdate = %sysfunc(today(), date9.);

/* Current time in HHMMSS format, removing colons */
%let timepart = %sysfunc(putn(%sysfunc(time()), time8.));
%let cleantimepart = %sysfunc(translate(&timepart, , :));

/* Concatenate the date and cleaned time parts for the timestamp */
%let timestamp = &rundate.%sysfunc(compress(&timepart,":"));

%put &timestamp;

*Importing original raw chaselist, our final list, and our final chaselist we submitted to Change on 1/31/24;

PROC IMPORT DATAFILE="&Root\HDA\RDA\mwindler\RDA20231205006 ACA Chart Project Target List CY2023\Data\1260-CHART_OPTIMIZED_STANDARD-2024012519520012v2.xlsx"
    OUT=work.chaselistraw3 /* Specify the output SAS dataset name */
    DBMS=XLSX REPLACE; /* Specify the DBMS as XLSX for Excel files */

    /* Specify the sheet name or number from the Excel file */
    SHEET="1260-CHART_OPTIMIZED_STANDARD-2"; /* Replace with your sheet name or number */

    /* Specify options for the Excel file */
    GETNAMES=YES; /* The first row contains variable names */

    /* Specify the format and length for Provider_Number as character */
    INFORMAT Provider_Number $CHAR16.;
RUN;


*read in final list from Angela that includes all data fields;
libname final '\\XXXXXXXXXX\XXXXXXXXXX ACA Chart Project Target List CY2023\Output';

data orig_final_list;
	set final.finallist (Drop=Provider_Number); run;


*creating a duplicate final_list that includes chart_ID for referencing;

proc sql;
    create table final1 as
    select 	a.*, 
			b.chase_weight, 
			b.Provider_cms_specialty_code,
			b.Provider_First_Name,
			b.Provider_Last_Name,
			b.Provider_Number,
			b.pos as POS_CODE
    from orig_final_list as a
    inner join chaselistraw3 as b
    on a.chart_id = b.chart_id;
quit;

data final2;
	Set final1 (Drop=POS); run;

*adding in project name & renaming columns;
data final3;
	set final2 (rename=(
		member_number=MEMBER
		Provider_Number=PROVIDER
		chase_weight=CHASE_WEIGHT
		provider_group_number=PROVIDER_GROUP
		Provider_First_Name=PROVIDER_FIRST_NAME
		Provider_Last_Name=PROVIDER_LAST_NAME
		Provider_cms_specialty_code=CMS_SPECIALTY_CODE
		chart_rank=CHASE_LIST_RANK
		provider_address_1=CHART_ADDRESS1
		provider_address_2=CHART_ADDRESS2
		provider_city=CHART_CITY
		provider_state=CHART_STATE
		provider_zip=CHART_ZIP
		provider_phone=PROVIDER_PHONE
		provider_fax=PROVIDER_FAX
		ccokflag=CCOK_FLAG
		POS_CODE=POS
));
	PROJECT_NAME= 'CMCROKCOMPI23';
	CHART_IMAGE_NAME='';
	PROVIDER_EMAIL='';
	SPECIAL_HANDLING_CATEGORY='';
	SPECIAL_HANDLING_COMMENT='';
	CONTACT_NAME='';
	CONTACT_PHONE='';
	CONTACT_EXT='';
	CONTACT_FAX=''; 
	USER_FIELD_3='';

	If CCOK_FLAG = 0 then CHART_CHASE_METHOD = 'Full Service';
	else CHART_CHASE_METHOD = 'ABS';

	If CCOK_FLAG = 0 then IS_ABSTRACT = 'N';
	else IS_ABSTRACT = 'Y';
	run;

data FINAL4_20240212152901;
	retain CHART_ID PROJECT_NAME MEMBER PROVIDER IS_ABSTRACT CHART_IMAGE_NAME
				CHASE_WEIGHT PROVIDER_GROUP CHASE_LIST_RANK CCOK_FLAG CHART_CHASE_METHOD
				USER_FIELD_3 PROVIDER_FIRST_NAME PROVIDER_LAST_NAME CMS_SPECIALTY_CODE
				CHART_ADDRESS1 CHART_ADDRESS2 CHART_CITY CHART_STATE CHART_ZIP
				PROVIDER_PHONE PROVIDER_FAX PROVIDER_EMAIL POS SPECIAL_HANDLING_CATEGORY
				SPECIAL_HANDLING_COMMENT CONTACT_NAME CONTACT_PHONE CONTACT_EXT CONTACT_FAX 
				Member_Plan_ID Member_HIOS_Product Member_DOB Member_Gender Member_Population
				Member_Rating_Area Member_Eligible_Months Member_Zip_Code Member_Score  ;

	set final3 (Keep= CHART_ID PROJECT_NAME MEMBER PROVIDER IS_ABSTRACT CHART_IMAGE_NAME
				CHASE_WEIGHT PROVIDER_GROUP CHASE_LIST_RANK CCOK_FLAG CHART_CHASE_METHOD
				USER_FIELD_3 PROVIDER_FIRST_NAME PROVIDER_LAST_NAME CMS_SPECIALTY_CODE
				CHART_ADDRESS1 CHART_ADDRESS2 CHART_CITY CHART_STATE CHART_ZIP
				PROVIDER_PHONE PROVIDER_FAX PROVIDER_EMAIL POS SPECIAL_HANDLING_CATEGORY
				SPECIAL_HANDLING_COMMENT CONTACT_NAME CONTACT_PHONE CONTACT_EXT CONTACT_FAX 
				Member_Plan_ID Member_HIOS_Product Member_DOB Member_Gender Member_Population
				Member_Rating_Area Member_Eligible_Months Member_Zip_Code Member_Score); 

	if member = 'XXXXXXXXXX' and chase_list_rank= 1904 then delete;
	if member = 'XXXXXXXXXX' and chase_list_rank= 3449 then delete; run;


	*read in final chart chase list submitted to Change;
data final_list_submitted;
	set final.final4_20240131153531; Run; 


*import the Client Chase Status report for project CMCROKCOMPI23 from XXXXXXXXXX on 2/12/24;
PROC IMPORT DATAFILE="&outpath\XXXXXXXXXX Chase Status Report 2122024.xlsx"
     OUT=work.chase_status_report
     DBMS=xlsx REPLACE;
   SHEET="Sheet1"; /* Replace Sheet1 with the actual name of the sheet you want to import */
   GETNAMES=YES; /* This option tells SAS to use the first row of the Excel sheet as variable names */
RUN;

*Adding variables from chaselist raw to the FINAL4_20240212152901;

proc sql;
    create table chaselist_combined as
    select a.*, b.Risk_View_Member_ID, b.LOB_Member_ID, b.Member_First_Name, b.Member_Last_Name,
            b.Member_Metal_Level, b.Member_PSI, b.Risk_View_Provider_ID, b.Provider_NPI,
            b.Provider_Tax_ID, b.Provider_CMS_Specialty_Desc, b.Chart_Type, b.Is_PCP, b.Provider_Group_Name
    from work.FINAL4_20240212152901 as a
    left join Chaselistraw3 as b
    on a.chart_ID = b.chart_ID;
quit;

*adding in chart_ID_AP from the chase status report from alert portal, joining on combos
of member_ID and provider NPI;

proc sql;
    create table chaselist_combined1 as
    select a.*, b.chart_ID as Chart_ID_AP
    from work.chaselist_combined as a
    left join Chase_Status_Report as b
    on a.member = b.Client_Member_ID and a.Provider = b.client_provider_ID;
quit;

*adding membet social security numbers to combined chaselist;
proc sql;
	create table chaselist_combined2 as
	select a.*, b.SSN as Member_SSN
	from chaselist_combined1 as a
	left join memb.memb as b
	on a.member = b.member_; run;

/**splitting chaselist into just ABS chart chases, where CCOK_Flag = 1*/
/*	2365 observations;*/

data chaselist_ABS;
	set chaselist_combined2;
	where CCOK_FLAG=1; run;

*split list into ones for Christy(560 obs), Saint Fraincis (1805), and Ciox (283 obs - all Full Service);

proc freq data=chaselist_ABS;
	tables Provider_Tax_ID ; run;

data chaselist_Christy;
	set chaselist_ABS;
	where provider_tax_id in ('XXXXXXXXXX' 'XXXXXXXXXX' 'XXXXXXXXXX'); run;

data chaselist_Saint_Francis;
	set chaselist_ABS;
	where provider_tax_id in ('XXXXXXXXXX' 'XXXXXXXXXX' 'XXXXXXXXXX'); run;


*0 observations are in the chaselist_ABS for Ciox tax IDs), checking in chaselist_combined;

proc sql;
    create table chaselist_XXXXXXXXXX as
    select a.*, b.ccokflag2
    from chaselist_ABS as a
    left join orig_final_list as b
    on a.chart_ID = b.chart_ID
    where b.ccokflag2 = 1;
quit;


*creating a review-specific list for Christy then exporting to excel;

data CHASELIST_XXXXXXXXXX;
	Format MEMBER PROVIDER_FIRST_NAME PROVIDER_LAST_NAME MEMBER_DOB MEMBER_GENDER 
							MEMBER_FIRST_NAME MEMBER_LAST_NAME CHART_TYPE CHART_ID_AP PROVIDER_GROUP_NAME CAPTURED NOTES;
	Set CHASELIST_CHRISTY (Keep=MEMBER PROVIDER_FIRST_NAME PROVIDER_LAST_NAME MEMBER_DOB MEMBER_GENDER 
							MEMBER_FIRST_NAME MEMBER_LAST_NAME CHART_TYPE CHART_ID_AP PROVIDER_GROUP_NAME);
	CAPTURED = '';
	NOTES = ''; 
run;

*creating a review-specific list of fields for Saint Francis then exporting to Excel;

data CHASELIST_XXXXXXXXXX;
	Format CHART_ID CHART_ID_AP MEMBER MRN MEMBER_FIRST_NAME MEMBER_LAST_NAME MEMBER_DOB MEMBER_GENDER
			MEMBER_SSN;
	Set chaselist_Saint_Francis (Keep=CHART_ID CHART_ID_AP MEMBER MEMBER_FIRST_NAME MEMBER_LAST_NAME 
								MEMBER_DOB MEMBER_GENDER MEMBER_SSN);
	MRN= ''; Run;

