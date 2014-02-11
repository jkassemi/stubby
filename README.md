      $ stubby
        ... Stubby needs _MORE POWER_ - give it sudo (or not, you're still cool) ...

      $ stubby status github
        ... Stubby agent not running ...

      $ stubby
        ... Stuby agent not running ...

      $ sudo stubby agent
        ... Stubby agent started! CTRL-C to revert system to normal ...

      $ sudo stubby help
         
       $ stubby status [*]
         	_github_ *happy*
         	_spreedly_
          
       $ stubby status github
            	_github_ *happy*

	$ stubby mode github
		_github_ *happy*

	$ stubby modes github
		happy
		angry
		unavailable
		
       $ stubby mode * happy
         	_github_ 'mode' is now *happy*
         	_spreedly_ 'mode' is now *happy*

         $ stubby get github
           _github_ installed

         $ stubby update github
           _github_ updated

         $ stubby update *
           _github_ updated
           _spreedly_ updated

         $ stubby remove github
           _github_ removed

         $ stubby mode github happy
           _github_ *happy*

         $ curl http://api.github.com/i/dont/exist
         ...
         < HTTP/1.1 200 OKIE DOKIE
         < Content-Type: application/json

      cat ./stubby.json
      "dev": {"http:\/\/secured.atpay.com":"http://localhost:3000"}}

      $ stubby dev
      $ stubby mode $PWD dev 
        local *dev*
        ... CTRL-C when you're done with 'dev' to revert ...

      curl http://secured.atpay.com/users/signin
      * STUBBY: dev; /Users/james/Documents/latest;
      ..
       HTTP/1.1 200 OK
       Content-Type: super/successful
