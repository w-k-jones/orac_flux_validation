pro save_to_netcdf,ncname,timearr,varName,varData,varLong,varStan,varUnit,varFill,longitude,latitude

nVars = N_ELEMENTS(varName)

;Save data to netCDF file
;open file
ncid=ncdf_create(ncname, /CLOBBER, /NETCDF4_FORMAT)


;Define dimensions
latID=ncdf_dimdef(ncid, 'latitude', 1)
lonID=ncdf_dimdef(ncid, 'longitude', 1)
tID=ncdf_dimdef(ncid, 'time', n_elements(timearr))

;Put in attributes
;latitude - location
lat2id=ncdf_vardef(ncid, 'latitude', latID)
ncdf_attput,ncid,lat2id,'long_name','latitude'
ncdf_attput,ncid,lat2id,'units','degrees'

;longitude - location
lon2id=ncdf_vardef(ncid, 'longitude', lonID)
ncdf_attput,ncid,lon2id,'long_name','longitude'
ncdf_attput,ncid,lon2id,'units','degrees'

;time
t2id=ncdf_vardef(ncid, 'time', tID, /double)
ncdf_attput,ncid,t2id,'long_name','days since -4712-01-01 12:00:00'
ncdf_attput,ncid,t2id,'units','days'

;Dimensions for each variable
dims=[tID]

vID=lonarr(nVars)
for i=0,nVars-1 do begin
 vID(i)=ncdf_vardef(ncid, varName(i), dims, GZIP=9)
 ncdf_attput,ncid, vID(I),'long_name',varLong(i)
 ncdf_attput,ncid, vID(I),'standard_name',varStan(i)
 ncdf_attput,ncid, vID(I),'units',varUnit(i)
 ncdf_attput,ncid, vID(I),'_FillValue',varFill(i)
endfor

;END define mode
ncdf_control, ncid, /endef

;Write data to defined variables
ncdf_varput, ncid, lat2id, latitude
ncdf_varput, ncid, lon2id, longitude
ncdf_varput, ncid, t2id, timearr

for i=0,nVars-1 do begin
 ncdf_varput, ncid, vID(I), REFORM( varData(i,*) )
endfor

;close netcdf file
ncdf_close,ncid

print,'CREATED: ',NCNAME


end
