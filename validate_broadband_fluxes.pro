pro validate_broadband_fluxes, year, month, $
                               satellite=satellite, $
                               station=station, $
                               d_or_n=d_or_n, $
                               subset=subset, $
                               version=version, $
                               dl=dl, $
                               dt=dt, $
                               replace=replace, $
                               get_files=get_files, $
                               run_orac=run_orac, $
                               replace_all=replace_all, $
                               process=process, $
                               ps = ps, $
                               prepath=prepath, mainpath=mainpath, $
                               postpath=postpath, radpath=radpath, $
                               savepath=savepath, $
                               qcflag=qcflag ,$
                               bugsrad=bugsrad ,$
                               fu_liou=fu_liou ,$
                               _ref_extra=ex

;
; Validate Broadband Fluxes
;
; Compares the ORAC broadband fluxes product to SURFRAD ground sites
; and CERES retrievals (currently MODIS-Terra only) for validation
; purposes.
;
; Calling Sequence:
;
; validate_broadband_fluxes, year, month, [satellite=string]
;                            [station=string], [d_or_n=string], 
;                            [version=string], [dl=value],
;                            [dt=value], [prepath=string],
;                            [mainpath=string], [postpath=string],
;                            [radpath=string], [savepath=string],
;                            [qcflag=qcflag],
;                            [/replace], [/get_files]
;                            [/replace_all], [/run_orac], [/subset],
;                            [/process], [/ps], [_EXTRA]
;
; Arguments:
;
; year - scalar or array input of years to analyse
; month - scalar or array input of months to analyes
;
; Keywords:
;
; satellite - string or string array input of satellite/sensor to
;             analyse. Will prompt input if missing or invalid.
;             Valid inputs:
;                'ATSR2' 'AATSR' 'MODIS-TERRA' 'MODIS-AQUA'
;   station - string or string array of SURFRAD ground sites to
;             analyse. Will prompt input if missing or invalid.
;             Valid inputs:
;                'Alamosa_CO' 'Bondville_IL' 'Boulder_CO'
;                'Desert_Rock_NV' 'Fort_Peck_MT' 'Goodwin_Creek_MS'
;                'Penn_State_PA' 'Rutland_VT' 'Sioux_Falls_SD'
;                'Wasco_OR' 
;    d_or_n - string or string array of day/night options. Will default
;             to 'D' if missing. Valid inputs: 'D' 'N'
;   version - 5 character length string. Will default to 'fv2.0' if
;             missing
;        dl - scalar value. Distance to ground site to average satellite 
;             measurements over. If ge 1 value is treated as km, else if
;             lt 1 treated as degrees latitude. Defaults to 10km if 
;             missing.
;        dt - scalar integer. Number of time steps of ground site data
;             to average on each side of overpass time. Defaults to 5 
;             if missing.
;   prepath - string. Path to ORAC preprocessor output files. Default
;             dependent on subset keyword.
;  mainpath - string. Path to ORAC main processor output files.
;  postpath - string. Path to ORAC post-processor output files.
;   radpath - string. Path to ORAC broadband fluxes output files.
;  savepath - string. Path to root directory of idl save files for
;             ground station data, overpass locations and compared
;             data.
;    qcflag - array containing the qc flags to remove from the
;             data. QC flag descriptions:
;                1: missing ORAC data (cloud or flux)
;                2: missing ground site data
;                4: small colocation area (lt 1/3 of expected)
;                8: colocation to ground site not within 1km
;               16: colocation to CERES not within 5 minutes
;               32: large variance in cloud phase
;               64: large variance in surface albedo
;              128: large variance in toa albedo
;  /replace - boolean. Replace existing save files.
; /get_files - boolean. Download missing L1 and geo files for MODIS.
; /replace_all - boolean. Replace all existing ORAC files.
; /run_orac - boolean. Run ORAC on colocated overpass files
;   /subset - boolean. Subset ORAC retrievals around overpass location 
;             to reduce time for retrieval.
;  /process - boolean. Process ORAC overpass files and compare to
;             ground site and CERES data.
;       /ps - save plots to postscript files.
;    _EXTRA - extra keywords passed to run_orac_bsub.
;             e.g.:
;                fu_liou   - integer{1 to 3}. Run the ORAC broadband
;                            fluxes product using the fu liou model in
;                            one of the following modes:
;                               1 - 4 stream
;                               2 - 2 stream gamma corrected
;                               3 - 2 stream
;                /heritage - boolean. Run ORAC in heritage (reduced
;                            channels) mode. Overriding option for
;                            ATSR sensors.
;                /replace_ - boolean. replace specific outputs of the
;                            ORAC processor
;
;
; Example calling sequence:
;
; validate_broadband_fluxes, 2008, [1,4,7,10], satellite='MODIS-TERRA', $
;                            station='Bondville_IL', version='fv4.1', $
;                            /run_orac, fu_liou=1, /process
;
; 2016/08/10, WJ: created from "compare_orac_surfrad.pro". Added
;   match_orbits procedure and subsetting of ORAC retrievals to 
;   improve speed.
; 2016/08/22, WJ: Rebuild as more modular structure.
; 2016/08/24, WJ: Debugged colocation procedures for ATSR and MODIS,
;   added ORAC bsub section.
; 2016/08/31, WJ: Improved ORAC submission, integrated processing of
;   matched files and plotting routines.
; 2016/09/01, WJ: Bug fix for non-heritage mode.
;
; Subroutines:
;
;   coyote graphics library
;
;   generic/get_ct.pro   
;   generic/read_hdf4.pro  
;   generic/set_op.pro     
;   generic/val_check_batch.pro    
;   generic/val_get_dist.pro  
;   generic/val_loop_ctrl.pro
;   generic/is_ncdf.pro  
;   generic/read_ncdf.pro  
;   generic/str_rebin.pro  
;   generic/val_check_keyword.pro  
;   generic/val_get_doy.pro   
;   generic/val_struct_concat.pro     
;
;   val_colocate_satellite.pro  
;   val_find_ecmwf_files.pro  
;   val_get_station_loc.pro        
;   val_orac_bsub.pro          
;   val_read_modis_geometa.pro
;   val_atsr_file_info.pro  
;   val_compare_scatter.pro     
;   val_find_overpass.pro     
;   val_process_nc.pro         
;   val_read_surfrad.pro
;   val_colocate_atsr.pro   
;   val_compare_versions.pro    
;   val_get_atsr_geometa.pro  
;   val_match_modis_geometa.pro    
;   val_process.pro
;   val_colocate_modis.pro  
;   val_download_modis.pro      
;   val_get_station_data.pro  
;   val_modis_file_info.pro        
;   val_read_atsr_geometa.pro
;


