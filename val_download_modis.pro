pro val_download_modis, file, type=type, $
                        year=year, month=month, day=day, hour=hour, $
                        minute=minute, $
                        satellite=satellite, $
                        modispath=modispath, replace=replace, $
                        out_files=out_files, quiet=quiet

; download_modis.pro
;
; wget wrapper to download MODIS L1/L2 files from the laadsweb ftp
; server. Can take input of either a list of modis file names or a
; scalar or array year[,month[,day[,hour[,minute]]]] and satellite
; input through keywords. Type must be specified, but will be prompted
; not included in the calling function.
;
; History:
; 2016/08/22, WJ: Added description and list of subroutines
; 2016/09/06, WJ: Bug fix to enable downloading multiple files when
;   using date keywords, fixed out_files output.
;
; Subroutines
; Generic:
;   -check_keyword.pro
;   -get_doy.pro
;
; Validation:
;   -modis_file_info.pro
;   

def_type = ['021KM','03','04_L2','05_L2','06_L2','07_L2','11_L2','35_L2']

VAL_CHECK_KEYWORD, type, def_type, key_name='type'
n_type = N_ELEMENTS(type)

def_path = '/group_workspaces/cems2/nceo_generic/cloud_ecv/modis_c6/'

if ~KEYWORD_SET(modispath) then modispath = def_path

   out_files = STRARR(n_files,n_type)

   for i = 0,n_files-1 do begin
      modis_file_info, file[i], prefix, time, mtype, timestr
      yrSTR=timeSTR[0]
      doySTR=timeSTR[1]
      moSTR=timeSTR[2]
      mDSTR=timeSTR[3]
      HrSTR=timeSTR[4]
      MnSTR=timeSTR[5]

;check for MOD021km files and add to download list if not found
      for j = 0,n_type-1 do begin
         ttype = STRMID(mtype,0,3)+type[j]
         pathToSave = modispath+STRLOWCASE(ttype)+'/'+yrSTR+'/'+doySTR
         junk = file_search(pathToSave+'/'+ttype+'.A'+prefix+'*.hdf', $
                            count=junkct)
         if junkct eq 0 then begin
            spwn_str = 'wget --user=anonymous --password='+"'a'"+ $
                       ' --directory-prefix='+pathToSave+ $
                       ' ftp://ladsweb.nascom.nasa.gov/allData/6/'+ttype+'/'+ $
                       yrSTR+'/'+doySTR+'/'+ttype+'.A'+yrSTR+doySTR+'.'+ $
                       HrSTR+MnSTR+'.006.'+'*.hdf ; '
            if ~KEYWORD_SET(quiet) then print, spwn_str
            spawn, spwn_str

            junk = file_search(pathToSave+'/'+ttype+'.A'+prefix+'*.hdf', $
                               count=junkct)
         endif $
         else if ~KEYWORD_SET(quiet) then $
            PRINT, 'Skipping '+type+'.A'+yrSTR+doySTR+'.'+HrSTR+MnSTR+'.006.hdf'

         out_files[i,j] = junk

      endfor
   endfor
endif $
else begin
   if ~KEYWORD_SET(year) then MESSAGE, 'File or year input required'

   if N_ELEMENTS(satellite) gt 0 then begin
      for i = 0,N_ELEMENTS(satellite)-1 do begin
         if satellite[i] eq 'MODIS-AQUA' then satellite[i] = 'AQUA'
         if satellite[i] eq 'MODIS-TERRA' then satellite[i] = 'TERRA'
      endfor
   endif

   def_sats = ['AQUA','TERRA']
   
   CHECK_KEYWORD, satellite, def_sats, key_name='satellite'

   if satellite eq 'AQUA' then mtype = 'MYD' $
                          else mtype = 'MOD'
      
   if ~KEYWORD_SET(month) && ~KEYWORD_SET(day) then $
      DoY = GET_DOY(year, [1:12]) $
   else if ~KEYWORD_SET(month) then $
      DoY = GET_DOY(year, [1:12], day=day) $
   else if ~KEYWORD_SET(day) then $
      DoY = GET_DOY(year, month) $
   else DoY = GET_DOY(year, month, day=day)
   if ~KEYWORD_SET(hour) then hour = [0:23]
   if ~KEYWORD_SET(minute) then minute = [0:55:5] $
                           else minute -= minute mod 5
      
   tc = LOOP_CTRL(['doy','hour','minute','year'],doy,hour,minute,year)

   
   wh_d0 = WHERE(tc.doy eq MIN(doy) and tc.hour eq MIN(hour) and $
                 tc.minute eq MIN(minute), /null, ct)

   n_dat = N_ELEMENTS(tc.doy)

   ;if ct eq N_ELEMENTS(year) then $
      ;year = REFORM(TRANSPOSE(REBIN([year], ct, n_dat/ct)), n_dat)
   
   yrstr = STRTRIM(STRING(tc.year),1)
   doystr = STRTRIM(STRING(tc.doy),1)
   hrstr = STRTRIM(STRING(tc.hour),1)
   mnstr = STRTRIM(STRING(tc.minute),1)
   
   prefix = yrstr+doystr+'.'+hrstr+mnstr

   out_files = STRARR(n_dat,n_type)
   
   for i = 0,n_dat-1 do begin
      for j = 0,n_type-1 do begin
         ttype = STRMID(mtype,0,3)+type[j]
         pathToSave = modispath+STRLOWCASE(ttype)+'/'+yrSTR+'/'+doySTR
         junk = file_search(pathToSave[i]+'/'+ttype+'.A'+prefix[i]+'*.hdf', $
                            count=junkct)
         if junkct eq 0 then begin 
            spwn_str = 'wget --user=anonymous --password='+"'a'"+ $
                       ' --directory-prefix='+pathToSave+ $
                       ' ftp://ladsweb.nascom.nasa.gov/allData/6/'+ttype+ $
                       '/'+ yrSTR[i]+'/'+doySTR[i]+'/'+ttype+'.A'+prefix[i]+ $
                       '.006.'+'*.hdf ; '
            if ~KEYWORD_SET(quiet) then print, spwn_str
            spawn, spwn_str

            junk = file_search(pathToSave[i]+'/'+ttype+'.A'+prefix[i]+'*.hdf', $
                               count=junkct)

         endif $
         else if ~KEYWORD_SET(quiet) then $
            PRINT, 'Skipping '+type+'.A'+prefix[i]+'.006.hdf'

         out_files[i,j] = junk

      endfor
   endfor
endelse

end
