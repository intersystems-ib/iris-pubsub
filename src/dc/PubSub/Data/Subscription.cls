Class dc.PubSub.Data.Subscription Extends (%Persistent, %XML.Adaptor)
{

Property Protocol As %String(VALUELIST = ",ClassMethod");

Property Endpoint As %String(MAXLEN = "");

Relationship Topic As Topic [ Cardinality = one, Inverse = Subscriptions ];

Index TopicIdx On Topic;

ClassMethod Create(pTopic As Topic, pAttr As %DynamicObject) As Subscription
{
    try {

        set sub = ..%New()
        set sub.Topic = pTopic
        set sub.Protocol = pAttr.Protocol
        set sub.Endpoint = pAttr.Endpoint
        $$$ThrowOnError(sub.%Save())

        return sub

    } catch ex {
        throw ex
    }
}

Storage Default
{
<Data name="SubscriptionDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Protocol</Value>
</Value>
<Value name="3">
<Value>Endpoint</Value>
</Value>
<Value name="4">
<Value>Topic</Value>
</Value>
</Data>
<DataLocation>^dc.PubSub.Data.SubscriptionD</DataLocation>
<DefaultData>SubscriptionDefaultData</DefaultData>
<IdLocation>^dc.PubSub.Data.SubscriptionD</IdLocation>
<IndexLocation>^dc.PubSub.Data.SubscriptionI</IndexLocation>
<StreamLocation>^dc.PubSub.Data.SubscriptionS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