;===============================================================================
; Define defaults for file paths and keywords
;===============================================================================

gws_path = '/group_workspaces/cems2/nceo_generic/cloud_ecv/'

;Define default ORAC output paths
if KEYWORD_SET(subset) then begin
   def_prepath = gws_path+'data_out/validation/'
   def_mainpath = gws_path+'data_out/validation/'
   def_postpath = gws_path+'data_out/validation/'
   def_radpath = gws_path+'data_out/validation/'
endif $
else begin
   def_prepath = gws_path+'data_out/preproc/'
   def_mainpath = gws_path+'data_out/mainproc/'
   def_postpath = gws_path+'data_out/postproc/'
   def_radpath = gws_path+'data_out/validation/broadband_fluxes/'
endelse
;

;Check output path inputs, set to defaults if undefined
if N_ELEMENTS(prepath) eq 0 then prepath = def_prepath
if N_ELEMENTS(mainpath) eq 0 then mainpath = def_mainpath
if N_ELEMENTS(postpath) eq 0 then postpath = def_postpath
if N_ELEMENTS(radpath) eq 0 then radpath = def_radpath


;Define default path to MODIS data
modispath = gws_path+'modis_c6/'


;Define path to CERES data and root name
CERESpath = gws_path+'validation/ceres/'
CERESname = 'CERES_SSF_Terra-XTRK_Edition4A_Subset_'


;Define default save path
def_savepath = gws_path+'validation/idl/'
if N_ELEMENTS(savepath) eq 0 then savepath = def_savepath

;create save directory if none exists
spawn, 'mkdir -p -v '+savepath+'proc/'

