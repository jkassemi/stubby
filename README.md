# Stubby

A local DNS and HTTP server combo that provides a package manager
solution to configuring network systems on a development machine. This
is currently only designed to run on OS X.

It's designed to allow you to:

* configure stubs for your company's API, allowing customers to
develop without the need of a development machine you're hosting.

* get a client system pointed to a dev version of their web app by
providing them a config file (no describing how to launch hosts)

* lock down access to a dev system only to users with a configuration
they've recevied diretly from you.

## Installation

Install the stubby gem:

		> $ sudo gem install stubby

## Agent

Start the stubby agent. This launches a DNS server and HTTP server on your
local system. All DNS requests are routed through the Stubby DNS server. If
no installed stub matches a request, it's passed upstream (Google's public DNS).

		> $ sudo stubby agent

There's some interface work to be done on stopping the agent - CTRL-C is unreliable at the moment. Additionally, it'd be nice to launchctl the stubby agent so that we don't start it from scratch. Homebrew recipe would be nice, too. 

## Stubs

Search for available stubs:


		> $ stubby search
		{ "example" => ... }
		
Install a stub:

		> $ stubby install example

List state of installed stubs:

		> $ stubby list
		> _example_ [staging,production]


## Modes

Each stub can be configured with several modes. By default, a stub 
without a mode is inactive. Use the mode command to set the mode:

		> $ stubby mode example staging
		> _example_ [*staging,production]

The `example` stub is now in staging mode. DNS requests will be routed
against the rules in the `example` stub configuration.

To disable the DNS overrides, use the mode command again with no mode
argument:

		> $ stubby mode example
		> _example_ [staging,production]
	

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