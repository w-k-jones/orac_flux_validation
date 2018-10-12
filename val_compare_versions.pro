pro val_compare_versions, year, month, version, station=station, satellite=satellite, d_or_n=d_or_n, savepath=savepath, dl=dl, dt=dt, percent=percent

if N_ELEMENTS(d_or_n) eq 0 then d_or_n = 'D'

gws_path = '/group_workspaces/cems2/nceo_generic/cloud_ecv/'
def_savepath = gws_path+'validation/idl/proc/'
if N_ELEMENTS(savepath) eq 0 then savepath = def_savepath

def_sats = ['MODIS-TERRA','MODIS-AQUA','AATSR','ATSR2']
def_gs = ['Alamosa_CO','Bondville_IL','Boulder_CO','Desert_Rock_NV', $
          'Fort_Peck_MT','Goodwin_Creek_MS','Penn_State_PA','Rutland_VT', $
          'Sioux_Falls_SD','Wasco_OR']

if N_ELEMENTS(station) eq 1 && station eq 'all' then $
   station = ['Bondville_IL','Boulder_CO','Desert_Rock_NV', $
              'Fort_Peck_MT','Goodwin_Creek_MS','Penn_State_PA']

CHECK_KEYWORD, satellite, def_sats, key_name='satellite'
CHECK_KEYWORD, station, def_gs, key_name='station'

n_sat = N_ELEMENTS(satellite)
n_gs = N_ELEMENTS(station)
n_month = N_ELEMENTS(month)
n_ver = N_ELEMENTS(version)

;array to hold averaged values per verion - 6 fluxes (4 BoA and 2 BoA)
;                                           and 4 phases (all, clear,
;                                           liquid, ice)
mean_flx = FLTARR(n_ver,6,4)
bias_flx = mean_flx

for ver = 0,n_ver-1 do begin
   add = 0
   for sat = 0,n_sat-1 do begin
      for i = 0,n_gs-1 do begin       ;station [i]
         for j = 0,n_month-1 do begin ;month [j]
             yrstr = string(format='(I04)',year)
             mostr = string(format='(I02)',month[j])
             savname = satellite[sat]+'_'+station[i]+'_'+yrstr+mostr+'_'+ $
                       version[ver]+'_'+d_or_n

             chk_d = 2*KEYWORD_SET(dl) + KEYWORD_SET(dt)
             case chk_d of
                3: savname = savname+'_dl='+STRTRIM(STRING(dl),1)+$
                                     '_dt='+STRTRIM(STRING(dt),1)
                2: savname = savname+'_dl='+STRTRIM(STRING(dl),1)+'*'
                1: savname = savname+'*_dt='+STRTRIM(STRING(dt),1)
                0: savname = savname+'*'
             endcase

             junk = FILE_SEARCH(savepath+savname+'.sav', count=junkct)
             
             if junkct gt 0 then begin
                print, 'Restoring '+savname
                RESTORE, savepath+savname+'.sav'
                if add eq 0 then begin
                   orac = orac_out
                   gs = gs_out
                   ceres = ceres_out
                   add = 1
                endif $
                else begin
                   STRUCT_CONCAT, orac, orac_out, dimension=1
                   STRUCT_CONCAT, gs, gs_out, dimension=1
                   STRUCT_CONCAT, ceres, ceres_out, dimension=1
                endelse
             endif
          endfor
      endfor
   endfor
   
   wh_clr = WHERE(orac.ctype eq 3 or orac.ctype eq 4, /null, clr_cnt)
   wh_wat = WHERE(orac.ctype eq 1 or orac.ctype eq 5, /null, wat_cnt)
   wh_ice = WHERE(orac.ctype eq 2 or orac.ctype eq 6, /null, ice_cnt)

   for k = 0,3 do begin
      wh_f = WHERE(FINITE(orac.boa.(k)[*,0]), /NULL, cnt)
      if cnt gt 0 then begin
         mean_flx[ver,k,0] = MEAN(orac.boa.(k)[*,0], /nan)
         bias_flx[ver,k,0] = MEAN(orac.boa.(k)[*,0]-gs.boa.(k), /nan)
         if KEYWORD_SET(percent) then $
            bias_flx[ver,k,0] /= mean_flx[ver,k,0]/100
         
         if TOTAL(FINITE(orac.boa.(k)[wh_clr,0])) gt 0 then begin
            mean_flx[ver,k,1] = MEAN(orac.boa.(k)[wh_clr,0], /nan)
            bias_flx[ver,k,1] = $
               MEAN((orac.boa.(k)[*,0]-gs.boa.(k))[wh_clr], /nan)
            if KEYWORD_SET(percent) then $
               bias_flx[ver,k,1] /= mean_flx[ver,k,1]/100
         endif

         if TOTAL(FINITE(orac.boa.(k)[wh_wat,0])) gt 0 then begin
            mean_flx[ver,k,2] = MEAN(orac.boa.(k)[wh_wat,0], /nan)
            bias_flx[ver,k,2] = $
               MEAN((orac.boa.(k)[*,0]-gs.boa.(k))[wh_wat], /nan)
            if KEYWORD_SET(percent) then $
               bias_flx[ver,k,2] /= mean_flx[ver,k,2]/100
         endif

         if TOTAL(FINITE(orac.boa.(k)[wh_ice,0])) gt 0 then begin
            mean_flx[ver,k,3] = MEAN(orac.boa.(k)[wh_ice,0], /nan)
            bias_flx[ver,k,3] = $
               MEAN((orac.boa.(k)[*,0]-gs.boa.(k))[wh_ice], /nan)
            if KEYWORD_SET(percent) then $
               bias_flx[ver,k,3] /= mean_flx[ver,k,3]/100
         endif
      endif
   endfor
   
   for k = 1,2 do begin
      wh_f = WHERE(FINITE(orac.toa.(k)[*,0]), /NULL, cnt)
      if cnt gt 0 then begin
         mean_flx[ver,k+3,0] = MEAN(orac.toa.(k)[*,0], /nan)
         bias_flx[ver,k+3,0] = MEAN(orac.toa.(k)[*,0]-ceres.toa.(k), /nan)
         if KEYWORD_SET(percent) then $
            bias_flx[ver,k+3,0] /= mean_flx[ver,k+3,0]/100
         
         if TOTAL(FINITE(orac.toa.(k)[wh_clr,0])) gt 0 then begin
            mean_flx[ver,k+3,1] = MEAN(orac.toa.(k)[wh_clr,0], /nan)
            bias_flx[ver,k+3,1] = $
               MEAN((orac.toa.(k)[*,0]-ceres.toa.(k))[wh_clr], /nan)
            if KEYWORD_SET(percent) then $
               bias_flx[ver,k+3,1] /= mean_flx[ver,k+3,1]/100
         endif

         if TOTAL(FINITE(orac.toa.(k)[wh_wat,0])) gt 0 then begin
            mean_flx[ver,k+3,2] = MEAN(orac.toa.(k)[wh_wat,0], /nan)
            bias_flx[ver,k+3,2] = $
               MEAN((orac.toa.(k)[*,0]-ceres.toa.(k))[wh_wat], /nan)
            if KEYWORD_SET(percent) then $
               bias_flx[ver,k+3,2] /= mean_flx[ver,k+3,2]/100
         endif

         if TOTAL(FINITE(orac.toa.(k)[wh_ice,0])) gt 0 then begin
            mean_flx[ver,k+3,3] = MEAN(orac.toa.(k)[wh_ice,0], /nan)
            bias_flx[ver,k+3,3] = $
               MEAN((orac.toa.(k)[*,0]-ceres.toa.(k))[wh_ice], /nan)
            if KEYWORD_SET(percent) then $
               bias_flx[ver,k+3,3] /= mean_flx[ver,k+3,3]/100
         endif
      endif
   endfor
   
