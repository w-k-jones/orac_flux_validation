function read_modis_geometa2, fname, STRvar

STRvar=['GranuleID','StartDateTime','ArchiveSet','OrbitNumber','DayNightFlag','EastBoundingCoord','NorthBoundingCoord','SouthBoundingCoord','WestBoundingCoord','GRingLongitude1','GRingLongitude2','GRingLongitude3','GRingLongitude4','GRingLatitude1','GRingLatitude2','GRingLatitude3','GRingLatitude4']

OPENR, lun, fname, /get_lun

n_lines = FILE_LINES(fname)
tstr=''
READF,lun,tstr
READF,lun,tstr
READF,lun,tstr
strvar = STRSPLIT(tstr, ',', count=ct, /extract)

tempvar = STRARR(n_lines-3)
READF, lun ,tempvar

datavar = STRSPLIT(tempvar,',',/extract)
datavar = TRANSPOSE(datavar.toarray())

CLOSE, lun
  
FREE_LUN, lun

RETURN, datavar

end
