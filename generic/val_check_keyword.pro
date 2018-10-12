pro val_check_keyword, keyword, def_keyword, $
                       key_name=key_name, description=description
;
; Check Keyword (validation)
;
; Procedure to check if a keyword is one of a set of pre-defined
; valid inputs. Deals with both scalar and array inputs, and numeric
; and string values. Structures, hashes and other data types not
; accepted.

;check key_name keyword
if N_ELEMENTS(key_name) eq 0 then key_name = '' $
   else key_name = '"'+key_name+'" '

;get type of accepted keywords
def_type = SIZE(def_keyword, /type)

;define variable to read in as a string if defined to be of this type
if def_type eq 7 then read_in = ''

;check if structure or other data type
if SIZE(keyword, /type) eq 8 || SIZE(keyword, /type) eq 11 then $
   MESSAGE, 'Compound data type for keyword '+key_name+'not accepted'

if N_ELEMENTS(keyword) eq 0 then begin
   if def_type eq 7 then keyword = '' $
      else keyword = []
   PRINT, 'No input for keyword '+key_name+ $
          ', please enter one of the following:'
   PRINT, string(def_keyword)
   PRINT, '...then press enter'
   if N_ELEMENTS(descriptions) gt 0 then begin
      PRINT, '(Descriptions: '
      PRINT, descriptions, ')'
   endif
   READ, keyword
   while TOTAL(def_keyword eq keyword) eq 0 do begin
      PRINT, 'Keyword input "'+string(keyword)+'" for keyword '+key_name+ $
             'not valid, please enter one of the following:'
      PRINT, def_keyword
      PRINT, '...then press enter'
      if N_ELEMENTS(descriptions) gt 0 then begin
         PRINT, '(Descriptions: '
         PRINT, descriptions, ')'
      endif
      READ, keyword
   endwhile
endif $
   else begin

   key_in = STRING(keyword)

   if (def_type eq 7 && SIZE(keyword, /type) ne 7) || $
      (SIZE(keyword, /type) eq 7 && def_type ne 7) then begin 

      keyword = MAKE_ARRAY(n_elements(keyword), type=def_type)
      key_flag = 1
   endif $
      else key_flag = 0

   for i = 0,N_ELEMENTS(keyword)-1 do begin
      if key_flag || TOTAL(def_keyword eq keyword[i]) eq 0 then begin
         PRINT, 'Keyword input "'+key_in[i]+'" for keyword '+key_name+ $
                'not valid, please enter one of the following:'
         PRINT, def_keyword
         PRINT, '...then press enter'
         if N_ELEMENTS(descriptions) gt 0 then begin
            PRINT, '(Descriptions: '
            PRINT, descriptions, ')'
         endif
         READ, read_in
         keyword[i] = FIX(read_in, type=def_type)
         while TOTAL(def_keyword eq keyword[i]) eq 0 do begin
            PRINT, 'Keyword input "'+key_in[i]+'" for keyword '+key_name+ $
                   'not valid, please enter one of the following:'
            PRINT, def_keyword
            PRINT, '...then press enter'
            if N_ELEMENTS(descriptions) gt 0 then begin
               PRINT, '(Descriptions: '
               PRINT, descriptions, ')'
            endif
            READ, read_in
            keyword[i] = FIX(read_in, type=def_type)
         endwhile
      endif
   endfor
endelse

end
