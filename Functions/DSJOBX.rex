/*****************************************************/
/*         EJECUTA UN JOB DE DATASTAGE               */
/* FECHA: 01/06/2015                                 */
/* AUTOR: ARO                                        */
/* ULTIMA MODIFICACION: 10/07/2015                   */
/*****************************************************/
/*19-08-2015 Se corrige la apertura de los files ~makearray con open('READ SHAREREAD')(ARO Imp2.1.1)*/
/*19-08-2015 Se permite setear mas de un PARAM  (ARO Imp2.1.2)*/
/*27-08-2015 Se toman los parametros con el case que se escribieron (PARSE CASELESS ARG) (ARO Imp2.2.1)*/
/*27-08-2015 Se permite pasar el proyecto y Job por valor. Ahora se puede pasar por valor y por variable (ARO Imp2.2.2)*/
PARSE UPPER ARG    !ambiente !nombre_proceso !pasonro !archivo_ini !path_clave !campo /*!pasonro !archivo_ini no se usan en esta funcion*/
PARSE CASELESS ARG !xx       !xx             !xx      !xx          !xx         !campo1  /*ARO Imp2.2.1*/ 
PARSE UPPER SOURCE !sist_op !calltype !full_name_this_file  /*!sist_op !calltype no se usan en esta funcion*/
SIGNAL ON SYNTAX
/*Drive*/

CALL TIME 'R' /*Reseteo Cronometro*/
FechaIni=DATE('S') /*S(Sring)  DATE('S') -> "19761224" */
HoraIni =TIME('N') /*N(Normal) TIME('N') -> "13:15:22" */
Rc_Ejecucion = 1
ErrorDsJob.Cant =0


CANT_RETRY =3
TIMEOUT_RETRY = 10 /*En Segundos*/
TIMEOUT_SLEEP = 2 /*Tiempo de espera para leer el Tamaño del fie (En Segundos)*/
MAX_WARNING = 50
LENGTH_FILENAME_EXTENSION = 4 /*Example: .rex  .exe .obj*/
NULL_VALUE = 'NULL'

Drive         =FILESPEC("drive",!full_name_this_file)
Path_This_File=FILESPEC("path", !full_name_this_file)
Name_This_File=FILESPEC("name", !full_name_this_file)

Path_This_JCL =Drive ||'\Batch\ArchLog\'||!nombre_proceso  || '\'
Name_This_Function = left( Name_This_File, Name_This_File~LENGTH - LENGTH_FILENAME_EXTENSION)

NOT_NUMERIC = 0
NUNERIC_POSITIVE = 1
NUMERIC_NEGATIVE = 2
DECIMAL_POSITIVE = 3
DECIMAL_NEGATIVE = 4

FILE_REINTENTOS  ='REINTENTOS'
FILE_MSGFUN      ='MSGFUN'
FILE_LOGDS       ='LOGDS'
FILE_DATASTAGE   ='DATASTAGE'
FILE_DSJOB_ERROR ='DSJOB'

File.FILE_REINTENTOS.Id = 1
File.FILE_REINTENTOS.NameFile = 'reintentos.tmp'
File.FILE_REINTENTOS.Path = Path_This_JCL
File.FILE_REINTENTOS.IsOpen = 0 /*False*/

File.FILE_MSGFUN.Id = 2
File.FILE_MSGFUN.NameFile = 'msgfun.tmp'
File.FILE_MSGFUN.Path = Path_This_JCL
File.FILE_MSGFUN.IsOpen = 0 /*False*/

File.FILE_LOGDS.Id = 3
File.FILE_LOGDS.NameFile = '#JCLNAME#.tmp'
File.FILE_LOGDS.Path ='#DRIVE#\appls\log_DS\'
File.FILE_LOGDS.IsOpen = 0 /*False*/

File.FILE_DATASTAGE.Id = 4
File.FILE_DATASTAGE.NameFile = '#JCLNAME#.txt'
File.FILE_DATASTAGE.Path ='#DRIVE#\data\datastage\' /*\\Tcswba03\stds_Datastage$*/
File.FILE_DATASTAGE.IsOpen = 0 /*False*/