;Define valid satellite and ground station inputs
def_sats = ['MODIS-TERRA','MODIS-AQUA','AATSR','ATSR2'];,'SEVIRI']
def_gs = ['Alamosa_CO','Bondville_IL','Boulder_CO','Desert_Rock_NV', $
          'Fort_Peck_MT','Goodwin_Creek_MS','Penn_State_PA','Rutland_VT', $
          'Sioux_Falls_SD','Wasco_OR']

if N_ELEMENTS(station) eq 1 && station eq 'all' then $
   station = ['Bondville_IL','Boulder_CO','Desert_Rock_NV', $
              'Fort_Peck_MT','Goodwin_Creek_MS','Penn_State_PA']

;Set dl to default of 10km if not set
if N_ELEMENTS(dl) eq 0 then dl = 10

;get distance and convert to km (for grid squares)
dkm = dl
if dkm lt 1 then dkm = dkm*(6371*2*!pi)/360
dkm = FIX(dkm)
;min value for colocating CERES measurements
dkm >= 25

;Set dt to default of 5 if not set
if N_ELEMENTS(dt) eq 0 then dt = 5


;Set day or night to day if not set
if N_ELEMENTS(d_or_n) eq 0 then d_or_n = 'D'
;note - should change this to both?


;Check satellite and station inputs are valid, if not prompt input
VAL_CHECK_KEYWORD, satellite, def_sats, key_name='satellite'
VAL_CHECK_KEYWORD, station, def_gs, key_name='station'


;Check version keyword
if N_ELEMENTS(version) eq 0 then version = 'fv2.0'

;Get array lengths of inputs
n_sat = N_ELEMENTS(satellite)
n_gs = N_ELEMENTS(station)
n_month = N_ELEMENTS(month)
n_year = N_ELEMENTS(year)
n_dn = N_ELEMENTS(d_or_n)

;Set up loop ctrl (to loop over all variables at once)
C = VAL_LOOP_CTRL(['station','d_or_n','month','year','satellite'], $
                  station,d_or_n,month,year,satellite)

;===============================================================================
; Get ground station data and locations
;===============================================================================

gs_files = VAL_GET_STATION_DATA(station=station, year=year, month=month)

;Rebin to include multiple sats
gs_files = REFORM(gs_files, [n_gs,1,n_year*n_month])
gs_files = STR_REBIN(gs_files, [n_gs,n_dn,n_year*n_month,n_sat])
gs_files = REFORM(gs_files, C.n)

;===============================================================================
; Find overpassing orbits
;===============================================================================

;Define empty list for orbit files
orbit_saves = list()

;Set up loop ctrl (to loop over all variables at once)
C2 = VAL_LOOP_CTRL(['d_or_n','month','year','satellite'], $
               d_or_n,month,year,satellite)

;Loop over control, producing a list C2.n long, each element being an
;array of n_gs length
for i = 0,C2.n-1 do begin
   orbit_saves.add, VAL_COLOCATE_SATELLITE(C2.satellite[i], C2.year[i], $
                                       C2.month[i], dl, station=station, $
                                       d_or_n=C2.d_or_n[i], replace=replace, $
                                       get_files=get_files)
endfor

;?

if N_ELEMENTS(station) gt 1 then $
   orbit_saves = orbit_saves.toarray(dimension=1) $
else orbit_saves = orbit_saves.toarray()
n_saves = n_elements(orbit_saves)

;===============================================================================
; Process colocated files for ORAC - subsetted
;===============================================================================

