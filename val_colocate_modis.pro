function val_colocate_modis, sat_in, year, month, lat, lon, $
                             dkm=dkm, d_or_n=d_or_n, $
                             get_files=get_files, replace=replace

; colocate_modis.pro
;
; Finds MODIS granules overpassing a set lat/lon location;
;
; History
; 2016/08/23, WJ: Branched from colocate_modis.pro aiming to reduce
;   the number of file searches required.
; 2016/08/24, WJ: Bug fix, arguments to get_dist were incorrectly
;   ordered
; 2016/08/31, WJ: Bug fix, incorrect indexing of matches when
;   downloading files
;
; Subroutines
; Generic
;   -check_keyword.pro
;   -get_dist.pro
;
; Validation:
;   -match_modis_geometa.pro
;   -modis_file_info.pro
;   -download_modis.pro
;
; HDF:
;   -read_hdf4.pro

;===============================================================================
; Check keyword inputs and set defaults
;===============================================================================

;set default path names
gws_path = '/group_workspaces/cems2/nceo_generic/cloud_ecv/'
modispath = gws_path+'modis_c6/'

;Convert satellite to filename format and check
def_sats = ['MODIS-AQUA','MODIS-TERRA']
def_sats_path = ['AQUA','TERRA']
;Reassign to avoid changing
satellite = sat_in
if satellite eq 'MODIS-AQUA' then satellite = 'AQUA' $
else if satellite eq 'MODIS-TERRA' then satellite = 'TERRA'
VAL_CHECK_KEYWORD, satellite, def_sats_path, key_name='satellite'

;Check d_or_n keyword and set version number accordingly
if ~KEYWORD_SET(d_or_n) then d_or_n = 'D'

;get initial rough match of
;overpasses, as this is for only one
;location convert list to array
PRINT, 'Acquiring inital matches...'

first_match = VAL_MATCH_MODIS_GEOMETA(satellite, year, month, lat, lon, $
                                      d_or_n=d_or_n)

;returns list, one element per lat/lon pair - convert to array and
;                                             find unique files to
;                                             load and check

;Get number of locations
n_loc = N_ELEMENTS(lat)

;Get number of first matches per location
n_f_match = FLTARR(n_loc)
for i = 0,n_loc-1 do n_f_match[i] = N_ELEMENTS(first_match[i])

PRINT, 'Initial matches found:',n_f_match

first_match = first_match.toarray(dimension=2)
uniq_match = first_match[UNIQ(first_match, SORT(first_match))]

;Get number of files to search
n_files = N_ELEMENTS(uniq_match)

if n_files gt 0 then begin

   PRINT, 'Finding exact matches'

   ;Define empty lists to store outputs in
   mod02_files = STRARR(n_loc, n_files)
   mod03_files = mod02_files
   date = DBLARR(n_loc, n_files)
   cx = INTARR(n_loc, n_files)
   cy = cx
   retr_ct = cx

   ;Loop over list elements
   for i = 0,n_files-1 do begin

      VAL_MODIS_FILE_INFO, uniq_match[i], prefix, time, mtype, timestr
      
      ;Find mod03 file
      type = STRMID(mtype,0,2)+'D03'
      pathtosave = modispath+STRLOWCASE(type)+'/'+timestr[0]+'/'+timestr[1]
   
      ;Download file if get_files is set
      if KEYWORD_SET(get_files) then $
         VAL_DOWNLOAD_MODIS, uniq_match[i], modispath=modispath, type='03', $
                         replace=replace, /quiet
   
      mod03file=FILE_SEARCH(pathtosave+'/*'+prefix+'*.hdf', count=mod03cnt)

      mod03_files[*,i] = mod03file
      
      if mod03cnt gt 0 then begin
         ;Read MODIS geolocation file for lat/lon pixels
         mod03 = READ_HDF4(mod03file[0], names=['Latitude','Longitude'])

         sl = SIZE(mod03.latitude, /dimensions)
         
         ;Loop over locations
         for j = 0,n_loc-1 do begin

            ;Calculate distance to input lat/lon from each pixel
            dist = VAL_GET_DIST(mod03.latitude, mod03.longitude, lat[j], lon[j])

            ;Find the closest pixel
            mn = MIN(dist, whm)
            ;PRINT, mn
            
            ;Convert minimum index to array subscripts
            ind = ARRAY_INDICES(mod03.latitude, whm)
            ;PRINT, ind
         
            ;Check if subscript is far enough from
            ;borders of the granuel to allow a
            ;good colocation. This will also
            ;filter out any locations that are
            ;outside the granule
            if ind[0] ge dkm && ind[0] lt sl[0]-dkm && $
               ind[1] ge dkm && ind[1] lt sl[1]-dkm then begin 
            
               ;Flag where this condition is met
               retr_ct[j,i] = 1
               cx[j,i] = ind[0]
               cy[j,i] = ind[1]

            endif
         endfor

         if TOTAL(retr_ct[*,i]) gt 0 then begin
            ;find mod02 file
            type = STRMID(mtype,0,2)+'D021KM'
            pathtosave = modispath+STRLOWCASE(type)+'/'+timestr[0]+'/'+ $
                         timestr[1]

            ;download file if get_files set
            if KEYWORD_SET(get_files) then $
               VAL_DOWNLOAD_MODIS, uniq_match[i], modispath=modispath, $
                               type='021KM', replace=replace, /quiet
            
            mod02file=FILE_SEARCH(pathtosave+'/*'+prefix+'*.hdf', $
                                  count=mod02cnt)
            
            mod02_files[*,i] = mod02file

            ;Date in julian time
            date[*,i] = JULDAY(time[2],time[3],time[0],time[4],time[5],0)
         endif
               
         ;PRINT, retr_ct[j,i]

      endif
   endfor

   PRINT, 'Exact matches found:', TOTAL((retr_ct ne 0), 2)

   ;Define empty lists for outputs
   l_matched_files = list()
   l_mod02_files = list()
   l_mod03_files = list()
   l_date = list()
   l_cx = list()
   l_cy = list()
   
   for j = 0,n_loc-1 do begin
      ;Find where match conditions met
      wh = WHERE(retr_ct[j,*] ne 0, /null, ct)

      if ct gt 0 then begin
         l_matched_files.add, uniq_match[wh]
         l_mod02_files.add, mod02_files[j,wh]
         l_mod03_files.add, mod03_files[j,wh]
         l_date.add, date[j,wh]
         l_cx.add, cx[j,wh]
         l_cy.add, cy[j,wh]
      endif $
      else begin
         l_matched_files.add, !null
         l_mod02_files.add, !null
         l_mod03_files.add, !null
         l_date.add, !null
         l_cx.add, !null
         l_cy.add, !null
      endelse
   endfor

   ;Compile output list
   out = list(l_matched_files, l_mod02_files, l_mod03_files, $
              l_date, l_cx, l_cy)
 
endif $
else begin
   ;Error message if no overpasses found
   PRINT, 'No matching files found'
   out = list()
endelse

RETURN, out

end
