function val_colocate_atsr, sat_in, year, month, lat, lon, $
                            dkm=dkm, d_or_n=d_or_n

; colocate_atsr.pro
;
; Finds ATSR2/AATSR granules overpassing a set lat/lon location
;
; History
; 2016/08/23, WJ: Branched from colocate_atsr
; 2016/08/24, WJ: Bug fix, arguments to get_dist were incorrectly ordered
;
; Subroutines:
; Generic
;   -check_keyword.pro
;   -read_ncdf.pro
;   -get_dist.pro
;   -str_rebin.pro
;
; Validation:
;   -get_atsr_geometa.pro
;   -read_atsr_geometa.pro
;   -atsr_file_info.pro
;
; Known bugs:
;   -First pass picks up any orbit that crosses the date line at the
;    site latitude.

;===============================================================================
; Check keyword inputs and set defaults
;===============================================================================

;Convert satellite to filename format and check
def_sats = ['AATSR','ATSR2']
def_sats_path = ['AATSR_ENVISAT','ATSR2_ERS2']
;Reassign to avoid changing
satellite = sat_in
if satellite eq 'AATSR' then satellite = 'AATSR_ENVISAT' $
else if satellite eq 'ATSR2' then satellite = 'ATSR2_ERS2'
VAL_CHECK_KEYWORD, satellite, def_sats_path, key_name='satellite'

;Check d_or_n keyword and set version number accordingly
if ~KEYWORD_SET(d_or_n) then d_or_n = 'D'

if KEYWORD_SET(d_or_n) && d_or_n eq 'N' then version = ['fv3.0', 'fv4.0'] $
   else version = 'fv2.0'

;===============================================================================
; Find or generate ATSR geo metadata files and search for matches
;===============================================================================

geometa_files = VAL_GET_ATSR_GEOMETA(year, month, d_or_n=d_or_n, $
                                     satellite=satellite)

;Get number of locations and number of files to search
n_loc = N_ELEMENTS(lat)
n_files = N_ELEMENTS(geometa_files)

if n_files gt 0 then begin

   PRINT, STRTRIM(STRING(n_files),1)+' files found'

   ;Initialise arrays
   l1_files = STRARR(n_loc, n_files)
   l2_files = l1_files
   date = DBLARR(n_loc, n_files)
   cx = INTARR(n_loc, n_files)
   cy = cx
   
   retr_ct = INTARR(n_loc,n_files)

   PRINT, 'Reading geo metadata...'
   
   for i = 0,n_files-1 do begin
      geometa = VAL_READ_ATSR_GEOMETA(geometa_files[i])
      
      n_col = N_ELEMENTS(geometa[0,*])
      
      lon0 = REBIN(geometa[0,*], n_loc, n_col)
      lat0 = REBIN(geometa[1,*], n_loc, n_col)
      lon1 = REBIN(geometa[2,*], n_loc, n_col)
      lat1 = REBIN(geometa[3,*], n_loc, n_col)
      
      mn0 = MIN(ABS(lat0-REBIN(lat, n_loc, n_col)), wh_m0, dimension=2)
      mn1 = MIN(ABS(lat1-REBIN(lat, n_loc, n_col)), wh_m1, dimension=2)
      
      retr_ct[*,i] = (lon gt lon0[wh_m0]) xor (lon gt lon1[wh_m1])
      ;Bug: need to filter out values that cross the date line!
      wh_dl = WHERE(ABS(lon0[wh_m0] - lon1[wh_m1]) gt 180, /null, dl_ct)
      if dl_ct gt 0 then retr_ct[wh_dl,i] = 0
      endfor

   wh = WHERE(TOTAL((retr_ct ne 0), 1) gt 0, /null, geo_ct)

   PRINT, 'Initial matches found:', TOTAL((retr_ct ne 0), 2)

endif $
else ct = 0



;===============================================================================
; Load L2 cloud files matched from geo metadata to find exact matches
;===============================================================================

if geo_ct gt 0 then begin

   sr = SIZE(retr_ct, /dimensions)

   ;geometa_files = STR_REBIN(geometa_files,sr)

   PRINT, 'Finding exact matches'

   for i = 0,geo_ct-1 do begin
      j = wh[i]
      geometa = VAL_READ_ATSR_GEOMETA(geometa_files[j],header, l1_name, l2_name)
      
      l2_cld = FILE_SEARCH(l2_name, count=ct)
      if ct gt 0 then begin
         stat = READ_NCDF(l2_cld[0], data, variable_list=['lat','lon'])
         if stat eq 1 then begin
            PRINT, FILE_BASENAME(l2_cld[0])
            sl = SIZE(data.lat, /dimensions)
            ;Loop over locations
            for k = 0,n_loc-1 do begin
               if retr_ct[k,j] ne 0 then begin
                  ;get distance to location from each pixel
                  dist = VAL_GET_DIST(data.lat, data.lon, lat[k], lon[k])
                  
                  ;Find the closest pixel
                  mn = MIN(dist, whm)
                  PRINT, mn
            
                  ;Convert minimum index to array subscripts
                  ind = ARRAY_INDICES(data.lat, whm)
                  PRINT, ind

                  

                  if ind[0] ge dkm && ind[0] lt sl[0]-dkm && $
                     ind[1] ge dkm && ind[1] lt sl[1]-dkm then begin 
                     
                     cx[k,j] = ind[0]
                     cy[k,j] = ind[1]
                  endif $
                  else retr_ct[k,j] = 0
                  PRINT, retr_ct[k,j]
               endif
            endfor
            
            VAL_ATSR_FILE_INFO, l1_name, l1_out, time, sensor, timestr

            l1_files[*,j] = l1_out
            l2_files[*,j] = l2_cld[0]

            date[*,j] = JULDAY(time[2],time[3],time[0],time[4],time[5],time[6])
            
         endif $
         else retr_ct[*,j] = 0
      endif $
      else retr_ct[*,j] = 0
          
   endfor

   PRINT, 'Exact matches found:', TOTAL((retr_ct ne 0), 2)



;===============================================================================
; Compile output list containing only matched data
;===============================================================================

   ;Define empty lists for outputs
   l_l1_files = list()
   l_l2_files = list()
   l_date = list()
   l_cx = list()
   l_cy = list()
   
   for j = 0,n_loc-1 do begin
      ;Find where match conditions met
      wh = WHERE(retr_ct[j,*] ne 0, /null, ct)

      if ct gt 0 then begin
         l_l1_files.add, l1_files[j,wh] 
         l_l2_files.add, l2_files[j,wh] 
         l_date.add, date[j,wh]
         l_cx.add, cx[j,wh]
         l_cy.add, cy[j,wh]
      endif $
      else begin
         l_l1_files.add, !null
         l_l2_files.add, !null
         l_date.add, !null
         l_cx.add, !null
         l_cy.add, !null
      endelse
   endfor

   ;Compile output list
   out = list(l_l2_files, l_l1_files, l_date, l_cx, l_cy)
 
endif $
else begin
   ;Error message if no overpasses found
   print, 'No matching files found'
   out = list()
endelse

RETURN, out

end

