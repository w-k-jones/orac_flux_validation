function val_loop_ctrl, varnames, in1, in2, in3, in4, in5, in6, in7, in8
  
; Rebins and reforms multiple variables to create a struct that can be
; looped over as a single loop, instead of nested loops. Accepts up to
; 8 variable inputs
;
; Subroutines
;
; Generic:
;   -str_rebin.pro


if ~N_ELEMENTS(in1) then MESSAGE, 'No input variables'

in = LIST()

for i = 1,8 do begin
   in_name = 'in'+STRTRIM(STRING(i),1)
   tstr = 'if N_ELEMENTS('+in_name+') gt 0 then in.add, '+in_name
   stat = EXECUTE(tstr)
   if stat ne 1 then MESSAGE, 'Failed to compile inputs'
endfor

n_in = N_ELEMENTS(in)

if n_in ne N_ELEMENTS(varnames) then MESSAGE, 'Number of variable names does not match number of inputs'

n_var = intarr(n_in)
for i = 0,n_in-1 do n_var[i] = N_ELEMENTS(in[i])

n_tot = PRODUCT(n_var)

varnames = ['n',varnames]
values = LIST(n_tot)

for i = 0,n_in-1 do begin
   if i eq 0 then values.add, REFORM(STR_REBIN(in[i],n_var),n_tot) $
   else begin
      ind_arr = REPLICATE(1, n_in)
      ind_arr[i] = n_var[i]
      values.add, REFORM(STR_REBIN(REFORM(in[i],ind_arr),n_var),n_tot)
   endelse
endfor

out = ORDEREDHASH(varnames,values)
out = out.tostruct()

return, out

end
