Import dc.PubSub.Data

Class dc.PubSub.API
{

Parameter ProductionName = "dc.PubSub.Interop.Production";

Parameter ParameterLUT = "dc.PubSub.Params";

ClassMethod CreateTopic(pTopicName As %String, pAttr As %DynamicObject) As Topic
{
    try {
        set topic = ##class(Topic).Create(pTopicName, pAttr)
        return topic

    } catch ex {
        throw ex
    }
}

ClassMethod CreateSubscription(pTopicName As %String, pAttr As %DynamicObject)
{
    try {
        set topic = ##class(Topic).GetByName(pTopicName)
        return ##class(Subscription).Create(topic, pAttr)

    } catch ex {
        throw ex
    }
}

ClassMethod Publish(pTopicName As %String, pPayload As %DynamicObject)
{
    try {
        set topic = ##class(Topic).GetByName(pTopicName)
        return ##class(PublishQueue).Publish(topic, pPayload)
        
    } catch ex {
        throw ex
    }
}

ClassMethod AddPartitions(pNewPartitions As %Integer)
{
    set production = ##class(Ens.Config.Production).%OpenId(..#ProductionName)
    set totalPartitions = ..GetParamValue("TotalPartitions")

    for i=(totalPartitions+1):1:(totalPartitions+pNewPartitions) {
        set currPartition = (i-1)

        // PubService
        set settings(1)=$lb("Adapter", "Query", "select %ID ID, Topic, Payload, Partition, PartitionKey from dc_PubSub_Data.PublishQueue where Partition=? order by ID")
        set settings(2)=$lb("Adapter", "Parameters", currPartition)
        set settings(3)=$lb("Adapter", "ParamSQLTypes", "SQL_INTEGER")
        set settings(4)=$lb("Adapter", "DeleteQuery", "delete from dc_PubSub_Data.PublishQueue where %ID=?")
        set settings(5)=$lb("Host", "PartitionId", currPartition)
        set settings = 5
        do ##class(dc.PubSub.Interop.Util).AddElement(production, { "Name": ("Pub"_currPartition), "ClassName": "dc.PubSub.Interop.PubService", "Enabled": 1, "PoolSize": 1 }, .settings)

        // SubOperation
        kill settings
        do ##class(dc.PubSub.Interop.Util).AddElement(production, { "Name": ("Sub"_currPartition), "ClassName": "dc.PubSub.Interop.SubOperation", "Enabled": 1, "PoolSize": 1 }, .settings)
    }

    do ..SetParamValue("TotalPartitions", totalPartitions+pNewPartitions)

    do ##class(Ens.Director).RestartProduction(0,1)
}

ClassMethod GetParamValue(pParamName As %String) As %String
{
    return ##class(Ens.Util.FunctionSet).Lookup(..#ParameterLUT,pParamName,"","")
}

ClassMethod SetParamValue(pParamName As %String, pValue As %String) As %String
{
    do ##class(Ens.Util.LookupTable).%UpdateValue(..#ParameterLUT,pParamName,pValue)
}

/// WARNING
ClassMethod DeleteAll()
{
    $$$ThrowOnError(##class(PublishQueue).%KillExtent())
    $$$ThrowOnError(##class(Subscription).%KillExtent())
    $$$ThrowOnError(##class(Topic).%KillExtent())
}

}