File.FILE_DSJOB_ERROR.Id = 5
File.FILE_DSJOB_ERROR.NameFile = 'CANCEL-' Name_This_Function || '.log'
File.FILE_DSJOB_ERROR.Path = Path_This_JCL
File.FILE_DSJOB_ERROR.IsOpen = 0 /*False*/

CALL WriteFile FILE_MSGFUN, '------------------------------------------------'
CALL WriteFile FILE_MSGFUN, '* FUNCION ' || Name_This_Function || ' *'
CALL WriteFile FILE_MSGFUN, DATE('N') ||' a las '|| TIME('N')  /* N(Normal) DATE('N') -> "24 Dec 1976" - / TIME('N') -> "13:15:22" */

IF !ambiente == 'DESARROLLO' THEN DO 
	!DsjobxEnvironment = Registry_Reading('@DSJOBX_ENVIRONMENT') /* Busca en Registry del proceso el campo @DSJOBX_ENVIRONMENT seteados con $SetVar */

	IF  UPPER(!DsjobxEnvironment) \= NULL_VALUE THEN DO
		SELECT
			WHEN !DsjobxEnvironment = 'DEVELOPMENT'      THEN Name_Alias_Function= Name_This_Function || '_DESA'
			WHEN !DsjobxEnvironment = 'QUALITYASSURANCE' THEN Name_Alias_Function= Name_This_Function
			OTHERWISE
			DO
				CALL WriteFile FILE_MSGFUN, '[' || !DsjobxEnvironment || '] Incorrect value for the global variable @DSJOBX_ENVIRONMENT'
				EXIT 1
			END
		END /* SELECT */	
	END /*END IF DsjobxEnvironment*/
	ELSE DO
		Name_Alias_Function = Name_This_Function
	END
END /*END IF !ambiente*/
ELSE DO /*OPERATIVO*/
	Name_Alias_Function = Name_This_Function
END

Path_DsJobExe = Get_Value_In_File(Drive || Path_This_File || 'funcion.ini', Name_Alias_Function, 3) 
!server       = Get_Value_In_File(!path_clave, Name_Alias_Function, 4) /*!path_clave='d:\Batch\JclSoft\WBP100.txt' */
!user         = Get_Value_In_File(!path_clave, Name_Alias_Function, 2) /*!path_clave='d:\Batch\JclSoft\WBP100.txt' */
!password     = Get_Value_In_File(!path_clave, Name_Alias_Function, 3) /*!path_clave='d:\Batch\JclSoft\WBP100.txt' */


Path_Exec = Path_DsJobExe || ' -domain NONE -server ' ||!server|| ' -user ' ||!user|| ' -password '|| !password

!proyecto  = Registry_Reading(word(!campo,1)) /* busca dentro del proceso los campos seteados con $SetVar */
IF (!proyecto  = NULL_VALUE) THEN DO 
	!proyecto  = word(!campo1,1)
END /*ARO Imp2.2.2*/

Caller_Job = Registry_Reading(word(!campo,2))
IF (Caller_Job = NULL_VALUE) THEN DO
	Caller_Job = word(!campo1,2)
END /*ARO Imp2.2.2*/
PARSE VAR Caller_Job Caller_Job '.' Instance

/*Quitar esta linea cuando se modifique el Job DataStage que lee el file C:\data\datastage\xxxx.txt*/
CALL Write_Time_DSSJOB(Rc_Ejecucion) 
/*Fin del comentario*/

/*************TEST REG*****************/
CALL Read_Registry_Write_File
/***********END TEST REG***************/



ValorWarningGlobal = Registry_Reading('@MAX_WARNING')
IF (ValorWarningGlobal = NULL_VALUE) THEN DO
	ValorWarningGlobal = ''
