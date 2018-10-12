;+
; function read_hdf4, filename, /quiet, /info, names=names, $
;                     /global_attributes, /variable_attributes, $
;                     /calipso_scaling
; 
; Reads data from a HDF4 file into an IDL structure. Automatically
; applies the scaling factors and offsets to the data arrays often
; found in NASA HDF-EOS data.
;
; RETURN VALUE
; Usually returns a structure containing the data from the HDF file.
; However, if the /info keyword is set, then the value 1 will be
; returned on completion. If the file is not a valid HDF file, 0 will
; be returned.
;
; INPUT PARAMETER
; filename The name (and path) of the HDF file to read.
;
; KEYWORDS
; /quiet   Supresses information usually printed to the screen.
; /info    Rather than reading the file, the routine prints detailed
;          information about the file contents to the screen.
;          If set with /quiet, the information is read, but not
;          displayed, thus providing a fairly rigorous, but not
;          verbose or slow, file integrity check.
; names=names  Allows the user to specify a subset of variables to read
;          from the file (by default all data will be read). This must
;          be a string array, with each element containing a variable
;          name AS IT APPEARS IN THE HDF FILE. It is case sensitive!
;          To get a list of the variable names in a given file, try
;          using the /info keyword.
; /global_attributes If set, the routine will read the global, or file,
;          attributes from the file as well as the data. These will
;          appear as variables in the output structure.
; /variable_attributes If set, the routine will read the attributes of
;          each variable into the output structure as well as the data.
;          In this case each data variable within the returned
;          structure will itself be a structure (rather than a simple 
;          data array). The data will be stored in a variable called
;          DATA within this sub-structure.
; /vdata   If set the routine will read any VDatas (metadata) within
;          the HDF file in addition to the SDS (Scientific Data Sets)
;          read by default.
; /calipso_scaling If set, the code will apply offsets and scaling in
;          the order used by the CALIPSO instrument (rather than the
;          modis method). The two methods are:
;          MODIS:   (data - offset) * scale_factor
;          CALIPSO: data/scale_factor + offset
; fill_value=value Specify a data value which denotes missing data.
;          Data with this value will not have the scale and offset 
;          corrections applied
;
; HISTORY
; 10/11/2008 G Thomas Original, hacked from "hdfread.pro" from the
;                     coyote library of IDL routines.
; 19/03/2009 G Thomas Bug fix: code now robustly deals with variables
;                     which lack any attributes
; 25/09/2009 B Grandey Bug fix: code now handles variables which begin
;                     with numeric digits
; 22/10/2009 B Grandey Bug fix: code now handles offsets, scaling
;                     factors and missing values correctly.
;                     (Tested on MODIS MOD08_D3 data.)
; 05/11/2009 B Grandey Bug fix: changes made on 25/09/2009 created
;                     potential for CHECK_LEGAL_NAME to modify
;                     input. This has been fixed.
; 15/12/2009 G Thomas Bug fix: Code crashed if a data array contained
;                     no fill values, because "isfill" wasn't defined
;                     unless fill values were found.
;                     Added the string "fillvalue" to those to look for
;                     when setting missing data value: not everyone
;                     applies CF naming standards properly!
;                     Added /CALIPSO_SCALING keyword.
;                     Added support for VData reading (with keyword)
;                     Bug fix: B Grandey's bug fix for scaling hadn't
;                     been applied to data-range attributes.
; 28/03/2011 G Thomas Added the string "scale" to the attributes to
;                     check for applying a scaling factor (used in
;                     AMSR-E data).
;                     Added the fill_value keyword, to allow manual
;                     setting of the missing data value.
; 05/05/2011 G Thomas Added a code section specifically for use with
;                     both the /quiet and /info keyword set. In this
;                     instance, information is read, but not printed
;                     to the screen.
; 02/04/2012 C Arnold Added a couple of lines to cope with data files
;		      containing SDS with the same names - these are 
;		      now output as SDS, SDS_2, SDS_3 etc
; 03/04/2012 G Thomas Added a section of code that deals with the
;                     grid definitions found in a lot of HDF-EOS
;                     files. These files will now produce an output
;                     structure containing a sub-structure called
;                     "GRIDS", which contains the grid definitions,
;                     converted to work with IDL's own mapping
;                     functions (both "cgMap" and MAP_PROJ_INIT)
; 16/08/2016 G Thomas Bug fix in detection of fill values
;-

