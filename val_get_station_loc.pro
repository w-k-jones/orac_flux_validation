function val_get_station_loc, station, savepath=savepath, lat=gs_lat, lon=gs_lon

; get_station_loc.pro
;
; Finds latitude/longitude values for SURFRAD ground stations using
; data contained in files produced by get_station_data

gws_path = '/group_workspaces/cems2/nceo_generic/cloud_ecv/'

def_surfrad = ['Alamosa_CO','Bondville_IL','Boulder_CO','Desert_Rock_NV', $
               'Fort_Peck_MT','Goodwin_Creek_MS','Penn_State_PA','Rutland_VT', $
               'Sioux_Falls_SD','Wasco_OR']

def_gs = def_surfrad

VAL_CHECK_KEYWORD, station, def_gs, key_name='station'

n = N_ELEMENTS(station)

if N_ELEMENTS(savepath) eq 1 then $
   save_path = savepath $
else save_path = gws_path+'validation/idl/surfrad/'

gs_lat = REPLICATE(!values.f_nan,n)
gs_lon = gs_lat

for i = 0,n-1 do begin
   save_name = station[i]+'*'
   files = FILE_SEARCH(save_path+save_name, count=ct)
   if ct gt 0 then begin
      stat = READ_NCDF(files[0], gs_data, $
                       variable_list=['latitude','longitude'])

      gs_lat[i] = gs_data.latitude
      gs_lon[i] = gs_data.longitude
   endif $
   else begin
      gs_lat[i] = !values.f_nan
      gs_lon[i] = !values.f_nan
   endelse
endfor

gs_loc = [[gs_lat],[gs_lon]]

RETURN, gs_loc

end
