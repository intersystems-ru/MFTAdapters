Include %syConfig

Class MFT.Installer
{

Parameter DB = "MFTLIB";

/// write $System.Status.GetErrorText(##class(MFT.Installer).Install())
ClassMethod Install(namespace = {$Namespace}) As %Status
{
	#Dim sc As %Status = $$$OK
	$$$QuitOnError(..CreateDatabase())
	$$$QuitOnError(..CreateMapping("%MFT.Addons"))
	$$$QuitOnError(..CreateMapping("%SYS.MFT.Connection.Addons"))
	$$$QuitOnError(..Load())
	
	Quit sc
}

ClassMethod CreateDatabase() As %Status
{
	#Dim sc As %Status = $$$OK
	Set dir = ##class(%File).SubDirectoryName(##class(%File).ManagerDirectory(), ..#DB, $$$YES)
	Set exists = ##class(%File).Exists(dir _ "CACHE.DAT")
	Quit:exists $$$ERROR($$$GeneralError, ..#DB _ " directory exists and contains CACHE.DAT")
	
	If '##class(%File).DirectoryExists(dir) {
		// Make sure the directory exists first
		If '##class(%File).CreateDirectoryChain(dir) {
			Quit $$$ERROR($$$DirectoryCannotCreate, dir)
		}
	}
	
	New $Namespace
	Set $Namespace = "%SYS"
	
	// Physically create the database
	$$$QuitOnError($$CreateDatabase^%SYS.DATABASE(dir))
	
	Kill properties
	Set properties("Directory") = dir
	$$$QuitOnError(##Class(Config.Databases).Create(..#DB, .properties))
	$$$QuitOnError(##class(%EnsembleMgr).assignResourceToDB("%DB_" _ ..#DB, dir, "R"))
	Quit sc
}

ClassMethod CreateMapping(package As %String, fromDB As %String = {..#DB}, toNS = "%SYS") As %Status
{
	New $Namespace
	Set $Namespace = "%SYS"
	#Dim sc As %Status = $$$OK
	Set toNS = $zcvt(toNS, "U")
	
	If '##Class(Config.MapPackages).Exists(toNS, package) {
		Kill properties
		Set properties("Database") = fromDB
		Set sc = ##Class(Config.MapPackages).Create(toNS, package, .properties)
	}
	Quit sc
}

/// write $System.Status.GetErrorText(##class(MFT.Installer).Load())
ClassMethod Load2()
{
	New $Namespace
	Set $Namespace = "%SYS"
	#Dim sc As %Status = $$$OK
	Set sc = $system.OBJ.LoadDir("C:\temp\MFTAdapters\", "cukb", .err, $$$YES)
	Quit sc
}

/// Downloads and compiles GitHub repository.<br>
///  <b>Owner</b> - The name of the repository owner.<br>
///  <b>Repository</b> - The name of the repository.<br>
///  <b>Branch</b> - The name of the commit/branch/tag. If skipped the repository’s default branch (usually master) would be used.<br>
///  <b>Username</b> - GitHub user, who has access to repository. Optional for public repositories.<br>
///  <b>Password</b> - GitHub password, corresponding to Username. Optional for public repositories.<br>
///  Note, that with Username, you can make up to 5,000 requests per hour.
///  For unauthenticated requests, the rate limit allows to make up to 60 requests per hour.
///  Unauthenticated requests are associated with an IP address.<br>
///  <b>Namespace</b> - Namespace, where to download and compile repository.<br>
/// 
///  For example in the repository: https://github.com/intersystems-ru/MFTAdapters<br>
///  Owner - intersystems-ru, Repository - MFTAdapters 
/// write $System.Status.GetErrorText(##class(MFT.Installer).Load())
ClassMethod Load(namespace As %String = {$Namespace}, owner As %String = "intersystems-ru", repository As %String = "MFTAdapters", branch As %String, username As %String, password As %String) As %Status
{
	New $Namespace
	Set $Namespace = "%SYS"
	Set ssl = "GitHub"
 	Do:'##class(Security.SSLConfigs).Exists(ssl) ##class(Security.SSLConfigs).Create(ssl)

 	Set req = ##class(%Net.HttpRequest).%New()
 	Set req.Https = $$$YES
	Set req.SSLConfiguration = ssl
	Set req.Server = "api.github.com"
	Set req.Location = "repos/" _ owner _ "/" _ repository _ "/contents" 	// as described in https://developer.github.com/v3/repos/
	Do:$d(Branch) req.SetParam("ref", branch) 								// if omitted the repository’s default branch (usually master) would be used
	Do req.SetHeader("Accept","application/vnd.github.v3+json") 			// we want to receive API v3

	If ($d(username) && $d(password)) {										// supply Username and Passwor, if both are provided. GitHub accept Basic Auth
		Set req.Username = username											// https://developer.github.com/v3/auth/
	 	Set req.Password = password
	}

	Set links = ##class(%ListOfDataTypes).%New()
 	$$$QuitOnError(..ProcessDirectory("", req, links))
	Quit ..DownloadFiles(links, req, namespace)
}

/// Process one directory of GitHub repository. Recursive.<br>
/// <b>path</b> -Internal repository path. Root is empty string<br>
/// <b>request</b> - Authenticated/Set %Net.HttpRequest object.<br>
/// <b>namespace</b> - load non % code here
ClassMethod ProcessDirectory(path As %String = "", request As %Net.HttpRequest, ByRef links As %ListOfDataTypes) As %Status
{
	New $Namespace
	Set $Namespace = "%SYS"
	
	Set location = request.Location
	Set request.Location = $zcvt(request.Location _ path, "I", "URL")

	$$$QuitOnError(request.Get(,,$$$NO))
	Return:(request.HttpResponse.StatusCode = 404) $$$ERROR($$$GeneralError,"Repository doesn't exist OR you don't have access")
	Return:((request.HttpResponse.StatusCode = 403) && (request.HttpResponse.GetHeader("X-RATELIMIT-REMAINING")=0)) $$$ERROR($$$GeneralError,"API rate limit exceeded. Try logging in.")
 	Return:(request.HttpResponse.StatusCode '= 200) $$$ERROR($$$GeneralError,"Received " _ request.HttpResponse.StatusCode _ " status, expected 200")

 	#dim objects As List of %ZEN.proxyObject
 	#dim obj As %ZEN.proxyObject
	$$$QuitOnError(##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(request.HttpResponse.Data,,.objects,1))

	For i = 1:1:objects.Count() {
		Set obj = objects.GetAt(i)
		If (obj.type = "dir") {
			$$$QuitOnError(..ProcessDirectory("/" _ obj.name, request, links))
		} ElseIf (obj.type = "file") {
			Do:..IsCacheFile(obj) links.Insert(obj."download_url")
		}
	}
	Set request.Location = location // to keep track of where in the repository tree we are
	Quit $$$OK
}

/// Check that incoming file is the one you need.
ClassMethod IsCacheFile(file As %ZEN.proxyObject) As %Boolean
{
	Set extensions = ",xml,cls,csp,csr,mac,int,bas,inc,gbl,prj,obj,pkg,gof,"
	Quit:($L(file.name,".")=1) 0 //no extension
	Set file.Extension = $P(file.name,".",$L(file.name,"."))
	Quit $F(extensions,","_$ZCVT(file.Extension,"l")_",")
}

/// Download list of files on https://raw.githubusercontent.com/ server.<br>
/// <b>Links</b> - List of links to raw files.<br>
/// <b>Request</b> - Authenticated/Set %Net.HttpRequest object.<br>
/// <b>loadedlist</b> - Returns an array of the items loaded. 
ClassMethod DownloadFiles(links As %ListOfDataTypes, request As %Net.HttpRequest, namespace As %String = {$Namespace}) As %Status
{
	New $Namespace
	#Dim sc As %Status = $$$OK
	Set nsItems = ""
	Set file = ##class(%File).TempFilename("cls")
	Set stream = ##class(%Stream.FileCharacter).%New()
	Do stream.LinkToFile(file)
	Set request.Server = "raw.githubusercontent.com"
	Set request.ResponseStream = stream

	For i = 1:1:links.Count() {
		set link = $e(links.GetAt(i),35,*)
		$$$QuitOnError(request.Get(link)) // Remove "https://raw.githubusercontent.com/" from URL.		
		If $find(link, "%25") {
			Set $Namespace = "%SYS"
		} Else {
			Set $Namespace = namespace
		}
		
		$$$QuitOnError($system.OBJ.Load(file,"",.error,.items,,,,"UTF8"))
		Merge nsItems = items 
	}
	Set $Namespace = namespace	
	$$$QuitOnError($system.OBJ.CompileList(.nsItems))
	
	Quit sc
}

}