if KEYWORD_SET(subset) then begin
   run_ct = INTARR(C.n)

   prefix = list()

   for i = 0,n_saves-1 do begin

      if orbit_saves[i] ne '' then begin
      
         temp = FILE_SEARCH(orbit_saves[i], count=file_ct)
         
         if file_ct gt 0 then begin
            run_ct[i] = 1
            
                                ;Restore colocation file
            RESTORE, orbit_saves[i]
            X0 = cx - dkm + 1
            X0 >= 1
            X1 = cx + dkm + 1
            Y0 = cy - dkm + 1
            Y0 >= 1
            Y1 = cy + dkm + 1
            
                                ;Find sensor name from L1 file name
            sensor = STRMID(FILE_BASENAME(l1_files),0,8)
            
            sensor[WHERE(sensor eq 'MYD021KM',/null)] = 'MODIS-AQUA'
            sensor[WHERE(sensor eq 'MOD021KM',/null)] = 'MODIS-TERRA'
            sensor[WHERE(sensor eq 'AT2_TOA_',/null)] = 'ATSR2'
            sensor[WHERE(sensor eq 'ATS_TOA_',/null)] = 'AATSR'
            
            sensor1 = sensor
            sensor1[WHERE(sensor eq 'MODIS-AQUA' or $
                          sensor eq 'MODIS-TERRA', /null)] = 'MODIS'
         
            platform = sensor
            platform[WHERE(sensor eq 'MODIS-AQUA', /null)] = 'AQUA'
            platform[WHERE(sensor eq 'MODIS-TERRA', /null)] = 'TERRA'
            platform[WHERE(sensor eq 'ATSR2', /null)] = 'ERS2'
            platform[WHERE(sensor eq  'AATSR', /null)] = 'Envisat'

                                ;Get date strings
            CALDAT, date, mo, dy, yr, hr, mn, sc
            mostr = STRING(mo, format='(I02)')
            dystr = STRING(dy, format='(I02)')
            yrstr = STRING(yr, format='(I04)')
            hrstr = STRING(hr, format='(I02)')
            mnstr = STRING(mn, format='(I02)')
            
                                ;Generate subdirectory names for subsetted files
            subdir = sensor+'/'+yrstr+'/'+mostr+'/'+dystr+'/'+C.station[i]
            
            rprefix = subdir+'/ESACCI-L2-CLOUD-CLD-'+sensor1+'_CC4CL_'+ $
                      platform+'_'+yrstr+mostr+dystr+hrstr+mnstr+'_'+version
            
            prefix.add, rprefix

            rprepath = prepath+subdir+'/PRE'
            rprocpath = mainpath+subdir
            rpostpath = postpath+subdir
            rderpath = radpath+subdir

            n_run = N_ELEMENTS(l1_files)

            if ~KEYWORD_SET(replace_all) then begin
               ;Check for existing broadband fluxes output files
               temp = SET_OP(radpath+rprefix+'.bugsrad.nc', $
                             FILE_SEARCH(radpath+rprefix+'.bugsrad.nc', $
                                         count=rad_ct), diff_ind=wh)
            endif $
            else begin 
               wh = INDGEN(n_run)
               rad_ct = 0
            endelse

;===============================================================================
; Submit ORAC jobs
;===============================================================================

            if KEYWORD_SET(run_orac) && rad_ct lt n_run then begin
               ;Submit batch jobs
               for j = 0,N_ELEMENTS(wh)-1 do begin
                  k = wh[j]
                  
                  if sensor[k] eq 'ATSR2' or sensor[k] eq 'AATSR' then h = 1 $
                  else if KEYWORD_SET(heritage) then h = 1 $
                  else h = 0

                  if C.d_or_n[i] eq 'D' then dn = '1' $
                  else if C.d_or_n[i] eq 'N' then dn = '2'
               

                  VAL_ORAC_BSUB, l1file=l1_files[k], geofile=geo_files[k], $
                                 /rPre, /rWat, /rIce, /rPst, /rDer, $
                                 preprocpath=rprepath[k], $
                                 procpath=rprocpath[k], $
                                 postpath=rpostpath[k], $
                                 derivedproductspath=rderpath[k], $
                                 version=version, heritage=h, $
                                 x0=x0[k], x1=x1[k], y0=y0[k], y1=y1[k], $
                                 day_night=dn, replace_all=replace_all, $
                                 bugsrad=bugsrad, fu_liou=fu_liou ,$
                                 _extra=ex
               endfor
            endif
         endif 
      endif
   ;End loop over save files
   endfor
endif

;===============================================================================
; Process colocated files for ORAC - entire files
;===============================================================================

