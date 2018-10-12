;==========================================================================
;+
;       pro run_orac_bsub
;
;       Description: Run ORAC for user-defined l1b files (currently
;set up to do MODIS or AATSR). Uses the bsub submission manager to run
;the preprocessor, main processor for water and ice, post processor,
;then derived products in succession. Job dependencies (using -w
;option) are used to ensure that the preprocessor finishes before the 
;main processor, and so on down the line.   
; 
;       Inputs:
;       user-defined array of L1 & geolocation files
; 
;       Example
;RUN_ORAC_BSUB, l1file=l1_files, geofile=geo_files, $
;               /rPre, /rWat, /rIce, /rPst, /rDer, $
;               version='fv2.0'
;               
;
;       Date
;       RAL - Remote Sensing Group : 10 November 2015
; $Id$
;
; 2016/07/28, WJ: Updated to new driver file format, added support
;                 for two layer retrieval (svn r4412) and general tidying
;                 NOTE: 2 layer retrievals are currently put in a
;                       subdirectory (ovr) under procpath, and do not
;                       work with BUGSrad
; 2016/08/01, WJ: Added selective processing of input files using
;                 x0,y0,x1,y1 inputs, and support for BUGSrad 2 layer
;                 processing.
; 2016/08/03, WJ: Fixed dependency conditions for BUGSrad with overlapping
;                 cloud layers, and added process specific replace keywords
; 2016/08/05, WJ: Added keyword "no16" to run without the 1.6 micron
;                 channel (to test MODIS AQUA sensitivity to missing
;                 channels) and "no37" to run without the 3.7 micron
;                 channel.
; 2016/08/11, WJ: Added options for running BUGSrad or Fu Liou model.
; 2016/09/01, WJ: Bug fix to tOffset
; 2016/09/06, WJ: Added Ctrl%Types_to_process to ice driver file to
;   circumvent process_cloudy_only flag
;-
;==========================================================================
pro val_orac_bsub, l1File=l1File, $           ;L1 input file
                   geoFile=geoFile, $         ;geolocation file
                   version=version, $         ;version number (5char string)
                   debug=debug,$              ;run ORAC in terminal mode
                   rPre=rPre, $               ;run preprocessor
                   rWat=rWat, $               ;run main processor for water type
                   rIce=rIce, $               ;run main processor for ice type
                   rClr=rClr, $               ;run main processor for clear type
                   rOvr=rOvr, $               ;run 2 layer processor
                   rPst=rPst, $               ;run post processor
                   rDer=rDer, $               ;run broadband fluxes
                   wAer=wAer, $               ;use colocated aerosol file
                   ecmwfScratch=ecmwfScratch, $ ;
                   heritage=heritage, $       ;use heritage mode
                   day_night=day_night,$      ;process for day/night
                   preprocPath=preprocPath, $ ;preprocessor output path
                   procPath=procPath, $       ;main processor output path
                   postPath=postPath, $       ;postprocessor output path
                   derivedProductsPath=derivedProductsPath, $ ;broadband fluxes output path
                   jobNameOut=jobNameOut, $   ;name of batch job
                   prefix=prefix, $           ;output file prefix
                   x0=x0,y0=y0,x1=x1,y1=y1,$  ;processing limits for ORAC
                   replace_all=replace_all, $ ;replace all output files
                   replace_Pre=replace_Pre, $ ;replace preprocessor output
                   replace_Wat=replace_Wat, $ ;replace water processor output
                   replace_Ice=replace_Ice, $ ;replace ice processor output
                   replace_Clr=replace_Clr, $ ;replace clear processor output
                   replace_Ovr=replace_Ovr, $ ;replace 2 layer processor output
                   replace_Pst=replace_Pst, $ ;replace postprocessor ouput
                   replace_Der=replace_Der, $ ;replace broadband fluxes output
                   no1_6=no1_6, $             ;run without 1.6 micron channel
                   no3_7=no3_7, $             ;run without 3.7 micron channel
                   BUGSrad=BUGSrad, $         ;use BUGSrad algoruthm
                   Fu_Liou=Fu_liou            ;use Fu Liou algorithm,
                                ; =1 - use 4 stream method,
                                ; =2 - use 2 stream gamma corrected method,
                                ; =3 - use 2 stream method


;Set Paths to Output Data
rootORAC = '/home/users/wkjones/orac/'
rootDATA = '/group_workspaces/cems/cloud_ecv/mchristensen/orac/'
IF KEYWORD_SET(preprocPath) EQ 0 THEN preprocPath = '/group_workspaces/cems/cloud_ecv/wkjones/orac/output/preproc'
IF KEYWORD_SET(procPath) EQ 0 THEN procPath    = '/group_workspaces/cems/cloud_ecv/wkjones/orac/output/orac'
IF KEYWORD_SET(postPath) EQ 0 THEN postPath    = '/group_workspaces/cems/cloud_ecv/wkjones/orac/output/postproc'
IF KEYWORD_SET(derivedProductsPath) EQ 0 THEN derivedProductsPath = '/home/users/wkjones/orac/output/derived_products'

;create output directories if they don't already exist
spawn, 'mkdir -p -v '+preprocpath
spawn, 'mkdir -p -v '+procpath+'/WAT'
spawn, 'mkdir -p -v '+procpath+'/ICE'
if keyword_set(rOvr) then spawn, 'mkdir -p -v '+procpath+'/OVR'
if keyword_set(rCLR) then spawn, 'mkdir -p -v '+procpath+'/CLR'
spawn, 'mkdir -p -v '+postpath
spawn, 'mkdir -p -v '+derivedproductspath

;Set Paths to Input Data
ecmwf_scratch =rootORAC+'data/ecmwf/' ;scratch directory for moving ECMWF files
ecmwf_BADC_path = '/badc/ecmwf-era-interim/data/'
albedoPath = '/group_workspaces/cems2/nceo_generic/cloud_ecv/data_in/modis/MCD43C3_MODIS_Albedo_neu/'
brdfPath = '/group_workspaces/cems2/nceo_generic/cloud_ecv/data_in/modis/MCD43C1_MODIS_BRDF_neu/'
ice_snowPath ='/group_workspaces/cems2/nceo_generic/cloud_ecv/data_in/ice_snow/'
cimss_emiss_path = '/group_workspaces/cems2/nceo_generic/cloud_ecv/data_in/emissivity'
aerosol_cci_path = '/group_workspaces/cems/aerosol_cci/public/cci_products/'
sad_dir_path = '/group_workspaces/cems/cloud_ecv/orac/sad_dir'

