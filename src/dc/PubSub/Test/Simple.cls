Import dc.PubSub

Class dc.PubSub.Test.Simple
{

ClassMethod Run()
{
    try {
        set topic = ##class(dc.PubSub.API).CreateTopic("simple/topic", { "PartitionKey": "patientId" })
        do ##class(dc.PubSub.API).CreateSubscription("simple/topic", { "Protocol": "ClassMethod", "Endpoint": "USER:dc.PubSub.Test.Simple:Subscriber"})

        do ##class(dc.PubSub.API).Publish("simple/topic", {"patientId": "HA1234", "data": "dummy" } )
        

    } catch ex {
        do ex.DisplayString()
    }
}

ClassMethod Subscriber(payload As %String)
{
    set obj = {}.%FromJSON(payload)
    set ^zlog($i(^zlog)) = "["_$classname()_":Subscriber] Received: "_obj.%ToJSON()
}

ClassMethod Sub2(payload As %String)
{
    set obj = {}.%FromJSON(payload)
    set ^zlog($i(^zlog)) = "["_$classname()_":Sub2] Received: "_obj.%ToJSON()
}

}
