# Stubby

Stubby makes your development environment act more like your
production environment. 

A local server suite with a declarative project-specific
configuration that helps the project see the host environment
just as it would see production if it were running there.

## Philosophy

Centralized configuration systems instruct your application how to 
function on the host environment. Stubby prefers that your application ask
the environment to mold itself to the needs of the application. 

Consider your app is a manager sent to Germany to lead an automotive 
operation. The manager has a language dictionary and translates each order
to German before giving it to the team. Consider the following interaction:

	"Where's the screwdriver?"
	"Wo ist der Schraubenzieher?"
	
	=>
	
	"Im roten Feld über die Straße"
	"In the red box down the street"
	
	# Get screwdriver from red box,
	# screw bolt into metal
	
This is what we tell our applications to do when we use a centralized
configuration:

	"Where's the database?"
	ENV["DATABASE_URI"]
	"mysql://blah/"
	
	# Connect to database
	# Execute query
	
Stubby is a translator in this instance. Since Stubby knows that you need 
a screwdriver, and it knows where you look for it, Stubby will make sure 
that the screwdriver your manager needs is where your manager expects it to be.

## Uses

* manage your .dev domains (or any random old TLD)

* stub APIs so you can run tests locally

* get your team on the right system with the proper hosts settings. 

## Development Status

The Stubfile.json format and the extension / adapter
organization is clear and complete enough to handle the majority of use
cases. No major changes to the general system or configuration formats.

## Installation

Install the stubby gem:

    > $ sudo gem install stubby

## Available Options

    > $ sudo stubby -h
    > Commands:
    >  stubby env NAME           # Switch stubby environment
    >  stubby help [COMMAND]     # Describe available commands or one specific command
    >  stubby start ENVIRONMENT  # Starts stubby HTTP and DNS servers, default env ENVIRONMENT
    >  stubby status             # View current rules

## Getting Started

Stubby uses `Stubfile.json` for configuration. This file includes a mapping of
environments to a number of rules that define server configurations and stub
usage for the project. 

    > cd ~/MyProject
    > cat Stubfile.json
    > {
    >  "test": {
    >    "dependencies": {
    >      "https://github.com/jkassemi/example-stubby.git": "staging"
    >    },
    >
    >    "example.com": "localhost:3000"
    >  },
    >
    >  "staging": {
    >    "dependencies": {
    >      "https://github.com/jkassemi/example-stubby.git": "staging"
    >    },
    >
    >    "example.com": "dns-cname://aws..."
    >  }
    > }

    > $ sudo stubby start

The 'test' and 'staging' modes for this project both include rules for the
'example' stub, and then define a single rule of their own. Stubby starts
by default in the 'development' environment, so with this `Stubfile.json`,
the stubby server is not yet modifying any requests. In a new terminal:

    > $ sudo stubby env test

Switches stubby to test mode. Now the 'example' stub is activated, and
additionally any requests to http or https versions of example.com are
routed to http://localhost:3000. Let's take a look at the rules applied:

    > $ sudo bin/stubby status

    > {
    > "rules":{
    >   "https://github.com/jkassemi/example-stubby.git":{
    >     "dns://admin.example.com/a":"dns-a://172.16.123.1",
    >     "http://admin.example.com":"http-redirect://blank?to=https://admin.example.com&code=302",
    >     "https://admin.example.com":"http-proxy://10.0.1.1",
    >     "dns://admin2.example.com/a":"dns-cname://admin.example.com",
    >     "http://(.*)\\.?example.com":"http-proxy://10.0.1.1",
    >     "dns://(.*)\\.?example.com/a":"dns-a://172.16.123.1",
    >     "https://g?mail.*/.*":"http-proxy://en.wikipedia.org/wiki/RTFM",
    >     "dns://g?mail.*/.*/a":"dns-a://172.16.123.1",
    >     "http://yahoo.com":"http-redirect://duckduckgo.com",
    >     "dns://yahoo.com/a":"dns-a://172.16.123.1",
    >     "https://yahoo.com":"https-redirect://duckduckgo.com",
    >     "dns://.*\\.stubby.dev/a":"dns-a://172.16.123.1",
    >     "http://.*\\.stubby.dev":"file:///var/www/tmp",
    >     "https://.*\\.stubby.dev":"file:///var/www/tmp",
    >     "dns://api.example.com/a":"dns-a://172.16.123.1",
    >     "http://api.example.com":"file://~/.stubby/example/files",
    >     "https://api.example.com":"file://~/.stubby/example/files",
    >     "dns://.*/mx":"dns-mx://172.16.123.1/?priority=10"
    >   },
    >   "_":{
    >     "dependencies":{
    >       "https://github.com/jkassemi/example-stubby.git":"staging"
    >     },
    >     "dns://secured.atpay.com/a":"dns-a://172.16.123.1",
    >     "http://secured.atpay.com":"http-redirect://blank?to=https://secured.atpay.com&code=302",
    >     "https://secured.atpay.com":"http-proxy://localhost:3000",
    >     "dns://api.atpay.com/a":"dns-a://172.16.123.1",
    >     "http://api.atpay.com":"http-redirect://blank?to=https://api.atpay.com&code=302",
    >     "https://api.atpay.com":"http-proxy://localhost:4000",
    >     "dns://.*/mx":"dns-mx://172.16.123.1/?priority=10"
    >   },
    >   "_smtp":{
    >     "dns://outbox.stubby.dev/a":"dns-a://172.16.123.1",
    >     "http://outbox.stubby.dev":"http-proxy://172.16.123.1:9001"
    >   }
    > },
    > "environment":"development"
    > }

