Class %SYS.MFT.Connection.Yandex Extends %SYS.MFT.Connection.Base
{

/// Each subclass will define the DefaultURL method to supply the default URL for the service.
ClassMethod DefaultURL() As %String
{
	Quit "https://cloud-api.yandex.net:443/v1/"
}

/// Internal method to normalize the a file or folder path.
Method NormalizePath(path As %String) As %String [ Internal ]
{
	If $e(path, 1, 5) = "disk:" {
		Set normalized = ##super($e(path, 6, *))
		Set normalized = "disk:" _ normalized
	} Else {
		Set normalized = ##super(path)
	}
	Quit normalized
}

/// Create an OAuth 2.0 client with the parameters required to authorize with Yandex.<br>
/// name is the name to be given to the OAuth 2.0 client.<br>
/// sslConfiguration is the SSLConfiguration used to make the HTTP request.<br>
/// clientId and ClientSecret are the id and secret for the OAuth 2.0 client which is obtained from
/// the Yandex App definition.<br>
/// If addiitonal properties are needed, then the Yandex OAuth 2.0 client may be opened and modified.<br>
/// If a server definition does not yet exist for Yandex, then a new server definition is created.
ClassMethod CreateClient(name As %String, sslConfiguration As %String, clientId As %String, clientSecret As %String, issuer As %String = "https://cloud-api.yandex.net:443", host As %String = "localhost", port As %Integer = "", prefix As %String = "", useSSL As %Boolean = 1) As %Status
{
	If '$SYSTEM.Security.Check($$$AdminSecureResourceName,$$$PermUseName) {
		Set sc=$$$ERROR($$$OperationRequires,$$$AdminSecureResourceName_":"_$$$PermUseName)
		Quit
	}
	$$$AddAllRoleTemporary
	
	New $namespace
	Set $namespace="%SYS"
	
	Do ##class(OAuth2.Client).DeleteId(name)
	Set client=##class(OAuth2.Client).%New()
	Set client.ApplicationName=name
	Set client.ClientType="confidential"
	Set client.SSLConfiguration=sslConfiguration
	Set client.RedirectionEndpoint.Host=host
	Set client.RedirectionEndpoint.Port=port
	Set client.RedirectionEndpoint.Prefix=prefix
	Set client.RedirectionEndpoint.UseSSL=useSSL

	Set client.AuthenticationType="body"
	Set client.SigningAlgorithm="RS256"
	Set client.Metadata."grant_types"=$lb("authorization_code")
	Set client.Metadata."client_name"=name_" client"

	Set server=##class(OAuth2.ServerDefinition).OpenByIssuer(issuer)
	If '$isobject(server) {
		Set server=##class(OAuth2.ServerDefinition).%New()
	}
	
	Set server.IssuerEndpoint=issuer
	Set server.Metadata."authorization_endpoint"="https://oauth.yandex.ru/authorize"
	Set server.Metadata."token_endpoint"="https://oauth.yandex.ru/token"
	Set sc=server.%Save()
	If $$$ISERR(sc) Quit sc

	Set client.ServerDefinition=server
	Set client.ClientId=clientId
	Set client.ClientSecret=clientSecret
	Set sc=client.%Save()
	If $$$ISERR(sc) Quit sc
	
	Quit $$$OK
}

/// Revoke the token associated with this connection.
/// Revoke the token in Yandex as well as locally.
Method RevokeToken() As %Status
{
	Set sc=$$$OK
	Set authorized=##class(%SYS.OAuth2.AccessToken).IsAuthorized(..ApplicationName,..ConnectionId,,.accessToken,,,.error)

	If authorized,accessToken'="" {
		// No need to make request
		// See https://tech.yandex.ru/oauth/doc/dg/concepts/device-token-docpage/
		
		// Locally revoke the access token.
		Set scSuper=##super()
		Set sc=$system.Status.AppendStatus(sc,scSuper)
	}
	Quit sc
}

