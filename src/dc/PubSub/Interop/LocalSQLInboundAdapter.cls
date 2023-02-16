/* 
   Copyright (c) 2022 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation.
   
   LocalInboundAdapter is a Copy of EnsLib.SQL.InboundAdapter with modifications made to access tables in a local IRIS instanc via Dynamic SQL 
   Although it inherits many features of the original code, This code is not part of InterSystems IRIS and is not supported by InterSystems Corp.
   You are hereby warned that this is Unsupported code which you can use at your own Risk.
    
   Change List:
   2022-10-14, PYD, Pierre-Yves Duquesnoy, Inital copy and modifications of EnsLib.SQL.InboundAdapter
   2022-10-19, PYD, Pierre-Yves Duquesnoy, Fixing the Row Copy from dynamic ResultSet to Snapshot (ImportOneRowFromResultSet) and some UnitTests
   
   */

/// SQL database polling client adapter. Repeatedly executes a query against a Local database using Dynamic SQL and processes each resulting row.
Class dc.PubSub.Interop.LocalSQLInboundAdapter Extends Ens.InboundAdapter [ ClassType = "", Inheritance = right, ProcedureBlock, System = 4 ]
{

Parameter DOMAIN = "ENSEMBLE";

Parameter SERVICEINPUTCLASS = "EnsLib.SQL.Snapshot";

/// The Base query string that will be repeatedly executed to look for new rows
Property Query As %String(MAXLEN = "") [ Required ];

/// A comma-separated list of parameter value specifiers, if any. These correspond to any replaceable ? parameters in the query string.
/// %<varname> refers to Adapter properties such as %LastKey;
/// $<varname> refers to Service class properties;
/// &<varname> refers to persistent values saved between invocations.
Property Parameters As %String(MAXLEN = 1000);

/// A comma-separated list of the SQL data types of each parameter used in the query (eg. SQL_CHAR,SQL_INTEGER).
/// This may be required for the query to execute successfully if the datatypes are not SQL_VARCHAR (the default used when unspecified)
Property ParamSQLTypes As %String(MAXLEN = "");

/// If specified, used to delete rows after processing. Must have exactly one parameter for IDKey value
Property DeleteQuery As %String(MAXLEN = "");

/// The name of the IDKey field in the query's resultset. Must be unique (non-reused) over time if DeleteQuery is empty.
Property KeyFieldName As %String [ InitialExpression = "ID" ];

/// Enable Verbose LogInfo for Adapter Debugging
Property Verbose As %Boolean [ InitialExpression = 0 ];

/// These are the production settings for this object
Parameter SETTINGS = "CallInterval:Basic,Verbose:Basic,Query:Data,Parameters:Data,ParamSQLTypes:Data,DeleteQuery:Data,KeyFieldName:Data,MaxVarCharLengthAsString:Data,DoNotInterruptResultSet:Data";

/// If DeleteQuery is empty or fails, the IDKey value of the last retrieved row is recorded here.
/// If you want to use a Query that will return only new ID values and not use a DeleteQuery, use
///  a Parameters specifier that includes "%LastKey" to access this transient value or "&%LastKey" to
///  access a persistent copy of this value.
Property %LastKey As %Numeric [ InitialExpression = 0, Private ];

/// ResultSet carried over to multiple OnTask() calls if multiple rows found
/// Property %CurrResultSet As EnsLib.SQL.GatewayResultSet [ Private ];
Property %CurrResultSet As %SQL.StatementResult [ Private ];

/// Key index for one Adapter instance to Array of RowIDs of rows found in the current execution of its query.
Property %InstKey As %Integer [ Private ];

/// A shell to hold the current row to pass to ProcessInput()
Property %Row As EnsLib.SQL.Snapshot [ Private ];

/// When a ResultSet is being processed the framework checks if the service ought to stop
/// after each Row is processed. <br>
/// Enabling this setting will mean that all Rows in a ResultSet will be processed
/// by the service before checking if it ought to stop. <br>
/// This should only be enabled if each row is processed without synchronous dependence
/// on another business host. <br>
/// It is intended to help where the SQL call that generated the ResultSet is such that
/// all rows returned in the ResultSet are considered immediately processed without a
/// separate SQL update/delete call and hence none of the rows in the ResultSet will
/// be returned by a repeat invocation. <br>
Property DoNotInterruptResultSet As %Boolean [ InitialExpression = 0 ];

/// PYD+: Copied from EnsLib.SQL.CommonJ
Method deleteRuntimeAppData() [ Internal ]
{
	Try {
		If $Get($$$ConfigPoolSize(..BusinessHost.%ConfigName))'=1 Quit
		Kill $$$EnsRuntimeAppData(..BusinessHost.%ConfigName,"%QCols")		; used by EnsLib.SQL.GatewayResultSet
		Kill $$$EnsRuntimeAppData(..BusinessHost.%ConfigName,"%QParms")		; used by EnsLib.SQL.CommonJ and .Common
		Kill $$$EnsRuntimeAppData(..BusinessHost.%ConfigName,"%ProcCols")	; used by EnsLib.SQL.Common
	} Catch {}
}

/// PYD: Copied from EnsLib.SQL.SnapShot and modified to create a snapshot of just one Row that gets passed to OnProcessInput
/// Import a result set into a Snapshot
/// ResultSet classes supported: EnsLib.SQL.GatewayResultSet, %Library.ResultSet, %ResultSet.* (%Library.IResultSet) as well as the result sets in %SQL package such as %SQL.StatementResult and %SQL.ISelectResult (%SQL.IResult)
/// If pLegacyMode is specified as 0 then attempt first to use %GetMetadata leading to different source of meta data for legacy ResultSet class
/// Default is 1 which maintains previous behavior while still supporting %SQL.* and %ResultSet.* classes.
/// If pODBCColumnType is set to 1 then ColumntType text is set to the ODBC type column type text and not the clientType.
Method ImportOneRowFromResultSet(pRS As %ResultSet, pLegacyMode As %Integer = 1, pODBCColumnType As %Boolean = 0) As %Status
{
	//PYD+
	Do ..%Row.Clean()
	//
	Quit:pRS.%IsA("EnsLib.SQL.GatewayResultSet") pRS.GetSnapshot($this)
	Set tSC = $$$OK
	#; Save metadata
	If (pLegacyMode = 1) {
		Try {
			Set nCols=pRS.GetColumnCount()
			Set tRSClassType = 1
		} Catch ex {
			Try {
				Set nCols = pRS.%GetMetadata().columns.Count()
				Set tRSClassType = 2
			} Catch ex2 {
				Set tSC = $$$ADDSC(ex2.AsStatus(),$$$ERROR($$$EnsErrGeneral,"Import class not supported"))
			}
		}
	} ElseIf (pLegacyMode = 0) {
		Try {
			Set nCols = pRS.%GetMetadata().columns.Count()
			Set tRSClassType = 2
		} Catch ex {
			Try {
				Set nCols=pRS.GetColumnCount()
				Set tRSClassType = 1
			} Catch ex2 {
				Set tSC = $$$ADDSC(ex2.AsStatus(),$$$ERROR($$$EnsErrGeneral,"Import class not supported"))
			}
		}
	} Else {
		Set tSC = $$$ERROR($$$EnsErrGeneral,"pLegacyMode Setting not supported"_": "_pLegacyMode)
	}
	Quit:$$$ISERR(tSC) tSC

	Set tGblRef=..%Row.%GblRef, @tGblRef@("ColNames")=nCols, @tGblRef@("ColIDs")=nCols, @tGblRef@("ColTypes")=nCols, @tGblRef@("ColSizes")=nCols
	For c = 1:1:nCols {
		Set tColumn = "",tOptionString = ""
		Try {
			If (tRSClassType = 1) {
				Set tName = pRS.GetColumnName(c)
			} Else {
				Set tColumn = pRS.%GetMetadata().columns.GetAt(c)
				Set tName = tColumn.colName
				Set tODBCType = tColumn.ODBCType
				Set @tGblRef@("ColTypes",c,"int") = tODBCType
				Set @tGblRef@("ColSizes",c) = tColumn.precision
				Set @tGblRef@("ColScales",c) = tColumn.scale
				Set @tGblRef@("ColisNuls",c) = tColumn.isNullable
				Set @tGblRef@("Collabels",c) = tColumn.label
				Set @tGblRef@("Coltables",c) = tColumn.tableName
				Set @tGblRef@("Colschemas",c) = tColumn.schemaName
				Set @tGblRef@("Colqualifiers",c) = tColumn.qualifier
				Set tOptionString = $Char($Select('tColumn.isAutoIncrement:0,1:1),$Select('tColumn.isCaseSensitive:0,1:1),$Select('tColumn.isCurrency:0,1:1))
				Set tOptionString = tOptionString_$Char($Select('tColumn.isReadOnly:0,1:1),$Select('tColumn.isRowVersion:0,1:1),$Select('tColumn.isUnique:0,1:1),$Select('tColumn.isAliased:0,1:1))
				Set tOptionString = tOptionString_$Char($Select('tColumn.isExpression:0,1:1),$Select('tColumn.isHidden:0,1:1),$Select('tColumn.isIdentity:0,1:1),$Select('tColumn.isKeyColumn:0,1:1),$Select('tColumn.isRowId:0,1:1))
				Set @tGblRef@("Coloptions",c) = tOptionString
			}
		} Catch ex {
			Set tSC = ex.AsStatus()
		}
		Quit:$$$ISERR(tSC)
		
		Set @tGblRef@("ColNames",c)=tName
		Set tBase=$ZCVT(tName,"L")
		If 0=$D(@tGblRef@("ColIDs",tBase)) {
			Set @tGblRef@("ColIDs",tBase)=c
		} Else {
			Set tNI=2, tNameI=tBase_"_2"
			For { Quit:0=$D(@tGblRef@("ColIDs",tNameI))  Set tNI=tNI+1,tNameI=tBase_"_"_tNI }
			Set @tGblRef@("ColIDs",tBase_"_"_tNI)=c
		}
		Try {
			If (tRSClassType = 1) {
		    	Set tColType = pRS.GetColumnType(c)
			} Else {
				Set tColType = tColumn.clientType
			}
		} Catch ex {
			Set tSC = ex.AsStatus()
		}
		Quit:$$$ISERR(tSC)

		If (pODBCColumnType = 1) {
			If ($G(tODBCType)'="") {
				Set tColTypeWord=$Case(tODBCType
					,-7:"BIT"
					,-6:"TINYINT"
					,-5:"BIGINT"
					,-4:"LONGVARBINARY"
					,-3:"VARBINARY"
					,-2:"BINARY"
					,-1:"LONGVARCHAR"
					,1:"CHAR"
					,2:"NUMERIC"
					,3:"DECIMAL"
					,4:"INTEGER"
					,5:"SMALLINT"
					,6:"FLOAT"
					,7:"REAL"
					,8:"DOUBLE"
					,9:"DATE"
					,91:"DATE"
					,10:"TIME"
					,92:"TIME"
					,11:"TIMESTAMP"
					,93:"TIMESTAMP"
					,12:"VARCHAR"
					,:"N/A:"_tODBCType)
			} Else { Set tColTypeWord = ""}
		} Else {
			Set tColTypeWord=$Case(tColType
				,1 :"BINARY"
				,2 :"DATE"
				,3 :"DOUBLE"
				,4 :"HANDLE"
				,5 :"INTEGER"
				,6 :"LIST"
				,7 :"LONGVARCHAR"
				,8 :"TIME"
				,9 :"TIMESTAMP"
				,10:"VARCHAR"
				,11:"STATUS"
				,12:"BINARYSTREAM"
				,13:"CHARACTERSTREAM"
				,14:"NUMERIC"
				,15:"CURRENCY"
				,16:"BOOLEAN"
				,17:"OID"
				,18:"BIGINT"
				,19:"FDATE"
				,20:"FTIMESTAMP"
				,:"N/A:"_tColType)
		}
		Set @tGblRef@("ColTypes",c) = $G(tColTypeWord)
		If (tRSClassType>1) {
			Try {Do pRS.%GetMetadata().columns.%UnSwizzleAt(c)} Catch ex {}
		}
	}
	Quit:$$$ISERR(tSC) tSC

	Try {
		If (tRSClassType=1) {
	    	Merge ..%Row.%Metadata=pRS.%Metadata ; shortcut for Do ..GenerateIResultSetMetadata()
		} Else {
			Do ..%Row.GenerateIResultSetMetadata()
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit:$$$ISERR(tSC) tSC

	#; Save data: 
	///PYD, just one Row for the Snapshot!
	//Set r=0  While pRS.%Next(.tSC) { Set r=r+1 For c = 1:1:nCols { Set @tGblRef@(r,c) = pRS.%GetData(c) } }
	Set r=0  if pRS.%Next(.tSC) { Set r=r+1 For c = 1:1:nCols { Set @tGblRef@(r,c) = pRS.%GetData(c) } }
	Set @tGblRef=r
	Quit tSC
}

/// PYD+: Remove all "Connection" Settings, as we are using Dynamic SQL
Method OnInit() As %Status
{
	Set ..%CurrResultSet=$$$NULLOREF
	
	#; Create an instance of the one-Row snapshot object
	Do ..%RowNewObject()  $$$ASSERT($IsObject(..%Row))
	Set ..%Row.MaxRowsToGet=1

	Set tSC=##super()  Quit:$$$ISERR(tSC) tSC
	#;;;Set tSC=..init()  Quit:$$$ISERR(tSC) tSC
	#;;;Set:..StayConnected>0&&(..StayConnected<..CallInterval) ..KeepaliveInterval=..StayConnected
	
	Kill $$$EnsRuntimeAppData(..BusinessHost.%ConfigName,"adapter.sqlrow") ; clean up on restart
	
	#;;;If ..StayConnected<0 { Set tSC=..Connect(..ConnectTimeout,1)  If $$$ISERR(tSC) $$$LOGWARNING($$$StatusDisplayString(tSC)) } // timeout is not fatal at this point, but do log it
	#;;;Else { $$$SetJobMonitor(..BusinessHost.%ConfigName,$$$SystemName_":"_$Job,$$$eMonitorConnected,"0|"_$$$timeUTC) }
	
	Set ..%InstKey=$I(^IRIS.Temp.Adapter.sqlrow(..BusinessHost.%ConfigName))
	Do ..deleteRuntimeAppData()
	Quit $$$OK
}

Method OnTearDown() As %Status
{
	Kill ^IRIS.Temp.Adapter.sqlrow(..BusinessHost.%ConfigName,..%InstKey)
	#;;;Quit ##Class(EnsLib.SQL.Common)$this.OnTearDown()
}

/// Parse out parameters by comma-separators, honoring single and double quotes, escaped by doubling
Method getParms(Output pArray, pIO As %String = "", pSQLType As %String = "") As %Status [ Private ]
{
	Kill pArray  Set pArray=0, tParm="", tParms=..Parameters_",", tLen=$L(tParms), qq1=0, qq2=0, lq=0, inq(lq)=0, pIO = $zcvt(pIO,"l")
	For i=1:1:tLen { Set c=$E(tParms,i)
		If ","=c&&('lq||(lq=1&&$Case(inq(1),1:qq1,2:qq2,:0))) {
			Quit:i=tLen&&(""=tParm) ; skip the trailing parm if blank
			Set tParm=$ZStrip(tParm,"<>W"), c1=$E(tParm), tParm=$E(tParm,2,*)
			Set tParm=$Case(c1, "%":$Property($this,"%"_tParm), "$":$Property(..BusinessHost,tParm), "&":$G($$$EnsStaticAppData(..BusinessHost.%ConfigName,"adapter.sqlparam",tParm)), :c1_tParm)
			Set tIOChar = "", tSQLType = ""
			If ""'=$E(pIO,pArray+1) {
				For {
					Set tIOChar = $E(pIO,pArray+1)
					Quit:""=tIOChar
					Set pArray(pArray+1,"IOType") = $Case(tIOChar,"i":1,"o":4,"b":2,:"")
					//PYD+: Do not maintain SQLTypes here, not used by DynamicSQL parameters
					/*
					Set tSQLType = $P(pSQLType,",",pArray+1)
					If (""'=tSQLType) {
						Set tSQLType = ..ConvertSQLTypeToInt(tSQLType)
						Set pArray(pArray+1,"SqlType") = tSQLType
					}
					*/
					//PYD-
					If $Case(tIOChar,"i":1,"b":1,:0) {
						Quit
					} Else {
						Set pArray = pArray+1
					}
				}
			}
			If (""=tIOChar)&&(""'=$P(pSQLType,",",pArray+1)) {
				//PYD+: do not use SqlType
				//Set tSQLType = ..ConvertSQLTypeToInt($P(pSQLType,",",pArray+1))
				//Set pArray(pArray+1,"SqlType") = tSQLType
				//PYD-
				
			}
			Set pArray=pArray+1, pArray(pArray)=tParm, tParm="", lq=0, qq1=0, qq2=0
		} Else {
			If "'"=c { Set:inq(lq)=2&&qq2 lq=lq-1  Set qq2=0
				If inq(lq)=1 { If qq1 { Set qq1=0 } Else { Set qq1=1 } }
				Else { Set lq=lq+1, inq(lq)=1 }
			}
			ElseIf """"=c { Set:inq(lq)=1&&qq1 lq=lq-1  Set qq1=0
				If inq(lq)=2 { If qq2 { Set qq2=0 } Else { Set qq2=1 } }
				Else { Set lq=lq+1, inq(lq)=2 }
			} Else {
				Set:qq1||qq2 lq=lq-1, qq1=0, qq2=0
			}
			Set tParm=tParm_c
		}
	}
	If ""'=tParm {
		#; remove artificial comma, match unbalanced quotes
		Set tParm=$E(tParm,1,*-1)
		For lq=lq:-1:1 Set tParm=tParm_$Case(inq(lq),1:"'",2:"""",:"")
		Set pArray=pArray+1, pArray(pArray)=tParm
	}
	Quit $$$OK
}

/// PYD: need equiv for ExecuteQueryParmArray
Method OnTask() As %Status
{
#define ErrorRowTable(%key) $$$EnsRuntimeAppData(..BusinessHost.%ConfigName,"adapter.sqlrow",%key)
#define DoneRowTable(%key) $$$EnsStaticAppData(..BusinessHost.%ConfigName,"adapter.sqlrow",%key)

	Set $ZT="Trap", tSC=$$$OK, tOneRow="" 
	Do {
		If '$IsObject(..%CurrResultSet) {  //PYD+: (||'..Connected)
			//PYD+: Set tSC=..Connect(..ConnectTimeout)
			
			Quit:""=..Query    //PYD+: ||'..Connected
			#; Query the database
			#; construct parms array
			Set tSC=..getParms(.tParms,,..ParamSQLTypes) Quit:$$$ISERR(tSC)
			Set ..%CurrResultSet=$$$NULLOREF
			///PYD+
			///Set tSC=..ExecuteQueryParmArray(.tRS,..Query,.tParms)  Quit:$$$ISERR(tSC)  $$$ASSERT($IsObject(tRS))
			#DIM tRS as %SQL.StatementResult
			set tStmt=##class(%SQL.Statement).%New()
	
			
			set tSC=tStmt.%Prepare(..Query) quit:$$$ISERR(tSC)
			//PYD+
			kill ttParms
			for k=1:1:tParms {
				set ttParms(k)=tParms(k)
			}
			set ttParms=tParms
				set tRS=tStmt.%Execute(ttParms...)  //PYD: Review Format of parms!
			if (tRS.%SQLCODE<0) set tSC=$$$ERROR($$$SQLError,tRS.%SQLCODE,tRS.%Message) quit
			///PYD-
			
			Set ..%CurrResultSet=tRS
			Kill ^IRIS.Temp.Adapter.sqlrow(..BusinessHost.%ConfigName,..%InstKey)
		}
		Set tRowID="",tCount=0  While $IsObject(..%CurrResultSet) {
			//PYD+: Replace GetSnapshot(): Needs to populate with Rows
			///Set tSC=..GetSnapshot(..%Row)  Quit:$$$ISERR(tSC)
			set tSC=..ImportOneRowFromResultSet(..%CurrResultSet)
			//PYD-:
			
			Set tCount=..%Row.RowCount
			If 'tCount {
				#; Done with this ResultSet now
				Set ..%CurrResultSet=$$$NULLOREF
				///PYD: Do:'..StayConnected ..Disconnect()

				#; Remove errored and/or processed rows from the globals if they no longer exist
				Set f="" For  Set f=$Order($$$ErrorRowTable(f)) Quit:f=""  if '$G(^IRIS.Temp.Adapter.sqlrow(..BusinessHost.%ConfigName,..%InstKey,f)) If ""'=$G($$$ErrorRowTable(f)) { $$$sysTRACE($$$FormatText($$$Text("Removed absent row '%1' from errored list"),f)) } Kill $$$ErrorRowTable(f)
				Set f="" For  Set f=$Order($$$DoneRowTable(f)) Quit:f=""   if '$G(^IRIS.Temp.Adapter.sqlrow(..BusinessHost.%ConfigName,..%InstKey,f)) $$$sysTRACE($$$FormatText($$$Text("Removed absent row '%1' from processed list"),f))  Kill $$$DoneRowTable(f)
				Quit
			}
			Do ..%Row.Next()  
			
			If ""=..KeyFieldName { Set tRowID="" }
			Else {
				Set tOneRow = ..%Row.Get(..KeyFieldName)
				If (""=tOneRow||($C(0)=tOneRow)) {
					$$$LOGERROR($$$FormatText($$$Text("Key value not found in field '%1'"),..KeyFieldName))
					#; Done with this ResultSet now
					Set ..%CurrResultSet=$$$NULLOREF
					///PYD: Do:'..StayConnected ..Disconnect()
					Quit
				}
				#; If we have seen this row before, continue to the next one
				Continue:..CheckAgainstDone(tOneRow)

				Set tRowID=tOneRow, tOneRow=""
			}
			$$$sysTRACE($$$FormatText($$$Text("About to process row '%1'"),tRowID))
			Quit ; found a good one
		}
		Quit:$$$ISERR(tSC)||$S(""=..KeyFieldName:'tCount, 1:""=tRowID)
 		if ..Verbose {  //PYD+
			$$$LOGINFO($$$FormatText($$$Text("Processing row %1 '%2'"),..KeyFieldName,tRowID))
		}

 		Set tSC=..BusinessHost.ProcessInput(..%Row.%ConstructClone())  Quit:$$$ISERR(tSC)
 		
		If ""'=..DeleteQuery {
			#; delete the row, and remove the row from do-not-process list if it is deleted
			///PYD+:
			///Set tSC=$S(""=..KeyFieldName:..ExecuteUpdate(.tOK,..DeleteQuery),1:..ExecuteUpdate(.tOK,..DeleteQuery,tRowID))  Set:$$$ISERR(tSC) tOK=0
			if (""=..KeyFieldName) {
				set tRS=##class(%SQL.Statement).%ExecDirect(,..DeleteQuery)
			}else {
				set tRS=##class(%SQL.Statement).%ExecDirect(,..DeleteQuery,tRowID)
			}	
			if (tRS.%SQLCODE<0) set tSC=$$$ERROR($$$SQLError,tRS.%SQLCODE,tRS.%Message) quit
			set tOK=(tRS.%ROWCOUNT=1)
			///PYD-
			
			If tOK { Kill:""'=tRowID $$$ErrorRowTable(tRowID) }
			Else { $$$LOGWARNING($$$FormatText($$$Text("Failed to delete row '%1'"),tRowID)) }
		} ElseIf ""'=tRowID {
			Set $$$ErrorRowTable(tRowID)="", ^(tRowID,"done")=1
			Set $$$DoneRowTable(tRowID)=1
		}
		Set:""'=tRowID (..%LastKey, $$$EnsStaticAppData(..BusinessHost.%ConfigName,"adapter.sqlparam","%LastKey"))=tRowID
	} While (..DoNotInterruptResultSet && $$$ISOK(tSC) && (..%CurrResultSet'=$$$NULLOREF))
Exit
	/*
		Ens.BusinessService::ProcessInput sets ..%WaitForNextCallInterval=0 which
		allows the framework to immediately return to look for next row since there was
		some data.
		Ens.BusinessService::OnTask sets ..%WaitForNextCallInterval=1 at the start of each loop
		Since with DoNotInterruptResultSet we are by passing the resetting in Ens.BusinessService::OnTask 
		we need to set it to 1 here (it may still be 1 if no data found.
	*/
	If ..DoNotInterruptResultSet Set ..BusinessHost.%WaitForNextCallInterval=1
	Quit tSC
Trap
 	Set $ZT="",tSC=$$$EnsSystemError
	Lock:""'=tOneRow -$$$ErrorRowTable(tOneRow)
	Goto Exit
}

/// Check the current RowID against the ErrorRowTable and the DoneRowTable to see if this is a new result
/// Return 1 of we should either quit or continue on to the next row.  Return 0 if this RowID is unique.
/// <param>pRowOrResult</param> is used to make sure trace results match for whether this is a parameter result or a query row
Method CheckAgainstDone(pRowID As %String, pRowOrResult As %String = "row") As %Boolean [ Internal ]
{
	#define ErrorRowTable(%key) $$$EnsRuntimeAppData(..BusinessHost.%ConfigName,"adapter.sqlrow",%key)
	#define DoneRowTable(%key) $$$EnsStaticAppData(..BusinessHost.%ConfigName,"adapter.sqlrow",%key)
	

	#dim tContinue As %Boolean = 1
	
	Do {
		Set ^IRIS.Temp.Adapter.sqlrow(..BusinessHost.%ConfigName,..%InstKey,pRowID)=1

		Lock +$$$ErrorRowTable(pRowID):0 Else  $$$LOGINFO($$$FormatText($$$Text("Skipping locked %1 '%2'"),pRowOrResult,pRowID)) Quit
		#; Skip the query results we have already processed or that errored; only warn once
		If $G($$$DoneRowTable(pRowID)) If $G(^(pRowID,"done"_$E($G($$$ErrorRowTable(pRowID)),-1))) { Kill ^("done") $$$sysTRACE($$$FormatText($$$Text("Skipping previously processed %1 '%2'"),pRowOrResult,pRowID)) } Lock -$$$ErrorRowTable(pRowID) Quit
		If $G($$$ErrorRowTable(pRowID)) If $G(^(pRowID,"wrn")) { Kill ^("wrn") $$$LOGWARNING($$$FormatText($$$Text("Skipping previously errored %1 '%2'"),pRowOrResult,pRowID)) } Lock -$$$ErrorRowTable(pRowID) Quit
		Set $$$ErrorRowTable(pRowID)=1, ^(pRowID,"wrn") = 1
		Set:""=..DeleteQuery ^("done")=1
		Lock -$$$ErrorRowTable(pRowID)
		
		#; If we didn't quit out by now, then don't need to skip to next RowID
		Set tContinue = 0
		
	} While 0
	
	Quit tContinue
}

ClassMethod GetPersistentValue(pConfigName As %String, pParamName As %String) As %String [ CodeMode = expression ]
{
$G($$$EnsStaticAppData(pConfigName,"adapter.sqlparam",pParamName))
}

ClassMethod SetPersistentValue(pConfigName As %String, pParamName As %String, pValue As %String) As %String
{
	Set tOld=$G($$$EnsStaticAppData(pConfigName,"adapter.sqlparam",pParamName))
	Set ^(pParamName) = pValue
	Quit tOld
}

/// Set persistent value (default name=%LastKey) to new value only if it is currently undefined. Return old value if any.
ClassMethod InitializePersistentValue(pConfigName As %String, pParamName As %String = "%LastKey", pNewValue As %String) As %String
{
	Set tDefined=$D($$$EnsStaticAppData(pConfigName,"adapter.sqlparam",pParamName),tOldVal)
	Quit:tDefined#2 tOldVal
	Set ^(pParamName) = pNewValue
	Quit ""
}

ClassMethod InitializeLastKeyValue(pConfigName As %String, pNewLastKey As %String = 0) As %String [ CodeMode = expression ]
{
..InitializePersistentValue(pConfigName,,pNewLastKey)
}

}