;Submit ORAC for whole L1 files
;List of files reduced to only use unique files
if ~KEYWORD_SET(subset) then begin

   ;Define lists to hold saved variables before concatenating
   all_l1 = list()
   all_geo = list()
   all_date = list()

   run_ct = INTARR(C.n)

   prefix = list()
   
   for i = 0,n_saves-1 do begin
      
      if orbit_saves[i] ne '' then begin
         
         temp = FILE_SEARCH(orbit_saves[i], count=file_ct)
      
         if file_ct gt 0 then begin
            run_ct[i] = 1
            
            ;Restore colocation file
            RESTORE, orbit_saves[i]
            all_l1.add, l1_files
            all_geo.add, geo_files
            all_date.add, date
            
            ;Process output prefix names

            ;Find sensor name from L1 file name
            sensor = STRMID(FILE_BASENAME(l1_files),0,8)
      
            sensor[WHERE(sensor eq 'MYD021KM',/null)] = 'MODIS-AQUA'
            sensor[WHERE(sensor eq 'MOD021KM',/null)] = 'MODIS-TERRA'
            sensor[WHERE(sensor eq 'AT2_TOA_',/null)] = 'ATSR2'
            sensor[WHERE(sensor eq 'ATS_TOA_',/null)] = 'AATSR'
            
            sensor1 = sensor
            sensor1[WHERE(sensor eq 'MODIS-AQUA' or $
                          sensor eq 'MODIS-TERRA', /null)] = 'MODIS'
            
            platform = sensor
            platform[WHERE(sensor eq 'MODIS-AQUA', /null)] = 'AQUA'
            platform[WHERE(sensor eq 'MODIS-TERRA', /null)] = 'TERRA'
            platform[WHERE(sensor eq 'ATSR2', /null)] = 'ERS2'
            platform[WHERE(sensor eq  'AATSR', /null)] = 'Envisat'

            ;Get date strings
            CALDAT, date, mo, dy, yr, hr, mn, sc
            mostr = STRING(mo, format='(I02)')
            dystr = STRING(dy, format='(I02)')
            yrstr = STRING(yr, format='(I04)')
            hrstr = STRING(hr, format='(I02)')
            mnstr = STRING(mn, format='(I02)')

            ;Generate subdirectory names for subsetted files
            subdir = sensor+'/'+yrstr+'/'+mostr+'/'+dystr+'/'
      

            ;Add to prefix list
            prefix.add, subdir+'/ESACCI-L2-CLOUD-CLD-'+sensor1+'_CC4CL_'+ $
                        platform+'_'+yrstr+mostr+dystr+hrstr+mnstr+'_'+version

         endif $
         else begin
            all_l1.add, !NULL
            all_geo.add, !NULL
            all_date.add, !NULL
            prefix.add, !NULL
         endelse
      endif
   endfor

   if TOTAL(run_ct) gt 0 then begin
      l1_files = all_l1.toarray(dimension=1)
      geo_files = all_geo.toarray(dimension=1)
      date = all_date.toarray(dimension=1)
      rprefix = prefix.toarray(dimension=1)
      
      ;Find sensor name from L1 file name
      sensor = STRMID(FILE_BASENAME(l1_files),0,8)
      
      sensor[WHERE(sensor eq 'MYD021KM',/null)] = 'MODIS-AQUA'
      sensor[WHERE(sensor eq 'MOD021KM',/null)] = 'MODIS-TERRA'
      sensor[WHERE(sensor eq 'AT2_TOA_',/null)] = 'ATSR2'
      sensor[WHERE(sensor eq 'ATS_TOA_',/null)] = 'AATSR'
      
      sensor1 = sensor
      sensor1[WHERE(sensor eq 'MODIS-AQUA' or $
                    sensor eq 'MODIS-TERRA', /null)] = 'MODIS'
      
      platform = sensor
      platform[WHERE(sensor eq 'MODIS-AQUA', /null)] = 'AQUA'
      platform[WHERE(sensor eq 'MODIS-TERRA', /null)] = 'TERRA'
      platform[WHERE(sensor eq 'ATSR2', /null)] = 'ERS2'
      platform[WHERE(sensor eq  'AATSR', /null)] = 'Envisat'
   
      ;Get date strings
      CALDAT, date, mo, dy, yr, hr, mn, sc
      mostr = STRING(mo, format='(I02)')
      dystr = STRING(dy, format='(I02)')
      yrstr = STRING(yr, format='(I04)')
      hrstr = STRING(hr, format='(I02)')
      mnstr = STRING(mn, format='(I02)')

      ;Generate subdirectory names for subsetted files
      subdir = sensor+'/'+yrstr+'/'+mostr+'/'+dystr+'/'
      
      ;prefix = subdir+'/ESACCI-L2-CLOUD-CLD-'+sensor1+'_CC4CL_'+ $
      ;         platform+'_'+yrstr+mostr+dystr+hrstr+mnstr+'_'+version

      rprepath = prepath+subdir
      rprocpath = mainpath+subdir
      rpostpath = postpath+subdir
      rderpath = radpath+subdir

      ;Get unique input files to avoid submitting duplicate jobs
      wh_uniq = UNIQ(l1_files, SORT(l1_files))

      if ~KEYWORD_SET(replace_all) then begin
         temp = SET_OP(radpath+rprefix[wh_uniq]+'.bugsrad.nc', $
                       FILE_SEARCH(radpath+rprefix[wh_uniq]+'.bugsrad.nc', $
                                   count=rad_ct), diff_ind=wh)
      endif $
      else begin 
         wh = INDGEN(N_ELEMENTS(wh_uniq))
         rad_ct = 0
      endelse

