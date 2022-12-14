package stacks.<STACK ID HERE>.policy.ingress

import data.stacks.<STACK ID HERE>.working_days as working_days
import future.keywords.in

default allow_workdays = false

deny {
  not allow_workdays
  input.parsed_path = ["account", "v2", account, "details"]
}

deny {
  not allow_workdays
  input.parsed_path = ["account", "v2", account, "transactions"]
}

allow_workdays {
  day := time.weekday(time.now_ns())
  work_days := working_days[jwt.preferred_username].workDays
  day in work_days
}

jwt := payload {
  [_, payload, _] := io.jwt.decode(bearer_token)
}

bearer_token := t {
  v := input.attributes.request.http.headers.authorization
  startswith(v, "Bearer ")
  t := substring(v, count("Bearer "), -1)
}