END
ELSE DO
	IF ISNUMERIC(ValorWarningGlobal) \= NUNERIC_POSITIVE THEN DO
		CALL _ADD_ERROR 'E-W01', 'La variable global @MAX_WARNING [' || ValorWarningGlobal || '] tiene que ser numerico positivo, mayor a 0(cero) y menor a '|| MAX_WARNING ||'.'
		ValorWarningGlobal =''
	END
	ELSE DO
		IF ( (ValorWarningGlobal = 0) | (ValorWarningGlobal > MAX_WARNING) ) THEN DO
			CALL _ADD_ERROR 'E-W02', 'La variable global @MAX_WARNING [' || ValorWarningGlobal || '] tiene que ser numerico positivo, mayor a 0(cero) y menor a '|| MAX_WARNING ||'.'
			ValorWarningGlobal =''
		END 
	END
END
VarWar=''
/*VarParam=''*//*ARO Imp2.1.2*/
VarParam.Cant =0/*ARO Imp2.1.2*/
VarInst=''
i=3
valor = WORD(!campo,i)
DO WHILE ( valor  \= '' )
	parametro=''
	valorparametro =''

	/*IF ((VarWar \= '') & (VarParam \= '') & (VarInst \= '' )) THEN DO
		CALL _ADD_ERROR 'E-X01',  '[' || valor || '] No se permiten setear mas de 3 comandos a la funcion.'
	END*//*ARO Imp2.1.2*/
	
	IF  ((valor \='-WAR')  & (valor \= '-PARAM') & (valor \= '-INS' )) THEN DO
		CALL _ADD_ERROR 'E-X02',  'Solo se permite setear los comandos -INS -WAR o -PARAM a la funcion. (Utilizo el comando: ' || valor || ').'
	END
	
	/*IF (((valor = '-WAR') & (VarWar \= '' )) | ((valor = '-PARAM') & (VarParam \= '' )) | ((valor = '-INS') & (VarInst \= '' ))) THEN DO
		CALL _ADD_ERROR 'E-X03',  'No se puede setear mas de una vez el mismo comando [' || valor || '].'
	END*//*ARO Imp2.1.2*/
	IF (((valor = '-WAR') & (VarWar \= '' )) | ((valor = '-INS') & (VarInst \= '' ))) THEN DO
		CALL _ADD_ERROR 'E-X03',  'No se puede setear mas de una vez el mismo comando [' || valor || '].'
	END	/*ARO Imp2.1.2*/
	
	IF ((valor = '-INS') & (Instance \= '')) THEN DO
		 CALL _ADD_ERROR 'E-I01', 'No se permiten realizar una instancia por nombre de job y por el comando -INS'
	END
	i = i +1
	parametro = WORD(!campo,i)
	
	IF ( parametro == '') THEN DO
		IF ((valor = '-WAR') | (valor = '-PARAM') | (valor = '-INS')) THEN DO
			CALL _ADD_ERROR 'E-X04',  'Se precisa un parametro para el comando [' || valor || '].'
		END
	END
	ELSE DO
		
		registry  = Registry_Reading(parametro)
		IF (registry \= NULL_VALUE) THEN DO
				IF POS('$JCLNAME$', parametro) > 0 THEN DO
					CALL _ADD_ERROR 'E-X05',  'El nombre de la variable pasada por parametro no puede tener la palabra reservada $JCLNAME$ [' || parametro || '].'
				END
				ELSE DO
					valorparametro = registry
				END
		END
		ELSE DO
				valorparametro = parametro
	    END
		valorparametro = STRREPLACE(UPPER(valorparametro),'$JCLNAME$',!nombre_proceso)
		
		IF ( ,
			(UPPER(STRREPLACE(valorparametro,'-','')) == 'WAR')   | ,
			(UPPER(STRREPLACE(parametro     ,'-','')) == 'WAR')   | ,			
			(UPPER(STRREPLACE(valorparametro,'-','')) == 'PARAM') | ,
			(UPPER(STRREPLACE(parametro     ,'-','')) == 'PARAM') | ,			
			(UPPER(STRREPLACE(valorparametro,'-','')) == 'INS')   | ,
			(UPPER(STRREPLACE(parametro     ,'-','')) == 'INS')		,
			) THEN DO
			CALL _ADD_ERROR 'E-X06', 'No se permite una variable o valor con la palabra calve -INS, -WAR, -PARAM '
		END	
		IF ((registry  == NULL_VALUE) & (valor = '-PARAM')) THEN DO
			CALL _ADD_ERROR 'E-P01', 'El comando -PARAM precisa recibir una variable.'
		END
	
		IF (valor =  '-WAR') THEN DO
			IF (ISNUMERIC(valorparametro) \= NUNERIC_POSITIVE) THEN DO
				CALL _ADD_ERROR 'E-W03', 'El valor del comando -WAR [' || valorparametro || '] tiene que ser numerico positivo, mayor a 0(cero) y menor a '|| MAX_WARNING ||'.'
			END
			ELSE DO
				IF ( (valorparametro = 0) | (valorparametro > MAX_WARNING) ) THEN DO
					CALL _ADD_ERROR 'E-W04', 'El valor del comando -WAR [' || valorparametro || '] tiene que ser numerico positivo, mayor a 0(cero) y menor a '|| MAX_WARNING ||'.'
				END 
				ELSE DO
					VarWar = valorparametro
					ValorWarningGlobal = VarWar
				END
			END
		END
		IF (valor = '-PARAM') THEN DO	
			/*VarParam = parametro || '=' || valorparametro*//*ARO Imp2.1.2*/
			NumParam = VarParam.Cant + 1
			VarParam.NumParam.Value  = parametro || '=' || valorparametro
			VarParam.Cant = NumParam /*ARO Imp2.1.2*/
		END
		IF (valor = '-INS') THEN DO	
			VarInst  = valorparametro 
			Instance = valorparametro 
		END 
	END
	i = i +1
	valor = WORD(!campo,i)
