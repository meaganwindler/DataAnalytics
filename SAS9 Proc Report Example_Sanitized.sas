/*	Project Title:				Proc Report Example
	Requesting Department:		Internal
	Requestor:					XXXXXXXXXX
	Origination Date:			9/19/2023
	Requested Completion Date:	9/29/2023
	Date received:				9/19/2023
	Assigned Priority:			High
	Assigned Delivery Date:		9/29/2023
	RDA_Project_number:			XXXXXXXXXX
	Assigned Analyst:			Meagan Windler	
	Assigned Days:				2
	Support Analyst: 				
	Perc_Support:				
	Assigned Completion Date:	9/29/2023

Remarks: 	All pharmacy fills during 1st quarter of 2023. Summary on one tab broken out by 
Company and network (Ascension St. John, Saint Francis, Other) and fill month. 
Claim Detail on another tab. Include Women's health. 	

For summary tab include – Month, Company Network, # of scripts, total days supply, 
Member Pay, CCOK Pay, and Total Allow

For detail tab include – Company, Network, claim number, member number, fill date, 
days supply, dispensed quantity, ndc,*/


/****************************************************************/
/***** Setup *****/
/****************************************************************/

/* Clearing Work Library */
Proc Datasets nolist nodetails lib=Work kill;
Quit;

%Let Root = XXXXXXXXXX;
%Let Outpath=&Root\\HDA\RDA\mwindler\Proc Report Example\Output;

%Let analyst=MW;
%Let rda=XXXXXXXXXX;
%Let RprtDate = %Sysfunc(PutN(%Sysfunc(Today()),yymmddn8)) ;
%Let RunDate = %Sysfunc(PutN(%Sysfunc(Today()),mmddyys10)) ;

%Let SASAutos  = &Root\HDA\Resources\SAS_Macros  ;
Options SASAutos = (SASAutos,"&SASAutos") ;
Options XSync NoXWait MAUTOSOURCE ;
Option FmtSearch = (Work Formats) ;

/*Timeframe for services*/
%Let period_start = '01JAN2023'd; 
%Let period_end = '31MAR2023'd;

/****************************************************************/
/***** Pharmacy Data Pull *****/
/****************************************************************/

*Establish variables for quicker data pulls;
%Let fill_vars= 
	buss_carr mbr_rgn rxclm rxclm_seq rev_paid_flg mbr_id date_fill 
	day_sup disp_quant ndc amt_mbr_pay amt_paid amt_tot;

%Let Network_SF='XXXXXXXXXX';
%Let Network_ASJ='XXXXXXXXXX','XXXXXXXXXX','XXXXXXXXXX';

*Data pull from CVSDATA.CVSRXDATA;
Data q1fills;
	Format buss_carr mbr_rgn rxclm rxclm_seq rev_paid_flg mbr_id 
	date_fill day_sup disp_quant ndc amt_mbr_pay amt_paid amt_tot;
	Set cvsdata.cvsrxdata (Keep=&fill_vars);
	Where &period_start <= date_fill <= &period_end; Run;

*Data pull from CVSDATA.CVSWH for women's health fills;

Data q1fills_wh;
	Format buss_carr mbr_rgn rxclm rxclm_seq rev_paid_flg mbr_id 
	date_fill day_sup disp_quant ndc amt_mbr_pay amt_paid amt_tot;
	Set cvsdata.cvswh (Keep=&fill_vars);
	Where &period_start <= date_fill <= &period_end; Run;

*Merge the two pharm pulls;
Data q1fills_merged;
	Set q1fills q1fills_wh; Run;

*Select only paid claims;
Proc Sort Data=q1fills_merged; 
	By rxclm Descending rxclm_seq Descending rev_paid_flg; Run;

Data paid_q1fills;
	Set q1fills_merged;
	By rxclm;
	If last.rxclm and rev_paid_flg > 0; Run;

*Adding company, network, and month_fill to dataset;
Data q1fills_2;
	Set paid_q1fills;
	bus_unit=substr(buss_carr,1,2);
	If bus_unit = 'XXXXXXXXXX' then Company="CommunityCare XXXXXXXXXX";
		Else if bus_unit = 'XXXXXXXXXX' then Company='CommunityCare XXXXXXXXXX';
		Else if bus_unit in ('XXXXXXXXXX', 'XXXXXXXXXX') then Company='CommunityCareXXXXXXXXXX';
		Else if bus_unit = 'XXXXXXXXXX' then Company='CommunityCare XXXXXXXXXX';
		Else if buss_carr = 'XXXXXXXXXX' then Company='CommunityCare XXXXXXXXXX';
	If mbr_rgn in (&Network_ASJ) then network = 'XXXXXXXXXX';
    	else if mbr_rgn in (&Network_SF) then network = 'XXXXXXXXXX';
    	else network = 'Other';		
	month_fill=Month(date_fill); Run;