;===============================================================================
; Submit ORAC jobs
;===============================================================================
      
      if KEYWORD_SET(run_orac) && rad_ct lt N_ELEMENTS(wh_uniq) then begin
         wh = wh_uniq[wh]
      
         n_run = N_ELEMENTS(wh)
      
         for j = 0,n_run-1 do begin
            
            k = wh[j]

            if sensor[k] eq 'ATSR2' or sensor[k] eq 'AATSR' then h = 1 $
            else if KEYWORD_SET(heritage) then h = 1 $
            else h = 0

            VAL_ORAC_BSUB, l1file=l1_files[k], geofile=geo_files[k], $
                           /rPre, /rWat, /rIce, /rPst, /rDer, $
                           preprocpath=rprepath[k], procpath=rprocpath[k], $
                           postpath=rpostpath[k], $
                           derivedproductspath=rderpath[k], $
                           version=version, $
                           day_night=dn, $
                           bugsrad=bugsrad ,$
                           fu_liou=fu_liou ,$
                           _extra=ex
         endfor
      endif
   endif
endif

;===============================================================================
; Process and compare colocated ORAC, ground site and CERES files
;===============================================================================

if KEYWORD_SET(process) then begin

   ;Wait until all batch jobs have completed
   if KEYWORD_SET(run_orac) then VAL_CHECK_BATCH

   ;Generate save names for colocation process files
   yrstr = string(format='(I04)',C.year)
   mostr = string(format='(I02)',C.month)

   save_name = C.satellite+'_'+C.station+'_'+yrstr+mostr+'_'+ $
               version+'_'+d_or_n+'_dl='+STRTRIM(STRING(dl),1)+ $
               '_dt='+STRTRIM(STRING(dt),1)+'.sav'

   proc_saves = savepath+'proc/'+save_name
   
   ;Loop over files to process
   for i = 0,C.n-1 do begin
      ;Search for existing files
      temp = FILE_SEARCH(proc_saves[i], count=proc_ct)
      
      ;If no file found begin colocation processing
      if proc_ct eq 0 then begin

         PRINT, 'Processing '+save_name[i]
      
         ;Find CERES data file - note, only 2008 currently!
         ;need to download using online tool
         CERES_file = FILE_SEARCH(CERESpath+CERESname+C.station[i]+'*', $
                                 count=junkct)

         VAL_PROCESS, prefix[i], gs_files[i], CERES_file, $
                      orac_out, gs_out, ceres_out, $
                      postpath=postpath, $
                      radpath=radpath, $
                      dl=dl[0], dt=dt[0], $
                      station=C.station[i], $
                      satellite=C.satellite[i], $
                      qc_out=qc_out

         ;save processed files
         PRINT, 'Saving '+save_name[i]

         orac_files = prefix[i]
         gs_file = gs_files[i]

         SAVE, orac_files, gs_file, CERES_file, $
               orac_out, gs_out, ceres_out, qc_out, $
               filename=proc_saves[i]

      endif $
      else begin
         PRINT, 'Restoring '+save_name[i]
         RESTORE, proc_saves[i]
      endelse

      ;Check if structure is valid, if so concatenate
      if N_ELEMENTS(orac_out.(0)) gt 5 then begin
         if N_ELEMENTS(orac) eq 0 then begin 
            ;If first files to be found, definte variables
            orac = orac_out
            gs = gs_out
            ceres = ceres_out
            qc = list(qc_out)
         endif $
         else begin
            ;Otherwise concatenate structures
            VAL_STRUCT_CONCAT, orac, orac_out, dimension=1
            VAL_STRUCT_CONCAT, gs, gs_out, dimension=1
            VAL_STRUCT_CONCAT, ceres, ceres_out, dimension=1
            qc.add, qc_out
         endelse
      endif
   ;End loop over processes save files
   endfor