FUNCTION TEST_ISHDF,filename
CATCH, err
IF (err EQ 0) THEN RETURN, HDF_ISHDF(filename) $
        ELSE RETURN, 0
END ;------------------------------------------------------------------

FUNCTION CHECK_LEGAL_NAME, nameIn
;     Create working copy of nameIn, so that we don't have side effects
      inName = nameIn
;     Check that inName doesn't begin with a number
      IF STREGEX(inName, '[0123456789]') EQ 0 THEN BEGIN
          inName = STRJOIN(['x', inName])
      ENDIF
;     Check that inName doesn't contain any illegal characters
      tmpName = strsplit(inName,' ,.-+=/$%()[]{}<>',/extract)
      if n_elements(tmpName) gt 1 then outName = strjoin(tmpName,'_') $
                                  else outName = inName
      return, outName
end ;------------------------------------------------------------------


; =====================================================================
; BEGINNING OF MAIN FUNCTION
function read_hdf4, filename, quiet=quiet, info=info, $
                    names=names, global_attributes=global_attributes, $
                    variable_attributes=variable_attributes, $
                    calipso_scaling=calipso_scaling, vdata=vdata, $
                    fill_value=fill_value

; Open file and initialize the SDS interface.

;IF N_ELEMENTS(filename) EQ 0 THEN filename = PICKFILE()
IF NOT TEST_ISHDF(filename) THEN BEGIN
   PRINT, 'Invalid HDF file ...'
   RETURN,-1
ENDIF ELSE $
   if ~keyword_set(quiet) then PRINT, 'Valid HDF file. Opening: ' + $
                                      filename

; Before opening the file, check to see if it is an HDF-EOS file by
; getting the number of grids defined in the file. If grid definitions
; exist, build them first (before reading the data) for incorporation
; into the output later on.
ngrid = eos_gd_inqgrid(filename, gridl)
if ngrid ge 1 then begin
   if ~keyword_set(quiet) then $
      PRINT, strtrim(ngrid,2)+' HDF-EOS grid definitions found'
   gridn = strsplit(gridl, ',', /extract)

;  Open the file using the IDL EOS_GD interface and then read each
;  grid in turn
   fidg = eos_gd_open(filename, /READ)
   for i=0,ngrid-1 do begin
;     Flag for the creation of the struct for this grid data:
      grid_made = 0
      gids = eos_gd_attach(fidg,gridn[i])
   
;     If the user has asked for variable attributes to be read, we
;     read them first (similar to variable attributes below)
      if keyword_set(variable_attributes) then begin
         natts = eos_gd_inqattrs(gids, attl)
         if natts ge 1 then begin
            attn = strsplit(attl, ',', /extract)
            for j=0,natts-1 do begin
               stat = eos_gd_readattr(gids, attn, thisAttd)
               outName = check_legal_name(attn)
               
               if grid_made then $
                  grid = create_struct(grid, outName, thisAttd) $
               else begin
                  grid = create_struct(outName, thisAttd)
                  grid_made = 1
               endelse
            endfor
         endif
      endif

;     Now we read the projection information and convert it to IDL
;     format
      void = eos_gd_projinfo(gids, projcode, zonecode, ellipsecode, $
                             params)
      if void ne 0 then $
         message, 'Warning, error detected reading projection information from grid: '+gridn[i], /info
      projcodesIndex = [ 0, 1, 4, 6, 7, 9, 11, 20, 22, 24, 99]
      projcodesNames = ['Geographic', 'UTM', 'Lambert Conformal Conic', $
                        'Polar Stereographic', 'Polyconic',            $
                        'Transverse Mercator', 'Lambert Equal Area',   $
                        'Hotine Oblique Mercator',                     $
                        'Space Oblique Mercator', 'Goode Homolosine',  $
                        'Intergerized Sinusoidal']
      index = Where(projcodesindex EQ projcode)
      thisProjection = projcodesNames[index]
      IF thisProjection EQ 'Intergerized Sinusoidal' THEN projcode = 31
      IF thisProjection EQ 'Geographic' THEN projcode = 17
      projcode = projcode + 100 ; To conform with Map_Proj_Init codes.
      
;     Next we load the size and upper-left, lower-right map coordinates
;     of the grid
      if void ne 0 then $
         message, 'Warning, error detected reading grid information from grid: '+gridn[i], /info
      void = eos_gd_gridinfo(gids, gxsize, gysize, gul, glr)

