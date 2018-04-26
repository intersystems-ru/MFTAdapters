Class MFT.Yandex
{

Parameter SSLConfig = "Yandex";

Parameter URL = "https://cloud-api.yandex.net:443/v1/";

Parameter Production = "MFT.Production";

/// w $System.Status.GetErrorText(##class(MFT.Yandex).Install())
ClassMethod Install(username As %String, clientId As %String, clientSecret As %String, host As %String = "localhost", port As %Integer = {$get(^%SYS("WebServer","Port"), 57772)}, useSSL As %Boolean = {$$$NO})
{
	New $Namespace
	Set $Namespace = "%SYS"	
 	
 	Do:'##class(Security.SSLConfigs).Exists(..#SSLConfig) ##class(Security.SSLConfigs).Create(..#SSLConfig)
	
	Set sys = ##class(%SYS.MFT.Connection.Yandex).%New()
	Set sys.Name = "Yandex"
	Set sys.Service = "Yandex"
	Set sys.ApplicationName = "Yandex"
	Set sys.SSLConfiguration = ..#SSLConfig
	Set sys.Username = username
	Set sys.URL = ..#URL
	
	$$$QuitOnError(##class(%SYS.MFT.Connection.Yandex).CreateClient(sys.Name, ..#SSLConfig, clientId, clientSecret, ,host, port,,useSSL))
	
	Quit sys.%Save()
}

/// w $System.Status.GetErrorText(##class(MFT.Yandex).ConfigureProduction())
ClassMethod ConfigureProduction(yandexSource As %String, fileDestination As %String, fileSource As %String, yandexDestination As %String) As %Status
{
	Set sc=$$$OK
	$$$QuitOnError(##class(Ens.Director).StopProduction())
	
	Set production = ##class(Ens.Config.Production).%OpenId(..#Production)
	
	$$$QuitOnError(..ModifySetting(production, "EnsLib.MFT.Service.Passthrough", "MFTSourceFolders", yandexSource))
	$$$QuitOnError(..ModifySetting(production, "EnsLib.File.PassthroughOperation", "FilePath", fileDestination))
	$$$QuitOnError(..ModifySetting(production, "EnsLib.File.PassthroughService", "FilePath", fileSource))
	$$$QuitOnError(..ModifySetting(production, "EnsLib.MFT.Operation.Passthrough", "DefaultMFTFolder", yandexDestination))
	$$$QuitOnError(production.%Save())
	Write !, "Success!", !
	Quit sc
}

ClassMethod ModifySetting(production As Ens.Config.Production = {..#Production}, itemName As %String, settingName As %String, value As %String) As %Status
{
	Set:'$isObject($get(production)) production = ##class(Ens.Config.Production).%OpenId(production)
	
	#Dim item As Ens.Config.Item
	Set item = production.FindItemByConfigName(itemName, .sc)
	Quit:$$$ISERR(sc) sc
	
	#Dim setting As Ens.Config.Setting
	Set setting = item.FindSettingByName(settingName)
	Quit:$$$ISERR(sc) sc
	
	Set setting.Value = value
	Quit item.%Save()
}

}

