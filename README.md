# Stubby

A local DNS and HTTP server combo that provides a package manager
solution to configuring network systems on a development machine. This
is currently only designed to run on OS X.

Use it to:

* manage your dev domains (like pow, with lethal power)

* distribute a spec for your API so developers can run basic tests without
hitting your dev server.

* point a client to the right version of an app without editing a hosts file.

* lock down access to a dev system only to users running a stubby.json config
from your project.

## Installation

Install the stubby gem:

		> $ sudo gem install stubby

## Available Options

                > $ sudo stubby -h
                > Commands:
                >  stubby env NAME           # Switch stubby environment
                >  stubby help [COMMAND]     # Describe available commands or one specific command
                >  stubby search             # View all available stubs
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
                >      "example": "staging"
                >    },
                >
                >    "(https?:\/\/)?example.com": "http://localhost:3000"
                >  },
                >
                >  "staging": {
                >    "dependencies": {
                >      "example": "staging"
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
                >  "rules":{
                >    "example":{
                >      "_comment":"All SMTP traffic (NOT YET FUNCTIONAL)",
                >      "admin.example.com":"10.0.1.1",
                >      "admin2.example.com":"dns-cname://admin.example.com",
                >      "(http?://)?merchant.example.com":"http://10.0.1.1",
                >      "(https?://)?.*.example.io":"http://10.0.1.1",
                >      "(https?://)?.*mail.*yahoo.*":"http://en.wikipedia.org/wiki/RTFM",
                >      "(https?://)?yahoo.com":"https-redirect://duckduckgo.com",
                >      "stubby\\..*":"file:///var/www/tmp",
                >      "api.example.com":"file://~/.stubby/example/files",
                >      "smtp://.*":"log:///var/log/out.txt"
                >    },
                >    "_":{
                >      "dependencies":{
                >        "example":"staging"
                >      },
                >      "(https?://)?example.com":"http://localhost:3000"
                >    }
                >  },
                >  "environment":"test"
                > }

This shows us all activated rules. the "_" indicates that the rules are loaded
from the current `Stubfile.json`. We also see that requests to yahoo.com are
redirected to https://duckduckgo.com:

To revert the system back to normal, just CTRL-C from the main stubby process.
This will revert any changes made to configure DNS servers for all network 
interfaces and will shut down the stubby server.

## Stubbing

A stub is a folder named with the name of the stub that contains a stubby.json file. The stubby.json file contains a hash with the available
modes. Each mode contains a set of rules that define how to route DNS and how to handle potential extension requests (redirects, file server, etc).

Installed stubs are in the ~/.stubby folder:

		> $ ls ~/.stubby 
		> example		system.json

The example folder is the `example` stub, and the system.json file contains the agent configurations. You don't need to manually edit it.

		> $ find ~/.stubby/example
		> ... example
		> ... example/files
		> ... example/hello.html
		> ... example/stubby.json
		
The example/stubby.json file has two modes, staging, and production:

		> cat ~/.stubby/example/stubby.json
		{ "staging": {...}, "production": {...} }

Each environment contains a number of rules:

		{ "staging": {
			"MATCH_REGEXP": "INSTRUCTION"
		} ... }		
		
When a request is made, either DNS or HTTP (important), the request is
compared against the MATCH_REGEXP. If matched, the INSTRUCTION is executed. Since the same rules are consulted for DNS and HTTP, if you are
trying to overwrite a domain, you should make sure the match won't exclude
simply the host. For example, to proxy web traffic from test.example.com
to a server at 10.0.1.5:

		"test.example.com": "http://10.0.1.5"
		
This results in 

		> $ dig test.example.com
		...
		;; ANSWER SECTION:
		test.example.com.   0       IN      A       172.16.123.1
 
172.16.123.1 is the stubby host url (TODO: configurable). All requests
to http://test.example.com are routed to the stubby web server at that
address.
 
		> $ curl test.example.com
 		
Issues a request handled by the stubby web server, which proxies the request to 172.16.123.1.

## Contributing a Stub

Fork this repository, update the index.json file, and submit a pull request. For
this major version, the remote registry will just be the index.json file from
this project's github.

### DNS Only

To simply override DNS for test.example.com, you can create an A record on lookup:

		"test.example.com": "10.0.1.5"		
		
Or a CNAME, if no IP is given:

		"test.example.com": "test.example2.com"
		
But you can be explicit in the INSTRUCTION:

		"test.example.com": "dns-a://10.0.1.5"
		"test.example.com": "dns-cname://test.example2.com"
		
Using the dns-#{name} convention, you can create simple references to 
any dns record type. TODO: need to allow mx record priority somehow.
 
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

		"(https?:\/\/)?yahoo.com": "http-redirect://duckduckgo.com"
		
DNS will resolve to the stubby server, and the web request to http://yahoo.com will redirect to http://duckduckgo.com.

### Capturing Outgoing Email

Stubby includes an SMTP extension to capture outgoing messages. Specify the
domain to capture mail from and forward to smtp://

                "dns-mx://.*\.example\.com": "smtp://"

will ensure any message sent by your system directly (this does not include
messages sent from yahoo or gmail) will be captured by Stubby. Visit
http://outbox.stubby.dev to see the captured messages. 

Mail capture is currently provided by the "MailCatcher" gem. 

### Vision

* protocol in instruction becomes a plugin system. dns-cname:, for instance,
  could be handled by the dns plugin. If it didn't exist when Stubfile.json was
  being installed, it would be installed. 
* proxy traffic on ports and send to log systems:
  ":25": "log-smtp://"
  ":3306": "log-mysql://"
* web app front-end: show emails sent, mysql queries made, etc.