;File name information
fprefix = 'ESACCI' ;Prefix for file identifier
fmission = 'CC4CL'
if ~keyword_set(version) then version = 'fv2.0'
;; if ~keyword_set(vPre) then vPre = version
;; if ~keyword_set(vWat) then vWat = version
;; if ~keyword_set(vIce) then vIce = version
;; if ~keyword_set(vOvr) then vOvr = version
;; if ~keyword_set(vPst) then vPst = version
;; if ~keyword_set(vDer) then vDer = version

;Replace options
if KEYWORD_SET(replace_all) then begin
   replace_Pre=1
   replace_Wat=1
   replace_Ice=1
   replace_Ovr=1
   replace_Clr=1
   replace_Pst=1
   replace_Der=1
endif

;Options
IF n_elements(day_night) EQ 0 THEN day_night = '0' ;assume both
;day_night: 0=both, 1=day, 2=night

if n_elements(x0) eq 0 then $
   x0=0
if n_elements(y0) eq 0 then $
   y0=0
if n_elements(x1) eq 0 then $
   x1=0
if n_elements(y1) eq 0 then $
   y1=0


x0 = STRTRIM(STRING(x0),1)
y0 = STRTRIM(STRING(y0),1)
x1 = STRTRIM(STRING(x1),1)
y1 = STRTRIM(STRING(y1),1)

;==========================================================================
;read input list - note these are the L1 input files you want to run
;                  using ORAC
;==========================================================================
 ;if keyword_set(asciifile) then begin
 ;files_l1  = STRARR(10000)
 ;files_geo = STRARR(10000)
 ;fct=0l
  ;openr,1,asciifile
   ;junk=strarr(1)
   ;f1=strarr(1)
   ;f2=strarr(1)
   ;while eof(1) eq 0 do begin
    ;readf,1,f1
    ;readf,1,f2
    ;readf,1,junk
    ;files_l1(fct)=f1
    ;files_geo(fct)=f2
    ;fct++
   ;endwhile  
  ;close,1
 ;endif
 ;files_l1=files_l1(0:fct-1)
 ;files_geo=files_geo(0:fct-1)
 ;fct=n_elements(files_l1)
 fct=1
 files_l1=[l1File]
 files_geo=[geoFile]