;     Now place this data into the grid structure
      if grid_made then $
         grid = create_struct(grid, 'projection', thisProjection) $
      else grid = create_struct('projection', thisProjection)
      grid = create_struct( grid, 'gctp_proj_code', projcode, $
                            'zone', zonecode, 'ellipsoid', ellipsecode, $
                            'parameters', params, 'xsize', gxsize, $
                            'ysize', gysize, 'upper_left', gul, $
                            'lower_right', glr )
;     "Detach" from this grid
      void = eos_gd_detach(gids)
;     Finally, create the "grids" container structure that will contain
;     the grid info in the output file, or add this grid to it, if it
;     already exists
      outName = check_legal_name(gridn[i])
      if i eq 0 then grids = create_struct(outName, grid) $
      else grids = create_struct(grids, outName, grid)
   endfor
;  Close the EOS file interface - datafields will be read by standard
;  HDF4 interface below.
   stat = eos_gd_close(fidg)
endif
   
fid   = HDF_OPEN(filename, /READ)
sdsid = HDF_SD_START(filename, /READ)
; Open VD interface
vdsid = HDF_VD_LONE(fid)

; If the info keyword is set, simply print information about the file
; and exit
HDF_SD_FILEINFO, sdsid, datasets, attributes
numPalettes = HDF_DFP_NPALS(filename)
if keyword_set(info) and ~keyword_set(quiet) then begin
;  What is in the file. Print the number of datasets, attributes, and 
;  palettes.
   PRINT, 'Reading number of datasets and file attributes in file ...'
   PRINT, ''
   PRINT, 'No. of Datasets:        ', datasets
   PRINT, 'No. of File Attributes: ', attributes
   PRINT, 'No. of Palettes:        ', numPalettes
   if vdsid[0] ge 0 then $
      print, 'No. of VData records:   ', n_elements(vdsid)
   ; Print the name of each file attribute.
   PRINT, ''
   PRINT, 'Printing name of each file attribute...'
   FOR j=0, attributes-1 DO BEGIN
      HDF_SD_ATTRINFO, sdsid, j, NAME=thisAttr
      PRINT, 'File Attribute No. ', + STRTRIM(j, 2), ': ', thisAttr
   ENDFOR

;  Print the name of each SDS and associated data attributes.

   PRINT, ''
   PRINT, 'Printing name of each data set and its associated data attributes...'
   FOR j=0, datasets-1 DO BEGIN
      thisSDS = HDF_SD_SELECT(sdsid, j)
      HDF_SD_GETINFO, thisSDS, NAME=thisSDSName, NATTS=numAttributes, DIMS=dimensions
      PRINT, 'Dataset No. ', STRTRIM(j,2), ': ', thisSDSName
      print, '    Dimensions: ', dimensions
      FOR k=0,numAttributes-1 DO BEGIN
         HDF_SD_ATTRINFO, thisSDS, k, NAME=thisAttrName
         PRINT, '   Data Attribute: ', thisAttrName
      ENDFOR
      PRINT, ''
   ENDFOR

;  Find the index of the "Gridded Data" SDS.

   index = HDF_SD_NAMETOINDEX(sdsid, "Gridded Data")
   
   if index ge 0 then begin
;     Select the Gridded Data SDS.

      thisSdsID = HDF_SD_SELECT(sdsid, index)
   
;     Print the names of the Gridded Data attributes.

      PRINT, ''
      PRINT, 'Printing names of each Gridded Data Attribute...'
      HDF_SD_GETINFO, thisSdsID, NATTS=numAttributes
      PRINT, 'Number of Gridded Data attributes: ', numAttributes
      FOR j=0,numAttributes-1 DO BEGIN
         HDF_SD_ATTRINFO, thisSdsID, j, NAME=thisAttr
         PRINT, 'SDS Attribute No. ', + STRTRIM(j, 2), ': ', thisAttr
      ENDFOR
   endif
;  Close SD interface
   HDF_SD_END, sdsid

;  Now, if they exist, go through the VData records...
   Print,'Printing name of the fields, and their associated attributes, in each VData record...'
   if vdsid[0] ge 0 then for i=0,n_elements(vdsid)-1 do begin
      vdatid = HDF_VD_ATTACH(fid,vdsid[i],/read)

