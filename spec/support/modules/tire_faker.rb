def tire_on
  FakeWeb.clean_registry
end

def tire_off
  FakeWeb.register_uri :any, %r(#{Tire::Configuration.url}), body: '{"took":6,"timed_out":false,"_shards":{"total":5,"successful":5,"failed":0},"hits":{"total":0,"max_score":1.0,"hits":[]}}'
end