;==========================================================================
; Process each file
;==========================================================================
;Loop over each file
FOR Itmp=0,fct-1 DO BEGIN  ;each file
   l1file = files_l1(Itmp) ;level 1 data
   geofile = files_geo(Itmp)    ;geolocation data for L1 file
 
 ;Determine Satellite Identifier
   file=file_basename(l1file)
   IF STRMID(file,0,8) eq 'MYD021KM' then begin
      sensor='MODIS'
      sensor1='MODIS-AQUA'
      satellite='AQUA'
   ENDIF

   IF STRMID(file,0,8) eq 'MOD021KM' then begin
      sensor='MODIS'
      sensor1='MODIS-TERRA'
      satellite='TERRA'
   ENDIF

   IF STRMID(file,0,8) eq 'AT2_TOA_' then begin
      sensor='ATSR2'
      sensor1='ATSR2'
      satellite='ERS2'
   ENDIF

   IF STRMID(file,0,8) eq 'ATS_TOA_' then begin
      sensor='AATSR'
      sensor1='AATSR'
      satellite='Envisat'
   ENDIF

   IF STRMID(file,0,8) eq 'MSG2-SEV' then begin
      sensor='SEVIRI'
      sensor1='SEVIRI-MSG2'
      satellite='MSG2'
   ENDIF


 ;File/path Naming information
   inl1file  = file_basename(l1file) ;l1 filename no path
   ingeofile = file_basename(geofile) ;geo filename no path
   l1path    = file_dirname(l1file)   ;l1 path
   geopath   = file_dirname(geofile)  ;geo filename path

 ;============================================
 ; Get timestamp (YYYY, MM, DD) of the input file
 ;============================================
   if sensor eq 'MODIS' then begin
      YYYY = STRMID(inl1file,10,4)
      JULD = STRMID(inl1file,14,3)*1.
      hr = STRMID(inl1file,18,4)
      hr = STRMID(inl1file,18,2)
      minute = STRMID(inl1file,20,2)  
      CALDAT, JULDAY(1,0,YYYY*1.)+JULD, month1, day1, year1
      MM = STRING(FORMAT='(I02)',month1)
      DD = STRING(FORMAT='(I02)',day1)
      tOffset = 2.5d0 / 1440d0  ;days (to get center time)
   endif
   if sensor eq 'ATSR2' then begin
      YYYY = STRMID(inl1file,14,4)
      MM = STRMID(inl1file,18,2)
      DD = STRMID(inl1file,20,2)
      hr = STRMID(inl1file,23,4)
      hr = STRMID(inl1file,23,2)
      minute = STRMID(inl1file,25,2)
      tOffset = 55d0 / 1440d0   ;days (to get center time)
      heritage = 1              ;force heritage mode
   endif
   if sensor eq 'AATSR' then begin
      YYYY = STRMID(inl1file,14,4)
      MM = STRMID(inl1file,18,2)
      DD = STRMID(inl1file,20,2)
      hr = STRMID(inl1file,23,4)
      hr = STRMID(inl1file,23,2)
      minute = STRMID(inl1file,25,2)
      tOffset = 55d0 / 1440d0   ;days (to get center time)
      heritage = 1              ;force heritage mode
   endif
   if sensor eq 'SEVIRI' then begin
      YYYY = STRMID(inl1file,24,4)
      MM = STRMID(inl1file,28,2)
      DD = STRMID(inl1file,30,2)
      hr = STRMID(inl1file,32,4)
      hr = STRMID(inl1file,32,2)
      minute = STRMID(inl1file,34,2)
      tOffset = 7.5d0 / 1440d0  ;days (to get center time)
   endif
   name = YYYY+MM+DD+hr+minute

  ;-----------------------------------
  ;GET CHANNEL IDS
  ;-----------------------------------

   chk_ch = 1*KEYWORD_SET(no1_6) + 2*KEYWORD_SET(no3_7)
   if keyword_set(heritage) then begin
      if sensor eq 'MODIS' then begin
         case chk_ch of 
            0: begin 
               ch_ids = '1,2,6,20,31,32'
               n_ids = '6'
            end
            1: begin 
               ch_ids = '1,2,20,31,32'
               n_ids = '5'
            end
            2: begin 
               ch_ids = '1,2,6,31,32'
               n_ids = '5'
            end
            2: begin
               ch_ids = '1,2,31,32'
               n_ids = '4'
            end
         endcase
      endif $
      else begin
         case chk_ch of 
            0: begin 
               ch_ids = '2,3,4,5,6,7'
               n_ids = '6'
            end
            1: begin 
               ch_ids = '2,3,5,6,7'
               n_ids = '5'
            end
            2: begin 
               ch_ids = '2,3,4,6,7'
               n_ids = '5'
            end
            2: begin
               ch_ids = '2,3,6,7'
               n_ids = '4'
            end
         endcase
      endelse
   endif $
   else begin
      case chk_ch of 
         0: begin
            ch_ids ='1,2,3,4,5,6,7,20,24,25,27,28,29,30,31,32,33,34,35,36'
            n_ids = '20'
         end
         1: begin
            ch_ids ='1,2,3,4,5,7,20,24,25,27,28,29,30,31,32,33,34,35,36'
            n_ids = '19'
         end
         2: begin
            ch_ids ='1,2,3,4,5,6,7,24,25,27,28,29,30,31,32,33,34,35,36'
            n_ids = '19'
         end
         2: begin
            ch_ids ='1,2,3,4,5,7,24,25,27,28,29,30,31,32,33,34,35,36'
            n_ids = '18'
         end
      endcase
   endelse

   


 ;==========================================================================
 ; ENTERING MAIN CODE
 ;==========================================================================

 ;pre-processor
   if keyword_set(rPre) then begin
      
      preprocfile=preprocpath+'/'+fprefix+'-L2-CLOUD-CLD-'+sensor+'_'+fmission+'_'+satellite+'_'+yyyy+mm+dd+hr+minute+'_'+version

  ;Check to see if file has already been created
      preSkip=0
      chk = file_search(preprocfile+'.alb.nc',count=chkCT)
      if chkCT EQ 0 OR keyword_set(replace_Pre) EQ 1 THEN BEGIN

  ;ECMWF FILES
         VAL_FIND_ECMWF_FILES,YYYY,MM,DD,hr,minute,tOffset, $
                              YYYY1,MM1,DD1,hr1,YYYY2,MM2,DD2,hr2
         GGAS_PATHS = ecmwf_BADC_path+'gg/as/'+[YYYY1+'/'+MM1+'/'+DD1+'/',YYYY2+'/'+MM2+'/'+DD2]
         GGAS_FILES = GGAS_PATHS+'/ggas'+[YYYY1+MM1+DD1+hr1,YYYY2+MM2+DD2+hr2]+'.nc'

         GGAM_PATHS = ecmwf_BADC_path+'gg/am/'+[YYYY1+'/'+MM1+'/'+DD1+'/',YYYY2+'/'+MM2+'/'+DD2]
         GGAM_FILES = GGAM_PATHS+'/ggam'+[YYYY1+MM1+DD1+hr1,YYYY2+MM2+DD2+hr2]+'.grb'

         GPAM_PATHS = ecmwf_BADC_path+'sp/am/'+[YYYY1+'/'+MM1+'/'+DD1+'/',YYYY2+'/'+MM2+'/'+DD2]
         GPAM_FILES = GPAM_PATHS+'/spam'+[YYYY1+MM1+DD1+hr1,YYYY2+MM2+DD2+hr2]+'.grb'

  ;Check that files exist
         GGAS_FILES = file_search(ggas_files,count=ggasCT)
         GGAM_FILES = file_search(ggam_files,count=ggamCT)
         GPAM_FILES = file_search(gpam_files,count=gpamCT)
         IF ggasCT LT 2. OR ggamCT LT 2. OR gpamCT LT 2. THEN STOP,'ECMWF FILE MISSING'
   

  ;Paths to data
         albedo_path      = albedoPath+YYYY
         IF YYYY*1. LT 2000 THEN albedo_path = albedoPath+'XXXX'
         brdf_path        = brdfPath+YYYY
         IF YYYY*1. LT 2000 THEN brdf_path = brdfPath+'XXXX'
         ice_snow_path    = ice_snowPath+YYYY

  
  ;BADC PATH LOCATION
         ecmwfPath1 = GGAM_PATHS(0)
         ecmwfPath2 = GGAS_PATHS(0)
         ecmwfPath3 = GPAM_PATHS(0)
         ecmwfPath4 = GGAM_PATHS(1)
         ecmwfPath5 = GGAS_PATHS(1)
         ecmwfPath6 = GPAM_PATHS(1)
         ecmwfOPTION = '2'      ;unpack within ORAC

  ;ECMWF SCRATCH DIRECTORY
         if keyword_set(ecmwfScratch) then begin
            ecmwfPath1 = STRMID(ecmwf_scratch,0,strlen(ecmwf_scratch)-1) ;remove '/' to end of file
            ecmwfPath2 = STRMID(ecmwf_scratch,0,strlen(ecmwf_scratch)-1)
            ecmwfPath3 = STRMID(ecmwf_scratch,0,strlen(ecmwf_scratch)-1)
            ecmwfPath4 = STRMID(ecmwf_scratch,0,strlen(ecmwf_scratch)-1)
            ecmwfPath5 = STRMID(ecmwf_scratch,0,strlen(ecmwf_scratch)-1)
            ecmwfPath6 = STRMID(ecmwf_scratch,0,strlen(ecmwf_scratch)-1)
            ecmwfOPTION = '1'   ;set ECMWF path and unpack offline
         endif
         print,inl1file
         print,ggam_files(0)
         print,ggas_files(0)
         print,gpam_files(0)
         print,ggam_files(1)
         print,ggas_files(1)
         print,gpam_files(1)
         print,''
  
  ;-----------------------------------
  ; OPTIONS - Channels Specified
  ;-----------------------------------
         OPTION_STRING = 'use_hr_ecmwf=.false.'+' '+$
                         'n_channels='+n_ids+' '+$
                         'channel_ids='+ch_ids
         
                                ;unpacking grib files within ORAC
         IF ecmwfOPTION eq '2' THEN BEGIN
            OPTION_STRING = OPTION_STRING+' '+ $
                            'ecmwf_time_int_method=2'+' '+$
                            'ecmwf_path_2='+ecmwfPath4+' '+$
                            'ecmwf_path2_2='+ecmwfPath5+' '+$
                            'ecmwf_path3_2='+ecmwfPath6
            
         ENDIF
         

  ;------------------------------------
  ; executable string for pre-processor
  ;------------------------------------
         tstr=rootORAC+'trunk/pre_processing/orac_preproc.x '+$
              sensor+' '+$
              l1path+'/'+inl1file+' '+$
              geopath+'/'+ingeofile+' '+$
              rootDATA+'data/Aux_file_CM_SAF_AVHRR_GAC_ori_0.05deg.nc '+$
              ecmwfPath1+' '+$
              rootDATA+'data/coeffs '+$
              rootDATA+'data/emis_data '+$
              ice_snow_path+' '+$
              albedo_path+' '+$
              brdf_path+' '+$
              cimss_emiss_path+' '+$
              '2.0 '+$
              '2.0 '+$
              preprocpath+' '+$
              x0+' '+$
              x1+' '+$
              y0+' '+$
              y1+' '+$
              'xxx '+$
              'CF-1.4 '+$
              'RAL '+$
              fmission+' '+$
              'matthew.christensen@stfc.ac.uk '+$
              'www.esa-cloud-cci.info '+$
              version+' '+$
              'ATBD '+$
              'xxx '+$
              'xxx '+$
              'xxx '+$
              'xxx '+$
              fprefix+' '+$
              'xxx '+$
              'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx '+$
              'xxxxxxxxxxxxxx '+$
              rootDATA+'data/AATSR_VIS_DRIFT_V03-00.DAT '+$
              ecmwfOPTION+' '+$
              ecmwfPath2+' '+$
              ecmwfPath3+' '+$
              'false '+$
              day_night+' '+$
              'true '+$
              'false '+$
              'false '+$
              'true '+$
              'xxx '+$
              'xxx '+$
              'xxx '+$
              OPTION_STRING

   ;Job and error file names
         jobPre = name+'PRE'
         outFile = preprocPath+'/'+name+'PRE.out'
         errFile = preprocPath+'/'+name+'PRE.err'
         jobNameOut=jobPre

   ;Check if output or errfile already exists if so delete them
         chkOut = file_search(outFile,count=chkOutCT)
         chkErr = file_search(errFile,count=chkErrCT)
         if chkOutCT eq 1 then spawn,'rm -f '+outFile
         if chkErrCT eq 1 then spawn,'rm -f '+errFile
   
   ;B-SUBMISSION command
         bsubEXE='bsub -q lotus -W 4:00 -M 1 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobPre+' '+tstr

   
         if ~keyword_set(debug) then begin
            print,'SUBMIT PRE-PROCESSING JOB'
            print,bsubEXE
            spawn,bsubEXE
         endif
         
         if keyword_set(debug) then begin
            print,'Pre-processor'
            print,tstr
            spawn,tstr
         endif

      endif else begin
    
         print,'Skipping PreProcessing: ',chk(0)
         preSkip = 1
      endelse
   endif else preSkip=1         ;preproc-keyword
   print,''



