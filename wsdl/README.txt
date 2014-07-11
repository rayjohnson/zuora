
Notes on upgrading WSDL

Get the WSDL you want to upgrade to from Zuora.

Run it through http://xmlprettyprint.com - save the result in a file in this directory.

Apply custom fields from the current WSDLinto this new WSDL.  By running the above prettyprint you can use a DIFF tool like Kaleidoscope to easily apply the custom fields.

Add the file to the git repro
Update the api.rb and other files that previously referenced the old WSDL.
Commit and push.

In the sales tool repro do:
bundle update zuora
Then add, commit and push the Gemfiule.lock file.

