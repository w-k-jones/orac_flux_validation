pro val_process, orac_files, $ ;file prefixes for orac files
                 gs_file, $    ;file name and path of ground station file
                 CERES_file, $ ;file name and path of CERES data file
                 orac_out, gs_out, ceres_out, $ ;output variables
                 postpath=postpath, radpath=radpath, $
                 dl=dl, dt=dt, $
                 prefix_out=prefix_out, $
                 station=station, $
                 satellite=satellite, $
                 QC_out=QC_out

gws_path = '/group_workspaces/cems2/nceo_generic/cloud_ecv/'

;define paths for ORAC products, only need post-processed and rad files
def_postpath = gws_path+'data_out/postproc/'
def_radpath = gws_path+'data_out/validation/broadband_fluxes/'

;if postpath and radpath keywords not set then use the default values
if N_ELEMENTS(postpath) eq 0 then postpath = def_postpath
if N_ELEMENTS(radpath) eq 0 then radpath = def_radpath

;check keyword input for dl, if not set use default value of 0.1
if N_ELEMENTS(dl) eq 0 then dl = 0.1

;get distance in km
if dl lt 1 then dkm = dl*(6371*2*!pi)/360 $
   else dkm = dl
dkm = FIX(dkm+0.01)
dkm2=dkm^2

;if gt 1 then assume distance in km, convert to degrees
if dl ge 1 then dl = dl/(6371*2*!pi)*360
dl2 = dl^2

;set up QC flag structure
QC = {no_orac:1B, no_gs:2B, area:4B, coloc_gs:8B, coloc_ceres:16B, $
      phase: 32B, sfc_a:64B, cc:128B}

;===============================================================================
; Load ground station netcdf file
;===============================================================================

;ground station netcdf variable names to load
gs_vars = ['time', 'latitude', 'longitude', 'solar_zenith_angle', $
           'swdn', 'swup', 'lwdn', 'lwup', 'par', 'T', 'P', 'q']

;index of boa flux and meteorology variables within the defined netcdf
;var names. Note that these won't be the actual structure indexes as the
;netcdf dimension values will also be read, so this needs to be
;accounted for using 'dtag' variables
gs_boa_inds = [4,5,6,7,8]
gs_met_inds = [9,10,11]

;read data
stat = READ_NCDF(gs_file, gs_data, variable_list=gs_vars)
if stat eq 1 then begin
   gs_dtag = N_TAGS(gs_data) - N_ELEMENTS(gs_vars)
   ;replace fill values with NaN
   for i = 0,N_ELEMENTS(gs_vars)-1 do begin
      wh_fill = WHERE(gs_data.(i+gs_dtag) eq -9999., /null, cnt)
      if cnt gt 0 then $
         gs_data.(i+gs_dtag)[wh_fill] = !values.f_nan
   endfor

   ;find tag locations with dimensions of time for taking mean over
   gs_wh = [gs_dtag+3:n_tags(gs_data)-1]
   gs_wh = [gs_dtag, gs_wh]

   ;find longitude adjustment factor for gs latitude.
   lon_fac = COS(gs_data.latitude*!pi/180)
endif $
   else MESSAGE, 'Failed to read surfrad files!' ;message if no file

;===============================================================================
; Load CERES data
;===============================================================================

;define CERES netcdf var names
CERES_vars = ['Time_of_observation', 'lat', 'lon', $
              'CERES_solar_zenith_at_surface', $
              'TOA_Incoming_Solar_Radiation', $
              'CERES_SW_TOA_flux___upwards', $
              'CERES_LW_TOA_flux___upwards']

;structure indexes of toa fluxes
CERES_toa_inds = [4,5,6]

ceres_data = VAL_PROCESS_NC(ceres_file[0], variable_list=CERES_vars, $
                            fillvalue=ceres_fills, dtag=ceres_dtag)

;===============================================================================
; Load and sort ORAC data
;===============================================================================

n_files = N_ELEMENTS(orac_files)

prim_vars = ['time', 'lat', 'lon', 'solar_zenith_view_no1', $
             'rel_azimuth_view_no1', 'stemp', 'cot']

rad_vars = ['retrflag', 'toa_swdn', 'toa_swup', 'toa_lwup', 'toa_par_tot', $
            'boa_swdn', 'boa_swup', 'boa_lwdn', 'boa_lwup', 'boa_par_tot', $
            'boa_tsfc', 'boa_psfc', 'boa_qsfc']
