pro val_compare_scatter, x, y, cfrac, ctype, $
                     title=title, prefix=prefix, range=range, $
                     clr=clr, wat=wat, ice=ice, $
                     verbose=verbose, percent=percent

if keyword_set(clr)+keyword_set(wat)+keyword_set(ice) eq 0 then begin
   clr = 1
   wat = 1
   ice = 1
endif

cfrac >= 0.01

xprefix = prefix
yprefix = prefix

wh_clr = where(ctype eq 3 or ctype eq 4, /null, clr_cnt)
wh_wat = where(ctype eq 1 or ctype eq 5, /null, wat_cnt)
wh_ice = where(ctype eq 2 or ctype eq 6, /null, ice_cnt)

wh_plot=[]
if keyword_set(clr) then $
   wh_plot=[wh_plot, wh_clr]
if keyword_set(wat) then $
   wh_plot=[wh_plot, wh_wat]
if keyword_set(ice) then $
   wh_plot=[wh_plot, wh_ice]

bias = mean(y[wh_plot]-x[wh_plot],/nan)
sdb = stddev(y[wh_plot]-x[wh_plot],/nan)

av = mean(x[wh_plot],/nan)
sd = stddev(x[wh_plot],/nan)

if keyword_set(clr) && clr_cnt gt 0 then begin
   bias_clear = mean((y-x)[wh_clr],/nan)
   sdb_clear = stddev((y-x)[wh_clr],/nan)
   av_clr = mean(x[wh_clr],/nan)
   sd_clr = stddev(x[wh_clr],/nan)
endif

if keyword_set(wat) && wat_cnt gt 0 then begin
   bias_wat = mean((y-x)[wh_wat],/nan)
   sdb_wat = stddev((y-x)[wh_wat],/nan)
   av_wat = mean(x[wh_wat],/nan)
   sd_wat = stddev(x[wh_wat],/nan)
endif

if keyword_set(ice) && ice_cnt gt 0 then begin
   bias_ice = mean((y-x)[wh_ice],/nan)
   sdb_ice = stddev((y-x)[wh_ice],/nan)
   av_ice = mean(x[wh_ice],/nan)
   sd_ice = stddev(x[wh_ice],/nan)
endif

if n_elements(range) eq 0 then $
   scatter_range = [0, FIX(MAX([x[wh_plot],y[wh_plot]],/nan)/100)+1]*100 $
                          else $
                             scatter_range=range

PLOT, scatter_range, scatter_range, linestyle=2, $
      xtitle = xprefix+' observed / W/m^2', $
      ytitle = yprefix+' derived / W/m^2', position = [0.1,0.2,0.45,0.9], $
      charsize = cgdefcharsize()*0.75

if keyword_set(clr) && clr_cnt gt 0 then $
   oplot, x[wh_clr], y[wh_clr], psym=cgsymcat(16), color =16,symsize=0.5
if keyword_set(wat) && wat_cnt gt 0 then $
   oplot, x[wh_wat], y[wh_wat], psym=cgsymcat(16), color =240,symsize=0.5
if keyword_set(ice) && ice_cnt gt 0 then $
   oplot, x[wh_ice], y[wh_ice], psym=cgsymcat(16), color =80,symsize=0.5

if ~KEYWORD_SET(percent) then begin
   temp_range = FIX(3*STDDEV(y[wh_plot]-x[wh_plot],/nan))/100 +1
   bias_range = [-temp_range,temp_range]*100

   PLOT, [0,0], [0.01,50], linestyle=2, xtitle = xprefix+' bias / W/m^2', $
         ytitle = 'Log cloud optical thickness', xrange = bias_range, $
         position = [0.55,0.2,0.9,0.9], /noerase, $
         charsize = cgdefcharsize()*0.75,/ylog

   if keyword_set(clr) && clr_cnt gt 0 then $
      oplot, y[wh_clr]-x[wh_clr], cfrac[wh_clr], psym=cgsymcat(16), color=16, $
             symsize=0.5
   if keyword_set(wat) && wat_cnt gt 0 then $
      oplot, y[wh_wat]-x[wh_wat], cfrac[wh_wat], psym=cgsymcat(16), color=240, $
             symsize=0.5
   if keyword_set(ice) && ice_cnt gt 0 then $
      oplot, y[wh_ice]-x[wh_ice], cfrac[wh_ice], psym=cgsymcat(16), color=80, $
             symsize=0.5
