ENV['RACK_ENV'] = 'test'
require 'web'
require 'rspec'
require 'twilio-ruby'

vars = ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_FROM_NUMBER',
        'ZENDESK_URL', 'ZENDESK_USERNAME', 'ZENDESK_PASSWORD']

describe 'Sinatra configuration tests' do
  it "detects when an environment variable is missing" do
    vars.each do |skip|
      test = {}
      vars.each do |key|
        test[key] = ''
      end
      test.delete(skip)

      msg = "Required environment variables not set: #{skip}"
      configuration = Configuration.new(test)
      expect { configuration.check_inputs() }.to raise_error(RuntimeError, msg)
    end # vars.each do |skip|
  end # it

  it "checks for an active Twilio account" do
    twilio_client = mock(Twilio::REST::Client)
    twilio_client.stub(:account).and_return(true)
    twilio_client.account.stub(:status).and_return('suspended')

    configuration = Configuration.new({})
    configuration.instance_variable_set(:@twilio_client, twilio_client)

    msg = "Error connecting to Twilio."
    expect { configuration.test_twilio_client() }.to raise_error(RuntimeError, msg)
  end

  it "checks for that number is attached to the Twilio account" do
    phone_number = '+14155551213'
    number = mock(Twilio::REST::ListResource)
    number.stub(:phone_number).and_return(phone_number)
    number.stub(:sms_url).and_return('mock_url')
    number.stub(:sms_method).and_return('mock_method')

    twilio_client = mock(Twilio::REST::Client)
    twilio_client.stub(:account).and_return(true)
    twilio_client.account.stub(:status).and_return('active')
    twilio_client.account.stub(:incoming_phone_numbers).and_return(true)
    twilio_client.account.incoming_phone_numbers.stub(:list).and_return([number])

    configuration = Configuration.new({})
    configuration.instance_variable_set(:@twilio_client, twilio_client)

    msg = "Twilio number '' not in account."
    expect { configuration.test_twilio_client() }.to raise_error(RuntimeError, msg)

    configuration = Configuration.new({'TWILIO_FROM_NUMBER' => phone_number})
    configuration.instance_variable_set(:@twilio_client, twilio_client)
    configuration.test_twilio_client()
    configuration.twilio_from_number.should == phone_number
  end

  it "checks that the Twilio client complains of bad input" do
    env = {'TWILIO_ACCOUNT_SID' => 'fake',
           'TWILIO_AUTH_TOKEN' => 'fake'}
    configuration = Configuration.new(env)
    configuration.setup_twilio_client()
    expect { configuration.test_twilio_client() }.to raise_error(Twilio::REST::RequestError)
  end

  it "checks for users in Zendesk" do
    zendesk_client = mock(ZendeskAPI::Client)
    zendesk_client.stub(:users).and_return(true)
    zendesk_client.users.stub(:length).and_return(0)

    configuration = Configuration.new({})
    configuration.instance_variable_set(:@zendesk_client, zendesk_client)
    msg = "Error connecting to Zendesk."
    expect { configuration.test_zendesk_client() }.to raise_error(RuntimeError, msg)
  end

  it "sets zendesk_update if users are found in Zendesk" do
    zendesk_client = mock(ZendeskAPI::Client)
    zendesk_client.stub(:users).and_return(true)
    zendesk_client.users.stub(:length).and_return(1)

    configuration = Configuration.new({})
    configuration.instance_variable_set(:@zendesk_client, zendesk_client)
    configuration.test_zendesk_client()
    configuration.zendesk_update.should be_a(ZendeskUpdate)
  end

  it "checks that the Zendesk client complains of bad input" do
    env = {'ZENDESK_URL' => 'fake',
           'ZENDESK_USERNAME' => 'fake',
           'ZENDESK_PASSWORD' => 'fake'}
    configuration = Configuration.new(env)
    expect { configuration.setup_zendesk_client() }.to raise_error(ArgumentError)

    env = {'ZENDESK_URL' => 'https://test.zendesk.com/api/v2',
           'ZENDESK_USERNAME' => 'fake',
           'ZENDESK_PASSWORD' => 'fake'}
    configuration = Configuration.new(env)
    configuration.setup_zendesk_client()
    msg = "Error connecting to Zendesk."
    expect { configuration.test_zendesk_client() }.to raise_error(RuntimeError, msg)
  end
end