;     Get number of fields in the VDat record and then retrieve info on
;     them
      HDF_VD_GET, vdatid, nfields=nvdats
      PRINT, 'VData record '+strtrim(i,2)+' has: '+strtrim(nvdats,2)+$
             ' fields:'
      for j=0,nvdats-1 do begin
         HDF_VD_GETINFO, vdatid, j, name=thisVDname
         numAttributes = HDF_VD_NATTRS(vdatid, j)
         print, '   VData field No. ', STRTRIM(j,2), ': ', thisVDname
         for k=0,numAttributes-1 do begin
            HDF_VD_ATTRINFO, vdatid, j, k, name=thisAttrName
            print, '      VData Attribute: ', thisAttrName
         endfor
      endfor
      HDF_VD_DETACH, vdatid
   endfor
   HDF_CLOSE, fid

   return, 0
endif else if keyword_set(info) and keyword_set(quiet) then begin
;  In this instance, we run through the whole file and check all
;  the attributes etc, but don't write to the screen. This is
;  useful for comprehensively checking for corrupted files.
;  File attributes
   FOR j=0, attributes-1 DO BEGIN
      HDF_SD_ATTRINFO, sdsid, j, NAME=thisAttr
   ENDFOR

;  "SDS" records
   FOR j=0, datasets-1 DO BEGIN
      thisSDS = HDF_SD_SELECT(sdsid, j)
      HDF_SD_GETINFO, thisSDS, NAME=thisSDSName, NATTS=numAttributes
      FOR k=0,numAttributes-1 DO BEGIN
         HDF_SD_ATTRINFO, thisSDS, k, NAME=thisAttrName
      ENDFOR
   ENDFOR

;  Find the gridded data SDS
   index = HDF_SD_NAMETOINDEX(sdsid, "Gridded Data")
   
   if index ge 0 then begin
;     Select the Gridded Data SDS.
      thisSdsID = HDF_SD_SELECT(sdsid, index)
      HDF_SD_GETINFO, thisSdsID, NATTS=numAttributes
      FOR j=0,numAttributes-1 DO BEGIN
         HDF_SD_ATTRINFO, thisSdsID, j, NAME=thisAttr
      ENDFOR
   endif
;  Close SD interface
   HDF_SD_END, sdsid

;  Now, if they exist, go through the VData records...
   if vdsid[0] ge 0 then for i=0,n_elements(vdsid)-1 do begin
      vdatid = HDF_VD_ATTACH(fid,vdsid[i],/read)

;     Get number of fields in the VDat record and then retrieve info on
;     them
      HDF_VD_GET, vdatid, nfields=nvdats
      for j=0,nvdats-1 do begin
         HDF_VD_GETINFO, vdatid, j, name=thisVDname
         numAttributes = HDF_VD_NATTRS(vdatid, j)
         for k=0,numAttributes-1 do begin
            HDF_VD_ATTRINFO, vdatid, j, k, name=thisAttrName
         endfor
      endfor
      HDF_VD_DETACH, vdatid
   endfor
   HDF_CLOSE, fid

   return, 0
endif else begin
;  Info keyword wasn't set, actually read the data into a structure for
;  returning
   data  = create_struct( 'No_datasets',        datasets,   $
                          'No_glob_attributes', attributes, $
                          'No_Palettes',        numPalettes )
;  If we've read in EOS grid attributes (see above) then add this info
;  to the output structure
   if ngrid ge 1 then data = create_struct( data,                   $
                                            'No_EOS_grids',  ngrid, $
                                            'GRIDS',         grids  )
;  Read global attributes if they're required
   if keyword_set(global_attributes) then for j=0,attributes-1 do begin
      HDF_SD_ATTRINFO, sdsid, j, NAME=thisAttr, data=thisAttrDat
      outName = check_legal_name(thisAttr)
      data = create_struct(data, outName, thisAttrDat)
   endfor

;  Now move on to reading the SDSs
   for j=0, datasets-1 do begin
      thisSDS = HDF_SD_SELECT(sdsid, j)
      HDF_SD_GETINFO, thisSDS, NAME=thisSDSName, NATTS=numAttributes      
;     If the names keyword has been set, then check the current 
;     variable agains the list. If it's not on the list, skip it
      if keyword_set(names) then begin
         inlist = where(names eq thisSDSName)
         if inlist[0] lt 0 then goto, skipSDS
      endif
      outName = check_legal_name(thisSDSName)
      if (j gt 0) then begin
         i=1
	 while (total(strcmp(tag_names(data),outName,/fold_case)) gt 0) do begin
      	    i=i+1
	    outName = check_legal_name(thisSDSName + '_'+strtrim(i,2))
	 endwhile
      endif
      HDF_SD_GETDATA, thisSDS, thisDATA