;==========================================================================
 ;main processor
   preprocfile=preprocpath+'/'+fprefix+'-L2-CLOUD-CLD-'+sensor+'_'+fmission+'_'+satellite+'_'+yyyy+mm+dd+hr+minute+'_'+version

   prefix=file_basename(preprocfile)

   ;get channel ids, check with no channel keywords
   chk_ch = 1*KEYWORD_SET(no1_6) + 2*KEYWORD_SET(no3_7)
   if keyword_set(heritage) then begin
      case chk_ch of 
         0: ch_ids = '1,1,1,1,1,1'
         1: ch_ids = '1,1,1,1,1'
         2: ch_ids = '1,1,1,1,1'
         2: ch_ids = '1,1,1,1'
      endcase
   endif $
      else begin
      case chk_ch of 
         0: ch_ids ='1,1,0,0,0,1,0,1,0,0,0,0,0,0,1,1,0,0,0,0'
         1: ch_ids ='1,1,0,0,0,0,1,0,0,0,0,0,0,1,1,0,0,0,0'
         2: ch_ids ='1,1,0,0,0,1,0,0,0,0,0,0,0,1,1,0,0,0,0'
         2: ch_ids ='1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0'
      endcase
   endelse 




  ;;  printf,1,"'"+preProcPath+"'"
  ;;  printf,1,"'"+prefix+"'"
  ;;  printf,1,"'"+ProcPath+"'"
  ;;  printf,1,"'"+sad_dir_Path+"'"
  ;;  printf,1,"'"+sensor1+"'"
  ;;  IF KEYWORD_SET(heritage) THEN BEGIN
  ;;   printf,1,'6'
  ;;   printf,1,'1 1 1 1 1 1'
  ;;  ENDIF
  ;;  IF ~KEYWORD_SET(heritage) THEN BEGIN
  ;;   printf,1,'20'
  ;;   printf,1,'1 1 0 0 0 1 0 1 0 0 0 0 0 0 1 1 0 0 0 0'
  ;;   ;         1,2,3,4,5,6,7,20242527282930313233343536'
  ;;  ENDIF
  ;;  printf,1,'WAT'
  ;;  printf,1,'Ctrl%process_cloudy_only=false'
  ;; close,1



  ;;  printf,1,"'"+preProcPath+"'"
  ;;  printf,1,"'"+prefix+"'"
  ;;  printf,1,"'"+ProcPath+"'"
  ;;  printf,1,"'"+sad_dir_Path+"'"
  ;;  printf,1,"'"+sensor1+"'"
  ;;  IF KEYWORD_SET(heritage) THEN BEGIN
  ;;   printf,1,'6'
  ;;   printf,1,'1 1 1 1 1 1'
  ;;  ENDIF
  ;;  IF ~KEYWORD_SET(heritage) THEN BEGIN
  ;;   printf,1,'20'
  ;;   printf,1,'1 1 0 0 0 1 0 1 0 0 0 0 0 0 1 1 0 0 0 0'
  ;;   ;         1,2,3,4,5,6,7,20242527282930313233343536'
  ;;  ENDIF
  ;;  printf,1,'ICE'
  ;;  printf,1,'Ctrl%process_cloudy_only=false'
  ;; close,1



 ;Water
 ;Check to see if already created
   WatSkip=0
   chk = file_search(procPath+'/WAT/'+prefix+'WAT.primary.nc',count=chkCT)
   if chkCT EQ 0 OR keyword_set(replace_Wat) EQ 1 THEN BEGIN

      ;WATER driver file
      watFile = procPath+'/'+'proc_driver_'+prefix+'WAT.txt'
      chk = file_search(watFile,count=chkCT)
      if chkCT eq 1 then spawn,'rm -f '+watFile

      openw,1,watFile
      printf,1,'# ORAC Driver File'
      printf,1,'Ctrl%FID%Data_Dir           = '+preProcPath
      printf,1,'Ctrl%FID%Filename           = "'+prefix+'"'
      printf,1,'Ctrl%FID%Out_Dir            = '+ProcPath+'/WAT'
      printf,1,'Ctrl%FID%SAD_Dir            = '+sad_dir_Path
      printf,1,'Ctrl%InstName               = '+sensor1
      printf,1,'Ctrl%Ind%NAvail             = '+n_ids
      printf,1,'Ctrl%Ind%Channel_Proc_Flag  = '+ch_ids
      printf,1,'Ctrl%LUTClass               = WAT'
      printf,1,'Ctrl%Approach               = AppCld1L'
      printf,1,'Ctrl%Class                  = ClsCldWat'
      printf,1,'Ctrl%process_cloudy_only    = true'
   ;; if x0 ne '0' && x1 ne '0' && y0 ne '0' && y1 ne '0' then begin
   ;;    printf,1,'Ctrl%Ind%X0 = '+x0
   ;;    printf,1,'Ctrl%Ind%X1 = '+x1
   ;;    printf,1,'Ctrl%Ind%Y0 = '+y0
   ;;    printf,1,'Ctrl%Ind%Y1 = '+y1
   ;; endif
      close,1

      ;executable
      tstr=rootorac+'/trunk/src/orac '+watFile
      jobWat = name+'WAT'
      outFile = procPath+'/'+name+'WAT.out'
      errFile = procPath+'/'+name+'WAT.err'
                                ;Check if output or errfile exist if so delete them
      chkOut = file_search(outFile,count=chkOutCT)
      chkErr = file_search(errFile,count=chkErrCT)
      if chkOutCT eq 1 then spawn,'rm -f '+outFile
      if chkErrCT eq 1 then spawn,'rm -f '+errFile

  ; bsub dependency condition
      if preSkip eq 0 then bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobWat+' -w '+"'"+'ended('+jobPre+')'+"' "+tstr
      if preSkip eq 1 then bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobWat+' '+tstr

      if keyword_set(rWat) then begin
         if ~keyword_set(debug) then begin
            print,'SUBMIT PROCESSOR WATER'
            print,bsubEXE
            spawn,bsubEXE
         endif

         if keyword_set(debug) then begin
            print,'Processor Water'
            print,tstr
            spawn,tstr
         endif
      endif $
      else begin                ;run water option
   
         print,'Skipping Main Processor for Water: ',chk(0)
         WatSkip=1
      endelse

      print,''
   endif $
   else begin
    
      print,'Skipping Main Processor for Water: ',chk(0)
      WatSkip=1
   endelse 
   print,''

 ;Ice
 ;Check to see if already created
   IceSkip=0
   chk = file_search(procPath+'/ICE/'+prefix+'ICE.primary.nc',count=chkCT)
   if chkCT EQ 0 OR keyword_set(replace_Ice) EQ 1 THEN BEGIN
      ;ICE driver file
      iceFile = procPath+'/'+'proc_driver_'+prefix+'ICE.txt'
      chk = file_search(iceFile,count=chkCT)
      if chkCT eq 1 then spawn,'rm -f '+iceFile

      openw,1,iceFile
      printf,1,'# ORAC Driver File'
      printf,1,'Ctrl%FID%Data_Dir           = '+preProcPath
      printf,1,'Ctrl%FID%Filename           = "'+prefix+'"'
      printf,1,'Ctrl%FID%Out_Dir            = '+ProcPath+'/ICE'
      printf,1,'Ctrl%FID%SAD_Dir            = '+sad_dir_Path
      printf,1,'Ctrl%InstName               = '+sensor1
      printf,1,'Ctrl%Ind%NAvail             = '+n_ids
      printf,1,'Ctrl%Ind%Channel_Proc_Flag  = '+ch_ids
      printf,1,'Ctrl%LUTClass               = ICE'
      printf,1,'Ctrl%Approach               = AppCld1L'
      printf,1,'Ctrl%Class                  = ClsCldIce'
      printf,1,'Ctrl%process_cloudy_only    = false'
      printf,1,'Ctrl%NTypes_to_process      = 6'
      printf,1,'Ctrl%Types_to_process(1)    = OPAQUE_ICE_TYPE'
      printf,1,'Ctrl%Types_to_process(2)    = CIRRUS_TYPE'
      printf,1,'Ctrl%Types_to_process(3)    = OVERLAP_TYPE'
      printf,1,'Ctrl%Types_to_process(4)    = PROB_OPAQUE_ICE_TYPE'
      printf,1,'Ctrl%Types_to_process(5)    = CLEAR_TYPE'
      printf,1,'Ctrl%Types_to_process(6)    = PROB_CLEAR_TYPE'
   ;; if x0 ne '0' && x1 ne '0' && y0 ne '0' && y1 ne '0' then begin
   ;;    printf,1,'Ctrl%Ind%X0 = '+x0
   ;;    printf,1,'Ctrl%Ind%X1 = '+x1
   ;;    printf,1,'Ctrl%Ind%Y0 = '+y0
   ;;    printf,1,'Ctrl%Ind%Y1 = '+y1
   ;; endif 
      close,1

                                ; executable
      tstr=rootorac+'/trunk/src/orac '+iceFile
                                ; bsub output file names
      jobIce = name+'ICE'
      outFile = procPath+'/'+name+'ICE.out'
      errFile = procPath+'/'+name+'ICE.err'
  ;Check if output or errfile exist if so delete them
      chkOut = file_search(outFile,count=chkOutCT)
      chkErr = file_search(errFile,count=chkErrCT)
      if chkOutCT eq 1 then spawn,'rm -f '+outFile
      if chkErrCT eq 1 then spawn,'rm -f '+errFile
      
  ; bsub dependency condition
      if preSkip eq 0 then bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobIce+' -w '+"'"+'ended('+jobPre+')'+"' "+tstr
      if preSkip eq 1 then bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobIce+' '+tstr

      if keyword_set(rIce) then begin

         if ~keyword_set(debug) then begin
            print,'SUBMIT PROCESSOR ICE'
            print,bsubEXE
            spawn,bsubEXE
         endif

         if keyword_set(debug) then begin
            print,'Processor ICE'
            print,tstr 
            spawn,tstr
         endif
      endif $
      else begin
   
         print,'Skipping Main Processor for Ice: ',chk(0)
         IceSkip=1
      endelse

      print,''
   endif $
   else begin
    
      print,'Skipping Main Processor for Ice: ',chk(0)
      IceSkip=1
   endelse 
   print,''