END

!ejecutar='del '|| Path_This_JCL ||'CANCEL*.*'
!ejecutar

IF  ErrorDsJob.Cant >0 THEN DO
	CALL WriteFile FILE_DSJOB_ERROR, '* ERROR IN FUNCION ' || Name_This_Function || ' *'
	CALL WriteFile FILE_DSJOB_ERROR, DATE('N') ||' a las '|| TIME('N')  /* N(Normal) DATE('N') -> "24 Dec 1976" - / TIME('N') -> "13:15:22" */
	CALL WriteFile FILE_DSJOB_ERROR,'--------------------------------------------------------'
	do irex=1 to ErrorDsJob.Cant
			CALL WriteFile FILE_DSJOB_ERROR, 'ERROR:' || ErrorDsJob.irex.Id || ': ' || ErrorDsJob.irex.Description
	end
	CALL WriteFile FILE_DSJOB_ERROR
	EXIT 3609
END

	IF  Instance \== '' THEN DO
		Batch_Job  = Caller_Job || 'JOB.' || Instance
		Caller_Job = Caller_Job || '.'    || Instance
	END
	ELSE DO
		Batch_Job  = Caller_Job || 'JOB'
	END
		
		/*if VarParam \== '' then do
			VarParam = '-param ' || VarParam
		end*//*ARO Imp2.1.2*/
		VarParam.Value = ''
		IF VarParam.Cant >0 THEN DO
			DO iparam=1 TO VarParam.Cant
				VarParam.Value = VarParam.Value || ' -param ' || VarParam.iparam.Value   
			END
		END/*ARO Imp2.1.2*/
		
		if ValorWarningGlobal \== '' then do
			ValorWarningGlobal  = '-warn ' || ValorWarningGlobal
		end 
		/*!ejecutar=  Path_Exec ||' -run -jobstatus '|| VarParam ||' '|| ValorWarningGlobal || ' ' || !proyecto||' '||Caller_Job*//*ARO Imp2.1.2*/
		!ejecutar=  Path_Exec ||' -run -jobstatus '|| VarParam.Value ||' '|| ValorWarningGlobal || ' ' || !proyecto||' '||Caller_Job/*ARO Imp2.1.2*/
		
		Linea_Ejecucion = !ejecutar
		Linea_Ejecucion = STRREPLACE(Linea_Ejecucion,!user,'XXXXXXXX') /* Oculta el User */
		Linea_Ejecucion = STRREPLACE(Linea_Ejecucion,!password,'********') /* Oculta Pass */
		
		CALL WriteFile FILE_MSGFUN, TIME('N') ||' Línea de ejecución: '|| Linea_Ejecucion /*N(Normal) TIME('N') -> "13:15:22" */
		CALL WriteFile FILE_LOGDS,  '------------------------------------------------'
		CALL WriteFile FILE_LOGDS,  TIME('N') ||' Línea de ejecución: '||!ejecutar /*N(Normal) TIME('N') -> "13:15:22" */
		
		!ejecutar
		Rc_Ejecucion = rc
		
		!log_linea='Rc de la ejecución: '|| Rc_Ejecucion
		CALL WriteFile FILE_MSGFUN,!log_linea
		
		Reintentos=0
		DO WHILE (Rc_Ejecucion=81011 & Reintentos < CANT_RETRY)
			Reintentos = Reintentos + 1

			IF Reintentos = 1 THEN DO
				CALL WriteFile FILE_REINTENTOS,  '------------------------------------------------'
				CALL WriteFile FILE_REINTENTOS,  'Reintento de ejecucion: Proyect: ' || !proyecto || ' Job: ' || Caller_Job
			END
			
			!log_linea='Error Nro. 3609 : Error al ejecutar el dsjob, reintentando. ('|| Rc_Ejecucion ||')'
			CALL WriteFile FILE_MSGFUN,!log_linea
			CALL WriteFile FILE_REINTENTOS,  '------------------------------------------------'
			CALL WriteFile FILE_REINTENTOS, !log_linea
			CALL WriteFile FILE_REINTENTOS, 'Reintento N°' || Reintentos
			
			!log_linea='Comienzo espera a las '|| TIME('N') /*N(Normal) TIME('N') -> "13:15:22" */
			CALL WriteFile FILE_MSGFUN,!log_linea
			CALL WriteFile FILE_REINTENTOS, !log_linea
			
			CALL SYSSLEEP TIMEOUT_RETRY
			
			!log_linea='Termina espera y reintenta a las '|| TIME('N') /*N(Normal) TIME('N') -> "13:15:22" */
			CALL WriteFile FILE_MSGFUN,!log_linea
			CALL WriteFile FILE_REINTENTOS, !log_linea
			CALL WriteFile FILE_REINTENTOS,  ' '
			!ejecutar
			Rc_Ejecucion = rc
		END
		CALL WriteFile FILE_REINTENTOS /* Cierra el file de Reintentos, si fue abierto. */



			if Rc_Ejecucion\=1 then do

				!ejecutar= Path_Exec ||' -logsum '||!proyecto||' '||Batch_Job||' > ' || Path_This_JCL ||'CANCEL'||Batch_Job||'.log' 
				!ejecutar
		        !ejecutar= Path_Exec ||' -logsum '||!proyecto||' '||Caller_Job       ||' > ' || Path_This_JCL ||'CANCEL'||Caller_Job       ||'.log'
				!ejecutar


				!ejecutar= Path_Exec ||' -run -mode RESET '||!proyecto||' '||Caller_Job
				!ejecutar
				!ejecutar= Path_Exec ||' -run -mode RESET '||!proyecto||' '||Batch_Job 
				!ejecutar


				!log_linea='Error Nro. 3609 : Error al ejecutar el dsjob. ('||Rc_Ejecucion||')'
				CALL WriteFile FILE_MSGFUN,!log_linea
				
				CALL Write_Time_DSSJOB(Rc_Ejecucion) 
				EXIT 3609
			end
	
		!ejecutar= Path_Exec ||' -logsum '||!proyecto||' '||Batch_Job||' > ' || Path_This_JCL ||Batch_Job||'.log' 
		!ejecutar
		!ejecutar= Path_Exec ||' -logsum '||!proyecto||' '||Caller_Job       ||' > ' || Path_This_JCL ||Caller_Job       ||'.log'
		!ejecutar

		CALL SYSSLEEP TIMEOUT_SLEEP /*Espera para que se graben los Logs, para poder leer el tamaño de los files. */
				
		Size_Log_Caller_Job   = Check_Size_Logs( Path_This_JCL ||Caller_Job       ||'.log' )
		Size_Log_Batch_Job    = Check_Size_Logs( Path_This_JCL ||Batch_Job||'.log' )
		IF ( Size_Log_Caller_Job =0 & Size_Log_Batch_Job =0 ) THEN DO
			CALL WriteFile FILE_LOGDS, TIME('N') ||' Cancelación por los dos logs en 0 y rc=1 ' /*N(Normal) TIME('N') -> "13:15:22" */
			CALL WriteFile FILE_MSGFUN, '3612 : Error al submitir el Job en Data Stage. REPROCESARLO.'
						
			CALL Write_Time_DSSJOB(Rc_Ejecucion) 
			EXIT 3612
		END
				