endif $
else begin
   temp_pc = STDDEV(y[wh_plot]-x[wh_plot],/nan) / av *100
   temp_range = FIX(3*temp_pc) +1
   bias_range = [-temp_range,temp_range]
   
   PLOT, [0,0], [0.01,50], linestyle=2, xtitle = xprefix+' bias / %', $
         ytitle = 'Log cloud optical thickness', xrange = bias_range, $
         position = [0.55,0.2,0.9,0.9], /noerase, $
         charsize = cgdefcharsize()*0.75,/ylog

   if keyword_set(clr) && clr_cnt gt 0 then $
      oplot,100*(y[wh_clr]-x[wh_clr])/av_clr, cfrac[wh_clr], $
            psym=cgsymcat(16), color=16, symsize=0.5
   if keyword_set(wat) && wat_cnt gt 0 then $
      oplot, 100*(y[wh_wat]-x[wh_wat])/av_wat, cfrac[wh_wat], $
             psym=cgsymcat(16), color=240, symsize=0.5
   if keyword_set(ice) && ice_cnt gt 0 then $
      oplot, 100*(y[wh_ice]-x[wh_ice])/av_ice, cfrac[wh_ice], $
             psym=cgsymcat(16), color=80, symsize=0.5

   ;change mean bias to %
   bias = 100*bias/av
   sdb = 100*sdb/av

   if keyword_set(clr) && clr_cnt gt 0 then begin
      bias_clear = 100*bias_clear/av_clr
      sdb_clear = 100*sdb_clear/av_clr
   endif

   if keyword_set(wat) && wat_cnt gt 0 then begin
      bias_wat = 100*bias_wat/av_wat
      sdb_wat = 100*sdb_wat/av_wat
   endif

   if keyword_set(ice) && ice_cnt gt 0 then begin
      bias_ice = 100*bias_ice/av_ice
      sdb_ice = 100*sdb_ice/av_ice
   endif

endelse
   

cgText, 0.5, 0.925, /normal, title, alignment = 0.5, charsize = cgdefcharsize()*1.25

;calculate correlation and bias
wh_fin = where(finite(x[wh_plot]+y[wh_plot]),/null,cnt)

if cnt gt 0 then begin
   cor = correlate(x[wh_plot[wh_fin]],y[wh_plot[wh_fin]])
   cor2 = correlate(x[wh_plot[wh_fin]]^2,y[wh_plot[wh_fin]]^2)
endif $
   else cor = !values.f_nan