;     Extract a list of attribute names. If the "scale_factor" and/or
;     "add_offset" are present, then change the data to a floating
;     point array and apply them.
      if numAttributes gt 0 then AttrNames = strarr(numAttributes) $
                            else AttrNames = ['']
      for k=0,numAttributes-1 do begin
         HDF_SD_ATTRINFO, thisSDS, k, NAME=thisAttrName
         AttrNames[k] = thisAttrName
      endfor
      i_scale  = (where(strlowcase(AttrNames) eq 'scale_factor' or $
                        strlowcase(AttrNames) eq 'scale'))[0]
      i_offset = (where(strlowcase(AttrNames) eq 'add_offset'))[0]
;     Only check for fill value attributes if the fill value hasn't
;     been specified by the fill_value keyword.
      if n_elements(fill_value) eq 0 then $
         i_fill   = (where(strlowcase(AttrNames) eq '_fillvalue' or $
                           strlowcase(AttrNames) eq 'fillvalue'))[0]
      if (i_scale ge 0) or (i_offset ge 0) then begin
         if i_scale ge 0 then begin
            HDF_SD_ATTRINFO, thisSDS, i_scale, DATA=thisScale
            thisScale = thisScale[0]
         endif else thisScale = 1.0
         if i_offset ge 0 then begin
            HDF_SD_ATTRINFO, thisSDS, i_offset, DATA=thisOffset
            thisOffset = thisOffset[0]
         endif else thisOffset = 0.0
;        Check for fill values before applying offset and scaling
         isfill = [-1]
;        First, check to see if the fill_value keyword has been set.
;        If it hasn't, use the value discovered by checking for the
;        standard attribute names
         if n_elements(fill_value) gt 0 then begin
            fillvalue = fill_value[0]
            isfill = where(thisDATA eq fillvalue)
         endif else if i_fill ge 0 then begin
            HDF_SD_ATTRINFO, thisSDS, i_fill, DATA=fillvalue
            isfill = where(thisDATA eq fillvalue[0])
         endif
;        Apply offset and scaling
         if keyword_set(calipso_scaling) then $
            tmp = float(thisDATA) / thisScale + thisOffset $
         else $
            tmp = (float(thisDATA) - thisOffset) * thisScale
         if isfill[0] ge 0 then tmp[isfill] = float(fillvalue)
         thisDATA = float(tmp)
      endif
;     if the variable_attributes keyword has been set, read all the
;     attributes and data into a sub structure, otherwise, just read
;     the data array itself
      if keyword_set(variable_attributes) and numAttributes gt 0 then $
         begin
         HDF_SD_ATTRINFO, thisSDS, 0, DATA=thisAttrDat
         datstr = create_struct(AttrNames[0], thisAttrDat)
         for k=1,numAttributes-1 do begin
            HDF_SD_ATTRINFO, thisSDS, k, DATA=thisAttrDat
;           If the data has been scaled and the certain attributes are
;           present, they should be scaled as well
            if ((i_scale ge 0) or (i_offset ge 0)) and $
               (AttrNames[k] eq 'valid_range') then begin
               if keyword_set(calipso_scaling) then $
                  thisAttrDat = float(thisAttrDat) / thisScale + $
                                thisOffset $
               else $
                  thisAttrDat = (float(thisAttrDat) - thisOffset) * $
                                thisScale
            endif
            outAttrName = check_legal_name(AttrNames[k])
;           Data is always returned as an array, even when it's one
;           value. Tidy it up...
            if n_elements(thisAttrDat) eq 1 then $
               thisAttrDat = thisAttrDat[0]
            datstr = create_struct(datstr, outAttrName, thisAttrDat)               
         endfor
;        Add in the data itself
         datstr = create_struct(datstr, 'Data', thisDATA)
;        Add this into the output
         data = create_struct(data, outName, datstr)
      endif else begin
;     If the variable attributes aren't required, simply put the array
;     of data into the output structure
         data = create_struct(data, outName, thisDATA)
      endelse
      skipSDS: ; Landing point if the current SDS isn't required
   endfor
   HDF_SD_END, sdsid

;  Open VD interface
   vdsid = HDF_VD_LONE(fid)
   if vdsid[0] ge 0 and keyword_set(vdata) then $
      for i=0,n_elements(vdsid)-1 do begin
      vdatid = HDF_VD_ATTACH(fid,vdsid[i],/read)