CALL WriteFile FILE_MSGFUN
CALL Write_Time_DSSJOB(Rc_Ejecucion) 
EXIT 0


/* ********** RUTINAS ************** */
/* ********************************* */
_ADD_ERROR: PROCEDURE EXPOSE ErrorDsJob.
PARSE ARG !id_error, !desc_error
Number_Error = ErrorDsJob.Cant
Number_Error 	=  Number_Error + 1

ErrorDsJob.Number_Error.Description = !desc_error
ErrorDsJob.Number_Error.Id 			= !id_error
ErrorDsJob.Cant 					= Number_Error
RETURN
	
Registry_Reading:
/* winregis.rex contains the required directives for the WindowsRegistry object [::REQUIRES "winsystm.cls"]*/
PARSE ARG !field

ObjRegistry =''
ObjValRegistry =''
ValData=''
Tree='SOFTWARE\BATCH\'||!nombre_proceso

CALL WriteFile FILE_MSGFUN, ' ' 
CALL WriteFile FILE_MSGFUN, 'Function: Registry_Reading. For field: ' || !field

IF UPPER(!field) = NULL_VALUE THEN DO
	CALL WriteFile FILE_MSGFUN, 'The variable name [' || !field || '] is a keyword. Is a word that is reserved by '|| Name_This_Function ||' function.' 
	EXIT 1