;===============================================================================
; Check QC data for best matches
;===============================================================================

   n_qc = N_ELEMENTS(qcflag)

   if n_qc gt 0 then begin
      ;convert qc flags to array
      qc = qc.toarray(dimension=1)

      ;create list for bad qc indices
      wh_qc = list()

      for i = 0,n_qc-1 do begin
         
         wh = WHERE((qc and qcflag[i]) eq qcflag[i], /null, ct)
         if ct gt 0 then wh_qc.add, wh

      endfor

      wh_qc = wh_qc.toarray(dimension=1)

      if N_ELEMENTS(wh_qc) gt 0 then begin

         wh_qc = wh_qc[UNIQ(wh_qc, SORT(wh_qc))]

         for j = 0,4 do begin
            orac.boa.(j)[wh_qc,*] = !values.f_nan
            gs.boa.(j)[wh_qc,*] = !values.f_nan
         endfor
         
         for j = 0,2 do begin
            orac.toa.(j)[wh_qc,*] = !values.f_nan
            ceres.toa.(j)[wh_qc,*] = !values.f_nan
         endfor
      endif
   endif
   
;===============================================================================
; Plot colocated data
;===============================================================================

   !p.font=1
   
   flx = ['SW down','SW up','LW down','LW up', 'PAR']

   if KEYWORD_SET(fu_liou) then alg_name = 'Fu_Liou' $
                           else alg_name = 'BUGSrad'
   
   for j = 0,4 do begin
      imtitle = alg_name+' '+satellite+' '+version+' BoA '+flx[j]+' - '+yrstr
      CGWINDOW, 'val_compare_scatter', gs.boa.(j),orac.boa.(j)[*,0], $
                orac.cot[*,0], orac.ctype, $
                title = imtitle, prefix=flx[j], $
                /percent
   endfor
   
   flx = flx[[0,1,3]]
   
   for j = 0,2 do begin
      imtitle = alg_name+' '+satellite+' '+version+' ToA '+flx[j]+ $
                ' vs CERES - '+yrstr
      CGWINDOW, 'val_compare_scatter', ceres.toa.(j),orac.toa.(j)[*,0], $
                orac.cot[*,0], orac.ctype, $
                title=imtitle, prefix=flx[j], $
                /percent
   endfor
   
   if KEYWORD_SET(ps) then begin
      flx = ['SWdn','SWup','LWdn','LWup', 'PAR']
      version = STRMID(version,0,3)+'_'+STRMID(version,4,1)
      
      for j = 0,4 do begin
         imtitle = alg_name+' '+satellite+' '+version+' BoA '+flx[j]+' - '+yrstr
         imname = '~/'+satellite+'_'+version+'_BoA_'+flx[j]
         CGPS_OPEN, imname+'.ps', font=1, default_thickness=1.5, $
                    tt_font = 'helvetica'
         VAL_COMPARE_SCATTER, gs.boa.(j), orac.boa.(j)[*,0], $
                              orac.cot[*,0],orac.ctype, $
                              title = imtitle, prefix=flx[j], /percent
         CGPS_CLOSE
         SPAWN, 'convert '+imname+'.ps '+imname+'.png'
      endfor
      
      flx = flx[[0,1,3]]

      for j = 0,2 do begin
         imtitle = alg_name+' '+satellite+' '+version+' ToA '+flx[j]+ $
                   ' vs CERES - '+yrstr
         imname = '~/'+satellite+'_'+version+'_ToA_'+flx[j]
         CGPS_OPEN, imname+'.ps', font=1, default_thickness=1.5, $
                    tt_font = 'helvetica'
         VAL_COMPARE_SCATTER, ceres.toa.(j), orac.toa.(j)[*,0], $
                              orac.cot[*,0], orac.ctype, $
                              title = imtitle, prefix=flx[j], /percent
         CGPS_CLOSE
         SPAWN, 'convert '+imname+'.ps '+imname+'.png'
      endfor
   endif

endif


stop

         

end
