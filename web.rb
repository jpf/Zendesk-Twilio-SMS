require 'rubygems'
require 'sinatra'
require 'logger'
require 'zendesk_api'
require 'twilio-ruby'
require 'json'

$stdout.sync = true

$log = Logger.new(STDOUT)
$log.level = Logger::ERROR
if ENV['DEBUG']
  $log.level = Logger::DEBUG
end

class ZendeskUpdate
  def initialize(zendesk_client)
    @client = zendesk_client
    @user = nil
    @log = $log
  end

  def for_user(phone_number)
    # :external_id is what allows all of this to work
    rv = @client.users.search(:external_id => phone_number)
    if rv.any? 
      @user = rv.first
      @log.debug("Found existing user: #{@user}")
    else
      # if user doesn't exist, create that user
      @user = @client.users.create(:verified => true,
                                   :name => phone_number,
                                   :phone => phone_number,
                                   :external_id => phone_number)
    end
  end

  def with_comment(text)
    return false unless @user
    # check to see if there is already a ticket for that user
    ticket = @user.requested_tickets.detect do |ticket|
      ticket.status != 'closed'
    end

    if ticket
      @log.debug("Found ticket: #{ticket}")
      ticket.comment = {:value => text}
      ticket.save
    else
      # if there isn't a ticket for that user, create a new ticket
      rv = @client.tickets.create(:subject => text,
                                  :comment => { :value => text }, 
                                  :submitter_id => @user.id,  
                                  :requester_id => @user.id)
      @log.debug("Created ticket: #{rv}")
    end # if
  end # with_comment
end

class Configuration
  attr_reader :twilio_client, :twilio_from_number,
              :zendesk_client, :zendesk_update
  def initialize(env)
    @env = env
  end

  def check_inputs()
    required = ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 
                'TWILIO_FROM_NUMBER',
                'ZENDESK_URL', 'ZENDESK_USERNAME', 'ZENDESK_PASSWORD']
    missing = required.reject { |var| not @env[var].nil? }
    if missing.length > 0
      raise "Required environment variables not set: " + missing.join(', ')
    end
  end

  def setup_twilio_client()
    @twilio_client = Twilio::REST::Client.new @env['TWILIO_ACCOUNT_SID'],
                                              @env['TWILIO_AUTH_TOKEN']
  end

  def test_twilio_client()
    unless @twilio_client.account.status == 'active'
      raise "Error connecting to Twilio."
    end

    n = {:phone_number => @env['TWILIO_FROM_NUMBER']}
    number = @twilio_client.account.incoming_phone_numbers.list(n).first
    unless number and number.phone_number == @env['TWILIO_FROM_NUMBER']
      raise "Twilio number '#{@env['TWILIO_FROM_NUMBER']}' not in account."
    else
      $log.info("Twilio number '#{@env['TWILIO_FROM_NUMBER']}' " +
                "sends SMS data to '#{number.sms_url}' " +
                "via a '#{number.sms_method}' request")
    end
    @twilio_from_number = @env['TWILIO_FROM_NUMBER']
  end

  def setup_zendesk_client()
    @zendesk_client = ZendeskAPI::Client.new do |config|
      config.url = @env['ZENDESK_URL']
      config.username = @env['ZENDESK_USERNAME']
      config.password = @env['ZENDESK_PASSWORD']

      config.retry = true
      config.logger = $log
    end
  end

  def test_zendesk_client()
    unless zendesk_client.users.length > 0
      raise "Error connecting to Zendesk."
    end
    @zendesk_update = ZendeskUpdate.new(@zendesk_client)
  end

  def do()
    check_inputs()
    setup_twilio_client()
    test_twilio_client()
    setup_zendesk_client()
    test_zendesk_client()
  end
end

configure :development do
  $log.level = Logger::DEBUG
end

configure :test do
  $log.level = Logger::ERROR
end

configure :production, :development do
  $log.info('Running configuration')
  configuration = Configuration.new(ENV)
  configuration.do()
  set :twilio_client, configuration.twilio_client
  set :twilio_from_number, configuration.twilio_from_number
  set :zendesk_client, configuration.zendesk_client
  set :zendesk_update, configuration.zendesk_update
end

get '/' do
  "Hello."
end

post '/sms' do
  unless params['From'] and params['Body'] 
    halt 400, 'Missing "From" or "Body" in POST'
  end
  $log.debug("Incoming SMS POST data: #{params.inspect}")
  update = settings.zendesk_update
  update.for_user(params['From'])
  update.with_comment(params['Body'])
  "<Response></Response>"
end

# FIXME: Consider using the "Extra" field for passing along information, to allow for things like auto-responders and so on.
post '/outgoing' do
  $log.debug("Received for outgoing SMS: #{params.inspect}")
  expect = 'Test message from Zendesk sent on: '
  if params.has_key?('Extra') and params['Extra'].start_with?(expect)
    halt 200, 'Hello Zendesk'
  end
  to = params['To']
  body = params['Body']
  if params.has_key?('Extra')
    extra = JSON.parse(params['Extra'])
    if extra.has_key?('To')
      to = extra['To']
    end
    if extra.has_key?('Body')
      body = extra['Body']
    end
  end
  msg = {
    :from => settings.twilio_from_number,
    :to => to,
    :body => body
  }
  settings.twilio_client.account.sms.messages.create(msg)
end
