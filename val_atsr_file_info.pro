pro val_atsr_file_info, file, l1_files, time, sensor, timestr

; atsr_file_info.pro
;
; Obtains the file stamp, sensor name and l1_file path of any L1 or
; cloud_cci L2 AATSR/ATSR2 file
;
; History:
; 2016/08/23, WJ: Created
;

atsr_l1_path = '/neodc/aatsr_multimission/'
aatsr_l1_path = atsr_l1_path+'aatsr-v3/data/ats_toa_1p/'
atsr2_l1_path = atsr_l1_path+'atsr2-v3/data/at2_toa_1p/'

n_files = N_ELEMENTS(file)

l1_files = STRARR(n_files)
time = DBLARR(8, n_files)
sensor = STRARR(n_files)
timestr = STRARR(7, n_files)

filename = file_basename(file)

f3 = STRMID(filename,0,3)

;case of L2 files - find corresponding L1 file and go from there
wh_l2 = WHERE(f3 eq 'ESA', /null, ct)
if ct gt 0 then begin
   ;loop over separately to assign filenames correctly
   for i = 0,ct-1 do begin
      split = STRSPLIT(filename[wh_l2[i]], '_')

      YYYY = STRMID(filename[wh_l2[i]],split[3],4)
      MM = STRMID(filename[wh_l2[i]],split[3]+4,2)
      DD = STRMID(filename[wh_l2[i]],split[3]+6,2)
      Hr = STRMID(filename[wh_l2[i]],split[3]+8,2)
      Mn = STRMID(filename[wh_l2[i]],split[3]+10,2)

      split = STRSPLIT(filename[wh_l2[i]], '-')

      stype = STRMID(filename[wh_l2[i]],split[4],5)
      if stype eq 'AATSR' then tstr = aatsr_l1_path+yyyy+'/'+mm+'/'+dd+'/'+ $
                                      'ATS_TOA_1PUUPA'+yyyy+mm+dd+'_'+hr+mn+ $
                                      '*.N1'
      if stype eq 'ATSR2' then tstr = atsr2_l1_path+yyyy+'/'+mm+'/'+dd+'/'+ $
                                      'AT2_TOA_1PURAL'+yyyy+mm+dd+'_'+hr+mn+ $
                                      '*.N1'
      t_file = FILE_SEARCH(tstr, count=ct)
      if ct gt 0 then filename[wh_l2[i]] = FILE_BASENAME(t_file) $
                 else filename[wh_l2[i]] = ''
   endfor
endif

f3 = STRMID(filename,0,3)

wh = WHERE(f3 eq 'ATS', /null, ct)
if ct gt 0 then begin

   yrstr = STRMID(filename[wh],14,4)
   year = FIX(yrstr)

   mostr = STRMID(filename[wh],18,2)
   month = FIX(mostr)

   dystr = STRMID(filename[wh],20,2)
   day = FIX(dystr)

   hrstr = STRMID(filename[wh],23,2)
   hour = FIX(hrstr)

   mnstr = STRMID(filename[wh],25,2)
   minute = FIX(mnstr)

   scstr = STRMID(filename[wh],27,2)
   second = FIX(scstr)

   jd = JULDAY(month,day,year,hour,minute,second)
   doy =  JULDAY(month,day,year) - JULDAY(1,1,year) + 1
   doystr = STRING(doy, format='(I03)')

   TAI = (JULDAY(month, day, year, hour, minute, second) $
          - JULDAY(1,1,1993,0,0,0) )*24D*3600D

   time[*, wh] = TRANSPOSE([[year],[doy],[month],[day], $
                            [hour],[minute],[second],[tai]])
   timestr[*, wh] = $
      TRANSPOSE([[yrstr],[doystr],[mostr],[dystr],[hrstr],[mnstr],[scstr]])
   
   sensor[wh] = 'AATSR'

   tstr = aatsr_l1_path+yrstr+'/'+mostr+'/'+dystr+'/'+ $
          'ATS_TOA_1PUUPA'+yrstr+mostr+dystr+'_'+hrstr+mnstr+'*.N1'
   
   l1_files[wh] = FILE_SEARCH(tstr)
endif
wh = WHERE(f3 eq 'AT2', /null, ct)
if ct gt 0 then begin

   yrstr = STRMID(filename[wh],14,4)
   year = FIX(yrstr)

   mostr = STRMID(filename[wh],18,2)
   month = FIX(mostr)

   dystr = STRMID(filename[wh],20,2)
   day = FIX(dystr)

   hrstr = STRMID(filename[wh],23,2)
   hour = FIX(hrstr)

   mnstr = STRMID(filename[wh],25,2)
   minute = FIX(mnstr)

   scstr = STRMID(filename[wh],27,2)
   second = FIX(scstr)

   jd = JULDAY(month,day,year,hour,minute,second)
   doy =  JULDAY(month,day,year) - JULDAY(1,1,year) + 1
   doystr = STRING(doy, format='(I03)')

   TAI = (JULDAY(month, day, year, hour, minute, second) $
          - JULDAY(1,1,1993,0,0,0) )*24D*3600D

   time[*, wh] = TRANSPOSE([[year],[doy],[month],[day], $
                            [hour],[minute],[second],[tai]])
   timestr[*, wh] = $
      TRANSPOSE([[yrstr],[doystr],[mostr],[dystr],[hrstr],[mnstr],[scstr]])
   
   sensor[wh] = 'ATSR2'

   tstr = ats2r_l1_path+yrstr+'/'+mostr+'/'+dystr+'/'+ $
          'AT2_TOA_1PURAL'+yrstr+mostr+dystr+'_'+hrstr+mnstr+'*.N1'
   
   l1_files[wh] = FILE_SEARCH(tstr)
endif

end
