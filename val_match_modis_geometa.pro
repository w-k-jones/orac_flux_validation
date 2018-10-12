function val_match_modis_geometa, satellite, year, month, lat, lon, $
                                  d_or_n=d_or_n

if satellite eq 'MODIS-TERRA' then satellite = 'TERRA'
if satellite eq 'MODIS-AQUA' then satellite = 'AQUA'

def_sats = ['AQUA','TERRA']

VAL_CHECK_KEYWORD, satellite, def_sats, key_name='satellite'

if satellite eq 'AQUA' then type = 'MYD' $
                       else type = 'MOD'

if N_ELEMENTS(lat) ne N_ELEMENTS(lon) then $
   MESSAGE, 'Lat and lon inputs must have the same length'

if ~KEYWORD_SET(d_or_n) then d_or_n = 'D'

n_loc = N_ELEMENTS(lat)

base_path = '/group_workspaces/cems/cloud_ecv/mchristensen/orac/data/modis/geoMeta/'

yyyy = STRING(format='(I4)',year)
mm = STRING(format='(I02)',month)

geo_path = base_path+satellite+'/'+yyyy+'/'

geo_files = FILE_SEARCH(geo_path+'*'+type+'*03_'+yyyy+'-'+mm+'*.txt',count=fct)

chk_match_all = list()
mod_names_all = list()

for i =0,fct-1 do begin
   datavar = VAL_READ_MODIS_GEOMETA(geo_files[i],strvar)

   east = DOUBLE(datavar[WHERE(STRvar EQ 'EastBoundingCoord', /null),*])
   n_col = N_ELEMENTS(east)
   east = REBIN(east,n_loc,n_col)
   west = REBIN(DOUBLE(datavar[WHERE(STRvar EQ 'WestBoundingCoord', $
                                                         /null),*]),n_loc,n_col)
   south = REBIN(DOUBLE(datavar[WHERE(STRvar EQ 'SouthBoundingCoord', $
                                                         /null),*]),n_loc,n_col)
   north = REBIN(DOUBLE(datavar[WHERE(STRvar EQ 'NorthBoundingCoord', $
                                                         /null),*]),n_loc,n_col)

   daynight = STR_REBIN(datavar[WHERE(STRvar EQ 'DayNightFlag', $
                                                         /null),*],n_loc,n_col)
   mod_names = STR_REBIN(datavar[WHERE(STRvar EQ '# GranuleID', /null),*], $
                         n_loc,n_col)

   lat2 = REBIN([lat],n_loc,n_col)
   lon2 = REBIN([lon],n_loc,n_col)
   dn2 = STR_REBIN([d_or_n],n_loc,n_col)
   
;check for overlapping map borders

   wh = WHERE(east lt 0 and west gt 0 and lon2 gt 0, /null, ct)
   if ct gt 0 then east[wh] +=360

   wh = WHERE(east lt 0 and west gt 0 and lon2 lt 0, /null, ct)
   if ct gt 0 then west[wh] -=360
   
   wh = WHERE(north lt 0 and south gt 0 and lat2 gt 0, /null, ct)
   if ct gt 0 then north[wh] +=180

   wh = WHERE(north lt 0 and south gt 0 and lat2 gt 0, /null, ct)
   if ct gt 0 then south[wh] -=180

   chk_match = (lat2 gt south) and (lat2 lt north) and $
               (lon2 gt west) and (lon2 lt east) and $
               (daynight eq dn2)
   
   chk_match_all.add, chk_match
   mod_names_all.add, mod_names
endfor

chk_match = chk_match_all.toarray(dimension=2)
mod_names = mod_names_all.toarray(dimension=2)

out = list()

for i =0,n_loc-1 do $
   out.add, mod_names[i,WHERE(chk_match[i,*],/null)]

RETURN, out

end