*Creating dataset for summary tab;
Data summary;
	Set q1fills_2 (Keep=company network month_fill day_sup amt_mbr_pay amt_paid amt_tot);
	Fill_count= 1;
	Run;

* Summarize claims by company, network, and fill month;
Proc Summary Data=summary nway missing;
    Class month_fill company network;
    Var fill_count day_sup amt_mbr_pay amt_paid amt_tot;
    output out=q1fills_summary sum=; Run;

Data q1fills_summary_2 (Drop=_type_ _freq_);
	Set q1fills_summary; Run;

Data q1fills_summary_3;
	Set q1fills_summary_2;
	fill_month = mdy(month_fill, 1, 2023);
	Format fill_month monyy7.; Run;

*Detail report dataset;
Data q1fills_detail;
	Set q1fills_2 (Keep=Company network rxclm mbr_id date_fill day_sup disp_quant ndc); 
	fill_date = put(date_fill, mmddyy10.);Run;


/****************************************************************/
/***** Macro Reports  *****/
/****************************************************************/
	
*Macro for q1 fill summary tab;
%Macro RprtQ1FillSummary();

Title;
%Let Title1 = Pharmacy Fills for Q1 2023;
%Let Title2 = Summary By Company, Network, and Month;

Footnote;

Proc Report Data = q1fills_summary_3 nowindows missing
	Style(Header) = {VerticalAlign = middle}
	Style(Column) = {FontFamily = "Trebuchet MS" FontSize = 12pt};

	Title1 j = l Height = 14pt Font = "Trebuchet MS" Bold Color = Black     " &Title1";
	Title2 j = l Height = 13pt Font = "Trebuchet MS" Bold Color = '#808080' " &Title2";

	Column fill_month Company network fill_count day_sup amt_mbr_pay amt_paid amt_tot;

	Define fill_month/Group 'Fill Month' order=data Style(column)=data[width=1000% tagattr='wrap:yes'];	
	Define company/Group 'Company' Style(column)=data[width=1000% tagattr='wrap:yes'];
	Define network/Group 'Network' Style(column)=data[width=1000% tagattr='wrap:yes'];
	Define fill_count/Analysis 'Total Scripts' Style(column)=data[width=1000% tagattr='wrap:yes']; 
	Define day_sup/Analysis 'Total Days Supply' Style(column)=data[width=1000% tagattr='wrap:yes'];
	Define amt_mbr_pay/Analysis 'Total Member Pay' Style(column)=data[width=1000% tagattr='wrap:yes'];
	Define amt_paid/Analysis 'Total CCOK Pay' Style(column)=data[width=1000% tagattr='wrap:yes'];
	Define amt_tot/Analysis 'Total Allow Amount' Style(column)=data[width=1000% tagattr='wrap:yes'];

	Break After fill_month / Summarize Style = {Background = #C8C8C8 Foreground = Black Font = ('Trebuchet MS',12pt,bold)};
	Compute Before fill_month;
	network='Subtotal'; Endcomp;

	RBreak After / Summarize Style = {Background = #DBF5DC Foreground = Black Font = ('Trebuchet MS',12pt,bold)};
	Compute after ; 
	network='Grand Total'; Endcomp;

	Run; %Mend;


*Macro pharmacy fill detail tab;
%Macro RprtQ1FillsDetails();

Title;
%Let Title1 = Pharmacy Fills for Q1 2023;
%Let Title2 = Detail Page;

Footnote;

Proc Report Data = q1fills_detail nowindows missing
	Style(Header) = {VerticalAlign = middle}
	Style(Column) = {FontFamily = "Trebuchet MS" FontSize = 12pt};

	Title1 j = l Height = 14pt Font = "Trebuchet MS" Bold Color = Black     " &Title1";
	Title2 j = l Height = 13pt Font = "Trebuchet MS" Bold Color = '#808080' " &Title2";

	Column Company network rxclm mbr_id fill_date day_sup disp_quant ndc;

	Define Company/Display 'Company';
	Define network/Display 'Network';
	Define rxclm/Display 'Claim Number';
	Define mbr_id/Display 'Member Number';
	Define fill_date/Display 'Fill Date';
	Define day_sup/Display 'Days Supply';
	Define disp_quant/Display 'Dispensed Quantity';
	Define ndc/Display 'National Drug Code';
	
	Run ; %Mend ;

/****************************************************************/
/***** Exporting Data *****/
/****************************************************************/

   %Let RprtFileName = Pharmacy Training Assignment;
   %Let PartOneWidths = 20, 20, 20, 20, 20, 20, 20;
   %Let PartTwoWidths = 20, 20, 20, 20, 20, 20, 20, 20;

    Options topmargin    = .5in
            bottommargin = .7in
            leftmargin   = .25in
            rightmargin  = .25in ;

    ODS Path(Prepend) Work.Template(Update) ;

    Proc Template ;
	  Define Style SummaryReport ;
	  Parent = Styles.Excel ;
	  Class Body /
	    BackGroundColor = White
	    FontFamily = "Trebuchet MS"
		Fontsize = 12pt
		Color = Black 
      ;
	  Class SystemTitle /
	    BackGroundColor = White
		FontFamily = "Trebuchet MS"
		FontWeight = Bold
	  ;
	  Class SystemFooter /
	    BackGroundColor = White
		FontFamily = "Trebuchet MS"
		FontSize = 12pt
	  ;
	  Style CellContents /
		FontFamily = "Trebuchet MS"
		FontSize = 12pt
		Color = Black 
      ;
	  Style Header /
	  	BackGroundColor = cx007852
	    FontFamily = "Trebuchet MS"
		FontSize = 12pt
		FontWeight = Bold
		Color = White 
      ;
	  Style Table /
		FontFamily = "Trebuchet MS"
		FontSize = 12pt
		Color = Black
      ;
	  End ; Run ;

    ODS _ALL_ Close ;

ODS Excel File = "%SuperQ(OutPath)\&RprtFileName &RprtDate..xlsx"

      Style = SummaryReport 
      Options(
	          Row_Repeat = '10' 
			  Frozen_Headers = '10'
			  Print_Footer = "%NRSTR(&L&11)&RDA - &Analyst %NRSTR(&C&11) Page %NRSTR(&P) of %NRSTR(&N) %NRSTR(&R&11) &rundate" /* Standard by Department policy */
			  Print_Footer_Margin = '.25'
              Embed_Titles_Once = 'On'
              Embedded_Titles = 'Yes'
			  Embedded_Footnotes = 'Yes'
			  GridLines = 'Off'
			  Row_Heights = '0,0,0,0,0,0,10' 
			  Orientation = 'Landscape'
              Center_Horizontal = 'no'
              FitToPage = 'yes'
              Pages_FitHeight = '9999'
              Pages_FitWidth = '1'
              Flow = 'Text'
              Suppress_ByLines = 'ON'
              Sheet_Interval = 'None'
              ) ;

	ODS Excel 
      Options(
              Sheet_Name = "Summary"
              Absolute_Column_Width = "&PartOneWidths") ;

      Proc GOptions ;/* Add logo */
	    Title ;
	    Footnote ;

	    GOptions iback = "&Root\HDA\Resources\Logos\Community Care Logo 856x282.jpg" 
	      ImageStyle = Fit VSize = 0.8in HSize = 1.85in ; Run ;

	  Proc GSlide ; Run ;

%RprtQ1FillSummary; /* Call Proc Report */

/****************************************************************/
/***** Exporting Detail Data *****/
/****************************************************************/

/*Exporting detail data using ODS Tag Sets as it times out via ODS Excel*/

ods results=off;
ods tagsets.excelxp file="&Outpath\Pharmacy Training.xml"

/* Conforming to CCOK Communication Guidelines */
style = SaswebCCOKcg
options(
	embedded_titles = 'yes'
	embedded_footnotes = 'yes'
	row_repeat = "5"
	frozen_headers = '4'
	print_footer = "%NRSTR(&L&11)&RDA - &analyst %NRSTR(&C&11) %NRSTR(&r&11)"
	page_order_across = 'yes'
	center_horizontal = 'yes'
	gridlines = 'yes'
	fittopage = 'yes'
	pages_fitwidth = '1'
	pages_fitheight = '1000'
	orientation = 'portrait'
	autofit_height = 'yes'
	sheet_interval = 'proc'
	zoom = "80"
	absolute_column_width = '20,20,20,20,20');
 
/* Defining Sheet Name for Export */
ods tagsets.Excelxp options(sheet_name="Details");

/* Addding titles and footnotes */
Title1 "Pharmacy Fills for Q1 2023";
Title2 "Detail Page";
%RprtQ1FillsDetails() ;

 title;
title2;
 
/* Closing ODS Excel */
ods tagsets.excelxp close;
ods results=on;
 

%XMLtoXLSX  (&OutPath ,
			%quote(Pharmacy Training) ,
			1 ) ;