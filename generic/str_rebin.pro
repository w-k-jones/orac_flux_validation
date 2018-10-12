function str_rebin, str_in, dim1, dim2, dim3, dim4, dim5, dim6, dim7, dim8
  
;Wrapper for rebin function in order to handle string array input. Can
;accept up to 8 dimensions in either an array input or separate inputs.

if ~N_ELEMENTS(str_in) then MESSAGE, 'Required input: string array'
if ~N_ELEMENTS(dim1) then MESSAGE, 'Required input: rebin dimensions'

;; srt = SORT(str_in)
;; uni = UNIQ(str_in, srt)
;; uni = uni[SORT(srt)]

uni = INDGEN(N_ELEMENTS(str_in))

uni = REFORM(uni, SIZE([str_in], /dim))

if N_ELEMENTS(dim1) gt 1 then begin
   if N_ELEMENTS(dim1) gt 8 then MESSAGE, 'Too many dimensions - maximum of 8'
   if N_ELEMENTS(dim2) gt 0 then MESSAGE, 'Too many input arguments' $
   else begin
      ind = REBIN(uni, dim1)
      str_out = str_in[ind]
   endelse
endif $
else begin
   dim = dim1
   for i = 2,8 do begin
      dim_name = 'dim'+STRTRIM(STRING(i),1)
      tstr = 'if N_ELEMENTS('+dim_name+') gt 0 then dim = [dim, '+dim_name+']'
      stat = EXECUTE(tstr)
      if stat ne 1 then MESSAGE, 'Failed to compile dimensions'
   endfor
   ind = REBIN(uni, dim)
   str_out = str_in[ind]
endelse

RETURN, str_out

end