;;  2 Layer - test version
;;  Check to see if already created
   OVRSkip=0
   chk = file_search(procPath+'/OVR/'+prefix+'ICE.primary.nc',count=chkCT)
   if chkCT EQ 0 OR keyword_set(replace_Ovr) EQ 1 THEN BEGIN
      ;2 layer driver file - experimental!
      ovrFile = procPath+'/'+'proc_driver_'+prefix+'OVR.txt'
      chk = file_search(ovrFile,count=chkCT)
      if chkCT eq 1 then spawn,'rm -f '+ovrFile

      openw,1,ovrFile
      printf,1,'# ORAC Driver File'
      printf,1,'Ctrl%FID%Data_Dir           = '+preProcPath
      printf,1,'Ctrl%FID%Filename           = "'+prefix+'"'
      printf,1,'Ctrl%FID%Out_Dir            = '+ProcPath+'/OVR'
      printf,1,'Ctrl%FID%SAD_Dir            = '+sad_dir_Path
      printf,1,'Ctrl%InstName               = '+sensor1
      printf,1,'Ctrl%Ind%NAvail             = '+n_ids
      printf,1,'Ctrl%Ind%Channel_Proc_Flag  = '+ch_ids
      printf,1,'Ctrl%LUTClass               = ICE'
      printf,1,'Ctrl%Approach               = AppCld2L'
      printf,1,'Ctrl%Class                  = ClsCldIce'
      printf,1,'Ctrl%Class2                 = ClsCldWat'
      printf,1,'Ctrl%FID%SAD_Dir2           = '+sad_dir_Path
      printf,1,'Ctrl%LUTClass2              = WAT'
      printf,1,'Ctrl%process_cloudy_only    = false'
   ;; if x0 ne '0' && x1 ne '0' && y0 ne '0' && y1 ne '0' then begin
   ;;    printf,1,'Ctrl%Ind%X0 = '+x0
   ;;    printf,1,'Ctrl%Ind%X1 = '+x1
   ;;    printf,1,'Ctrl%Ind%Y0 = '+y0
   ;;    printf,1,'Ctrl%Ind%Y1 = '+y1
   ;; endif
      close,1

                                ;executable
      tstr=rootorac+'/trunk/src/orac '+OVRFile
  ;bsub output file names
      jobOVR = name+'OVR'
      outFile = procPath+'/'+name+'OVR.out'
      errFile = procPath+'/'+name+'OVR.err'
                                ;Check if output or errfile exist if so delete them
      chkOut = file_search(outFile,count=chkOutCT)
      chkErr = file_search(errFile,count=chkErrCT)
      if chkOutCT eq 1 then spawn,'rm -f '+outFile
      if chkErrCT eq 1 then spawn,'rm -f '+errFile

 ; bsub dependency condition
      if preSkip eq 0 then bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobOVR+' -w '+"'"+'ended('+jobPre+')'+"' "+tstr
      if preSkip eq 1 then bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobOVR+' '+tstr

      if keyword_set(rOVR) then begin

         if ~keyword_set(debug) then begin
            print,'SUBMIT PROCESSOR 2 LAYER'
            print,bsubEXE
            spawn,bsubEXE
         endif
         
         if keyword_set(debug) then begin
            print,'Processor 2 LAYER'
            print,tstr 
            spawn,tstr
         endif
      endif $
      else begin
   
         print,'Skipping Main Processor for 2 LAYER: ',chk(0)
         OVRSkip=1
      endelse

      print,''
   endif $
   else begin
    
      print,'Skipping Main Processor for 2 LAYER: ',chk(0)
      OVRSkip=1
   endelse 
   print,''