END
ELSE DO			
	ObjRegistry = .WindowsRegistry~new            
	IF  ObjRegistry~InitCode = 0 THEN DO
		IF ObjRegistry~open(ObjRegistry~Local_Machine,Tree) \= 0 THEN DO /* open the HKEY_LOCAL_MACHINE\SOFTWARE key. */
	
			ObjValRegistry.=ObjRegistry~GETVALUE(,!field)
			ValData=ObjValRegistry.data   
		
			IF (ObjValRegistry.type = 0) THEN DO
				ValData= NULL_VALUE
			END 
			ELSE DO
				IF (ValData='') THEN DO
					CALL WriteFile FILE_MSGFUN, 'There is no set value for the variable name '|| !field
					EXIT 1
				END
				ELSE DO
					IF UPPER(ValData) = NULL_VALUE THEN DO
						CALL WriteFile FILE_MSGFUN, 'The value [' || ValData || '] of the variable named '|| !field ||' is a keyword. Is a word that is reserved by '|| Name_This_Function ||' function.' 
						EXIT 1
					END
				END
			END
			ObjRegistry~Close
		END
		ELSE DO
			CALL WriteFile FILE_MSGFUN, 'Unexpected error opening the environment subkey: HKEY_LOCAL_MACHINE\SOFTWARE\' || Tree
			EXIT 1
		END
	END
	ELSE DO
		CALL WriteFile FILE_MSGFUN, 'Could not successfully create the WindowsRegistry object'
		EXIT 1
	END

	CALL WriteFile FILE_MSGFUN, 'The value for the field ' || !field || ' is: ' || ValData
END
DROP ObjRegistry.
DROP ObjValRegistry.
RETURN ValData