This shows us all activated rules. the "_" indicates that the rules are loaded
from the current `Stubfile.json`, while "example" indicates that the rules are
loaded from an installed stub, "example". 

To revert the system back to normal, just CTRL-C from the main stubby process.
This will revert any changes made to configure DNS servers for all network 
interfaces and will shut down the stubby server.

### Stubs

- example: https://github.com/jkassemi/example-stubby.git 

To contribute a stub, just add your stub to the list above and issue a pull
request. There is no automated central index.

## Environment Verification

It may be useful to deny requests that aren't routed by a system using stubby,
or for a site accessed with stubby to display some information about the
environment requested.

The HTTP and HTTPS extensions both append request headers to proxied 
requests. A STUBBY_ENV header contains the name of the stubby environment.

Additionally, stubby requests send a STUBBY_KEY header which contains a hash
that should be unique over the stubby user and the instruction that the trigger
executed. If you configure your application to track STUBBY_KEY values, you can
whitelist requests to a stubby system. 

## Stubbing

A stub is a folder named with the name of the stub that contains a stubby.json file. The stubby.json file contains a hash with the available
modes. Each mode contains a set of rules that define how to route DNS and how to handle potential extension requests (redirects, file server, etc).

Installed stubs are in the ~/.stubby folder:

    > $ ls ~/.stubby/jkassemi
    > stubby-example

The example folder is the `example` stub, and the system.json file contains the agent configurations. You don't need to manually edit it.

    > $ find ~/.stubby/jkassemi/example
    > ... jkassemi/example
    > ... jkassemi/example/files
    > ... jkassemi/example/hello.html
    > ... jkassemi/example/stubby.json
		
The example/stubby.json file has two modes, staging, and production:

    > cat ~/.stubby/jkassemi/example-stubby/stubby.json
    { "staging": {...}, "production": {...} }

Each environment contains a number of rules:

    { "staging": {
            "[PROTOCOL://]MATCH_REGEXP": "INSTRUCTION"
    } ... }		
		
When a request is made, either DNS or HTTP (important), the request is
compared against the PROTOCOL and MATCH_REGEXP (together these are 
called the TRIGGER). If matched, INSTRUCTION is executed. 
Excluding a protocol from the trigger causes Stubby to presuppose a few
things about your request. It'll handle DNS, HTTP and HTTPS for definitions
like this. 

    "test.example.com": "http://10.0.1.5"
		
Expands to:

    "dns://test.example.com/a": "dns-a://10.0.1.5",
    "http://test.example.com": "http-redirect://blank?to=https://test.example.com&code=302",
    "https://test.example.com": "http-proxy://10.0.1.5

Don't want to default over to https? You can be more explicit:

    "http://test.example.com": "http://10.0.1.5"

Which expands to:

    "dns://test.example.com/a": "dns-a://10.0.1.5",
    "http://test.example.com": "http-proxy://10.0.1.5"

    > $ dig test.example.com
    ...
    ;; ANSWER SECTION:
    test.example.com.   0       IN      A       172.16.123.1
 
172.16.123.1 is the stubby interface (TODO: configurable). All requests
to http://test.example.com are routed to the stubby web server at that
address.
 
    > $ curl test.example.com

Issues a request handled by the stubby web server, which proxies the request to 172.16.123.1.

### DNS Only

To simply override DNS for test.example.com, you can create an A record on lookup:

    "dns://test.example.com": "dns-a://10.0.1.5"		
              
For a CNAME:

    "dns://test.example.com": "dns-cname://test.example2.com"
		
Using the dns-#{name} convention, you can create simple references to 
any dns record type.

### File Server

Because stubby can intercept HTTP requests, it includes a base set of functionality that allows you two serve files directly from the stub. Given a rule:

    "api.example.com": "file://~/.stubby/example/files"
		
DNS will resolve to the stubby server:

    > $ dig api.example.com
    ... 
    api.example.com.   0       IN      A       172.16.123.1
		
And a web request to api.example.com will serve files from the ~/.stubby/example/files directory:

    > $ curl http://api.example.com/hello.html
    > <html><head></head><body>Hello</body></html>

This is designed to allow you to create API stubs (success responses, for instance).


### HTTP Redirects

Given a rule:

    "http://yahoo.com": "http-redirect://blank?to=duckduckgo.com"
		
DNS will resolve to the stubby server, and the web request to http://yahoo.com will redirect to http://duckduckgo.com.

### Capturing Outgoing Email

Stubby includes an SMTP extension to capture outgoing messages. Specify the
domain to capture mail from and forward to smtp://

    "smtp://.*\.example\.com": "about://blank"

will ensure any message sent by your system directly (this does not include
messages sent from yahoo or gmail) will be captured by Stubby. Visit
http://outbox.stubby.dev to see the captured messages. 

Mail capture is currently provided by the "MailCatcher" gem. 

### Vision

* general traffic monitoring proxy traffic on ports and send to log systems:
  ":25": "smtp://"
  ":3306": "mysql://"
* web app front-end: show emails sent, mysql queries made, etc.
* github installation with no index.json
* P2P connections allow access to dev systems running stubby (agent mode?)

    "example.com" => "localhost:3000"
    "tunnel://example.com": "tunnel://jkassemi@stubby.site"

      =>

    On host system:

    "example.com" => "localhost:3000"

    On guest system:

    "dns://example.com/.*" => @
    "http://example.com" => "tunnel://jkassemi@stubby.site/?to=http://example.com"
    "https://example.com" => "tunnel://jkassemi@stubby.site/?to=http://example.com"
    "smtp://.*" => "tunnel://jkassemi@stubby.site/?to=smtp://$1"


guest opens a connection to stubby.site, requesting last broadcast of NAT address
for host. guest attempts udp tunnel with host
