pro getct, ct, reverse=rev, grey=grey, range=range, repeatcolour=repcol

;+
;getct procedure
;
;wrapper for loadct to load, combine and modify idl colour
;tables. Will set value 0 to black and 255 to white by default. Can
;also set 1 to grey for use as a missing value colour.
;
;inputs: ct - scalar or 1d array of colour table values to load. An
;             array will downscale the colour tables by a power of 2
;             and combine them, with white space filling gaps.
;
;keywords: rev - scalar or 1d array. If 1 reverse the colour table. An
;                array of the same length as ct input will reverse or
;                not for corresponding elements.
;
;          grey - set value at 1 to grey
;
;          range - set a range of the colour table to select (must
;                  have a power of 2 number of elements)
;
;          repeatcolour - repeat each colour a certain number of
;                         times, instead of a continuous blend - must
;                         be a power of 2
;-

if not keyword_set(rev) then rev = 0

if n_elements(rev) ne n_elements(ct) then rev = replicate(rev[0], n_elements(ct))

p = bindgen(9)
n = value_locate(2^p, n_elements(ct))
if n_elements(ct) gt (2^p)[n] then n++
pow=reverse(2^p)

if n_elements(range) ne 0 then begin
   junk = where(2^p eq n_elements([range[0]:range[-1]]), cnt)
   if cnt eq 0 then message, 'Range must cover 2^n elements!'
   range = [range[0]:range[-1]]
endif else range = [0:255]

if n_elements(repcol) ne 0 then begin
   junk = where(2^p eq repcol, cnt)
   if cnt eq 0 then message, 'repeatcolour input must be a power of 2!'
endif else repcol = 1

r=replicate(255B,256)
g=r
b=r

for i = 0, n_elements(ct)-1 do begin
   loadct,ct[i]
   tvlct,ri,gi,bi,/get

   if rev[i] eq 1 then begin
      ri=reverse(ri)
      gi=reverse(gi)
      bi=reverse(bi)
   endif

   ri=rebin(rebin(rebin(ri[range],256/repcol),256),pow[n])
   r[i*pow[n]]=ri

   gi=rebin(rebin(rebin(gi[range],256/repcol),256),pow[n])
   g[i*pow[n]]=gi

   bi=rebin(rebin(rebin(bi[range],256/repcol),256),pow[n])
   b[i*pow[n]]=bi
endfor

r[255]=255
r[0]=0
g[255]=255
g[0]=0
b[255]=255
b[0]=0

if keyword_set(grey) then begin
   r[1] = 128
   g[1] = 128
   b[1] = 128
endif

tvlct,r,g,b

return

end
