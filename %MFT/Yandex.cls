Class %MFT.Yandex Extends %MFT.API
{

/// Get the form of id for a file or folder that is most efficient for subsequent calls.
/// GetRequestId will return either an id of the form "id:<id>" or a full path depending on which is more efficient.
/// This method is included to allow the id for future requests to be saved in the most efficient form.
ClassMethod GetRequestId(connection As %SYS.MFT.Connection.Yandex, itemInfo As %MFT.ItemInfo) As %String
{
	Quit itemInfo.GetPath()
}

/// Return the item info object which describes the specified folder.
/// path may be a folder path.
ClassMethod GetFolderInfo(connection As %SYS.MFT.Connection.Yandex, path As %String, Output itemInfo As %MFT.ItemInfo) As %Status
{
	Try {
		$$$SysLog(2,"MFT","[%MFT.Yandex:GetFolderInfo]","path="_path)

		// Validate the connection
		If connection.Service'=$piece($classname(),".",*) {
			Set sc=$$$ERROR($$$MFTBadConnection)
			Quit
		}

		Set sc=..GetItemInfo(connection,path,.itemInfo)
		// If file returned, then folder not found
		If ($$$ISERR(sc) || '$isobject(itemInfo) || (itemInfo.Type'=$$$MFTfolder)) {
			Set itemInfo=""
		}
	} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%MFT.Yandex:GetFolderInfo]","MFT",sc)
	}
	Quit sc
}

/// Return the item info object which describes the specified file or folder.
/// "" May be used as the itemPath to specify the current folder.<br>
/// If an item does not exist at the specified path, then $$$OK is returned as status and itemInfo is returned as "".<br>
ClassMethod GetItemInfo(connection As %SYS.MFT.Connection.Yandex, itemPath As %String, Output itemInfo As %MFT.ItemInfo) As %Status [ Internal ]
{
	Set sc=$$$OK
	
	Try {
		$$$SysLog(2,"MFT","[%MFT.Yandex:GetItemInfo]","itemPath="_itemPath)
		Set itemInfo=""
		Set folder=""
		
		// Validate the connection
		If connection.Service'=$piece($classname(),".",*) {
			Set sc=$$$ERROR($$$MFTBadConnection)
			Quit
		}

		// Request the metadata for this item.
		Set parameters("path")=itemPath
		
		Set sc=connection.MakeRequest("disk/resources", "GET", .parameters, .response)		
		If response.description="Resource not found." {
			Set sc=$$$OK
			Quit
		}
		Quit:$$$ISERR(sc) 

		// Validate the response	
		If (response.name="") {
			Set text=$extract(response.%ToJSON(),1,200)
			Set sc=$$$ERROR($$$MFTUnexpectedResponse,"GetItemInfo",text)
			Quit
		}
	
		// Create the returned item info object.
		Set itemInfo=..CreateItemInfo(response)

		// If folder requested, then make sure that it is not a file.
		If folder,itemInfo.Type'=$$$MFTfolder {
			Set sc=$$$ERROR($$$MFTFolderExpected,itemPath)
		}

	} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%MFT.Yandex:GetItemInfo]","MFT",sc)
	}
	Quit sc
}

/// Create an ItemInfo object from a Yandex response
ClassMethod CreateItemInfo(response As %DynamicObject) As %MFT.ItemInfo [ Internal ]
{
	Set itemInfo=##class(%MFT.ItemInfo).%New()
	Set itemInfo.Name=response.name
	Set itemInfo.Type = $case(response.type, "dir":$$$MFTfolder, "file":$$$MFTfile)
	Set itemInfo.Container= $piece(response.path,"/",1,*-1)_"/"
	//Set itemInfo.ItemId=response."resource_id"
	Set itemInfo.Details=response.%ToJSON()
	Set itemInfo.Modified=##class(%TimeStamp).XSDToLogical(response.modified)

	Quit itemInfo
}

