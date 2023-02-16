Class dc.PubSub.Interop.SubMsgReq Extends Ens.Request
{

Property TopicName As %String(MAXLEN = "");

Property Payload As %String(MAXLEN = "");

Property Partition As %Integer;

Property PartitionKey As %String(MAXLEN = "");

Property Subscription As dc.PubSub.Data.Subscription;

Storage Default
{
<Data name="SubMsgReqDefaultData">
<Subscript>"SubMsgReq"</Subscript>
<Value name="1">
<Value>TopicName</Value>
</Value>
<Value name="2">
<Value>Payload</Value>
</Value>
<Value name="3">
<Value>Partition</Value>
</Value>
<Value name="4">
<Value>PartitionKey</Value>
</Value>
<Value name="5">
<Value>Subscription</Value>
</Value>
</Data>
<DefaultData>SubMsgReqDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