/// Make an REST https request to Yandex API
Method MakeRequest(location As %String, method As %String = "GET", ByRef parameters As %String, Output response As %DynamicObject) As %Status
{
	Try {
		#dim httpRequest As %Net.HttpRequest
		// Get a %Net.HttpRequest object if one is not yet associated with the connection.
		If '$isobject(..HttpRequest) {
			Set ..HttpRequest=##class(%Net.HttpRequest).%New()
		}
		Set httpRequest=..HttpRequest
		
		
		// Make sure to UTF-8 encode the JSON object
		Set httpRequest.ContentType="application/json"

		// Make the request
		/// !!!!
		Set httpRequest.ResponseStream = ##class(%Stream.TmpCharacter).%New()
		Do httpRequest.EntityBody.Rewind()
		Set:..URL="" ..URL=..DefaultURL()

		Set httpRequest.SSLConfiguration = ..SSLConfiguration
		
		
		Set param = ""
		For {
			Set param=$order(parameters(param),1, value) 
			Quit:param=""
			Do httpRequest.SetParam(param, value)
		}
		
		Set sc=..MakeHttpRequest(httpRequest, method, ..URL _ location, $$$YES)	
		
		Quit:$$$ISERR(sc) 
		
		/// Workaround for UTF8 conversion in GetJSONResponse
		#Dim json As %Stream.FileCharacterGzip
		
		Set json=httpRequest.HttpResponse.Data
		Set sc=..ProcessResponse(httpRequest,json,.response)
		
	} Catch ex {
		Set sc=ex.AsStatus()
	}
	
	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%SYS.MFT.Connection.Yandex:MakeRequest]","MFT",sc)
	}
	Quit sc
}

/// Make an REST https request to Yandex API
Method MakeDownloadRequest(location As %String, ByRef stream As %Stream.Object) As %Status
{
	Try {
		Set:'$isObject($g(stream)) stream=##class(%GlobalBinaryStream).%New()
		Set httpRequest=##class(%Net.HttpRequest).%New()
		Set httpRequest.Https=$$$YES
		Set httpRequest.SSLConfiguration=..SSLConfiguration
		Set httpRequest.ResponseStream=stream
		Set sc=httpRequest.Get(location)	
	} Catch ex {
		Set sc=ex.AsStatus()
	}
	
	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%SYS.MFT.Connection.Yandex:MakeDownloadRequest]","MFT",sc)
	}
	Quit sc
}

/// MakeHttpRequest will add authentication to the specified %Net.HttpRequest object and
/// execute the request using the specified method with the specified REST parameters added to the URL.
/// After the request is made, the authentication information is removed to avoid making this available to user code.
Method MakeHttpRequest(httpRequest As %Net.HttpRequest, method As %String = "GET", url As %String, reset As %Boolean = 1) As %Status
{
	Try {
		// Get a %Net.HttpRequest object if one is not yet associated with the connection.
		If '$isobject($get(httpRequest)) {
			Set httpRequest=##class(%Net.HttpRequest).%New()
		}
		
		// Add authorization as a bearer token
		Set sc=..AddAccessToken(httpRequest,,..SSLConfiguration,..ApplicationName,..ConnectionId)
		If $$$ISERR(sc) Quit
		
		// Log the request that we are making
		If $$$SysLogLevel>=2 {
			Do ##class(%OAuth2.Utils).LogHTTPRequest("[%SYS.MFT.Connection.Yandex:MakeHttpRequest]","MFT",
				httpRequest,method,url,,2)
		}
	
		// Make the REST request.
		Set sc=httpRequest.Send(method,url,,reset)
		
		If $$$ISOK(sc) {
			// Log the response
			If $$$SysLogLevel>=2 {
				Do ##class(%OAuth2.Utils).LogHTTPResponse("[%SYS.MFT.Connection.Yandex:MakeHttpRequest]","MFT",httpRequest,2)
			}
			// Treat no HTTP status code as an error
			If httpRequest.HttpResponse.StatusCode="" {
				Set sc=$$$ERROR($$$MFTErrorResponse,"response has null HTTP status code")
			}
		}
		
		// Remove the access token from the %Net.HttpRequest object authorization header.
		Set sc1=##class(%SYS.OAuth2.AccessToken).RemoveAuthorizationAccessToken(httpRequest)
		Set sc=$system.Status.AppendStatus(sc,sc1)
		
	} Catch ex {
		Set sc=ex.AsStatus()
	}
	
	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%SYS.MFT.Connection.Yandex:MakeHttpRequest]","MFT",sc)
	}
	Quit sc
}