;defs = [typeflag (1,2, cloud, 3,4, clear, 5,6, aci), ..., T, P, q]

;for now just look at boa (until ceres data incorporated)
;boa_vars = ['time','retrflag', 'boa_swdn', 'boa_swup', 'boa_lwdn',
;            'boa_lwup', 'boa_tsfc', 'boa_psfc', 'boa_qsfc']

;inds for boa and toa var names from rad files
toa_inds = [1,2,3,4]
boa_inds = [5,6,7,8,9]
met_inds = [10,11,12]


;declare output arrays----------------------------------------------------------

;count of matched pixels
retr_cnt = INTARR(n_files)

;define arrays, using double values to accomodate julian day values.
primarr = DBLARR(n_files, 5, N_ELEMENTS(prim_vars))
radarr = DBLARR(n_files, 5, N_ELEMENTS(rad_vars))
gsarr = DBLARR(n_files, N_ELEMENTS(gs_wh))
ceresarr = DBLARR(n_files, N_ELEMENTS(CERES_vars))

;define array for modal cloud type
ctype = DBLARR(n_files)

;define array for QC flags
QCarr= BYTARR(n_files)


;===============================================================================
; Begin loop over files
;===============================================================================

for ind = 0,n_files-1 do begin

   prefix = orac_files[ind]
   ;check if files exist
   junk = FILE_SEARCH(postpath+prefix+'.primary.nc', count=junkct)
   junk = FILE_SEARCH(radpath+prefix+'.bugsrad.nc', count=junkct2)
   
   if junkct ne 0 && junkct2 ne 0 then begin
      PRINT, prefix

      prim_data = VAL_PROCESS_NC(postpath+prefix+'.primary.nc', $
                                 variable_list=prim_vars, $
                                 fillvalue=prim_fills, $
                                 dtag=prim_dtag)
      
                             ;want to update to give 20x20km grid,
                             ;or similar, and exclude files
                             ;that don't have full grid square
      wh = WHERE(VAL_GET_DIST(prim_data.lat, prim_data.lon, gs_data.latitude, $
                              gs_data.longitude) lt dl, $
                 cnt, /null)

      ;keep a count of number of pixels retrieved
      retr_cnt[ind] = cnt gt 0

      PRINT, 'matched pixels = '+string(cnt)

      if cnt ne 0 then begin
         ;Check # of colocatd pixels
         if cnt lt dkm2 then QCarr[ind] = QCarr[ind] or QC.area
         mlat = MEAN(prim_data.lat[wh], /nan)
         mlon = MEAN(prim_data.lon[wh], /nan)
         dd = VAL_GET_DIST(mlat, mlon, gs_data.latitude, $
                           gs_data.longitude, lon_fac=lon_fac)
         ;Convert to km
         dd = dd*(6371*2*!pi)/360
         if dd gt 1 then QCarr[ind] = QCarr[ind] or QC.coloc_gs


         ;======================================================================
         ;write mean of primary vars over colocated pixels to array
         ;======================================================================
         
         for j = 0,N_ELEMENTS(prim_vars)-1 do begin
            if N_ELEMENTS(prim_data.(j+prim_dtag)) gt 1 && $
               TOTAL(FINITE(prim_data.(j+prim_dtag)[wh])) gt 0 then begin

               primarr[ind,0,j] = MEAN(prim_data.(j+prim_dtag)[wh],/nan)
               primarr[ind,1,j] = MEDIAN(prim_data.(j+prim_dtag)[wh])
               primarr[ind,2,j] = MIN(prim_data.(j+prim_dtag)[wh],/nan)
               primarr[ind,3,j] = MAX(prim_data.(j+prim_dtag)[wh],/nan)
               primarr[ind,4,j] = STDDEV(prim_data.(j+prim_dtag)[wh],/nan)
            endif $
            else if N_ELEMENTS(prim_data.(j+prim_dtag)) eq 1 then begin
               primarr[ind,0:3,j] = prim_data.(j+prim_dtag)
               primarr[ind,4,j] = 0
            endif $
            else begin
               primarr[ind,0:4,j] = !values.f_nan
               QCarr[ind] = QCarr[ind] or QC.no_orac
            endelse
         endfor
         
         ;======================================================================
         ;load BUGSrad output file and extract colocated pixels
         ;======================================================================
         
         rad_data = VAL_PROCESS_NC(radpath+prefix+'.bugsrad.nc', $
                                   variable_list=rad_vars, $
                                   fillvalue=rad_fills, $
                                   dtag=rad_dtag)
         
         ;check for flux values lt 0
         for i = 1,9 do begin
            wh_neg = WHERE(rad_data.(i+rad_dtag) lt 0, /null, cnt)
            if cnt gt 0 then $
               rad_data.(i+rad_dtag)[wh_neg] = !values.f_nan
         endfor

         ;check for SW_up gt SW_dn
         wh_fill = WHERE(rad_data.boa_swup gt rad_data.boa_swdn, /null, cnt)
         if cnt gt 0 then $
            rad_data.boa_swup[wh_fill] = !values.f_nan

         ;dtag = n_tags(rad_data)-n_elements(rad_vars) ;get # of dimension tags to avoid outputting)
         radarr[ind,0] = MEAN((rad_data.retrflag[wh] ne 3) * $
                              (rad_data.retrflag[wh] ne 4) ,/nan)
         hh = HISTOGRAM(rad_data.retrflag[wh], min=0)
         whm = REVERSE(sort(hh))
         ctype[ind] = whm[0]
         
         if hh[whm[0]] lt 2* hh[whm[1]] then $
            QCarr[ind] = QCarr[ind] or QC.phase

         for j = 1,N_ELEMENTS(rad_vars)-1 do begin
            if N_ELEMENTS(rad_data.(j+rad_dtag)) gt 1 && $
               TOTAL(FINITE(rad_data.(j+rad_dtag)[wh])) gt 0 then begin

               radarr[ind,0,j] = MEAN(rad_data.(j+rad_dtag)[wh],/nan)
               radarr[ind,1,j] = MEDIAN(rad_data.(j+rad_dtag)[wh])
               radarr[ind,2,j] = MIN(rad_data.(j+rad_dtag)[wh],/nan)
               radarr[ind,3,j] = MAX(rad_data.(j+rad_dtag)[wh],/nan)
               radarr[ind,4,j] = STDDEV(rad_data.(j+rad_dtag)[wh],/nan)
            endif $
            else if N_ELEMENTS(rad_data.(j+rad_dtag)) eq 1 then begin 
               radarr[ind,0:3,j] = rad_data.(j+rad_dtag)
               radarr[ind,4,j] = 0
            endif $
            else begin
               radarr[ind,*,j] = !values.f_nan
               QCarr[ind] = QCarr[ind] or QC.no_orac
            endelse
         endfor

         ;check consistency of surface albedo, cloud cover
         wh_swup = WHERE(rad_vars eq 'boa_swup')
         if ABS(radarr[ind,0,wh_swup]) lt 2*radarr[ind,4,wh_swup] then $
            QCarr[ind] = QCarr[ind] or QC.sfc_a

         wh_swdn = WHERE(rad_vars eq 'boa_swdn')
         if ABS(radarr[ind,0,wh_swdn]) lt 2*radarr[ind,4,wh_swdn] then $
            QCarr[ind] = QCarr[ind] or QC.cc
         
         ;======================================================================
         ;get interpolated (linear) values for surfrad station
         ;======================================================================

         ;calculate mean overpass time and find
         ;adjacent ground station time values
         optime = MEAN(prim_data.time[wh], /nan)
         opzen = MEAN(prim_data.solar_zenith_view_no1[wh], /nan)
         opazi = MEAN(prim_data.rel_azimuth_view_no1[wh], /nan)
         
         VAL_FIND_OVERPASS, gs_data, optime, opzen, opazi, $
                            wh_up=wh_up, wh_dn=wh_dn
         
         zenup = gs_data.solar_zenith_angle[wh_up]
         zendn = gs_data.solar_zenith_angle[wh_dn]
         
         weight = [(zenup-opzen)/(zenup-zendn),(opzen-zendn)/(zenup-zendn)]
            
         if N_ELEMENTS(dt) eq 0 then begin
            for j = 0,N_ELEMENTS(gs_wh)-1 do begin
            ;check if adjacent values are finite,
            ;if both are interpolate, if either
            ;exists take that one, if neither
            ;return NaN
               whf = TOTAL(finite((gs_data.(gs_wh[j]))[wh_dn:wh_up]))
               case whf of
                  2: gsarr[ind,j] = TOTAL((gs_data.(gs_wh[j]))[wh_dn:wh_up] * $
                                          weight)
                  1: gsarr[ind,j] = TOTAL((gs_data.(gs_wh[j]))[wh_dn:wh_up], $
                                          /nan)
                  0: begin
                     gsarr[ind,j] = !values.f_nan
                     QCarr[ind] = QCarr[ind] or QC.no_gs
                  end
               endcase
            endfor
         endif $
         else $
            for j = 0,N_ELEMENTS(gs_wh)-1 do begin
            temp = (gs_data.(gs_wh[j]))[wh_dn-dt+1:wh_up+dt-1]
            if N_ELEMENTS(finite(temp)) gt 0 then $
               gsarr[ind,j] = MEAN(temp, /nan) $
            else begin
               gsarr[ind,j] = !values.f_nan
               QCarr[ind] = QCarr[ind] or QC.no_gs
            endelse
         endfor
         


         ;======================================================================
         ;locate and interpolate CERES overpass pixels (20x20km)
         ;======================================================================

         ;find temporally near CERES pixels to overpass
         wh_t = WHERE(CERES_data.Time_of_observation gt $
                           fix(min(prim_data.time), type=3) and $
                      CERES_data.Time_of_observation lt $
                           fix(max(prim_data.time), type=3)+0.5, /null, cnt)
         
         if cnt gt 0 then begin

            c_wh = wh_t[(SORT(VAL_GET_DIST(ceres_data.lat[wh_t], $
                                           ceres_data.lon[wh_t], $
                                           gs_data.latitude, $
                                           gs_data.longitude)))[0]]
            
            wh = WHERE(VAL_GET_DIST(prim_data.lat, $
                                    prim_data.lon, $
                                    ceres_data.lat[c_wh], $
                                    ceres_data.lon[c_wh]) lt 0.1, cnt, /null)

            for j = 0, N_ELEMENTS(ceres_vars)-1 do $
               ceresarr[ind,j] = ceres_data.(j+ceres_dtag)[c_wh]

            if cnt gt 0 then begin

               mlat = MEAN(prim_data.lat[wh], /nan)
               mlon = MEAN(prim_data.lon[wh], /nan)
               dd = VAL_GET_DIST(mlat, mlon, ceres_data.lat[c_wh], $
                                 ceres_data.lon[c_wh])
               dd = dd*(6371*2*!pi)/360
               ddt = ABS(CERES_data.Time_of_observation[c_wh] - $
                         primarr[ind,0,0])
               if dd gt 1 or ddt gt 0.0035 then $ ;approx 5 min
                  QCarr[ind] = QCarr[ind] or QC.coloc_ceres


               for j = 0,2 do begin 
                  radarr[ind,0,toa_inds[j]] = $
                     MEAN(rad_data.(toa_inds[j]+rad_dtag)[wh],/nan)

                  radarr[ind,1,toa_inds[j]] = $
                     MEDIAN(rad_data.(toa_inds[j]+rad_dtag)[wh])

                  radarr[ind,2,toa_inds[j]] = $
                     MIN(rad_data.(toa_inds[j]+rad_dtag)[wh],/nan)

                  radarr[ind,3,toa_inds[j]] = $
                     MAX(rad_data.(toa_inds[j]+rad_dtag)[wh],/nan)

                  radarr[ind,4,toa_inds[j]] = $
                     STDDEV(rad_data.(toa_inds[j]+rad_dtag)[wh],/nan)

               endfor
            endif $
            else for j = 0,2 do $
               radarr[ind, *, toa_inds[j]] = !values.f_nan

         endif $
            else for j = 0, N_ELEMENTS(ceres_vars)-1 do $
               ceresarr[ind,j] = !values.f_nan

      endif
   endif
   
   PRINT, QCarr[ind]

