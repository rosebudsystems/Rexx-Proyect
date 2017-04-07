/**********************************************************************/
/*                          BORRA UN ARCHIVO                          */
/*(Contempla la posibilidad de que la ruta del file contenga espacios)*/
/*                                                                    */
/* FECHA: 19/12/2016                                                  */
/* AUTOR: ARO                                                         */
/* ULTIMA MODIFICACION: 21/12/2016                                    */
/**********************************************************************/
/*Imp1.0 Version Inicial - Se copia la Funcion BORRAA.rexx como planitilla */
/*Imp1.1 Se agrega la funcion STRREPLACE para poder quitar las comillas de la ruta si las tuviera*/
/*Imp1.2 Se agrega las comillas dobles a la ruta para poder hacer el erase si la ruta tiene espacios */

parse upper arg !ambiente !nombre_proceso !pasonro !archivo_ini !PathClave !campo 
!fecha=Date('N') 
!hora=TIME('N') 

signal on syntax

call 0010_Nombre_Archivo_Activo		/* busca dentro de la funcion en SOFTWARE/BATCH */
call 0020_Logging_Open

/*!field=word(!campo,1)*/
/*call 0040_Leo_Registry	*/		/* busca dentro del proceso los campos seteados con $SetVar */
/*!arch=!dato*/
!arch = Registry_Reading(word(!campo,1))


!arch = STRREPLACE(!arch, '"','') /*Imp1.1 Saco las comillas dobles si la ruta las tiene*/

call 0050_Check_Existencia
if rc\=0 then do
	!log_linea='Error Nro. 3505 : Archivo de Usuario no encontrado '||!arch
	call 0022_Logging_Write
	exit 3505
end
else do
	
	!arch = '"' || !arch  || '"' /*Imp1.2 Se agrega las comillas dobles a la ruta para poder hacer el erase si la ruta tiene espacios */
	'erase' !arch

		if rc\=0 then do
				!log_linea='Error Nro. 3523 : No se puede hacer el borrado. Archivo Origen en uso.'
				call 0022_Logging_Write
				Exit 3523
				end
	end
!log_file~close

exit 0


/* ********** RUTINAS ************** */
/* ********************************* */

0010_Nombre_Archivo_Activo:
parse upper source !sist_op !ambiente !arch_actual	
!drive=FILESPEC("drive", !arch_actual)
!arch=FILESPEC("name", !arch_actual)
!cant=0
!cant=!arch~LENGTH
!nombre_funcion=left(!arch,!cant-4)
return


0020_Logging_Open:
!log_file_func=!drive||'\Batch\ArchLog\'||!nombre_proceso||'\msgfun.tmp'
!log_file=.stream~new(!log_file_func)
!log_file~open 
!log_linea='------------------------------------------------'
call 0022_Logging_Write
!log_linea='* FUNCION BORRAX *'
call 0022_Logging_Write
!log_linea=!fecha||' a las '||!hora
call 0022_Logging_Write
return

0022_Logging_Write:
!log_file~LINEOUT(!log_linea)
return


0040_Leo_Registry:
!log_linea='0040_Leo_Registry'
call 0022_Logging_Write
r = .WindowsRegistry~new            

if r~InitCode \= 0 then exit 1	    

/* open the HKEY_LOCAL_MACHINE\SOFTWARE key. */
!arbol='SOFTWARE\BATCH\'||!nombre_proceso

if r~open(r~Current_User,!arbol) \= 0 then do
  myval.=r~GETVALUE(,!field)
  !dato=myval.data   
  !log_linea='Archivo: '||!dato
  call 0022_Logging_Write  
end 

return


0050_Check_Existencia:
qfile=.stream~new(!arch)
if qfile~query('exists')='' then do
	rc=1 
	end 
else do
	rc=0
end
return

Registry_Reading:
/* winregis.rex contains the required directives for the WindowsRegistry object [::REQUIRES "winsystm.cls"]*/
PARSE ARG !field

ObjRegistry =''
ObjValRegistry =''
ValData=''
RC_Registry='' 
Tree='SOFTWARE\BATCH\'||!nombre_proceso
SO_VERSION = UPPER(VALUE('CONTROLMOS',,'ENVIRONMENT')) /*Variable de Entorno*/

!log_linea= 'Function: Registry_Reading. For field: ' || !field
call 0022_Logging_Write
!log_linea= 'Operating System Version:['|| SO_VERSION ||']'
call 0022_Logging_Write

IF  SO_VERSION ='WIN2012' THEN DO
	HandleKey  ='HKEY_CURRENT_USER'
END
ELSE DO
	HandleKey  ='HKEY_LOCAL_MACHINE'
END

	ObjRegistry = .WindowsRegistry~new
	IF  ObjRegistry~InitCode = 0 THEN DO /*ARO Imp2.4.1*/

	    IF HandleKey = 'HKEY_CURRENT_USER' THEN DO
				RC_Registry = ObjRegistry~open(ObjRegistry~Current_User,Tree)
		END
		ELSE DO /*Para Win WIN2003 o Null o cualquier otro win*/
				RC_Registry = ObjRegistry~open(ObjRegistry~Local_Machine,Tree)
		END

		IF RC_Registry  \= 0 THEN DO /*open the Handle Key\SOFTWARE. */ 
			ObjValRegistry.=ObjRegistry~GETVALUE(,!field)
			ValData=ObjValRegistry.data
			ObjRegistry~Close
		END
		ELSE DO
			!log_linea= 'Unexpected error opening the environment subkey: '|| HandleKey ||'\SOFTWARE\' || Tree 
			call 0022_Logging_Write
			EXIT CODE_ERROR_REG_LOAD
		END
	END
	ELSE DO
		!log_linea= 'Could not successfully create the WindowsRegistry object'
		call 0022_Logging_Write
		EXIT CODE_ERROR_REG_OPEN
	END
	!log_linea= 'The value for the field ' || !field || ' is: ' || ValData
	call 0022_Logging_Write

DROP ObjRegistry.
DROP ObjValRegistry.
RETURN ValData

/*Imp1.1 */
STRREPLACE: PROCEDURE
PARSE ARG !original, !oldtxt, !newtxt
CantParticiones =0
Contador = 0
NewStr = ''
TmpStr = !original
DO WHILE POS(!oldtxt,TmpStr) > 0
	CantParticiones = CantParticiones + 1 
	Particiones.CantParticiones = SUBSTR(TmpStr, 1 , POS(!oldtxt,TmpStr)-1)
	TmpStr = SUBSTR(TmpStr, POS(!oldtxt,TmpStr) + LENGTH(!oldtxt))
END
DO Contador =1 TO CantParticiones
	NewStr = NewStr || Particiones.Contador || !newtxt
END 
NewStr = NewStr || TmpStr
drop Particiones.
RETURN NewStr

UPPER: PROCEDURE
PARSE ARG !text
Result = !text
AlphabetLower = 'abcdefghijklmnñopqrstuvwyz'
AlphabetUpper =  translate(AlphabetLower)                       
Result =  translate(!text,AlphabetUpper,AlphabetLower)
RETURN Result

syntax:							
MsgErr='Rexx Error 50'|| rc ||' in line ' ||sigl||':'||"ERRORTEXT"(rc)
say MsgErr
say "SOURCELINE"(sigl)
!nro='50'||rc
exit !nro
nop 

/* winregis.rex contains the required directives for the WindowsRegistry object */
::requires "winsystm.cls"