function val_get_dist, lat0, lon0, lat1, lon1, lon_fac=lon_fac

; get_dist.pro
;
; Calculate the distance (in degrees) between two points of lat/lon or
; an array and a point of lat/lon
;
; History:
; 2016/08/24, WJ: bug fix, set dlat and dlon to doubles in case of
;   overflow occuring for values greater than ~180 degrees

dlat = (lat0-lat1)*1D
dlon = (lon0-lon1)*1D

if ~KEYWORD_SET(lon_fac) then $
   lon_fac = COS(lat1*!pi/180)

distance = (dlat^2 + (lon_fac*dlon)^2)^0.5

RETURN, distance

end
