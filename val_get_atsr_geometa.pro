function val_get_atsr_geometa, year, month, d_or_n=d_or_n, satellite=satellite

; get_atsr_geometa.pro
;
; Produces geo metadata files for ATSR2/AATSR l2 data. These consist
; of the outside pixels of each orbit track, given as lat/lon
; values. Makes searching much easier.
;
; History:
; 2016/08/23, WJ: Created
;
;

gws_path = '/group_workspaces/cems2/nceo_generic/cloud_ecv/'
meta_path = gws_path+'validation/atsr_geometa/'

def_sats = ['AATSR','ATSR2']
def_sats_path = ['AATSR_ENVISAT','ATSR2_ERS2']
if satellite eq 'AATSR' then satellite = 'AATSR_ENVISAT' $
else if satellite eq 'ATSR2' then satellite = 'ATSR2_ERS2'
VAL_CHECK_KEYWORD, satellite, def_sats_path, key_name='satellite'

;Path to cloud_cci data
prim_path = '/group_workspaces/cems/cloud_ecv/public/ESA_Cloud_CCI/CLD_PRODUCTS/L2/'

;Check d_or_n keyword and set version number accordingly
if KEYWORD_SET(d_or_n) && d_or_n eq 'N' then begin
   version = ['fv3.0', 'fv4.0']
endif $
else begin
   d_or_n = 'D'
   version = 'fv2.0'
endelse

;Get yyyy/mm strings
yrstr = STRING(format='(I04)',year)
mostr = STRING(format='(I02)',month)

;Search for cloud_cci files
search_path = prim_path+satellite+'/v2.0/'+yrstr+'/'+mostr+'/'
PRINT, 'Searching for files in '+search_path
matched_files = FILE_SEARCH(search_path,'*'+version+'.primary.nc',count=fcnt)
if N_ELEMENTS(version) gt 1 then begin
   matched_files = [matched_files, $
                    file_search(search_path,'*'+version[1]+'.primary.nc', $
                                count=fcnt2)]
   fcnt += fcnt2
endif

if d_or_n eq 'N' then $
   version = REFORM(STR_REBIN(TRANSPOSE(version),(fcnt/2),2), fcnt, /overwrite)

if fcnt eq 0 then MESSAGE, 'No ATSR files found'

VAL_ATSR_FILE_INFO, matched_files, l1_files, time, sensor, timestr

yrstr = timestr[0,*]
mostr = timestr[2,*]
dystr = timestr[3,*]
hrstr = timestr[4,*]
mnstr = timestr[5,*]
scstr = timestr[6,*]

prefix = sensor

wh = WHERE(sensor eq 'AATSR', /null, ct)
if ct gt 0 then $
   prefix[wh] = 'ATS_TOA_1PUUPA'

wh = WHERE(sensor eq 'ATSR2', /null, ct)
if ct gt 0 then $
   prefix[wh] = 'AT2_TOA_1PURAL'

meta_files = prefix+yrstr+mostr+dystr+'_'+hrstr+mnstr+dystr+'_'+version+'.txt'

subdir = yrstr+'/'+mostr+'/'+dystr+'/'

txt_files = meta_path+subdir+meta_files

temp = SET_OP(txt_files, FILE_SEARCH(txt_files, count=ct), diff_ind=wh_ms)

if ct ne N_ELEMENTS(txt_files) then begin
   for i =0,N_ELEMENTS(wh_ms)-1 do begin
      j = [wh_ms[i]]

      spawn, 'mkdir -p -v '+meta_path+subdir[j]
      
      tstr = prim_path+satellite+'/v2.0/'+yrstr[j]+'/'+mostr[j]+'/'+dystr[j]+ $
             '/'+'/ESACCI-L2-CLOUD-CLD-*'+yrstr[j]+mostr[j]+dystr[j]+hrstr[j] $
             +mnstr[j]+'_'+version[j]+'.primary.nc'
      L2_cld = FILE_SEARCH(tstr, count=ct)
      if ct gt 0 then begin
         stat = READ_NCDF(L2_cld[0], data, variable_list=['lat','lon'])
         if stat eq 1 then begin
            PRINT, FILE_BASENAME(l2_cld)

            lon0 = data.lon[0,*]
            lat0 = data.lat[0,*]
            lon1 = data.lon[-1,*]
            lat1 = data.lat[-1,*]

            header = ['Lon0            ','Lat0            ', $
                      'Lon1            ','Lat1            ']
            wr_arr = STRING([lon0,lat0,lon1,lat1])
            
            OPENW, lun, txt_files[j], /get_lun
            PRINTF, lun, FILE_BASENAME(l1_files[j])
            PRINTF, lun, L2_cld
            PRINTF, lun, header
            PRINTF, lun, wr_arr
            CLOSE, lun
            FREE_LUN, lun
         endif
      endif
   endfor
endif


RETURN, txt_files

end