;;  2 Layer - test version
;;  Check to see if already created
   CLRSkip=0
   chk = file_search(procPath+'/CLR/'+prefix+'WAT.primary.nc',count=chkCT)
   if chkCT EQ 0 OR keyword_set(replace_Clr) EQ 1 THEN BEGIN
      ;clear driver file
      clrFile = procPath+'/'+'proc_driver_'+prefix+'CLR.txt'
      chk = file_search(ovrFile,count=chkCT)
      if chkCT eq 1 then spawn,'rm -f '+clrFile

      openw,1,clrFile
      printf,1,'# ORAC Driver File'
      printf,1,'Ctrl%FID%Data_Dir           = '+preProcPath
      printf,1,'Ctrl%FID%Filename           = "'+prefix+'"'
      printf,1,'Ctrl%FID%Out_Dir            = '+ProcPath+'/CLR'
      printf,1,'Ctrl%FID%SAD_Dir            = '+sad_dir_Path
      printf,1,'Ctrl%InstName               = '+sensor1
      printf,1,'Ctrl%Ind%NAvail             = '+n_ids
      printf,1,'Ctrl%Ind%Channel_Proc_Flag  = '+ch_ids
      printf,1,'Ctrl%LUTClass               = WAT'
      printf,1,'Ctrl%Approach               = AppCld1L'
      printf,1,'Ctrl%Class                  = ClsCldWat'
      printf,1,'Ctrl%process_cloudy_only    = false'
   ;; if x0 ne '0' && x1 ne '0' && y0 ne '0' && y1 ne '0' then begin
   ;;    printf,1,'Ctrl%Ind%X0 = '+x0
   ;;    printf,1,'Ctrl%Ind%X1 = '+x1
   ;;    printf,1,'Ctrl%Ind%Y0 = '+y0
   ;;    printf,1,'Ctrl%Ind%Y1 = '+y1
   ;; endif
      printf,1,'Ctrl%AP[IFr,:] = SelmCtrl'
      printf,1,'Ctrl%XB[ITau] = -2'
      printf,1,'Ctrl%XB[IFr] = 0'
      printf,1,'Ctrl%Sx[ITau] = 0.000001'
      printf,1,'Ctrl%Sx[IFr] = 0.000001'
      close,1

                                ;executable
      tstr=rootorac+'/trunk/src/orac '+CLRFile
  ;bsub output file names
      jobCLR = name+'CLR'
      outFile = procPath+'/'+name+'CLR.out'
      errFile = procPath+'/'+name+'CLR.err'
                                ;Check if output or errfile exist if so delete them
      chkOut = file_search(outFile,count=chkOutCT)
      chkErr = file_search(errFile,count=chkErrCT)
      if chkOutCT eq 1 then spawn,'rm -f '+outFile
      if chkErrCT eq 1 then spawn,'rm -f '+errFile

 ; bsub dependency condition
      if preSkip eq 0 then bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobCLR+' -w '+"'"+'ended('+jobPre+')'+"' "+tstr
      if preSkip eq 1 then bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobCLR+' '+tstr

      if keyword_set(rCLR) then begin

         if ~keyword_set(debug) then begin
            print,'SUBMIT PROCESSOR CLEAR'
            print,bsubEXE
            spawn,bsubEXE
         endif
         
         if keyword_set(debug) then begin
            print,'Processor Clear'
            print,tstr 
            spawn,tstr
         endif
      endif $
      else begin
   
         print,'Skipping Main Processor for Clear: ',chk(0)
         CLRSkip=1
      endelse

      print,''
   endif $
   else begin
    
      print,'Skipping Main Processor for Clear: ',chk(0)
      CLRSkip=1
   endelse 
   print,''