/// Return the item info object which describes the specified file.
/// path may be a file path.
/// If a file does not exist at the specified path, then $$$OK is returned as status and itemInfo is returned as "".
ClassMethod GetFileInfo(connection As %SYS.MFT.Connection.Yandex, path As %String, Output itemInfo As %MFT.ItemInfo) As %Status
{
	Try {
		$$$SysLog(2,"MFT","[%MFT.Yandex:GetFileInfo]","path="_path)

		// Validate the connection
		If connection.Service'=$piece($classname(),".",*) {
			Set sc=$$$ERROR($$$MFTBadConnection)
			Quit
		}

		Set sc=..GetItemInfo(connection,path,.itemInfo)
		// If folder returned, then file not found
		If ($$$ISERR(sc) || '$isobject(itemInfo) || (itemInfo.Type'=$$$MFTfile)) {
			Set itemInfo=""
		}
	} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%MFT.Yandex:GetFileInfo]","MFT",sc)
	}
	Quit sc
}

/// Creates the remote folder at the specified folderPath.
/// Each level of the folder path should be created separately if it does not already exist.
/// An %MFT.ItemInfo object is returned for the new folder.<br>
ClassMethod CreateFolder(connection As %SYS.MFT.Connection.Yandex, folderPath As %String, Output itemInfo As %MFT.ItemInfo) As %Status
{
	Try {
		$$$SysLog(2,"MFT","[%MFT.Yandex:CreateFolder]","folderPath="_folderPath)
		Set itemInfo=""

		// Validate the connection
		If connection.Service'=$piece($classname(),".",*) {
			Set sc=$$$ERROR($$$MFTBadConnection)
			Quit
		}

		// Remove trailing / from folder name
		Set path=connection.NormalizePath(folderPath)
		If $extract(path,*)="/" {
			Set $extract(path,*)=""
		}

		// Request the that the specified folder be created.
		Set parameters("path")=path
		
		Set sc=connection.MakeRequest("disk/resources", "PUT", .parameters, .response)
		
		If $$$ISERR(sc) Quit

		// Validate the response	
		If response.href="" {
			Set text=$extract(response.%ToJSON(),1,200)
			Set sc=$$$ERROR($$$MFTUnexpectedResponse,"CreateFolder",text)
			Quit
		}
		
		Set sc=..GetItemInfo(connection,path,.itemInfo)

	} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%MFT.Yandex:CreateFolder]","MFT",sc)
	}
	Quit sc
}

/// Delete the remote folder.
/// path may be a folder path.
ClassMethod DeleteFolder(connection As %SYS.MFT.Connection.Yandex, path As %String, permanent As %Boolean = 0) As %Status
{
	Quit ..DeleteFile(connection, path, permanent)
}

/// Delete the remote file.
/// path may be a file path.
/// path may also be specified as an id of the form "id:<id>" which was obtained from a %MFT.ItemInfo object.<br>
/// If permanent is true, then the file will be permanently deleted. Otherwise the file will be moved to trash.<br>
ClassMethod DeleteFile(connection As %SYS.MFT.Connection.Yandex, path As %String, permanent As %Boolean = 0) As %Status
{
	Try {
		$$$SysLog(2,"MFT","[%MFT.Yandex:DeleteFile]","path="_path)
		
		// Validate the connection
		If connection.Service'=$piece($classname(),".",*) {
			Set sc=$$$ERROR($$$MFTBadConnection)
			Quit
		}

		Set path=connection.NormalizePath(path)
		
		// Request the that the specified folder be created.
		Set parameters("path")=path
		Set parameters("permanently") = $case(permanent, $$$NO:"false", $$$YES: "true")
		Set parameters("force_async") = "false"
		
		Set sc=connection.MakeRequest("disk/resources", "DELETE", .parameters, .response)
	} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%MFT.Yandex:DeleteFile]","MFT",sc)
	}
	Quit sc
}

/// Get current user name
ClassMethod GetUsername(connection As %SYS.MFT.Connection.Yandex, internalId As %String, Output username As %String) As %Status
{
	Try {
		$$$SysLog(2,"MFT","[%MFT.Yandex:GetUsername]","internalId="_internalId)
		Set username=""

		// Validate the connection
		If connection.Service'=$piece($classname(),".",*) {
			Set sc=$$$ERROR($$$MFTBadConnection)
			Quit
		}
		
		Set username=connection.Username


	} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%MFT.Yandex:GetUsername]","MFT",sc)
	}
	Quit sc
}

