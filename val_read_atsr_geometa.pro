function val_read_atsr_geometa, fname, header, l1_name, l2_name

OPENR, lun, fname, /get_lun

n_lines = FILE_LINES(fname)

l1_name=''
READF,lun,l1_name

l2_name=''
READF,lun,l2_name

header = ''
READF,lun,header
header = STRSPLIT(header, /extract)

data = FLTARR(4, n_lines-3)
READF,lun,data

CLOSE, lun
  
FREE_LUN, lun

RETURN, data

end