endfor

;Bar plots----------------------------------------------------------------------

b_width = 1./(n_ver+1)
b_space = b_width*n_ver
b_labels = ['BoA SWdn','BoA SWup','BoA LWdn','BoA LWup','ToA SWup','ToA LWup']
b_off = FINDGEN(n_ver)+1
b_colors = [16,80,240]

;Plot mean fluxes---------------------------------------------------------------

;all
title = 'Mean Flux (all), '+version[0]
for l = 1,n_ver-1 do title = title+' vs '+version[l]

def_bars = REPLICATE(MAX(mean_flx[*,*,0]),6)
def_off = MEAN(b_off)

CGWINDOW
CGBARPLOT, def_bars, baroffset=def_off, barspace=b_space, barwidth=b_width, $
           barnames=b_labels, color=255, ytitle='Mean Flux /Wm^-2', $
           title=title, /addcmd;, yrange=[0,MAX(def_bars)]
for l = 0,n_ver-1 do $
   CGBARPLOT, mean_flx[l,*,0], baroffset=b_off[l], barspace=b_space, $
              barwidth=b_width, colors=b_colors[l mod 3], /addcmd, /overplot
   

;clear
title = 'Mean Flux (clear), '+version[0]
for l = 1,n_ver-1 do title = title+' vs '+version[l]

def_bars = MAX(mean_flx[*,*,1], dimension=1)
def_off = MEAN(b_off)

CGWINDOW
CGBARPLOT, def_bars, baroffset=def_off, barspace=b_space, barwidth=b_width, $
           barnames=b_labels, color=255, ytitle='Mean Flux /Wm^-2', $
           title=title, /addcmd;, yrange=[0,MAX(def_bars)]
for l = 0,n_ver-1 do $
   CGBARPLOT, mean_flx[l,*,1], baroffset=b_off[l], barspace=b_space, $
              barwidth=b_width, colors=b_colors[l mod 3], /addcmd, /overplot
   
;liquid cloud
title = 'Mean Flux (liquid), '+version[0]
for l = 1,n_ver-1 do title = title+' vs '+version[l]

