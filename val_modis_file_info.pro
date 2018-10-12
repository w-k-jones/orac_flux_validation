;+
;NAME:
;
;   Modis File Information
;
;PURPOSE:
;
;   This procedure is used to obtain the time stamp of any Modis file
;
;INPUT: file = Modis File Name
;
;OUTPUT: Prefix = common feature to all MODIS files first yearday.hourmin characters
;        mtype  = first portion of the file name e.g. MYD021KM.A   (aqua calibrated radiances)
;Time(9)
;Time(0) = year
;Time(1) = day of the year (1-365) or (1-366)
;Time(2) = Month
;Time(3) = Day of the month
;Time(4) = Hour (0-23)
;Time(5) = Minute (0-59)
;Time(6) = Second (0-59)
;Time(7) = Time expressed in International Atomic Time (TAI) units are in seconds since January 1, 1993
;Time(8) = Orbit #   Calipso = -99
;
;EXAMPLE
;modis_file_info,'/raid3/chrismat/modis/MYD04_L2.A2008358.2300.hdf',p,t,mt
;
;AUTHOR:
;    Matt Christensen
;    Colorado State University
;
;History:
; 2016/08/22, WJ: Update to output 2D array of times for array input
;   of file name (existing scalar applications will not be affected)
;###########################################################################
PRO VAL_MODIS_FILE_INFO,file,prefix,time,mtype,timeSTR

  n_files = N_ELEMENTS(file)
  st = INTARR(n_files)

  ;Determine Aqua or Terra
  wh_a = WHERE(strpos(file,'MYD0') gt -1, /null, ct)
  if ct gt 0 then st[wh_a] = strpos(file[wh_a],'MYD0')
  wh_t = WHERE(strpos(file,'MOD0') gt -1, /null, ct)
  if ct gt 0 then st[wh_t] = strpos(file[wh_t],'MOD0')
  ;; if strpos(file,'MYD0') gt -1 then st=strpos(file,'MYD0')
  ;; if strpos(file,'MOD0') gt -1 then st=strpos(file,'MOD0')
  
  diag = indgen(n_files)*(n_files+1)

  dotA = strpos(file,'.A')
  prefix = (strmid(file,st+(dotA-st)+2,12))[diag]
  mtype = (strmid(file,st,(dotA-st)+2))[diag]
  
  year = strmid(prefix,0,4)*1D
  yday = strmid(prefix,4,3)*1D  
  hour = strmid(prefix,8,2)*1D
  min = strmid(prefix,10,2)*1D
  sec = 0
  CALDAT,JULDAY(1,yday,year),month,mday
  TAI = ( JULDAY(Month, MDay, Year, Hour, Min, Sec) - JULDAY(1,1,1993,0,0,0) )*24D*3600D
  ;print,year,' ',yday,'  ',hour,'  ',min,' ',sec,'  ',month,'  ',mday,'  ',TAI

;Construct Time array
time = dblarr(9, n_files)
time(0,*) = year
time(1,*) = yday
time(2,*) = month
time(3,*) = mday
time(4,*) = hour
time(5,*) = min
time(6,*) = -99
time(7,*) = TAI
time(8,*) = -99

timeSTR = STRARR(7,n_files)
timeSTR(0,*)=STRING(FORMAT='(I04)',YEAR)
timeSTR(1,*)=STRING(FORMAT='(I03)',yday)
timeSTR(2,*)=STRING(FORMAT='(I02)',month)
timeSTR(3,*)=STRING(FORMAT='(I02)',mDay)
timeSTR(4,*)=STRING(FORMAT='(I02)',HOUR)
timeSTR(5,*)=STRING(FORMAT='(I02)',min)
timeSTR(6,*)=STRING(FORMAT='(F16.5)',TAI)
 
return
end