Get_Value_In_File:
/*Busca en el file (!file,) donde la primer palabra sea !namekey y devuelve la palabra que se encuentra en la posision !positionfield*/
PARSE ARG !path_file_get, !namekey, !positionfield
CALL WriteFile FILE_MSGFUN, 'Get_Value_In_File. [File: '|| !path_file_get || '] [Name Key: '|| !namekey ||'] [Position Field: '|| !positionfield ||']'
ValueField =''
Count=0
DROP infile
DROP lines
DROP i
infile=.stream~new(!path_file_get)
if infile~query('exists')='' then do
	CALL WriteFile FILE_MSGFUN,'Error nro. 3540: Archivo de Claves '|| !path_file_get ||' no existe'
	EXIT 3540
	end 
else do
	infile~open('READ SHAREREAD') /*ARO Imp2.1.1*/
	lines=infile~makearray(line)
	infile~close
	do i over lines
		Count = Count + 1
		if word(i,1) = !namekey then do
			ValueField =word(i,!positionfield)   
			if ValueField='' then do  
				CALL WriteFile FILE_MSGFUN,'Error Nro. 3513:  Position Field: '|| !positionfield ||' is empty.'
				EXIT 3513 
			end
		end   
	end
	
	if Count=0  then do
		CALL WriteFile FILE_MSGFUN,'Count: '|| Count
		CALL WriteFile FILE_MSGFUN,'i: '|| i
		CALL WriteFile FILE_MSGFUN,'ValueField: '|| ValueField
		CALL WriteFile FILE_MSGFUN,'Error Nro. 3512:  No se pudo recorrer el File: '|| !path_file_get 
		EXIT 3512
	end
	else do
		if ValueField='' then do  
			CALL WriteFile FILE_MSGFUN,'Error Nro. 3511:  Name Key: '|| !namekey ||' no encontrada'
			EXIT 3504  
		end
	end	
end
RETURN ValueField

WriteFile:
PARSE ARG !file, !linea
Identificador = File.!file.Id

IF File.!file.IsOpen == 0 THEN DO
	IF !linea \== '' THEN DO
		PathFile = File.!file.Path || File.!file.NameFile
		PathFile = STRREPLACE(PathFile,'#DRIVE#',Drive)
		PathFile = STRREPLACE(PathFile,'#JCLNAME#',!nombre_proceso)

		Log_file.Identificador =.stream~new(PathFile)
		Log_file.Identificador~open 
	 
		File.!file.IsOpen = 1

		Log_file.Identificador~LINEOUT(!linea)
		
	END
END 
ELSE DO
	IF !linea \== '' THEN DO
		Log_file.Identificador~LINEOUT(!linea)
	END 
	ELSE DO
		Log_file.Identificador~close
		File.!file.IsOpen = 0
	END
END
RETURN

Read_Registry_Write_File:
/* winregis.rex contains the required directives for the WindowsRegistry object [::REQUIRES "winsystm.cls"]*/
ObjRegistry =''
ObjQueryRegistry =''
ValData=''
Contador = 0
Tree='SOFTWARE\BATCH\'||!nombre_proceso

CALL WriteFile FILE_MSGFUN, '----------Read the Registry ( '|| Tree || ' )----------'

ObjRegistry = .WindowsRegistry~new            
IF  ObjRegistry~InitCode = 0 THEN DO
	IF ObjRegistry~open(ObjRegistry~Local_Machine,Tree) \= 0 THEN DO  /*open the HKEY_LOCAL_MACHINE\SOFTWARE key. */
		ObjQueryRegistry. = ObjRegistry~query 
		IF ObjRegistry~ListValues(,ValData.) = 0 THEN DO Contador = 1 TO ObjQueryRegistry.values
			CALL WriteFile FILE_MSGFUN, (ValData.Contador.name || '=' || ValData.Contador.data)
		END
		ObjRegistry~Close
	END
	ELSE DO
		CALL WriteFile FILE_MSGFUN, 'Unexpected error opening the environment subkey: HKEY_LOCAL_MACHINE\SOFTWARE\' || Tree
		EXIT 1
	END
END
ELSE DO
	CALL WriteFile FILE_MSGFUN, 'Could not successfully create the WindowsRegistry object'
	EXIT 1