;==========================================================================
 ;run post processor
   postFile = postPath+'/'+'postproc_driver_'+prefix+'.txt'
   chk = file_search(postFile,count=chkCT)
   if chkCT eq 1 then spawn,'rm -f '+postFile

  ;Primary and secondary files
   prefix=file_basename(preprocfile)

  ;input files
   fWATprimary = procPath+'/WAT/'+prefix+'WAT.primary.nc'
   fWATsecondary = procPath+'/WAT/'+prefix+'WAT.secondary.nc'
  ;; if keyword_set(rICE) || ~keyword_set(rOVR) then begin
  ;;  fICEprimary = procPath+'/'+prefix+'ICE.primary.nc'
  ;;  fICEsecondary = procPath+'/'+prefix+'ICE.secondary.nc'
  ;; endif $
  ;; else begin
   fICEprimary = procPath+'/ICE/'+prefix+'ICE.primary.nc'
   fICEsecondary = procPath+'/ICE/'+prefix+'ICE.secondary.nc'
   fCLRprimary = procPath+'/CLR/'+prefix+'WAT.primary.nc'
   fCLRsecondary = procPath+'/CLR/'+prefix+'WAT.secondary.nc'
  ;; endelse
   fOVRprimary = procPath+'/OVR/'+prefix+'ICE.primary.nc'
   fOVRsecondary = procPath+'/OVR/'+prefix+'ICE.secondary.nc'
  fOVRprimary = procPath+'/ovr/'+prefix+'ICE.primary.nc'
  fOVRsecondary = procPath+'/ovr/'+prefix+'ICE.secondary.nc'

  ;output files
   fprimary = postPath+'/'+prefix+'.primary.nc'
   fsecondary = postPath+'/'+prefix+'.secondary.nc'

   openw,1,postFile
   printf,1,fWATprimary
   printf,1,fICEprimary
   ;printf,1,fCLRprimary
   printf,1,fWATsecondary
   printf,1,fICEsecondary
   ;printf,1,fCLRsecondary
   printf,1,fprimary
   printf,1,fsecondary
   printf,1,'false'             ;use Pavolonis typing only
    ;; if keyword_set(rOVR) && keyword_set(rICE) then begin
    ;;  printf,1,fOVRprimary
    ;;  printf,1,fOVRsecondary
    ;; endif
   printf,1,'output_optical_props_at_night=true'
   printf,1,'use_chunking=true'
    ;; if keyword_set(useBayesian) then $
    ;;  printf,1,'use_bayesian_selection=true' $
    ;; else if (keyword_set(rOVR) && keyword_set(rICE)) then $
    ;;  printf,1,'use_bayesian_selection=true'
   ;; endelse
   close,1  


 ;check if post file exists
   postSkip=0
   chk = file_search(postPath+'/'+prefix+'.primary.nc',count=chkCT)
   if chkCT EQ 0 OR keyword_set(replace_Pst) EQ 1 THEN BEGIN
                                ; executable
      tstr=rootorac+'/trunk/post_processing/post_process_level2 '+postFile
      jobPost = name+'PST'
      outFile = postPath+'/'+name+'PST.out'
      errFile = postPath+'/'+name+'PST.err'
  ;Check if output or errfile exist if so delete them
      chkOut = file_search(outFile,count=chkOutCT)
      chkErr = file_search(errFile,count=chkErrCT)
      if chkOutCT eq 1 then spawn,'rm -f '+outFile
      if chkErrCT eq 1 then spawn,'rm -f '+errFile

   ;; ;Dependency condition - needs updating for case of only ice or water!
   ;; if WatSkip eq 0 and IceSkip eq 0 then begin
   ;;  bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobPost+' -w '+"'"+'ended('+jobWat+') && ended('+jobIce+')'+"' "+tstr
   ;; endif
  
   ;; ;No Dependency condition
   ;; if WatSkip eq 1 and IceSkip eq 1 then begin
   ;;  bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobPost+' '+tstr   
   ;; endif

      chkDep = WatSkip + 2*IceSkip +4*clrskip
      case chkDep of
         0: bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobPost+' -w '+"'"+'ended('+jobWat+') && ended('+jobIce+') && ended('+jobCLR+')'+"' "+tstr
         1: bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobPost+' -w '+"'"+'ended('+jobIce+') && ended('+jobCLR+')'+"' "+tstr
         2: bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobPost+' -w '+"'"+'ended('+jobWat+') && ended('+jobCLR+')'+"' "+tstr
         3: bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobPost+' -w '+"'"+'ended('+jobCLR+')'+"' "+tstr
         4: bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobPost+' -w '+"'"+'ended('+jobWat+') && ended('+jobIce+')'+"' "+tstr
         5: bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobPost+' -w '+"'"+'ended('+jobIce+')'+"' "+tstr
         6: bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobPost+' -w '+"'"+'ended('+jobWat+')'+"' "+tstr
         7: bsubEXE='bsub -q lotus -W 6:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobPost+' '+tstr
      endcase

      if keyword_set(rPst) then begin
         if ~keyword_set(debug) then begin
            print,'SUBMIT POST PROCESSOR'
            print,bsubEXE
            spawn,bsubEXE
         endif

         if keyword_set(debug) then begin
            print,'POST PROCESSOR'
            print,tstr
            spawn,tstr
         endif
      endif $
      else begin
         print,'Skipping Post Processor: ',chk(0)
         postSkip = 1
      endelse

   endif $
   else begin
      print,'Skipping Post Processor: ',chk(0)
      postSkip = 1
   endelse
   print,''