def_bars = MAX(mean_flx[*,*,2], dimension=1)
def_off = MEAN(b_off)

CGWINDOW
CGBARPLOT, def_bars, baroffset=def_off, barspace=b_space, barwidth=b_width, $
           barnames=b_labels, color=255, ytitle='Mean Flux /Wm^-2', $
           title=title, /addcmd;, yrange=[0,MAX(def_bars)]
for l = 0,n_ver-1 do $
   CGBARPLOT, mean_flx[l,*,2], baroffset=b_off[l], barspace=b_space, $
              barwidth=b_width, colors=b_colors[l mod 3], /addcmd, /overplot
   
;ice cloud
title = 'Mean Flux (ice), '+version[0]
for l = 1,n_ver-1 do title = title+' vs '+version[l]

def_bars = MAX(mean_flx[*,*,3], dimension=1)
def_off = MEAN(b_off)

CGWINDOW
CGBARPLOT, def_bars, baroffset=def_off, barspace=b_space, barwidth=b_width, $
           barnames=b_labels, color=255, ytitle='Mean Flux /Wm^-2', $
           title=title, /addcmd
for l = 0,n_ver-1 do $
   CGBARPLOT, mean_flx[l,*,3], baroffset=b_off[l], barspace=b_space, $
              barwidth=b_width, colors=b_colors[l mod 3], /addcmd, /overplot
   

;plot mean bias-----------------------------------------------------------------

title = 'Mean Bias (all), '+version[0]
for l = 1,n_ver-1 do title = title+' vs '+version[l]

def_bars = REPLICATE(MAX(ABS(bias_flx[*,*,0])),6)
def_bars[1] = -def_bars[0]
def_off = MEAN(b_off)

if KEYWORD_SET(percent) then ylabel = 'Mean Bias / %' $
                        else ylabel = 'Mean Bias /Wm^-2'

CGWINDOW
CGBARPLOT, def_bars, baroffset=def_off, barspace=b_space, barwidth=b_width, $
           barnames=b_labels, color=255, ytitle=ylabel, $
           title=title, /addcmd, charsize = cgdefcharsize()*0.75;, yrange=[-MAX(def_bars),MAX(de'Mean Bias /Wm^-2'f_bars)]
for l = 0,n_ver-1 do $
   CGBARPLOT, bias_flx[l,*,0], baroffset=b_off[l], barspace=b_space, $
              barwidth=b_width, colors=b_colors[l mod 3], /addcmd, /overplot
stop

title = 'Mean Bias (clear), '+version[0]
for l = 1,n_ver-1 do title = title+' vs '+version[l]

def_bars = MAX(ABS(bias_flx[*,*,1]), whm, dimension=1)
def_bars = (bias_flx[*,*,1])[whm]
def_off = MEAN(b_off)

CGWINDOW
CGBARPLOT, def_bars, baroffset=def_off, barspace=b_space, barwidth=b_width, $
           barnames=b_labels, color=255, ytitle=ylabel, $
           title=title, /addcmd;, yrange=[-MAX(def_bars),MAX(def_bars)]
for l = 0,n_ver-1 do $
   CGBARPLOT, bias_flx[l,*,1], baroffset=b_off[l], barspace=b_space, $
              barwidth=b_width, colors=b_colors[l mod 3], /addcmd, /overplot
 

title = 'Mean Bias (liquid), '+version[0]
for l = 1,n_ver-1 do title = title+' vs '+version[l]

def_bars = MAX(ABS(bias_flx[*,*,2]), whm, dimension=1)
def_bars = (bias_flx[*,*,2])[whm]
def_off = MEAN(b_off)

CGWINDOW
CGBARPLOT, def_bars, baroffset=def_off, barspace=b_space, barwidth=b_width, $
           barnames=b_labels, color=255, ytitle=ylabel, $
           title=title, /addcmd;, yrange=[-MAX(def_bars),MAX(def_bars)]
for l = 0,n_ver-1 do $
   CGBARPLOT, bias_flx[l,*,2], baroffset=b_off[l], barspace=b_space, $
              barwidth=b_width, colors=b_colors[l mod 3], /addcmd, /overplot


title = 'Mean Bias (ice), '+version[0]
for l = 1,n_ver-1 do title = title+' vs '+version[l]

def_bars = MAX(ABS(bias_flx[*,*,3]), whm, dimension=1)
def_bars = (bias_flx[*,*,3])[whm]
def_off = MEAN(b_off)

CGWINDOW
CGBARPLOT, def_bars, baroffset=def_off, barspace=b_space, barwidth=b_width, $
           barnames=b_labels, color=255, ytitle=ylabel, $
           title=title, /addcmd;, yrange=[-MAX(def_bars),MAX(def_bars)]
for l = 0,n_ver-1 do $
   CGBARPLOT, bias_flx[l,*,3], baroffset=b_off[l], barspace=b_space, $
              barwidth=b_width, colors=b_colors[l mod 3], /addcmd, /overplot

stop
end