END
CALL WriteFile FILE_MSGFUN, '----------End Read the Registry----------'
	
DROP ObjRegistry.
DROP ObjQueryRegistry.
DROP ValData.
RETURN


Check_Size_Logs:
PARSE ARG !path_file_check
Size_File = 0
Infile = 0

CALL WriteFile FILE_MSGFUN,'Check_Size_Logs'

Infile =.stream~new(!path_file_check)
Size_File=Infile~QUERY('SIZE')

CALL WriteFile FILE_MSGFUN, ('The '|| !path_file_check ||' file is the size of '|| Size_File)

RETURN Size_File

Write_Time_DSSJOB:
PARSE ARG !rc_ejec
	/* Lineas para loguear archivo para metricas de duracion de funcion DSJOB */
	/*Cuando Se replace las funciones DSJOBA, DSJOBQ, DSJOBM, DSJOBN por DSJOBX:
	1.-Modificr el Job DataStage que lee el file C:\data\datastage\xxxx.txt para que leea el nuevo formato Fecha Inicio; Hora Inicio; Fecha de Fin; Hora de Fin; Duracion en Segundos; Proyecto DataSatege; Job DataSateg; Nombre de JCL; RC de ejecucion
	2.-Modificar la linea CALL WriteFile  FILE_DATASTAGE, Log_Dsjob_a_cambiar por CALL WriteFile  FILE_DATASTAGE, Log_Dsjob 
	3.-Quitar la primer llamada a CALL Write_Time_DSSJOB(Rc_Ejecucion) Solo tiene que quedar cuando hace exit
	*/
	Log_Dsjob = ( FechaIni ||';'|| HoraIni ||';'|| DATE('S') ||';'|| TIME('N') ||';'|| TRUNC(TIME('E'),0) ||';'|| !proyecto ||';'|| Caller_Job ||';'|| !nombre_proceso ||';'|| !rc_ejec )
	Log_Dsjob_a_cambiar = ( DATE('S') ||';'|| TIME('N') ||';'|| !proyecto ||';'|| Caller_Job|| ';' || !nombre_proceso ||';'|| !rc_ejec)
	/*S(Sring)   DATE('S') -> "19761224" 
	  N(Normal)  TIME('N') -> "13:15:22"
	  E(Elapsed) TIME('E') -> Returns the elapsed time since the last call to TIME('R')
	 */
	
	CALL WriteFile  FILE_DATASTAGE, Log_Dsjob_a_cambiar
RETURN

ISNUMERIC: PROCEDURE
PARSE ARG !text
	NOTNUM = 0
	NUNPOS = 1
	NUMNEG = 2
	DECPOS = 3
	DECNEG = 4
	
	Result = NOTNUM
	IF  DATATYPE(!text) == 'NUM' THEN DO
		IF  !text ==  trunc(!text,0)  THEN DO
			IF (!text < 0) THEN DO
				Result = NUMNEG /*Numerico Negativo*/
			END
			ELSE DO
				Result = NUNPOS /*Numerico Positivo*/
			END
		END
		ELSE DO
			IF (!text < 0) THEN DO
				Result = DECNEG /*Decimal Negativo*/
			END
			ELSE DO
				Result = DECPOS /*Decimal Positivo*/
			END
		END
	END
	ELSE DO
		Result = NOTNUM /*No Numerico*/
	END
RETURN Result

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

LOWER: PROCEDURE
PARSE ARG !text
Result = !text
AlphabetLower = 'abcdefghijklmnñopqrstuvwyz'
AlphabetUpper =  translate(AlphabetLower)                       
Result =  translate(!text,AlphabetLower,AlphabetUpper)
RETURN Result

SYNTAX:
MsgErr='Rexx Error 50'|| rc ||' in line ' ||sigl||':'||"ERRORTEXT"(rc)
SAY MsgErr
SAY "SOURCELINE"(sigl)
EXIT '50'|| rc
nop 

/* winregis.rex contains the required directives for the WindowsRegistry object [::REQUIRES "winsystm.cls"]*/
::REQUIRES "winsystm.cls"