endfor

wh = WHERE(retr_cnt gt 0)

print, N_ELEMENTS(wh)

prefix_out = orac_files[wh]
QC_out = QCarr[wh]

primarr = primarr[wh,*,*]
radarr = radarr[wh,*,*]
gsarr = gsarr[wh,*]
ceresarr = ceresarr[wh,*]
ctype = ctype[wh]

;===============================================================================
; Sort data into hashes then convert to structures for output
;===============================================================================

boa_keys = ['swdn','swup','lwdn','lwup','par']
toa_keys = ['swdn','swup','lwup','par']

;gs data------------------------------------------------------------------------

gs_keys = ['filename','station','time','lat','lon','szen','boa','met']

dtag = -2

gs_boa_vars = list()

for i = 0,N_ELEMENTS(gs_boa_inds)-1 do $
   gs_boa_vars.add, gsarr[*, gs_boa_inds[i]+dtag]

                   ;; gsarr[*, gs_boa_inds[0]+dtag], $
                   ;; gsarr[*, gs_boa_inds[1]+dtag], $
                   ;; gsarr[*, gs_boa_inds[2]+dtag], $
                   ;; gsarr[*, gs_boa_inds[3]+dtag])

gs_boa = ORDEREDHASH(boa_keys, gs_boa_vars, /fold_case)

