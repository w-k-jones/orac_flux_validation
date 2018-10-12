function val_colocate_satellite, satellite, year, month, dl, $
                                 station=station, savepath=savepath, $
                                 d_or_n=d_or_n, get_files=get_files, $
                                 replace=replace

; colocate_satellite.pro
;
; Provides overpass information for variety of satellites over a point
; specified by lat and lon, for a given month.
;
; History
; 2016/08/22, WJ: Updated description, added list of subroutines.
; 2016/09/01, WJ: Prevented overwriting of pre-exisiting and correct
;   overpass files when others are missing.
;
; Subroutines
; Generic
;
; Validation
;   -get_station_loc.pro
;   -colocate_modis.pro
;   -colocate_atsr.pro
;


;set default path names
gws_path = '/group_workspaces/cems2/nceo_generic/cloud_ecv/'
modispath = gws_path+'modis_c6/'
def_savepath = gws_path+'validation/idl/colocation/'
if N_ELEMENTS(savepath) eq 0 then savepath = def_savepath

;create save directory if none exists
SPAWN, 'mkdir -p -v '+savepath

;get distance and convert to km (for grid squares)
dkm = dl
if dkm lt 1 then dkm = dkm*(6371*2*!pi)/360
dkm = FIX(dkm)
;min value of dkm for colocating CERES measurements (~20km pixel size)
dkm >= 25

;check day/night keyword set, default to day
if ~KEYWORD_SET(d_or_n) then d_or_n = 'D'

;create strings for year/month
yrstr = string(format='(I04)',year)
mostr = string(format='(I02)',month)

;get lat/lon using get_station_loc

loc = VAL_GET_STATION_LOC(station, lat=lat, lon=lon)

;===============================================================================
; Generate save names for output files containing overpass information
;===============================================================================

;create save name
save_name = 'colocated_files_'+yrstr+mostr
save_name = station+'_'+save_name
save_name = satellite+'_'+save_name+'_'+d_or_n+'.sav'
saves = savepath+save_name
n_save = N_ELEMENTS(saves)

;===============================================================================
; Search for existing output files and check information is present
;===============================================================================

PRINT, 'Searching for saved colocations...'
chk = INTARR(n_save)
temp = FILE_SEARCH(saves, count=tempcnt)
if tempcnt gt 0 then begin
   ;if existing files found, restore and
   ;check that all the required variables
   ;are present
   if tempcnt gt 0 then begin

      ;Find which saves exist using the intersection indices
      junk = SET_OP(saves, temp, int_ind=wh)

      ;Restore exisintg files to check if the correct variables are present
      for i= 0,tempcnt-1 do begin
         j = wh[i]
         print, 'Restoring existing file, '+save_name[j]
         RESTORE, saves[j]
         n_match = N_ELEMENTS(matched_files)
         n_l1 = N_ELEMENTS(l1_files)
         n_geo = N_ELEMENTS(geo_files)
         n_date = N_ELEMENTS(date)
         n_cx = N_ELEMENTS(cx)
         n_cy = N_ELEMENTS(cy)
   
         ;check if all vars present and if so assume file is correct
         if ~KEYWORD_SET(replace) && n_match gt 0 && n_l1 gt 0 && n_geo gt 0 $
            && n_date gt 0 && n_cx gt 0 && n_cy gt 0 then $
               chk[j] = 1
      endfor

      ;If all files correct return immediatedly
      if TOTAL(chk) eq n_save then begin 
         PRINT, 'All colocation files found, returning'
         RETURN, saves
      endif

   endif
endif
;Otherwise continue and process overpasses

;===============================================================================
; Find overpass information for MODIS sensors
;===============================================================================

if satellite eq 'MODIS-TERRA' or $
   satellite eq 'MODIS-AQUA' then begin

   PRINT, 'Colocating MODIS'

   modis = VAL_COLOCATE_MODIS(satellite, year, month, lat, lon, $
                              dkm=dkm, d_or_n=d_or_n, $
                              get_files=get_files, replace=replace)

   if N_ELEMENTS(modis) eq 6 then begin
      all_matched_files = modis[0]
      all_l1_files = modis[1]
      all_geo_files = modis[2]
      all_date = modis[3]
      all_cx = modis[4]
      all_cy = modis[5]
   endif $
   else RETURN, ''
endif

;===============================================================================
; Find overpass information for ATSR sensors
;===============================================================================

if satellite eq 'ATSR2' or $
   satellite eq 'AATSR' then begin

   PRINT, 'Colocating ATSR'
   
   atsr = VAL_COLOCATE_ATSR(satellite, year, month, lat, lon, $
                            dkm=dkm, d_or_n=d_or_n)

   if N_ELEMENTS(atsr) eq 5 then begin
      all_matched_files = atsr[0]
      all_l1_files = atsr[1]
      ;ATSR L1 files contain geographical information, so duplicate
      all_geo_files = atsr[1]
      all_date = atsr[2]
      all_cx = atsr[3]
      all_cy = atsr[4]
   endif $
   else RETURN, ''

endif

;===============================================================================
; Process overpass information and save to file
;===============================================================================


;Loop over output save names (i.e. ground site locations)
for i = 0,n_save-1 do begin
   if N_ELEMENTS(all_matched_files[i]) gt 0 then begin
      matched_files = all_matched_files[i,*]
      l1_files = all_l1_files[i,*]
      geo_files = all_geo_files[i,*]
      date = all_date[i,*]
      cx = all_cx[i,*]
      cy = all_cy[i,*]
   
      ;Save overpass information to file
      if chk[i] ne 1 then begin
         PRINT, 'Saving '+save_name[i]
         SAVE, matched_files, l1_files, geo_files, date, cx, cy, $
               filename=saves[i]
      endif
   endif $
   else begin
      PRINT, 'No overpasses found for '+save_name[i]
      saves[i] = ''
   endelse
endfor

RETURN, saves

end
