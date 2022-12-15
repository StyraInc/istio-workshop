# Amazic World Istio Workshop

Owners

- Adam Sandor
- Greg Brown

---  

## Prerequisites

1. Access to Styra DAS Free - https://signup.styra.com  
2. Kubernetes Cluster (local / cloud instance) available  
3. Istio installed - https://istio.io/latest/docs/setup/getting-started/#download  

---  

## Hands-on Lab - Styra DAS Quickstart

For the first hands on lab we'll be walking through the Istio 'Getting Started' quick start.  

What you'll learn how to:
- Deploy and configure Istio, OPA and SLP.
- Author, change and deploy basic policy.

Steps:
1. Select the '?' symbol in the top right-hand corner and select `Getting Started`.
2. In the `Getting Started` screen select `Take a tutorial` and then `Lets get started`.
3. Select `Istio Policy Enforcement with OPA` and `Continue`.
4. The `Quick Start` wizard will appear on the right hand side and we'll follow these steps to complete this lab.
5. IMPORTANT: 
- Select the `Istio and OPA without SLP` instructions tab
- Name the system on step 1 `Workshop`
- DON'T deploy the sample Bookinfo application as we'll be using a different application.

---  

## Hands-on Lab - Advanced Policies

For this lab we'll be deploying the Styra Banking demo application from this Git repository.  The banking app is a basic example of an application that could be used by bank customer service employees to access customer accounts.

TODO: Add the high level overview of policy enforcement and users here from banking demo Git repo.

We'll be reusing the same `default` K8s namespace as the Quick Start above.

### Pre-deployment cleanup step
1. Remove the Quick Start application service from the namespace
```
kubectl delete deployments client-load
kubectl delete deployments example-app
```

### Deploying Styra Banking App  

1. Create a new `Istio` system type called `Banking App` and hit `Create system`.  
2. Deploy the new OPA config
```
# Copy the OPA download script from Banking App | Settings | Install | Istio and OPA without SLP | Create OPA config
# The script downloads opaconfig.yaml and applies to the K8s cluster.
```  
3. Deploy the banking application  
```
# Navigate to the istio-workshop git Repo
kubectl apply -k banking-demo/k8s
```
4. Check all pods are up and running  
```
kubectl get pods -A
```
5. Get the external IP of the Istio gateway to reach UI:
```
# FOR MINIKUBE ONLY: Setup a tunnel to access the gateway from the local machine:
# Run under a new tab to keep process running
$ minikube tunnel
Status:
	machine: istio-test
	pid: 71776
	route: 10.96.0.0/12 -> 172.9.9.9
	minikube: Running
	services: [istio-ingressgateway]
    errors:
		minikube: no errors
		router: no errors
		loadbalancer emulator: no errors

$ kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
<external ip>

```
6. Check the UI is available from a browser:
```
# IMPORTANT: Ensure that the trailing forward slash is included
http://<IP address>/portal/
```

If everything is working correctly the app should redirect to the Banking Demo login screen https://banking-demo.expo.styralab.com/auth

---

### Application Policy Implementation

Now we have the app deployed we need to add some basic policy to get to a valid initial state.

1. Enable all requests to OPA.  
Replace the policy in system/authz/authz.rego with the below:  

```
package system.authz

# Allow access by default.
default allow = true
```

Select `Publish` to commit changes, build the bundle and push out to the connected OPAs.

By default the Istio system type whitelists the APIs that can be called on the OPA REST API.  This is best practice.  However, for this demo application we're using a number of APIs outside the standard APIs and for simplicity are allowing all requests.

2. Add an Istio `app` policy to allow all requests.  
This is the policy invoked directly by the Java services of the application.  

Replace the policy/app/rules.rego policy with the following:  

```
package policy.app
import future.keywords.in

default allowed = false

allowed = true {
    count(deny) == 0
}

deny = []
transaction_filter = {}
```

3. Add a Decision Mapping

It's sometimes necessary to define how Allowed / Denied should be determined based on the decision payload.  With decision mapping you can specify this and also any extra columns to include in the decison summary row.

- Select the `Banking App` then Settings | Decision Mappings the `Add decision mapping`
- Set the following values
```
Package/rule = policy/app
Path to decision = result.allowed

# Add 2 columns
Search key = iban, Path to value = input.account.iban
Search key = geo_region , Path to value = input.account.geo_region

```  

This tells Styra DAS that the result.allowed is the value to look at to determine whether allowed or denied status specifically for the policy.app package.  It also tells Styra DAS to include the IBAN and Geo Region in the decision log summary row and for indexing.

4. Return to the Banking Demo UI in the browser and login

```
username: agent_smith_ws
password: 1234agentsmith
```

You should now be able to:
- Login to the UI and see the main application screen.
- Click on the EU and US accounts on the left hand-side and see that the `Details` and `Transactions` tabs populate with the details of the accounts.

