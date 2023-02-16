Class dc.PubSub.Interop.Util
{

ClassMethod AddElement(pProd As Ens.Config.Production, pAttr As %DynamicObject, ByRef pSettings)
{
  set objItem = ##class(Ens.Config.Item).%New()
  set objItem.Production = pProd
  set objItem.Name = pAttr.Name
  set objItem.ClassName = pAttr.ClassName
  set objItem.Enabled = pAttr.Enabled
  set objItem.LogTraceEvents = pAttr.LogTraceEvents
  set objItem.Category = pAttr.Category
  set objItem.PoolSize = pAttr.PoolSize
  set objItem.Comment = pAttr.Comment
  if $data(pSettings) do objItem.UpdateSettings(.pSettings)
  do pProd.Items.Insert(objItem)
  $$$ThrowOnError(pProd.%Save())
}

}
