;+
; NAME:
;	COPY_STRUCT_INX
; PURPOSE:
;	Copy matching tags & specified indices from one structure to another
; EXPLANATION:
; 	Copy all fields with matching tag names (except for "except_Tags")
;	from one structure array to another structure array of different type.
;	This allows copying of tag values when equating the structures of
;	different types is not allowed, or when not all tags are to be copied.
;	Can also recursively copy from/to structures nested within structures.
;	This procedure is same as copy_struct with option to
;	specify indices (subscripts) of which array elements to copy from/to.
; CALLING SEQUENCE:
;
;	copy_struct_inx, struct_From, struct_To, NT_copied, INDEX_FROM=subf
;
;	copy_struct_inx, struct_From, struct_To, INDEX_FROM=subf, INDEX_TO=subto
;
; INPUTS:
;	struct_From = structure array to copy from.
;	struct_To = structure array to copy values to.
;
; KEYWORDS:
;
;	INDEX_FROM = indices (subscripts) of which elements of array to copy.
;		(default is all elements of input structure array)
;
;	INDEX_TO = indices (subscripts) of which elements to copy to.
;		(default is all elements of output structure array)
;
;	EXCEPT_TAGS = string array of Tag names to ignore (to NOT copy).
;		Used at all levels of recursion.
;
;	SELECT_TAGS = Tag names to copy (takes priority over EXCEPT).
;		This keyword is not passed to recursive calls in order
;		to avoid the confusion of not copying tags in sub-structures.
;
;	/RECUR_FROM = search for sub-structures in struct_From, and then
;		call copy_struct recursively for those nested structures.
;
;	/RECUR_TO = search for sub-structures of struct_To, and then
;		call copy_struct recursively for those nested structures.
;
;	/RECUR_TANDEM = call copy_struct recursively for the sub-structures
;		with matching Tag names in struct_From and struct_To
;		(for use when Tag names match but sub-structure types differ).
;
; OUTPUTS:
;	struct_To = structure array to which new tag values are copied.
;	NT_copied = incremented by total # of tags copied (optional)
;
; INTERNAL:
;	Recur_Level = # of times copy_struct_inx calls itself.
;		This argument is for internal recursive execution only.
;		The user call is 1, subsequent recursive calls increment it,
;		and the counter is decremented before returning.
;		The counter is used just to find out if argument checking
;		should be performed, and to set NT_copied = 0 first call.
; EXTERNAL CALLS:
;	pro match	(when keyword SELECT_TAGS is specified)
; PROCEDURE:
;	Match Tag names and then use corresponding Tag numbers,
;	apply the sub-indices during = and recursion.
; HISTORY:
;	adapted from copy_struct: 1991 Frank Varosi STX @ NASA/GSFC
;	mod Aug.95 by F.V. to fix match of a single selected tag.
;	mod Mar.97 by F.V. do not pass the SELECT_TAGS keyword in recursion,
;		and check validity of INDEX_FROM and INDEX_TO in more detail.
;	Converted to IDL V5.0   W. Landsman   September 1997
;       Use long integers W. Landsman May 2001  
;-

pro copy_struct_inx, struct_From, struct_To, NT_copied, Recur_Level,        $
						EXCEPT_TAGS  = except_Tags, $
						SELECT_TAGS  = select_Tags, $
						INDEX_From   = index_From,  $
						INDEX_To     = index_To,    $
						RECUR_From   = recur_From,  $
						RECUR_To     = recur_To,    $
						RECUR_TANDEM = recur_tandem
        COMPILE_OPT HIDDEN
	if N_elements( Recur_Level ) NE 1 then Recur_Level = 0L

	Ntag_from = N_tags( struct_From )
	Ntag_to = N_tags( struct_To )

	if (Recur_Level EQ 0) then begin	;check only at first user call.

		NT_copied = 0L

		if (Ntag_from LE 0) OR (Ntag_to LE 0) then begin
			message,"two arguments must be structures",/INFO
			print," "
			print,"syntax:  copy_struct_inx, struct_From, struct_To"
			print," "
			print,"keywords:	INDEX_From= , INDEX_To="
			print,"		EXCEPT_TAGS= , SELECT_TAGS=,  "
			print,"		/RECUR_From,  /RECUR_To,  /RECUR_TANDEM"
			return
		   endif

		N_from = N_elements( struct_From )
		N_to = N_elements( struct_To )

		if N_elements( index_From ) LE 0 then index_From = $
								lindgen( N_from )
		Ni_from = N_elements( index_From )
		if N_elements( index_To ) LE 0 then index_To = lindgen( Ni_from )
		Ni_to = N_elements( index_To )

		if (Ni_from LT Ni_to) then begin

			message," # elements (" + strtrim( Ni_to, 2 ) + $
					") in output TO indices",/INFO
			message," decreased to (" + strtrim( Ni_from, 2 ) + $
					") as in FROM indices",/INFO
			index_To = index_To[0:Ni_from-1]

		  endif	else if (Ni_from GT Ni_to) then begin

			message," # elements (" + strtrim( Ni_from, 2 ) + $
					") of input FROM indices",/INFO
			message," decreased to (" + strtrim( Ni_to, 2 ) + $
					") as in TO indices",/INFO
			index_From = index_From[0:Ni_to-1]
		   endif

		Mi_to = max( [index_To] )
		Mi_from = max( [index_From] )

		if (Mi_to GE N_to) then begin

			message," # elements (" + strtrim( N_to, 2 ) + $
					") in output TO structure",/INFO
			message," increased to (" + strtrim( Mi_to, 2 ) + $
					") as max value of INDEX_To",/INFO
			struct_To = [ struct_To, $
					replicate( struct_To[0], Mi_to-N_to ) ]
		  endif

 		if (Mi_from GE N_from) then begin

			w = where( index_From LT N_from, nw )

			if (nw GT 0) then begin
				index_From = index_From[w]
				message,"max value (" + strtrim( Mi_from, 2 ) +$
					") in FROM indices",/INFO
				print,"decreased to " + strtrim( N_from,2 ) + $
					") as in FROM structure",/INFO
			 endif else begin
				message,"all FROM indices are out of bounds",/IN
				return
			  endelse
		  endif
	   endif

	Recur_Level = Recur_Level + 1		;go for it...

	Tags_from = Tag_names( struct_From )
	Tags_to = Tag_names( struct_To )
	wto = lindgen( Ntag_to )