/// AddAccessToken adds the bearer access token associated with applicationName and sessionId
/// to the resource server request as defined by RFC 6750.
/// The sslConfiguration that is specified for the client is added to the httpRequest object.
/// This method is used to prepare requests from the Client to the Resource Server.
/// The type argument specifies one of three ways defined by RFC 6750 to send the access token to the Resource Server:<br>
/// 	"header" to use Bearer token HTTP header.<br>
/// 	"body" to use form encoded body.  In this case, request must be a POST with form encoded body.<br>
/// 	"query" to use a query parameter.<br>
/// The sslConfiguration is the name of the Security.SSLConfigs object to use for this request.
/// The default for sslConfiguration comes from the OAuth2.Client instance.
ClassMethod AddAccessToken(httpRequest As %Net.HttpRequest, type As %String = "header", sslConfiguration As %String, applicationName As %String, sessionId As %String) As %Status
{
	Set sc=$$$OK
	$$$AddAllRoleTemporary
	New $namespace
	Set $namespace="%SYS"
	
	Try {
		Do ##class(%OAuth2.Utils).GetDefaultSessionId(.sessionId)

		If '##class(%SYS.OAuth2.AccessToken).GetAccessToken(applicationName,sessionId,,.accessToken) {
			Set sc=$$$ERROR($$$OAuth2NoAccessToken)
			Quit
		}
		
		$$$SysLog(3,"OAuth2","[%SYS.MFT.Connection.Yandex:AddAccessToken]","applicationName="_applicationName_", sessionId="_sessionId)

		Do httpRequest.SetHeader("Authorization","OAuth "_accessToken)		
	} Catch ex {
		Set sc=ex.AsStatus()
	}

	If $$$ISERR(sc) Do ##class(%OAuth2.Utils).LogError("[%SYS.OAuth2.AccessToken:AddAccessToken]",0,sc)
	Quit sc
}

/// TODO
/// Make an Upload style http request to Dropbox API
Method MakeUploadRequest(location As %String, stream As %Stream.Object) As %Status
{
	Try {
		Set httpRequest=##class(%Net.HttpRequest).%New()
		Set httpRequest.Https=$$$YES
		Set httpRequest.SSLConfiguration=..SSLConfiguration
		Set httpRequest.EntityBody = stream
		Set httpRequest.ContentType = "text/plain"
		Set httpRequest.NoDefaultContentCharset = $$$YES
		Set sc=httpRequest.Put(location)	
	} Catch ex {
		Set sc=ex.AsStatus()
	}
	
	If $$$ISERR(sc) {
		Do ##class(%OAuth2.Utils).LogError("[%SYS.MFT.Connection.Yandex:MakeDownloadRequest]","MFT",sc)
	}
	Quit sc
}

/// Get the response object
ClassMethod ProcessResponse(httpRequest As %Net.HttpRequest, json As %Stream.TmpCharacter, Output response As %DynamicObject) As %Status [ Final, Internal ]
{
	Try {
		Set sc=$$$OK
		Set response=""

		// Handle success and error cases
		Set statusCode=httpRequest.HttpResponse.StatusCode
		Set:json.Size>0 response=##class(%DynamicAbstractObject).%FromJSON(json)
		Set:$e(statusCode)'=2 sc=$$$ERROR($$$MFTErrorResponse, $$$FormatText("Error code: %1, error body: %2", statusCode, response.%ToJSON()))

	} Catch ex {
		Set sc=$$$ADDSC($$$ERROR($$$MFTErrorResponse,"Exception"),ex.AsStatus())
	}
	
	Quit sc
}

Storage Default
{
<Type>%Library.CacheStorage</Type>
}

}