met_keys=['t_air','p','q']

gs_met_vars = list()

for i = 0,N_ELEMENTS(gs_met_inds)-1 do $
   gs_met_vars.add, gsarr[*, gs_met_inds[i]+dtag]

                   ;; gsarr[*, gs_met_inds[0]+dtag], $
                   ;; gsarr[*, gs_met_inds[1]+dtag], $
                   ;; gsarr[*, gs_met_inds[2]+dtag])

gs_met = ORDEREDHASH(met_keys, gs_met_vars, /fold_case)

values = list(replicate(gs_file[0], n_elements(wh)), $
              replicate(station, n_elements(wh)), $
              gsarr[*, 0], $
              replicate(gs_data.latitude,n_elements(wh)), $
              replicate(gs_data.longitude,n_elements(wh)), $
              gsarr[*, 1], $
              gs_boa, $
              gs_met)

gs_hash = ORDEREDHASH(gs_keys, values)

gs_out = gs_hash.tostruct(/recursive)

;dtag = n_tags(rad_data)-n_elements(rad_vars)

;orac data----------------------------------------------------------------------

orac_keys = ['filename', 'satellite', 'time', 'lat', 'lon', 'szen', $
             'cot', 'cfrac', 'ctype', 'boa', 'toa', 'met']

;dtag = n_tags(prim_data)-n_elements(prim_vars)