/// Share a folder with a list of users pass as a $list.
/// path may be a folder path or a file. Share is for all.
/// accessLevel and users properties are ignored. 
ClassMethod ShareFolder(connection As %SYS.MFT.Connection.Yandex, path As %String, accessLevel As %String = "viewer", users As %List) As %Status
{
	Try {
		$$$SysLog(2,"MFT","[%MFT.Yandex:ShareFolder]","path="_path_", accessLevel="_accessLevel_", users="_$listtostring(users))
		
		// Validate the connection
		If connection.Service'=$piece($classname(),".",*) {
			Set sc=$$$ERROR($$$MFTBadConnection)
			Quit
		}
		Set parameters("path")=path
		
		Set sc=connection.MakeRequest("disk/resources/publish", "PUT", .parameters, .response)
	} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%MFT.Yandex:ShareFolder]","MFT",sc)
	}
	Quit sc
}

/// Unshare a folder from everyone, user is ignored
/// 
ClassMethod UnshareFolder(connection As %SYS.MFT.Connection.Yandex, path As %String, user As %String) As %Status
{
	Quit ..UnshareFolderAll(connection, path)
}

/// Unshare a folder from all users.
/// path may be a folder path.
/// path may also be specified as an id of the form "id:<id>" which was obtained from a %MFT.ItemInfo object.
ClassMethod UnshareFolderAll(connection As %SYS.MFT.Connection.Yandex, path As %String) As %Status
{
	Try {
		$$$SysLog(2,"MFT","[%MFT.Yandex:ShareFolder]","path="_path_", accessLevel="_accessLevel_", users="_$listtostring(users))
		
		// Validate the connection
		If connection.Service'=$piece($classname(),".",*) {
			Set sc=$$$ERROR($$$MFTBadConnection)
			Quit
		}
		Set parameters("path")=path
		
		Set sc=connection.MakeRequest("disk/resources/unpublish", "PUT", .parameters, .response)
	} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%MFT.Yandex:ShareFolder]","MFT",sc)
	}
	Quit sc
}

/// Update the specified remote file with the contents of the specified local file.
/// filePath must be a file path.  An id may not be specified.
/// If replace is true, then an existing file of the same name will be replaced.  
/// The default is to return an error if a replacement is attempted.
ClassMethod UploadFile(connection As %SYS.MFT.Connection.Yandex, localFilePath As %String, filePath As %String, replace As %Boolean = 0, Output itemInfo As %MFT.ItemInfo) As %Status
{
	Set stream=##class(%FileBinaryStream).%New()
	Set stream.Filename=localFilePath
	Quit ..UploadStream(.connection,stream,filePath,replace,.itemInfo)
}

/// Update the specified remote file with the contents of the specified stream.
/// filePath must be a file path.  An id may not be specified.
/// If replace is true, then an existing file of the same name will be replaced.  
/// The default is to return an error if a replacement is attempted.
ClassMethod UploadStream(connection As %SYS.MFT.Connection.Yandex, stream As %BinaryStream, filePath As %String, replace As %Boolean = 0, Output itemInfo As %MFT.ItemInfo) As %Status
{
	Try {
		$$$SysLog(2,"MFT","[%MFT.Yandex:Upload]","filePath="_filePath)
		Set itemInfo=""

		// Validate the connection
		If connection.Service'=$piece($classname(),".",*) {
			Set sc=$$$ERROR($$$MFTBadConnection)
			Quit
		}

		// Normalize path and make sure a file is being uploaded, not a folder.
		Set path=connection.NormalizePath(filePath)
		If $extract(path,*)="/" {
			Set sc=$$$ERROR($$$MFTNoFolder)
			Quit
		}

		// Request the upload
		Set parameters("path")=path
		Set parameters("overwrite") = $case(replace, $$$NO:"false", $$$YES: "true")
		
		Set sc=connection.MakeRequest("disk/resources/upload", "GET", .parameters, .response)
		If $$$ISERR(sc) Quit

		// Validate the response	
		If response.href="" {
			Set text=$extract(response.%ToJSON(),1,200)
			Set sc=$$$ERROR($$$MFTUnexpectedResponse,"Upload",text)
			Quit
		}
		
		Set sc=connection.MakeUploadRequest(response.href, stream)
		If $$$ISERR(sc) Quit
		
		Set sc=..GetFileInfo(connection, path, .itemInfo)
	} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%MFT.Yandex:Upload]","MFT",sc)
	}
	Quit sc
}

