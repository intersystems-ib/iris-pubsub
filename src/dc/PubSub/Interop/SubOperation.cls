Class dc.PubSub.Interop.SubOperation Extends Ens.BusinessOperation
{

Parameter ADAPTER;

Parameter INVOCATION = "Queue";

Method DeliverToSubscriber(pRequest As dc.PubSub.Interop.SubMsgReq, Output pResponse As Ens.Response) As %Status
{
    set ret = $$$OK
    new $namespace
    set originalNs = $namespace

    try {    
        set protocol = pRequest.Subscription.Protocol
        if protocol="ClassMethod" {
            set ns = $piece(pRequest.Subscription.Endpoint, ":", 1)
            set classname = $piece(pRequest.Subscription.Endpoint, ":", 2)
            set classmethod = $piece(pRequest.Subscription.Endpoint, ":", 3)
            set $namespace = ns
            do $classmethod(classname, classmethod, pRequest.Payload)
            set $namespace = originalNs
        }

    } catch ex {
        set ret = ex.AsStatus()
        set $namespace = originalNs
    }
    quit ret
}

XData MessageMap
{
<MapItems>
	<MapItem MessageType="dc.PubSub.Interop.SubMsgReq"> 
		<Method>DeliverToSubscriber</Method>
	</MapItem>
</MapItems>
}

}
