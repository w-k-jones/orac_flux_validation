pro val_read_bsrn, station , $ ;station input
                   year, month, $ ;date input
                   strictqc=strictqc, $    ;filter out values with a qc flag of 2 (questionable). By default only qc flag of 1 is removed.
                   ncname=ncname, $        ;return keyword for output ncdf file name
                   replace=replace, $      ;replace existing files
                   savepath=savepath, $    ;path to save
                   location=location       ;[lat,lon] location of ground station

; 2018/10/18 - WJ: created

day_range = floor(JULDAY(month+1, 1, year) - JULDAY(month, 1, year))

; todo: search for bsrn file using date and station name

n_lines = file_lines(bsrn_file)

openr, lun, bsrn_file, /get_lun

tstr = ''
; Read the first line and check if the data record is correct
readf, lun, tstr
if tstr ne '*U0001' then message, 'Error, val_read_bsrn: unexpected file content in '+bsrn_file

tarr = intarr(4)
; Read the second line to an array and check if the year and month of the file
;  match the input values
readf, lun, tarr

if tarr[2] ne year then message, 'Error, val_read_bsrn: unexpected year in '+bsrn_file
if tarr[1] ne month then message, 'Error, val_read_bsrn: unexpected month in '+bsrn_file

; Reset to the start of the file
point_lun, lun, 0

; Loop over file, search for data record of basic measurements
data_flag = 0
for line = 0, n_lines-1 do begin
  readf, lun, tstr
  if tstr eq '*C0100' then begin
    data_flag = 1
    point_lun, -lun, pos
    break
  endif
endfor
if data_flag then begin
  ; Find length of record
  for line = pos, n_lines-1 do begin
    readf, lun, tstr
    if strmid(tstr,0,1) eq '*' then break
  endfor
  record_length = floor((line - pos)/2) ; basic measurement row is split over two lines
  ; Return to start of record and read all data into an array
  point_lun, lun, pos
  data_array = fltarr(21, record_length)
  readf, lun, data_array
  ; read first two lines of the record to get the temporal spacing of measurements
  min0 = data_array[1,0]
  min1 = data_array[1,1]
  d_t = floor(min0-min1)
endif $
else message, 'Error, val_read_bsrn: missing basic measurement record in '+bsrn_file

point_lun, -lun, pos
; Find other measurment record
data_flag = 0
for line = pos, n_lines-1 do begin
  readf, lun, tstr
  if tstr eq '*C0300' then begin
    data_flag = 1
    point_lun, -lun, pos
    break
  endif
endfor

if data_flag then begin
  ; Find length of record
  for line = pos, n_lines-1 do begin
    readf, lun, tstr
    if strmid(tstr,0,1) eq '*' then break
  endfor
  record_length = floor((line - pos)/1)
  ; Return to start of record and read all data into an array
  point_lun, lun, pos
  data_array2 = fltarr(14, record_length)
  readf, lun, data_array2
  ; read first two lines of the record to get the temporal spacing of measurements
  min0 = data_array2[1,0]
  min1 = data_array2[1,1]
  d_t2 = floor(min0-min1)
endif

point_lun, -lun, pos
; Find other measurment record
data_flag = 0
for line = pos, n_lines-1 do begin
  readf, lun, tstr
  if tstr eq '*C3010' then begin
    data_flag = 1
    point_lun, -lun, pos
    break
  endif
endfor

if data_flag then begin
  ; Find length of record
  for line = pos, n_lines-1 do begin
    readf, lun, tstr
    if strmid(tstr,0,1) eq '*' then break
  endfor
  record_length = floor((line - pos)/1)
  ; Return to start of record and read all data into an array
  point_lun, lun, pos
  data_array2 = fltarr(14, record_length)
  readf, lun, data_array2
  ; read first two lines of the record to get the temporal spacing of measurements
  min0 = data_array2[1,0]
  min1 = data_array2[1,1]
  d_t2 = floor(min0-min1)
endif

point_lun, -lun, pos
; Find other measurment record
data_flag = 0
for line = pos, n_lines-1 do begin
  readf, lun, tstr
  if tstr eq '*C3030' then begin
    data_flag = 1
    point_lun, -lun, pos
    break
  endif
endfor

if data_flag then begin
  ; Find length of record
  for line = pos, n_lines-1 do begin
    readf, lun, tstr
    if strmid(tstr,0,1) eq '*' then break
  endfor
  record_length = floor((line - pos)/1)
  ; Return to start of record and read all data into an array
  point_lun, lun, pos
  data_array2 = fltarr(14, record_length)
  readf, lun, data_array2
  ; read first two lines of the record to get the temporal spacing of measurements
  min0 = data_array2[1,0]
  min1 = data_array2[1,1]
  d_t2 = floor(min0-min1)
endif

return data_array

end
