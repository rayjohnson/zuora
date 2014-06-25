require 'singleton'
require 'savon'

module Zuora

  # Configure Zuora by passing in an options hash. This must be done before
  # you can use any of the Zuora::Object models.
  # @example
  #   Zuora.configure(:username => 'USERNAME', :password => 'PASSWORD')
  # @param [Hash] configuration option hash
  # @return [Config]
  def self.configure(opts={})
    HTTPI.logger = opts[:logger]
    HTTPI.log = opts[:log] || false

    Api.instance.config = Config.new(opts)
    if Api.instance.config.sandbox
      Api.instance.sandbox!
    else
      Api.instance.production!
    end
  end

  class Api
    include Singleton

    # @return [Savon::Client]
    def client
      @client ||= make_client
    end

    # @return [Zuora::Session]
    attr_accessor :session

    # @return [Zuora::Config]
    attr_accessor :config

    # @return Zuora::Api options
    attr_accessor :options

    # The XML that was transmited in the last request
    # @return [String]
    attr_reader :last_request

    # WSDL = File.expand_path('../../../wsdl/zuora.a.47.1.wsdl', __FILE__)
    WSDL = File.expand_path('../../../wsdl/zuora.a.57.0.wsdl', __FILE__)
    SOAP_VERSION = 2
    # SANDBOX_ENDPOINT = 'https://apisandbox.zuora.com/apps/services/a/38.0'
    SANDBOX_ENDPOINT = 'https://apisandbox.zuora.com/apps/services/a/57.0'
    PRODUCTION_ENDPOINT = 'https://www.zuora.com/apps/services/a/57.0'

    def wsdl
      client.instance_variable_get(:@wsdl)
    end

    # Is this an authenticated session?
    # @return [Boolean]
    def authenticated?
      self.session.try(:active?)
    end

    # Change client to sandbox url
    def sandbox!
      @client = nil
      # this is the source's change but instead taking Ray's change
      self.class.instance.client.globals[:endpoint] = SANDBOX_ENDPOINT
      # self.class.instance.client.wsdl.endpoint = "https://apisandbox.zuora.com/apps/services/a/57.0"
    end

    # Change client to production url
    def production!
      @client = nil
      self.class.instance.client.globals[:endpoint] = PRODUCTION_ENDPOINT
      # self.class.instance.client.wsdl.endpoint = "https://www.zuora.com/apps/services/a/57.0"
    end

    # The XML that was transmited in the last request
    # @return [String]
    def last_request
      client.http.body
    end

    # Generate an API request with the given block.  The block yields an xml
    # builder instance which can be used to build out the request as needed.
    # You can also provide the xml_body which will be used instead of the block.
    # @param [Symbol] symbol of the WSDL operation to call
    # @param [String] string xml body pass to the operation
    # @yield [Builder] xml builder instance
    # @raise [Zuora::Fault]
    def request(method, options={}, &block)
      authenticate! unless authenticated?

      if block_given?
        xml = Builder::XmlMarkup.new
        yield xml
        options[:message] = xml.target!
      end

      client.call(method, options)
    rescue Savon::SOAPFault, IOError => e
      raise Zuora::Fault.new(:message => e.message)
    end

    # Attempt to authenticate against Zuora and initialize the Zuora::Session object
    #
    # @note that the Zuora API requires username to come first in the SOAP request so
    # it is manually generated here instead of simply passing an ordered hash to the client.
    #
    # Upon failure a Zoura::Fault will be raised.
    # @raise [Zuora::Fault]
    def authenticate!
      response = client.call(:login) do
        message username: Zuora::Api.instance.config.username, password: Zuora::Api.instance.config.password
      end
      self.session = Zuora::Session.generate(response.to_hash)
      client.globals.soap_header({'env:SessionHeader' => {'ins0:Session' => self.session.try(:key) }})
    rescue Savon::SOAPFault => e
      raise Zuora::Fault.new(:message => e.message)
    end

    private

    def initialize
      @config = Config.new
    end

    def make_client
      Savon.client(wsdl: WSDL, soap_version: SOAP_VERSION, log: config.log || false, logger: config.logger, ssl_verify_mode: :none, filters: [:password])
    end

  end
end
