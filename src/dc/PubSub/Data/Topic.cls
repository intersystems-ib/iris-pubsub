Class dc.PubSub.Data.Topic Extends (%Persistent, %XML.Adaptor)
{

Property Name As %String(MAXLEN = 512);

Property PartitionKey As %String(MAXLEN = 256);

Relationship Subscriptions As Subscription [ Cardinality = many, Inverse = Topic ];

Index NameIdx On Name [ Unique ];

ClassMethod Create(pName As %String, pAttr As %DynamicObject) As Topic
{
    try {

        set topic = ..%New()
        set topic.Name = pName
        set topic.PartitionKey = pAttr.PartitionKey
        $$$ThrowOnError(topic.%Save())

        return topic

    } catch ex {
        throw ex
    }
}

ClassMethod GetByName(pTopicName As %String) As Topic
{
    set topic = ##class(Topic).NameIdxOpen(pTopicName)
    if '$isobject(topic) $$$ThrowStatus($$$ERROR($$$GeneralError, "Topic "_pTopicName_" does not exist"))
    return topic
}

ClassMethod GetById(pTopicId As %String) As Topic
{
    set topic = ##class(dc.PubSub.Data.Topic).%OpenId(pTopicId)
    if '$isobject(topic) $$$ThrowStatus($$$ERROR($$$GeneralError, "Topic "_pTopicId_" does not exist"))
    return topic
}

Storage Default
{
<Data name="TopicDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="3">
<Value>PartitionKey</Value>
</Value>
</Data>
<DataLocation>^dc.PubSub.Data.TopicD</DataLocation>
<DefaultData>TopicDefaultData</DefaultData>
<IdLocation>^dc.PubSub.Data.TopicD</IdLocation>
<IndexLocation>^dc.PubSub.Data.TopicI</IndexLocation>
<StreamLocation>^dc.PubSub.Data.TopicS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