;cgText, 0.44, 0.28, /normal, 'R = '+string(cor, format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1
cgText, 0.42, 0.24, /normal, 'R^2 = '+string(cor^2, format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1

print, title

;Define arrays for legend input
lgnd_title = ['mean = '+string(av, format='(f0.2)')+'$\+-$'+string(sd, format='(f0.2)')]
lgnd_sym = [0]
lgnd_color = [255]

blgnd_title = ['bias = '+string(bias, format='(f0.2)')+'$\+-$'+string(sdb, format='(f0.2)')]
blgnd_sym = [0]
blgnd_color = [255]

;cgText, 0.44, 0.4, /normal, 'mean = '+string(av, format='(f0.2)')+'$\+-$'+string(sd, format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1
;cgText, 0.89, 0.4, /normal, 'bias = '+string(bias, format='(f0.2)')+'$\+-$'+string(sdb, format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1

if keyword_set(verbose) then begin
   print, 'mean = '+string(av, format='(f0.2)')+'$\+-$'+string(sd, format='(f0.2)')
   print, 'bias = '+string(bias, format='(f0.2)')+'$\+-$'+string(sdb, format='(f0.2)')
   print, '     = '+string(100*bias/av, format='(f0.2)')+'$\+-$'+string(100*sdb/av, format='(f0.2)')+'%'
   print, 'R^2 = '+string(cor^2, format='(f0.2)')
endif

if keyword_set(clr) && clr_cnt gt 0 then begin

   lgnd_title = [lgnd_title, '(clear) = '+string(av_clr, format='(f0.2)')+'$\+-$'+string(sd_clr, format='(f0.2)')]
   lgnd_sym = [lgnd_sym, 16]
   lgnd_color = [lgnd_color, 16]

   blgnd_title = [blgnd_title, '(clear) = '+string(bias_clear, format='(f0.2)')+'$\+-$'+string(sdb_clear, format='(f0.2)')]
   blgnd_sym = [blgnd_sym, 16]
   blgnd_color = [blgnd_color, 16]

   ;cgText, 0.44, 0.36, /normal, '(clear) = '+string(av_clr, format='(f0.2)')+'$\+-$'+string(sd_clr, format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1
                                ;cgText, 0.89, 0.36, /normal, '(clear)
                                ;= '+string(bias_clear,
                                ;format='(f0.2)')+'$\+-$'+string(sdb_clear,
                                ;format='(f0.2)'), charsize =
                                ;cgdefcharsize()*0.5,alignment=1

   if keyword_set(verbose) then begin
      print, 'Clear:'
      print, 'mean = '+string(av_clr, format='(f0.2)')+'$\+-$'+string(sd_clr, format='(f0.2)')
      print, 'bias = '+string(bias_clear, format='(f0.2)')+'$\+-$'+string(sdb_clear, format='(f0.2)')
      print, '     = '+string(100*bias_clear/av_clr, format='(f0.2)')+'$\+-$'+string(100*sdb_clear/av_clr, format='(f0.2)')+'%'
   endif
endif $
   else print, 'No clear retrievals'



if keyword_set(wat) && wat_cnt gt 0 then begin

   lgnd_title = [lgnd_title, '(liquid) = '+string(av_wat, format='(f0.2)')+'$\+-$'+string(sd_wat, format='(f0.2)')]
   lgnd_sym = [lgnd_sym, 16]
   lgnd_color = [lgnd_color, 240]

   blgnd_title = [blgnd_title, '(liquid) = '+string(bias_wat, format='(f0.2)')+'$\+-$'+string(sdb_wat, format='(f0.2)')]
   blgnd_sym = [blgnd_sym, 16]
   blgnd_color = [blgnd_color, 240]

   ;cgText, 0.44, 0.32, /normal, '(liquid) = '+string(av_wat, format='(f0.2)')+'$\+-$'+string(sd_wat, format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1
                                ;cgText, 0.89, 0.32, /normal,
                                ;'(liquid) = '+string(bias_wat,
                                ;format='(f0.2)')+'$\+-$'+string(sdb_wat,
                                ;format='(f0.2)'), charsize =
                                ;cgdefcharsize()*0.5,alignment=1
   if keyword_set(verbose) then begin
      print, 'Liquid:'
      print, 'mean = '+string(av_wat, format='(f0.2)')+'$\+-$'+string(sd_wat, format='(f0.2)')
      print, 'bias = '+string(bias_wat, format='(f0.2)')+'$\+-$'+string(sdb_wat, format='(f0.2)')
      print, '     = '+string(100*bias_wat/av_wat, format='(f0.2)')+'$\+-$'+string(100*sdb_wat/av_wat, format='(f0.2)')+'%'
   endif
endif $
   else print, 'No liquid etrievals'

if keyword_set(ice) && ice_cnt gt 0 then begin

   lgnd_title = [lgnd_title, '(ice) = '+string(av_ice, format='(f0.2)')+'$\+-$'+string(sd_ice, format='(f0.2)')]
   lgnd_sym = [lgnd_sym, 16]
   lgnd_color = [lgnd_color, 80]

   blgnd_title = [blgnd_title, '(ice) = '+string(bias_ice, format='(f0.2)')+'$\+-$'+string(sdb_ice, format='(f0.2)')]
   blgnd_sym = [blgnd_sym, 16]
   blgnd_color = [blgnd_color, 80]

   ;cgText, 0.44, 0.28, /normal, '(ice) = '+string(av_ice, format='(f0.2)')+'$\+-$'+string(sd_ice, format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1
   ;cgText, 0.89, 0.28, /normal, '(ice) = '+string(bias_ice, format='(f0.2)')+'$\+-$'+string(sdb_ice, format='(f0.2)'), charsize = cgdefcharsize()*0.5,alignment=1
   if keyword_set(verbose) then begin
      print, 'Ice:'
      print, 'mean = '+string(av_ice, format='(f0.2)')+'$\+-$'+string(sd_ice, format='(f0.2)')
      print, 'bias = '+string(bias_ice, format='(f0.2)')+'$\+-$'+string(sdb_ice, format='(f0.2)')
      print, '     = '+string(100*bias_ice/av_ice, format='(f0.2)')+'$\+-$'+string(100*sdb_ice/av_ice, format='(f0.2)')+'%'
   endif
endif $
   else print, 'No ice etrievals'

if keyword_set(verbose) then print, '--------------------'

;lgnd_title = [lgnd_title, 'R^2 = '+string(cor^2, format='(f0.2)')]
;lgnd_sym = [lgnd_sym, 0]
;lgnd_color = [lgnd_color, 255]

if n_elements(lgnd_title) eq 2 then begin
   cgLegend, title=lgnd_title, psym=lgnd_sym, color=lgnd_color, $
             location=[0.25,0.05], alignment=8, length = 0., $
             charsize = cgdefcharsize()*0.5, /box, /background, bg_color=255

   cgLegend, title=blgnd_title, psym=blgnd_sym, color=blgnd_color, $
             location=[0.75,0.05], alignment=8, length = 0., $
             charsize = cgdefcharsize()*0.5, /box, /background, bg_color=255
endif $
   else begin
   if n_elements(lgnd_title) eq 3 then begin
      lgnd_title = [lgnd_title, '']
      lgnd_sym = [lgnd_sym, 0]
      lgnd_color = [lgnd_color, 255]
      
      blgnd_title = [blgnd_title, '']
      blgnd_sym = [blgnd_sym, 0]
      blgnd_color = [blgnd_color, 255]
   endif

   cgLegend, title=lgnd_title[0:1], psym=lgnd_sym[0:1], color=lgnd_color[0:1], $
             location=[0.28,0.06], alignment=7, length = 0., $
             charsize = cgdefcharsize()*0.6, /box, /background, bg_color=255

   cgLegend, title=blgnd_title[0:1], psym=blgnd_sym[0:1], color=blgnd_color[0:1], $
             location=[0.72,0.06], alignment=7, length = 0., $
             charsize = cgdefcharsize()*0.6, /box, /background, bg_color=255

   cgLegend, title=lgnd_title[2:3], psym=lgnd_sym[2:3], color=lgnd_color[2:3], $
             location=[0.28,0.06], alignment=6, length = 0., $
             charsize = cgdefcharsize()*0.6, /box, /background, bg_color=255

   cgLegend, title=blgnd_title[2:3], psym=blgnd_sym[2:3], color=blgnd_color[2:3], $
             location=[0.72,0.06], alignment=6, length = 0., $
             charsize = cgdefcharsize()*0.6, /box, /background, bg_color=255
endelse


;cgLegend, title=lgnd_title, psym=lgnd_sym, color=lgnd_color, location=[0.44,0.21], alignment=2, length = 0., charsize = cgdefcharsize()*0.5, /box, /background, bg_color=255

;cgLegend, title=blgnd_title, psym=blgnd_sym, color=blgnd_color, location=[0.89,0.21], alignment=2, length = 0., charsize = cgdefcharsize()*0.5, /box, /background, bg_color=255

;cgText, 0.44, 0.4, /normal, 'mean = '+string(av, format='(f0.2)')+'$\+-$'+string(sd, format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1
;cgText, 0.89, 0.4, /normal, 'bias = '+string(bias, format='(f0.2)')+'$\+-$'+string(sdb, format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1



;cgText, 0.44, 0.4, /normal, 'mean = '+string(mean(y,/nan), format='(f0.2)')+'$\+-$'+string(stddev(y,/nan), format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1
;cgText, 0.44, 0.36, /normal, '(clear) = '+string(mean(y[where(cfrac lt 0.5,/null)],/nan), format='(f0.2)')+'$\+-$'+string(stddev(y[where(cfrac lt 0.5,/null)],/nan), format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1
;cgText, 0.44, 0.32, /normal, '(cloudy) = '+string(mean(y[where(cfrac ge 0.5,/null)],/nan), format='(f0.2)')+'$\+-$'+string(stddev(y[where(cfrac ge 0.5,/null)],/nan), format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1

;cgText, 0.44, 0.28, /normal, 'R = '+string(cor, format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1
;cgText, 0.44, 0.24, /normal, 'R^2 = '+string(cor^2, format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1

;cgText, 0.89, 0.4, /normal, 'bias = '+string(bias, format='(f0.2)')+'$\+-$'+string(sdb, format='(f0.2)'), charsize = cgdefcharsize()*0.6,alignment=1
;cgText, 0.89, 0.36, /normal, '(clear) = '+string(bias_clear, format='(f0.2)')+'$\+-$'+string(sdb_clear, format='(f0.2)'), charsize = cgdefcharsize()*0.5,alignment=1
;cgText, 0.89, 0.32, /normal, '(cloudy) = '+string(bias_cloud, format='(f0.2)')+'$\+-$'+string(sdb_cloud, format='(f0.2)'), charsize = cgdefcharsize()*0.5,alignment=1

end