/// Download the specified remote file and store at the location given by localFilePath.
/// filePath may be a file path.
ClassMethod DownloadFile(connection As %SYS.MFT.Connection.Yandex, filePath As %String, localFilePath As %String) As %Status
{
	Set stream=##class(%FileBinaryStream).%New()
	Set stream.Filename=localFilePath
	Quit ..DownloadStream(.connection,filePath,stream)
}

/// Download the specified remote file and store in the specified stream which must be a %FileBinaryStream or a %GlobalBinaryStream.
/// If stream is not specified, then a %GlobalBinaryStream will be created.
/// filePath may be a file path.
ClassMethod DownloadStream(connection As %SYS.MFT.Connection.Yandex, filePath As %String, ByRef stream As %BinaryStream) As %Status
{
	Try {
		$$$SysLog(2,"MFT","[%MFT.Yandex:Download]","filePath="_filePath)
		Set itemInfo=""

		// Validate the connection
		If connection.Service'=$piece($classname(),".",*) {
			Set sc=$$$ERROR($$$MFTBadConnection)
			Quit
		}
		Set path = filePath
		//Set path=connection.NormalizePath(filePath)
		If $extract(path,*)="/" {
			Set sc=$$$ERROR($$$MFTNoFolder)
			Quit
		}

		// Request the download
		Set parameters("path")=path
		
		Set sc=connection.MakeRequest("disk/resources/download", "GET", .parameters, .response)
		If $$$ISERR(sc) Quit

		// Validate the response	
		If (response.href="") {
			Set text=$extract(response.%ToJSON(),1,200)
			Set sc=$$$ERROR($$$MFTUnexpectedResponse,"Download",text)
			Quit
		}
		
		Set sc=connection.MakeDownloadRequest(response.href, .stream)
		Set sc=stream.SaveStream()
	
	} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%MFT.Yandex:Download]","MFT",sc)
	}
	Quit sc
}

/// Return the folder contents object for the specified folder.
/// folderPath may be a folder path.
/// folderPath may also be specified as an id of the form "id:<id>" which was obtained from a %MFT.ItemInfo object.
/// "" May be used as the folderPath to specify the current folder.
/// The FolderContents object will include a list of %MFT.ItemInfo objects which contain a file or folder name
/// and some additional simple information.
ClassMethod GetFolderContents(connection As %SYS.MFT.Connection.Yandex, folderPath As %String, recursive As %Boolean = 0, Output folderContents As %MFT.FolderContents) As %Status
{
	Try {
		$$$SysLog(2,"MFT","[%MFT.Yandex:GetFolderContents]","folderPath="_folderPath_", recursive="_recursive)

		// Validate the connection
		If connection.Service'=$piece($classname(),".",*) {
			Set sc=$$$ERROR($$$MFTBadConnection)
			Quit
		}

		// Get contents of folder possibly recursing over children of the folder also.
		Set folderContents=##class(%MFT.FolderContents).%New()
		Set folderContents.Recursive=''recursive
		Set sc=..GetFolderContentsInternal(connection,folderPath,recursive,folderContents)

	} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%MFT.Yandex:GetFolderContents]","MFT",sc)
	}
	Quit sc
}

