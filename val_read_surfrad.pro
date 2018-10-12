pro val_read_surfrad, station , $ ;station input
                      year, month, $ ;date input
                      strictqc=strictqc, $    ;filter out values with a qc flag of 2 (questionable). By default only qc flag of 1 is removed.
                      ncname=ncname, $        ;return keyword for output ncdf file name
                      replace=replace, $      ;replace existing files
                      savepath=savepath, $    ;path to save
                      location=location       ;[lat,lon] location of ground station

;2016/07/26 - WJ: added direct solar radiation and PAR to output file
;2016/07/27 - WJ: added all measured variables to output file
;2016/07/27 - WJ: allow array input for station, year, month, day
;2016/07/27 - WJ: renamed to read_surfrad_vec in order to restore
;                 original version

;============================
;Check station input is valid
;============================

def_gs = ['Alamosa_CO','Bondville_IL','Boulder_CO','Desert_Rock_NV','Fort_Peck_MT','Goodwin_Creek_MS','Penn_State_PA','Rutland_VT','Sioux_Falls_SD','Wasco_OR']

VAL_CHECK_KEYWORD, station, def_gs, key_name='station'

n_gs = N_ELEMENTS(station)
n_year = N_ELEMENTS(year)
n_month = N_ELEMENTS(month)

location = FLTARR(2,n_gs)

;Root path for surfrad files
root = '/group_workspaces/cems2/nceo_generic/cloud_ecv/validation/surfrad/'

;create save directory if none exists
SPAWN, 'mkdir -p -v '+savepath

;Surfrad variables from readme file - note, all vars from dw_solar
;                                     onwards have qc_tags follwing
;                                     them, so actual legnth is 48 cols.
;0 ; year			integer	year, i.e., 1995
;1 ; jday			integer	Julian day (1 through 365 [or 366])
;2 ; month			integer	number of the month (1-12)
;3 ; day			integer	day of the month(1-31)
;4 ; hour			integer	hour of the day (0-23)
;5 ; min			integer	minute of the hour (0-59)
;6 ; dt			real	decimal time (hour.decimalminutes, e.g., 23.5 = 2330)
;7 ; zen			real	solar zenith angle (degrees)
;8 ; dw_solar		real	downwelling global solar (Watts m^-2)
;9 ; uw_solar		real	upwelling global solar (Watts m^-2)
;10; direct_n		real	direct-normal solar (Watts m^-2)
;11; diffuse		real	downwelling diffuse solar (Watts m^-2)
;12; dw_ir			real	downwelling thermal infrared (Watts m^-2)
;13; dw_casetemp		real	downwelling IR case temp. (K)
;14; dw_dometemp		real	downwelling IR dome temp. (K)
;15; uw_ir			real	upwelling thermal infrared (Watts m^-2)
;16; uw_casetemp		real	upwelling IR case temp. (K)
;17; uw_dometemp		real	upwelling IR dome temp. (K)
;18; uvb			real	global UVB (milliWatts m^-2)
;19; par			real	photosynthetically active radiation (Watts m^-2)
;20; netsolar		real	net solar (dw_solar - uw_solar) (Watts m^-2)
;21; netir			real	net infrared (dw_ir - uw_ir) (Watts m^-2)
;22; totalnet		real	net radiation (netsolar+netir) (Watts m^-2)
;23; temp			real	10-meter air temperature (?C)
;24; rh			real	relative humidity (%)
;25; windspd		real	wind speed (ms^-1)
;26; winddir		real	wind direction (degrees, clockwise from north)
;27; pressure		real	station pressure (mb)


;Column vars for surfrad files (from readme - see above)
header_in = ['year','jday','month','day','hour','min','dt','zen','dw_solar', $
             'uw_solar','direct_n','diffuse','dw_ir','dw_casetemp', $
             'dw_dometemp','uw_ir','uw_casetemp','uw_dometemp','uvb','par', $
             'netsolar','netir','totalnet','temp','rh','windspd','winddir', $
             'pressure']