In Styra DAS, select the `Banking App` level and then select Decisions and confirm all decisions are allowed. 

5. Geo-location restrictions.  
The employee Agent Smith covers the EU and so should not be able to see the US bank accounts.  Let's put a restriction in for this in policy/app/rules.rego by changing the policy:  

```
# Replace the following line as we now want to specific a specific geo region deny rule
deny = []

# With this...
deny[message] {
    input.subject.geo_region != input.account.geo_region
    message := sprintf("geo region of customer support employee (%v) doesn't match account's (%v)", [input.subject.geo_region, input.account.geo_region])
} 

This looks at the geo region of the employee with that of the geo region of the account and if there is not a match returns a message with the reason.
```  
6. Publish the changes

Best practice is to check the impact of the draft changes before continuing.

- Select `Validate` and check the `Decisions` tab to see the impact of the change.
You should see there are changes as would be expected.  Select the change and drill into the Json and you can confirm `account.geo_region = US` and `subject.geo_region = EU` and so no longer valid under the new policy.

- Publish the draft by selecting `Publish`

- Confirm the Banking App UI now returns an error message when select the US account.
```
"geo region of customer support employee (EU) doesn't match account's (US)"
```

7. Enhance policy/app/rule.rego policy

Let now add some more policy to apply to the decison requests by adding the following to the end of the policy/app/rule.rego file:

```
deny[message] {
    not "customer_support" in input.subject.roles
    message := "missing customer_support role"
}

deny[message] {
    input.subject.role_level < 2
    message := sprintf("role level too low %v", [input.subject.role_level])
}
```  
Then replace the following...
```
transaction_filter = {}
```  
With this...
```
transaction_filter["result"] = "FAILURE" {
    input.subject.role_level <= 2
}
```

- `Preview / Validate` the changes and then select `Publish`

This will restrict access to:
- Only employees that have the `customer_support` role.
- Have a role level higher than 2
- Transactions restricted to `Failed` where employees have a role level <= 2

8. At this point we have the App level policy implemented

We can now test other users against the policy.  
Log out from the application and try the following users:
```
username: agent_brown_ws
password: 1234agentbrown

username: agent_jones_ws
password: 1234agentjones

```  

You should find the outcome as follows:  

Agent Smith:  
- Is allowed to see EU but not US accounts as he's EU based
- Is customer suport so allowed access
- Can only see all 7 transactions (not restricted to failed) 
Agent Brown:
- Is allowed to see EU but not US accounts as he's EU based
- Is customer suport so allowed access
- Can only see the 3 `Failed` transactions (instead of the full 7 transactions)  
Agent Jones:
- Is allowed to see US but not EU accounts as he's US based
- Is customer suport so allowed access
- Can only see the 3 `Failed` transactions (instead of the full 7 transactions)


---

### Ingress Policy Implementation

We can implement a similar policy on the Istio ingress as we done above for the application.    

1. Replace the policy/ingress/rules.rego with the following:

```
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
```  

The above policy demostrates:
- Decoding a JWT token from the request and accessing the claims within it
- Service to service authorization based on Spiffe IDs.
- Authorization based on URL paths

2. Validate and Publish

- Select `Validate` to check impact and then `Publish`
- Confirm the application UI exhibits the same behaviour as previously with Application policy.

---

### Istio Stack Policy Implementation

Styra DAS Stacks provide a mechanism to enforce policy across multiple Systems.  The typical use case is for implementing corporate level policy (business or regulatory) in a consistent fashion, often by security teams or product owners.  

Lets implement a Stack policy to ensure that employees can only access the system on the days they should be working.  

1. Create a new `Stack`
- Select the "+" button next to stacks and select `Istio` stack type and name it `Bank Policy`
- Select `Add stack` to create the stack

2. Configure the System mapping
- Select selectors/selectors.rego, on the left hand side add key/value label `system-type` and value `istio`
- Select `Preview` which should show that the Stack is mapping to the `Banking App` system.
- Select `Publish` to push the updates.

3. Create a datasource
- Select the Bank Policy Stack level and select the 3 dots icon and then `Add Data Source`
- Set `Datasource name` as `working_days` and then `Save`
- Select `Create new draft` and then add the following Json

```
{
  "agent_brown": {
    "workDays": [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday"
    ]
  },
  "agent_jones": {
    "workDays": [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday"
    ]
  },
  "agent_smith": {
    "workDays": [
      "Tuesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday"
    ]
  }
}
```

4. Add the policy

- Go to policy/ingress/rules.rego and make a note of the unique stack ID in the package statement
- Update the below `<STACK ID HERE>` placeholders with your ID from above and add replace the existing rules.rego.

```
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
```

- Select `Preview` to ensure the policy is valid and then `Publish`.

The above policy takes the username from the JWT token for user and users the working_days datasource to find the days they are scheduled to work and then compares to the current day.  If the user is trying to access the system on a day they are not scheduled to then `Deny` will be true and override the System policy.