/// Internal method for recursing over subfolders to return the folder contents object for the specified folder.
ClassMethod GetFolderContentsInternal(connection As %SYS.MFT.Connection.Yandex, path As %String, recursive As %Boolean = 0, folderContents As %MFT.FolderContents) As %Status [ Internal ]
{
	Try {
		$$$SysLog(2,"MFT","[%MFT.Yandex:GetFolderContentsInternal]","path="_path_", recursive="_recursive)


		#Dim itemInfo As %MFT.ItemInfo
		Set sc=..GetFolderInfo(connection,path,.itemInfo) 
		If $$$ISERR(sc) Quit

		Set entries={}.%FromJSON(itemInfo.Details)
		
		// Add the entries in this response to the list.
		Set iterator=entries."_embedded".items.%GetIterator()
		While iterator.%GetNext(.key,.entry) {
			// Create the returned item info object for the folder child.
			Set itemInfo=..CreateItemInfo(entry)
			If itemInfo="" Continue
			Do folderContents.Contents.Insert(itemInfo)

			// If recorsive required, then add the children
			If ((recursive=$$$YES) && (itemInfo.Type=$$$MFTfolder)) {
				Set sc=..GetFolderContentsInternal(connection,itemInfo.GetPath(),recursive,folderContents)
				If $$$ISERR(sc) Quit
			}
		}
		
	} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%MFT.Yandex:GetFolderContentsInternal]","MFT",sc)
	}
	Quit sc
}

/// Retrieve the %MFT.UserInfo for current user
ClassMethod GetUser(connection As %SYS.MFT.Connection.Yandex, username As %String, Output userInfo As %MFT.UserInfo) As %Status
{
	Try {
		$$$SysLog(2,"MFT","[%MFT.Yandex:GetUser]","username="_username)
		
		Set userInfo = ""
		// Validate the connection
		If (connection.Service'=$piece($classname(),".",*)) {
			Set sc=$$$ERROR($$$MFTBadConnection)
			Quit
		}

		
		Set sc=connection.MakeRequest("disk", "GET", .parameters, .response)
		
		Set userInfo = ##class(%MFT.UserInfo).%New()
		Set userInfo.Username = connection.Username
		Set userInfo.Name = response.user."display_name"
		Set userInfo.Userid = response.user.uid
		Set userInfo.Details = response.%ToJSON()
		
		
		} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%MFT.Yandex:GetUser]","MFT",sc)
	}
	Quit sc
}

/// Retrieve the %MFT.UserInfo specified by the service defined Userid.
/// If the user does not exist, then $$$OK is returned as status and userInfo is returned as "".
ClassMethod GetUserById(connection As %SYS.MFT.Connection.Base, userid As %String, Output userInfo As %MFT.UserInfo) As %Status
{
	Quit ..GetUser(connection, userid, .userInfo)
}

/// Return the list of all currently defined users for this team or enterprise.
ClassMethod GetUserList(connection As %SYS.MFT.Connection.Yandex, Output userList As %MFT.UserList) As %Status
{
	Set sc = $$$OK
	Set userList = ##class(%MFT.UserList).%New()
	Set sc = ..GetUser(connection, "", .userInfo)
	Quit:$$$ISERR(sc) sc
	
	Do userList.Users.Insert(userInfo)
	
	Quit sc
}

/// Create a new user.
/// Unable to do it in Yandex
ClassMethod CreateUser(connection As %SYS.MFT.Connection.Yandex, userInfo As %MFT.UserInfo) As %Status
{
	Quit $$$ERROR($$$MFTBadConnection)
}

/// Delete new user.
/// Unable to do it in Yandex
ClassMethod DeleteUser(connection As %SYS.MFT.Connection.Yandex, username As %String) As %Status
{
	Quit $$$ERROR($$$MFTBadConnection)
}

/// Delete the user that is specified by the id.
ClassMethod DeleteUserById(connection As %SYS.MFT.Connection.Yandex, userid As %String) As %Status
{
	Quit $$$ERROR($$$MFTBadConnection)
}

/// MountFolder is a Dropbox specific method to mount a shared folder that was shared by a different user.
/// MountFolder is treated as a NOP for all other services.
ClassMethod MountFolder(connection As %SYS.MFT.Connection.Box, folderName As %String) As %Status
{
	// A NOP if not Dropbox
	Quit $$$OK
}

/// UnmountFolder is a Dropbox specific method to unmount a shared folder that was shared by a different user.
/// UnmountFolder is treated as a NOP for all other services.
ClassMethod UnmountFolder(connection As %SYS.MFT.Connection.Box, folderName As %String) As %Status
{
	// A NOP if not Dropbox
	Quit $$$OK
}

}

