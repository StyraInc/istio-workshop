package policy.ingress

import input.attributes.request as request
import future.keywords.in

default allow = false

allow {
  some account
  input.parsed_path = ["account", "v2", account, "details"]
  "customer_support" in jwt.realm_access.roles
  jwt.role_level >= 1
}

allow {
  some account
  input.parsed_path = ["account", "v2", account, "transactions"]
  "customer_support" in jwt.realm_access.roles
  jwt.role_level >= 2
}

allow {
  #account service is allowed to call accountholder service
  input.attributes.destination.principal == "spiffe://cluster.local/ns/default/sa/accountholder-sa"
  input.attributes.source.principal == "spiffe://cluster.local/ns/default/sa/account-sa"
}

allow {
  input.parsed_path[0] == "portal"
}

allow {
  input.parsed_path[0] == "entitlements"
}

jwt := payload {
  [_, payload, _] := io.jwt.decode(bearer_token)
}

bearer_token := t {
  v := input.attributes.request.http.headers.authorization
  startswith(v, "Bearer ")
  t := substring(v, count("Bearer "), -1)
}