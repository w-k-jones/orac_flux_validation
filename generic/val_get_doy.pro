function val_get_doy, year, month, day=day, norepeat=norepeat

if keyword_set(norepeat) && n_elements(day) ge 1 && n_elements(day) ne n_elements(month) then message, 'Month and day arrays have different lengths!'

if n_elements(day) gt 1 && n_elements(month) && ~keyword_set(norepeat) gt 1 then doy = julday(rebin(transpose(month), n_elements(day), n_elements(month)), rebin(day, n_elements(day), n_elements(month)), year,0,0,0) - julday(1,1,year,0,0,0) + 1 else if n_elements(day) ge 1 then doy = julday(month,day,year,0,0,0) - julday(1,1,year,0,0,0) + 1 else foreach mo, month, ind do if ind eq 0 then doy = [julday(mo,1,year,0,0,0)+1:julday(mo+1,1,year,0,0,0)] - julday(1,1,year,0,0,0) else doy = [doy, [julday(mo,1,year,0,0,0)+1:julday(mo+1,1,year,0,0,0)] - julday(1,1,year,0,0,0)]

doy = fix(reform(doy,n_elements(doy),/overwrite))

return, doy

end


