pro val_check_batch, n_files_in

b_stat=[]
b_pend=[]
b_chk = 0

SPAWN, 'bjobs', b_stat
if N_ELEMENTS(b_stat) eq 1 && b_stat eq '' then print, 'no jobs require processing' else begin
   n_last_chk = N_ELEMENTS(b_stat) - 1
   if N_ELEMENTS(n_files_in) eq 0 then n_files_in = n_last_chk
   print, 'waiting for batch jobs to complete'

   TIC

   while 1 do begin
      WAIT, 1
      spawn, 'bjobs', b_stat
      n_chk = N_ELEMENTS(b_stat) - 1
      if N_ELEMENTS(b_pend) ne 1 then SPAWN, 'bjobs -p', b_pend
      if N_ELEMENTS(b_stat) eq 1 && b_stat eq '' then begin
         print, 'All files processed'
         TOC
         break
      endif
      if N_ELEMENTS(b_pend) eq N_ELEMENTS(b_stat) then $
         if b_chk ge 15 then begin
            print, 'No jobs running!' 
            TOC
            break
         endif $
            else b_chk +=1
      if n_chk lt n_last_chk then begin
         pc = 100.*(1 - FLOAT(n_chk)/FLOAT(n_files_in))
         print, string(pc, format='(f0.2)')+'% complete'
         TOC

         n_last_chk = n_chk
      endif
   endwhile
endelse

end
