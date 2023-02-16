Class dc.PubSub.Interop.PubService Extends Ens.BusinessService
{

Parameter ADAPTER = "dc.PubSub.Interop.LocalSQLInboundAdapter";

Property PartitionId As %Integer;

Parameter SETTINGS = "PartitionId:PubSub,GenerateSuperSessionID:Additional,AlertGracePeriod:Alerting";

/// Override this method to process incoming data. Do not call SendRequestSync/Async() from outside this method (e.g. in a SOAP Service or a CSP page).
Method OnProcessInput(pInput As EnsLib.SQL.Snapshot, Output pOutput As %RegisteredObject, ByRef pHint As %String) As %Status
{
    set ret = $$$OK
    try {
        set topic = ##class(dc.PubSub.Data.Topic).GetById(pInput.Get("Topic"))

        set payload = pInput.Get("Payload")
        set totalSubscriptions = topic.Subscriptions.Count()
        for i=1:1:totalSubscriptions {
            set msg = ##class(dc.PubSub.Interop.SubMsgReq).%New()
            set msg.Subscription = topic.Subscriptions.GetAt(i)
            set msg.Payload = payload
            set msg.TopicName = topic.Name
            set msg.Partition = pInput.Get("Partition")
            set msg.PartitionKey = pInput.Get("PartitionKey")
            $$$ThrowOnError(..SendRequestAsync("Sub"_..PartitionId, msg))
        }

    } catch ex {
        set ret = ex.AsStatus()
    }
    quit ret
}

}