;     Get number of fields in the VDat record and then retrieve info on
;     them
      HDF_VD_GET, vdatid, nfields=nvdats
      for j=0,nvdats-1 do begin
         HDF_VD_GETINFO, vdatid, j, name=thisVDname
         numAttributes = HDF_VD_NATTRS(vdatid, j)
;        If the names keyword has been set, then check the current 
;        variable agains the list. If it's not on the list, skip it
         if keyword_set(names) then begin
            inlist = where(names eq thisVDname)
            if inlist[0] lt 0 then goto, skipVD
         endif
         outName = check_legal_name(thisVDname)
         stat=HDF_VD_READ(vdatid, thisDATA, fields=thisVDname)
         if numAttributes gt 0 then AttrNames = strarr(numAttributes) $
                               else AttrNames = ['']
         for k=0,numAttributes-1 do begin
            HDF_VD_ATTRINFO, vdatid, j, k, NAME=thisAttrName
            AttrNames[k] = thisAttrName
         endfor
         i_scale  = (where(strlowcase(AttrNames) eq 'scale_factor'))[0]
         i_offset = (where(strlowcase(AttrNames) eq 'add_offset'))[0]
         i_fill   = (where(strlowcase(AttrNames) eq '_fillvalue' or $
                           strlowcase(AttrNames) eq 'fillvalue'))[0]
         if (i_scale ge 0) or (i_offset ge 0) then begin
            if i_scale ge 0 then begin
               HDF_VD_ATTRINFO, vdatid, j, i_scale, DATA=thisScale
               thisScale = thisScale[0]
            endif else thisScale = 1.0
            if i_offset ge 0 then begin
               HDF_VD_ATTRINFO, vdatid, j, i_offset, DATA=thisOffset
               thisOffset = thisOffset[0]
            endif else thisOffset = 0.0
;           Check for fill values before applying offset and scaling
            isfill = [-1]
            if i_fill ge 0 then begin
               HDF_VD_ATTRINFO, vdatid, j, i_fill, DATA=fillvalue
               isfill = where(thisDATA eq fillvalue[0])
            endif
;           Apply offset and scaling
            if keyword_set(calipso_scaling) then $
               tmp = float(thisDATA) / thisScale + thisOffset $
            else $
               tmp = (float(thisDATA) - thisOffset) * thisScale
            if isfill[0] ge 0 then tmp[isfill] = float(fillvalue)
            thisDATA = float(tmp)
         endif
;        if the variable_attributes keyword has been set, read all the
;        attributes and data into a sub structure, otherwise, just read
;        the data array itself
         if keyword_set(variable_attributes) and numAttributes gt 0 $
         then begin
            HDF_VD_ATTRINFO, vdatid, j, 0, DATA=thisAttrDat
            datstr = create_struct(AttrNames[0], thisAttrDat)
            for k=1,numAttributes-1 do begin
               HDF_VD_ATTRINFO, vdatid, j, k, DATA=thisAttrDat
;              If the data has been scaled and the certain attributes
;              are present, they should be scaled as well
               if ((i_scale ge 0) or (i_offset ge 0)) and $
                  (AttrNames[k] eq 'valid_range') then begin
                  if keyword_set(calipso_scaling) then $
                     thisAttrDat = float(thisAttrDat) / thisScale + $
                                   thisOffset $
                  else $
                     thisAttrDat = (float(thisAttrDat) - thisOffset) *$
                                   thisScale
               endif
               outAttrName = check_legal_name(AttrNames[k])
;              Data is always returned as an array, even when it's one
;              value. Tidy it up...
               if n_elements(thisAttrDat) eq 1 then $
                  thisAttrDat = thisAttrDat[0]
               datstr = create_struct(datstr, outAttrName, thisAttrDat)
            endfor
;           Add in the data itself
            datstr = create_struct(datstr, 'Data', thisDATA)
;           Add this into the output
            data = create_struct(data, outName, datstr)
         endif else begin
;        If the variable attributes aren't required, simply put the
;        array of data into the output structure
            data = create_struct(data, outName, thisDATA)
         endelse
         skipVD:       ; Landing point if the current VD isn't required
      endfor
      HDF_VD_DETACH, vdatid
   endfor
   HDF_CLOSE, fid
   return,data
endelse
END ; =================================================================
