Class dc.PubSub.Data.PublishQueue Extends (%Persistent, %XML.Adaptor)
{

Property Topic As Topic;

Property Payload As %String(MAXLEN = "");

Property Partition As %Integer;

Property PartitionKey As %String(MAXLEN = "");

Index PartitionIdx On Partition [ Type = bitmap ];

ClassMethod Publish(pTopic As Topic, pPayload As %DynamicObject)
{
    set totalPartitions = ##class(dc.PubSub.API).GetParamValue("TotalPartitions")

    set partKey = pTopic.Name
    if pTopic.PartitionKey'="" {
        set partKey = partKey_"/"_pPayload.%Get(pTopic.PartitionKey)
    } 
    
    set partition = ($ascii($e($System.Encryption.SHA1Hash(partKey), 1, 2))) # totalPartitions

    set queueObj = ..%New()
    set queueObj.Topic = pTopic
    set queueObj.Payload = pPayload.%ToJSON()
    set queueObj.Partition = partition
    set queueObj.PartitionKey = partKey
    $$$ThrowOnError(queueObj.%Save())

    return 1
}

Storage Default
{
<Data name="PublishQueueDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Topic</Value>
</Value>
<Value name="3">
<Value>Payload</Value>
</Value>
<Value name="4">
<Value>Partition</Value>
</Value>
<Value name="5">
<Value>PartitionKey</Value>
</Value>
</Data>
<DataLocation>^dc.PubSub.Data.PublishQueueD</DataLocation>
<DefaultData>PublishQueueDefaultData</DefaultData>
<IdLocation>^dc.PubSub.Data.PublishQueueD</IdLocation>
<IndexLocation>^dc.PubSub.Data.PublishQueueI</IndexLocation>
<StreamLocation>^dc.PubSub.Data.PublishQueueS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
