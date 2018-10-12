pro val_struct_concat, struct, add, dimension=dimension

forward_function val_struct_concat

if n_tags(struct) ne n_tags(add) then message, 'Structures have different number of tags'

if n_elements(dimension) eq 0 then dimset = 0 $
   else dimset = 1

tags = tag_names(struct)

tmp_struct = {}

for i = 0,n_tags(struct)-1 do begin
   if size(struct.(i),/type) eq 8 or size(struct.(i),/type) eq 11 then begin
      val = struct.(i)
      val_struct_concat, val, add.(i), dimension=dimension
   endif $
      else begin
      if dimset eq 0 then begin
         n_dim = size(struct.(i),/n_dimensions)
         dimension = n_dim+1
      endif
      if n_elements(add.(i)) eq 1 then $
         val = list(struct.(i),[add.(i)]) $
      else $
         val = list(struct.(i),add.(i))
      val = val.toarray(dimension=dimension)
   endelse
   tmp_struct = create_struct(tmp_struct, tags[i], val)
endfor

struct = tmp_struct

end
