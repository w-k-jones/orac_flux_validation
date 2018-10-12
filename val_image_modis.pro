pro val_image_modis, mod021_in, mod03_in, false=false

if SIZE(mod021_in, /type) eq 7 then $
   mod021 = READ_HDF4(mod021_in[0]) $
else mod021 = mod021_in

!p.multi=[0,2,1]

truergb=[[[bytscl(mod021.EV_250_AGGR1KM_REFSB[*,*,0]^0.2, min=4, max=8)]], $
         [[bytscl(mod021.EV_500_AGGR1KM_REFSB[*,*,1]^0.2, min=4, max=7.5)]], $
         [[bytscl(mod021.EV_500_AGGR1KM_REFSB[*,*,0]^0.2, min=4, max=7)]]]

if N_ELEMENTS(mod03_in) gt 0 then begin
   if SIZE(mod021_in, /type) eq 7 then $
      mod03 = READ_HDF4(mod03_in[0]) $
   else mod03 = mod03

   im_dat = l2chunk3(truergb, mod03.lat, mod03.lon, gridsize=0.1)
   cgwindow
   cgimage,im_dat,/addcmd
   
endif $
else begin
   cgwindow
   cgimage,reverse(truergb,2),/addcmd
endelse

end
