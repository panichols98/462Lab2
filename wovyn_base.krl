ruleset wovyn_base {
  meta {
    use module twilio-sdk alias sdk
      with
        aToken = meta:rulesetConfig{"aToken"}
        sid = meta:rulesetConfig{"sid"}
  }
  global {
    temperature_threshold = 75

    to = meta:rulesetConfig{"to"}
    sender = meta:rulesetConfig{"sender"}

    lastResponse = function() {
      {}.put(ent:lastTimestamp,ent:lastResponse)
    }
  }
  rule process_heartbeat {
    select when wovyn heartbeat where event:attrs{"genericThing"}
    pre {
      temp = event:attrs{"genericThing"}{"data"}{"temperature"}[0]
      time = time:now()
      temp_map = {}.put("temp", temp)
      attribute_map = temp_map.put("time", time)
    }
    fired {
      raise wovyn event "new_temperature_reading" attributes attribute_map
    }
  }
  rule find_high_temps {
    select when wovyn new_temperature_reading
    send_directive("current temp: " + event:attrs{"temp"}{"temperatureF"})
    fired {
      raise wovyn event "temperature_violation" attributes event:attrs
        if (event:attrs{"temp"}{"temperatureF"} > temperature_threshold)
    }
  }
  rule threshold_notification {
    select when wovyn temperature_violation
    /* send_directive("sent text") */
    sdk:sendText(to, sender, "Temperature violation: " + event:attrs{"temp"}{"temperatureF"}) setting(response)
    fired {
      ent:lastResponse := response
      ent:lastTimestamp := time:now()
    }
  }
}
