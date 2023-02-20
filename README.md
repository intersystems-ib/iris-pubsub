Simple local Publisher-Subscriber utility for InterSystems IRIS.

# QuickStart

* Run sample container
```
docker-compose up -d
```

* PubSub uses [dc.PubSub.Interop.Production](http://localhost:52773/csp/user/EnsPortal.ProductionConfig.zen?PRODUCTION=dc.PubSub.Interop.Production&$NAMESPACE=USER). It's empty.
* Create some partitions. This is only needed the first time. Check the production again.
```objectscript
do ##class(dc.PubSub.API).AddPartitions(3)
```

* Create a topic:
    * You will create a topic called `simple/topic`. 
    * Optionally, you can add a `PartitionKey` in your topic. This allows you to define which field, in a message published in your topic, will be used to determine the partition that will handle the message. 
    * All messages in same partition are processed in order.

```objectscript
set topic = ##class(dc.PubSub.API).CreateTopic("simple/topic", { "PartitionKey": "patientId" })
```

* Create some subscribers to your topic.
* These subscribers are class methods that will be called each time a message is published in the topic you created.

```objectscript
do ##class(dc.PubSub.API).CreateSubscription("simple/topic", { "Protocol": "ClassMethod", "Endpoint": "USER:dc.PubSub.Test.Simple:Subscriber"})
do ##class(dc.PubSub.API).CreateSubscription("simple/topic", { "Protocol": "ClassMethod", "Endpoint": "USER:dc.PubSub.Test.Simple:Sub2"})
```

* Publish some messages to your topic
```objectscript
do ##class(dc.PubSub.API).Publish("simple/topic", {"patientId": "HA98744455", "data": "dummy" } )
do ##class(dc.PubSub.API).Publish("simple/topic", {"patientId": "12TFFFHM88", "data": "dummy999" } )
```

* Check [messages](http://localhost:52773/csp/user/EnsPortal.MessageViewer.zen) in your production

* Also, check included `^zlog` global:
```objectscript
zw ^zlog
^zlog=4
^zlog(1)="[dc.PubSub.Test.Simple:Subscriber] Received: {""patientId"":""HA98744455"",""data"":""dummy""}"
^zlog(2)="[dc.PubSub.Test.Simple:Sub2] Received: {""patientId"":""HA98744455"",""data"":""dummy""}"
^zlog(3)="[dc.PubSub.Test.Simple:Subscriber] Received: {""patientId"":""12TFFFHM88"",""data"":""dummy999""}"
^zlog(4)="[dc.PubSub.Test.Simple:Sub2] Received: {""patientId"":""12TFFFHM88"",""data"":""dummy999""}"
```