;Measured vars to read out
header_out = ['solar_zenith_angle','swdn','swup','direct_n','diffuse','lwdn', $
              'dw_casetemp','dw_dometemp','lwup','uw_casetemp','uw_dometemp', $
              'uvb','par','swnet','lwnet','totalnet','T','q','windspd', $
              'winddir','P']

header_long = ['solar zenith angle','mean downwelling shortwave radiation', $
               'mean upwelling shortwave radiation', $
               'mean direct shortwave radiation', $
               'mean diffuse shortwave radiation', $
               'mean downwelling longwave radiation', $
               'downwelling PIR case temperature', $
               'downwelling PIR dome temperature', $
               'mean upwelling longwave radiation', $
               'upwelling PIR case temperature', $
               'upwelling PIR dome temperature','UVB radiation', $
               'photosynthetically active radiation', $
               'net shortwave radiation flux','net longwave radiation flux', $
               'total net radiation flux','10m air temperature', $
               '10m specific humidity','10m wind speed','10m wind direction', $
               '10m air pressure']

var_stan = ['solz','boa_swdn','boa_swup','boa_swdn_dir','boa_swdn_dif', $
            'boa_lwdn','boa_lwdn_casetemp','boa_lwdn_dometemp','boa_lwup', $
            'boa_lwup_casetemp','boa_lwup_dometemp','UVB','PAR','boa_swnet', $
            'boa_lwnet','boa_net','Tair','q','windspd','winddir','P']

var_unit = ['degrees','W/m2','W/m2','W/m2','W/m2','W/m2','K','K','W/m2','K', $
            'K','mW/m2','W/m2','W/m2','W/m2','W/m2','K','1','m/s','1','hPa']

var_fill = REPLICATE(-9999.,N_ELEMENTS(header_out))

yrstr = STRING(year, format='(I04)')
yrstr_2 = STRMID(yrstr, 2, 2)
mostr = STRING(month, format='(I02)')

ncname = STRARR(n_gs*n_year*n_month)
n = 0

for g = 0,n_gs-1 do begin
   for y = 0,n_year-1 do begin
      for m = 0,n_month-1 do begin


;==================
;Define output name
;==================

         doy = GET_DOY(year[y], month[m])
         doystr = STRING(doy, format='(I03)')

         if N_ELEMENTS(savepath) eq 0 then savepath = '~/'
         savename = savepath+station[g]+'_' + yrstr[y] + mostr[m]

         savename = savename + '.nc'

         ncname[n] = savename
         n +=1