;==========================================================================
 ;BUGSrad
 ;Get primary file
   if keyword_set(rDer) then begin
      dervSkip=0
      chk = file_search(derivedProductsPath+'/'+prefix+'.bugsrad.nc',count=chkCT)
      if chkCT EQ 0 OR keyword_set(replace_Der) EQ 1 THEN BEGIN

         prefix=file_basename(preprocfile)
         fexecutable = rootorac+'/trunk/derived_products/broadband_fluxes/process_broadband_fluxes'
         fprimary = postPath+'/'+prefix+'.primary.nc'
         fprtm = preprocfile+'.prtm.nc'
         falb  = preprocfile+'.alb.nc'
         ftsi  = '/group_workspaces/cems/cloud_ecv/mchristensen/orac/data/tsi/tsi.nc'
         fbugs = derivedproductspath+'/'+prefix+'.bugsrad.nc'
         faerosol = file_search(aerosol_cci_path+sensor+'_ORAC_v03-02/L2/'+YYYY+'/'+YYYY+'_'+MM+'_'+DD+'/'+YYYY+MM+DD+hr+'*.nc')
         fcollocation = '/group_workspaces/cems/cloud_ecv/mchristensen/orac/output/aci/collocation/'+YYYY+MM+DD+hr+'_'+version+'.collocation.nc'
         ;f2layer = file_search(procPath+'/ovr/'+prefix+'ICE.primary.nc',count=chkCT)
 f2layer = file_search(procPath+'/ovr/*'+name+'*'+version+'*.primary.nc',count=chkCT)

         ;if KEYWORD_SET(BUGSrad) then alg_mode = '1' $
         alg_mode = '1'
         app_mode = '0'
         if KEYWORD_SET(Fu_Liou) then begin
            alg_mode = '2'
            if N_ELEMENTS(WHERE([1,2,3] eq Fu_Liou)) eq 0 then $
               app_mode = '1' $
            else app_mode = STRTRIM(STRING(Fu_Liou),1)
         endif

         tstr=fexecutable+' '+fprimary+' '+fprtm+' '+falb+' '+ftsi+' '+fbugs+ $
              ' '+alg_mode+' '+app_mode

         if keyword_set(wAer) then tstr=tstr+' '+ $
            faerosol+' '+fcollocation
         ;if ~keyword_set(wAer) and keyword_set(rOVR) then tstr=fexecutable+' '+fprimary+' '+fprtm+' '+falb+' '+ftsi+' '+fbugs+' n n '+f2layer
         ;if keyword_set(wAer) and keyword_set(rOVR) then tstr=fexecutable+' '+fprimary+' '+fprtm+' '+falb+' '+ftsi+' '+fbugs+' '+faerosol+' '+fcollocation+' '+f2layer
         ;; if x0 ne '0' and y0 ne '0' then tstr = tstr+' '+x0+' '+y0
         ;; if x1 ne '0' and y1 ne '0' then tstr = tstr+' '+x1+' '+y1
         
         jobBUGSrad = name+'RAD'

  ;Output & Error Log
         outFile = derivedProductsPath+'/'+name+'.out'
         errFile = derivedProductsPath+'/'+name+'.err'
  ;Check if output or errfile exist if so delete them
         chkOut = file_search(outFile,count=chkOutCT)
         chkErr = file_search(errFile,count=chkErrCT)
         if chkOutCT eq 1 then spawn,'rm -f '+outFile
         if chkErrCT eq 1 then spawn,'rm -f '+errFile

  ;Dependency condition - note needs overlap as well
         chkDep = PostSkip + 2*OvrSkip
         case chkDep of
            0: bsubEXE='bsub -q lotus -W 12:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobBUGSrad+' -w '+"'"+'ended('+jobPost+') && ended('+jobOVR+')'+"' "+tstr
            1: bsubEXE='bsub -q lotus -W 12:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobBUGSrad+' -w '+"'"+'ended('+jobOvr+')'+"' "+tstr
            2: bsubEXE='bsub -q lotus -W 12:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobBUGSrad+' -w '+"'"+'ended('+jobPost+')'+"' "+tstr
            3: bsubEXE='bsub -q lotus -W 12:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobBUGSrad+' '+tstr   
  ;; if postSkip eq 0 then begin
  ;;  bsubEXE='bsub -q lotus -W 12:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobBUGSrad+' -w '+"'"+'ended('+jobPost+')'+"' "+tstr
  ;; endif
 
  ;; ;No Dependency condition
  ;; if postSkip eq 1 then begin
  ;;  bsubEXE='bsub -q lotus -W 12:00 -R "order[-r15s:pg]" -o '+outFile+' -e '+errFile+' -J '+jobBUGSrad+' '+tstr   
         endcase
         if ~keyword_set(debug) then begin
            print,'SUBMIT BUGSrad'
            print,bsubEXE
            spawn,bsubEXE
         endif

         if keyword_set(debug) then begin
            print,'BUGSrad'
            print,tstr
            spawn,tstr
         endif
         print,''
         
      endif $
      else begin
         print,'Skipping Derived Products: ',chk(0)
         dervSkip = 1
      endelse
   endif
   print,''
   
ENDFOR                          ;each file

end
