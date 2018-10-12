function val_process_nc, filename, $
                         variable_list=variable_list, $
                         fillvalue=fillvalue, $
                         replacevalue=replacevalue, $
                         dtag=dtag

if n_elements(replacevalue) eq 0 then replacevalue = !values.f_nan

;get fill values
if n_elements(fillvalue) eq 0 then begin
   fillvalue = list()
   stat = read_ncdf(filename[0], attr_data, variable_list=variable_list, $
                 /no_data, /variable_attributes)
   if stat eq 1 then begin
      dtag = n_tags(attr_data)-n_elements(variable_list)
      for i = 0,n_elements(variable_list)-1 do begin
         if total(tag_names(attr_data.(i+dtag)) eq '_FILLVALUE') eq 1 then $
            fillvalue.add, attr_data.(i+dtag)._fillvalue $
         else fillvalue.add, !null
      endfor
   endif
endif

;now read data and set missing values to replacevalue, or NaN
stat = read_ncdf(filename[0], data, variable_list=variable_list)
if stat eq 1 then begin
   dtag = n_tags(data)-n_elements(variable_list)
   for i = 0,n_elements(variable_list)-1 do begin
      if n_elements(fillvalue[i]) gt 0 then begin
         wh_fill = where(data.(i+dtag) eq fillvalue[i], /null, cnt)
         if cnt gt 0 then $
            data.(i+dtag)[wh_fill] = replacevalue
      endif
   endfor
endif $
   else print, 'Failed to read '+filename[0]

return, data

end
