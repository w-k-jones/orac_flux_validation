function val_get_station_data, station=station, year=year, month=month, $
                               savepath=savepath

; Finds ground site data for validation process. Currently only works
; with SURFRAD sites, but more can be added in and checked for using
; the default sites array
;
; WJ, 2016/08/22: Updated description anbd added list of subroutines
;
; Subroutines
; 
; Generic:
;   -check_keyword.pro
;   -loop_ctrl.pro
;
; Validation
;   -read_surfrad.pro

gws_path = '/group_workspaces/cems2/nceo_generic/cloud_ecv/'

def_surfrad = ['Alamosa_CO','Bondville_IL','Boulder_CO','Desert_Rock_NV', $
               'Fort_Peck_MT','Goodwin_Creek_MS','Penn_State_PA','Rutland_VT', $
               'Sioux_Falls_SD','Wasco_OR']

def_gs = def_surfrad

VAL_CHECK_KEYWORD, station, def_gs, key_name='station'

;Check control input or keyword input, generate from those if missing
if ~N_ELEMENTS(station) || $
   ~N_ELEMENTS(year) || $
   ~N_ELEMENTS(month) then MESSAGE, 'No CTRL input' $
else ctrl = VAL_LOOP_CTRL(['station','month','year'],station,month,year)


yyyy = STRING(ctrl.year, format='(I04)')
mm = STRING(ctrl.month, format='(I02)')

save_name = ctrl.station+'_'+yyyy+mm+'.nc'

if N_ELEMENTS(savepath) eq 1 then $
   save_path = savepath $
else save_path = gws_path+'validation/idl/station/'

junk = SET_OP(save_path+save_name, FILE_SEARCH(save_path+save_name, count=ct), $
              diff_ind=wh)

n_miss = N_ELEMENTS(wh)

if ct lt ctrl.n then begin
   for i = 0,n_miss-1 do begin
      j = wh[i]
      if TOTAL(WHERE(def_surfrad eq ctrl.station[j])) gt 0 then $
         gs_type = 'SURFRAD'

      if gs_type eq 'SURFRAD' then begin
         VAL_READ_SURFRAD, ctrl.station[j], ctrl.year[j], ctrl.month[j], $
                    /strictqc, savepath=save_path
      endif
   endfor
endif

RETURN, save_path+save_name

end