orac_boa_vars = list()

for i = 0,N_ELEMENTS(boa_inds)-1 do $
   orac_boa_vars.add, radarr[*, *, boa_inds[i]]

                     ;; radarr[*, *, boa_inds[0]], $
                     ;; radarr[*, *, boa_inds[1]], $
                     ;; radarr[*, *, boa_inds[2]], $
                     ;; radarr[*, *, boa_inds[3]])

orac_boa = ORDEREDHASH(boa_keys, orac_boa_vars, /fold_case)

orac_toa_vars = list()

for i = 0,N_ELEMENTS(toa_inds)-1 do $
   orac_toa_vars.add, radarr[*, *, toa_inds[i]]

                     ;; radarr[*, *, toa_inds[0]], $
                     ;; radarr[*, *, toa_inds[1]], $
                     ;; radarr[*, *, toa_inds[2]])

orac_toa = ORDEREDHASH(toa_keys, orac_toa_vars, /fold_case)

met_keys=['t_air','t_sfc','p','q']

orac_met_vars = list(radarr[*, *, met_inds[0]], $
                     primarr[*, *, 5], $
                     radarr[*, *, met_inds[1]], $
                     radarr[*, *, met_inds[2]])

orac_met = ORDEREDHASH(met_keys, orac_met_vars, /fold_case)

values = list(orac_files[wh], $
              replicate(satellite[0], n_elements(wh)), $
              primarr[*, *, 0], primarr[*, *, 1], $
              primarr[*, *, 2], primarr[*, *, 3], $
              primarr[*, *, 6], radarr[*, *, 0], $
              ctype, orac_boa, orac_toa, orac_met)

orac_hash = ORDEREDHASH(orac_keys, values)

orac_out = orac_hash.tostruct(/recursive)

;ceres data---------------------------------------------------------------------

ceres_keys = ['filename','time','lat','lon','szen','toa']

ceres_toa_vars = list(ceresarr[*, ceres_toa_inds[0]], $
                      ceresarr[*, ceres_toa_inds[1]], $
                      ceresarr[*, ceres_toa_inds[2]], $
                      REPLICATE(!values.f_nan, $
                                N_ELEMENTS(ceresarr[*, ceres_toa_inds[2]])))

ceres_toa = ORDEREDHASH(toa_keys, ceres_toa_vars, /fold_case)

values = list(replicate(ceres_file[0], n_elements(wh)), $
              ceresarr[*, 0], ceresarr[*, 1], $
              ceresarr[*, 2], ceresarr[*, 3], $
              ceres_toa)

ceres_hash = ORDEREDHASH(ceres_keys, values)

ceres_out = ceres_hash.tostruct(/recursive)

;-------------------------------------------------------------------------------

end