;=============================================
;Load and process SURFRAD files for each month
;=============================================

         ;Search for existing file and begin if none exists or replace keyword
         ;is set
         junk = FILE_SEARCH(savename, count=junkct)
         
         if KEYWORD_SET(replace) || junkct eq 0 then begin

            ;define file path and search string(s)
            fpath = root + station[g] + '/' + yrstr[y] + '/'
            fsearch = '*' + yrstr_2[y] + doystr + '.dat'

            files = FILE_SEARCH(fpath+fsearch, count=fcnt)

            if fcnt gt 0 then begin
               for f = 0,N_ELEMENTS(files)-1 do begin
                  PRINT, files[f]
                  ;Generate a lun for the file
                  OPENR, lun, files[f], /get_lun

                  ;Get full length of file - should be
                  ;482 for SURFRAD (480 rows of data + 2 header lines)
                  n_lines = FILE_LINES(files[f])

                  ;Get station name from first line of file, 
                  ;then lat/lon/elev from 2nd line   
                  tstr = ''
                  ;First line
                  READF, lun, tstr 
                  if f eq 0 then $
                     station_name = tstr[0]
                  ;Second line
                  READF, lun, tstr
                  if f eq 0 then begin
                     station_lat = FLOAT(strmid(tstr,0,8))
                     station_lon = FLOAT(strmid(tstr,9,8))
                     station_elev = FLOAT(strmid(tstr,17,4))

                     ;Read out lat,lon if keyword set
                     location[0,g] = station_lat
                     location[1,g] = station_lon
                  endif

                  ;Now get actual data - note file has 48 columns due to qc flags
                  temp = FLTARR(48, n_lines-2)
                  READF, lun, temp
   
                  ;Add each files data to the bottom of the array, defining array if first loop
                  if f eq 0 then $
                     data_in = list(temp) $
                     else $
                        data_in.add, temp

                  ;Close file and free lun
                  CLOSE, lun
                  FREE_LUN, lun
               endfor
      
               ;Convert list to array, concatenating over second dimension
               data_in = data_in.toarray(dimension=2)
      
               ;Get column length of data array
               l_data = N_ELEMENTS(data_in[0,*])

               ;Data without qc flag: time data, (year, month, day, hour, minute,
               ;Decimal time, JDay, solar_zenith angle
               t_data = data_in[0:7,*]

               ;Separate actual data and qc flags
               data_in = TRANSPOSE(data_in[8:*,*])
               data_in = REFORM(data_in,l_data*2, 20)
               data_qc = TRANSPOSE(data_in[l_data:*,*])
               data_in = TRANSPOSE(data_in[0:l_data-1,*])

               ;Write missing data and flagged data as nan
               data_in[WHERE(data_in eq -9999.9, /null)] = !values.f_nan
               data_in[WHERE(data_qc eq 1, /null)] = !values.f_nan
               if KEYWROD_SET(strictqc) then $
                  data_in[WHERE(data_qc eq 2, /null)] = !values.f_nan
               
               data_in = [t_data,data_in]
               
               data_out = FLTARR(n_elements(header_out), l_data)

               ;q using rh, T, P (cols 24,23,27)
               ;Note rh in %, not fractional
               T = data_in[23, *]
               RH = data_in[24, *]/100. ;convert to fractional in line w/ ORAC
               P = data_in[27, *]
               ;Equilibrium vapor pressure - T in degrees C, P in hPa (mB)
               es = 6.1094*EXP(17.625*T/(T+243.04))
               ;Specific vapor pressure
               e = RH *es
               q = 0.622*e/(P-0.378*e)

               ;convert T to K
               data_in[[13,14,16,17,23],*] += 273.15

               ;write modified vars to data_in
               data_in[24, *] = q

               ;Get total SW_in from direct and diffuse values, if either is
               ;non-existant use the observed total (less accurate)
               sw_dir =  data_in[10,*]*COS(data_in[7,*]*!pi/180)
               tot_sw_dn = sw_dir + data_in[11,*]
               tot_sw_dn[WHERE(~FINITE(tot_sw_dn))] = $
                  data_in[8, WHERE(~FINITE(tot_sw_dn))]
               data_in[8,*] = tot_sw_dn

               ;Make array of variables to write to ncdf file
               data_out = data_in[7:*,*]
               data_out[WHERE(~FINITE(data_out))] = -9999.

               ;Time in julian days
               timearr = JULDAY(data_in[2,*],data_in[3,*],data_in[0,*], $
                                data_in[4,*],data_in[5,*])

               SAVE_TO_NETCDF, savename, transpose(timearr), header_out, $
                               data_out, header_long, var_stan, var_unit, $
                               var_fill, station_lon, station_lat

               PRINT, 'file ' + savename + ' created'
            endif $
               else PRINT, 'No SURFRAD files found for '+station[g]+' '+ $
               yrstr[y]+'/'+mostr[m]
         endif $
            else begin
            PRINT, 'file ' + savename + ' already exists'
            stat = READ_NCDF(savename, gs_data, $
                             variable_list=['latitude','longitude'])
            location[0,g] = gs_data.latitude
            location[1,g] = gs_data.longitude
         endelse
      endfor ;month
   endfor ;year
endfor ;day
end