;Determine which Tags are selected or excluded from copying:

	Nseltag = N_elements( select_Tags )
	Nextag = N_elements( except_Tags )

	if (Nseltag GT 0) then begin

		match, Tags_to, [strupcase( select_Tags )], mt, ms,COUNT=Ntag_to

		if (Ntag_to LE 0) then begin
			message," selected tags not found",/INFO
			return
		   endif

		Tags_to = Tags_to[mt]
		wto = wto[mt]

	  endif else if (Nextag GT 0) then begin

		except_Tags = [strupcase( except_Tags )]

		for t=0L,Nextag-1 do begin
			w = where( Tags_to NE except_Tags[t], Ntag_to )
			Tags_to = Tags_to[w]
			wto = wto[w]
		  endfor
	   endif

;Now find the matching Tags and copy them...

	for t = 0L, Ntag_to-1 do begin

		wf = where( Tags_from EQ Tags_to[t] , nf )

		if (nf GT 0) then begin

			from = wf[0]
			to = wto[t]

			if keyword_set( recur_tandem ) AND		$
			   ( N_tags( struct_To.(to) ) GT 0 ) AND	$
			   ( N_tags( struct_From.(from) ) GT 0 ) then begin

				struct_tmp = struct_To[index_To].(to)

				copy_struct, struct_From[index_From].(from),  $
						struct_tmp,                   $
						NT_copied, Recur_Level,       $
						EXCEPT=except_Tags,           $
						/RECUR_TANDEM,                $
						RECUR_FROM = recur_From,      $
						RECUR_To   = recur_To

				struct_To[index_To].(to) = struct_tmp

			  endif else begin

				struct_To[index_To].(to) = $
				struct_From[index_From].(from)
				NT_copied = NT_copied + 1
			   endelse
		  endif
	  endfor

;Handle request for recursion on FROM structure:

	if keyword_set( recur_From ) then begin

		wfrom = lindgen( Ntag_from )

		if (Nextag GT 0) then begin

			for t=0L,Nextag-1 do begin
			    w = where( Tags_from NE except_Tags[t], Ntag_from )
			    Tags_from = Tags_from[w]
			    wfrom = wfrom[w]
			  endfor
		   endif

		for t = 0L, Ntag_from-1 do begin

		     from = wfrom[t]

		     if N_tags( struct_From.(from) ) GT 0 then begin

			copy_struct_inx, struct_From.(from), struct_To,        $
						NT_copied, Recur_Level,    $
						EXCEPT=except_Tags,        $
						/RECUR_FROM,               $
						INDEX_From   = index_From, $
						INDEX_To     = index_To,   $
						RECUR_To     = recur_To,   $
						RECUR_TANDEM = recur_tandem
			endif
		  endfor
	  endif

;Handle request for recursion on TO structure:

	if keyword_set( recur_To ) then begin

		for t = 0L, Ntag_to-1 do begin

		   to = wto[t]

		   if N_tags( struct_To.(to) ) GT 0 then begin

			struct_tmp = struct_To[index_To].(to)

			copy_struct_inx, struct_From, struct_tmp,          $
						NT_copied, Recur_Level,    $
						EXCEPT=except_Tags,        $
						/RECUR_To,                 $
						INDEX_From   = index_From, $
						RECUR_FROM = recur_From,   $
						RECUR_TANDEM = recur_tandem
			struct_To[index_To].(to) = struct_tmp
		     endif
		  endfor
	  endif

   Recur_Level = Recur_Level - 1
end
