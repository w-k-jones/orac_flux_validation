pro val_find_overpass, gs_data, optime, opzen, opazi,  wh_up=wh_up, wh_dn=wh_dn

tup_wh = (WHERE(gs_data.time gt optime))[0]

zenflag = (gs_data.solar_zenith_angle[tup_wh-1] lt opzen) + $
          (gs_data.solar_zenith_angle[tup_wh] lt opzen)

if opazi gt 0 then begin
   case zenflag of
      0: wh_up = (WHERE(gs_data.solar_zenith_angle[tup_wh-120:tup_wh-1] gt $
                        opzen))[-1] + tup_wh - 120
      1: wh_up = tup_wh
      2: wh_up = (WHERE(gs_data.solar_zenith_angle[tup_wh:tup_wh+119] gt $
                        opzen))[0] + tup_wh
   endcase
endif $
   else begin
   case zenflag of
      2: wh_up = (WHERE(gs_data.solar_zenith_angle[tup_wh-120:tup_wh-1] gt $
                        opzen))[-1] + tup_wh - 120
      1: wh_up = tup_wh
      0: wh_up = (WHERE(gs_data.solar_zenith_angle[tup_wh:tup_wh+119] gt $
                        opzen))[0] + tup_wh
   endcase
endelse

;; print, string(opazi)
;; print, string(zenflag)
;; print, string(tup_wh)
;; print, string(wh_up)
;; print, string(abs(gs_data.time[wh_up]-gs_data.time[tup_wh]))

wh_dn = wh_up-1

end
