Class MFT.Production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="MFT.Production" LogGeneralTraceEvents="false">
  <Description></Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="EnsLib.MFT.Service.Passthrough" Category="" ClassName="EnsLib.MFT.Service.Passthrough" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Adapter" Name="MFTConnectionName">Yandex</Setting>
    <Setting Target="Host" Name="TargetConfigNames">EnsLib.File.PassthroughOperation</Setting>
    <Setting Target="Adapter" Name="IncludeSubFolders">1</Setting>
    <Setting Target="Adapter" Name="MFTSourceFolders">/Source/</Setting>
  </Item>
  <Item Name="EnsLib.File.PassthroughOperation" Category="" ClassName="EnsLib.File.PassthroughOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="FilePath">C:\InterSystems\IRIS\DropboxOut\</Setting>
    <Setting Target="Adapter" Name="Charset">Binary</Setting>
    <Setting Target="Host" Name="Filename">%f</Setting>
  </Item>
  <Item Name="EnsLib.MFT.Operation.Passthrough" Category="" ClassName="EnsLib.MFT.Operation.Passthrough" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="MFTConnectionName">Yandex</Setting>
    <Setting Target="Host" Name="DefaultMFTFolder">/Destination/</Setting>
  </Item>
  <Item Name="EnsLib.File.PassthroughService" Category="" ClassName="EnsLib.File.PassthroughService" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="TargetConfigNames">EnsLib.MFT.Operation.Passthrough</Setting>
    <Setting Target="Adapter" Name="FilePath">C:\InterSystems\IRIS\Dropbox</Setting>
    <Setting Target="Adapter" Name="Charset">Binary</Setting>
  </Item>
</Production>
}

}

