ENV['RACK_ENV'] = 'test'
require 'web'  # <-- your sinatra app
require 'rspec'
require 'rack/test'


describe 'web.rb' do
  include Rack::Test::Methods

  before(:each) do
    @ticket_1 = mock(ZendeskAPI::Ticket)
    @ticket_1.stub(:id).and_return('ticket_1')

    @ticket_2 = mock(ZendeskAPI::Ticket)
    @ticket_2.stub(:id).and_return('ticket_2')

    @ticket_3 = mock(ZendeskAPI::Ticket)
    @ticket_3.stub(:id).and_return('ticket_3')

    @zendesk_user = mock(ZendeskAPI::User)
    @zendesk_user.stub(:id).and_return('mock_user')

    @zendesk_client = mock(ZendeskAPI::Client)
    @zendesk_client.stub(:users).and_return(true)
    @zendesk_client.stub(:tickets).and_return(true)

    @twilio_client = mock(Twilio::REST::Client)
    @twilio_client.stub(:mocked).and_return('mock')
    @twilio_client.stub(:account).and_return(true)
    @twilio_client.account.stub(:sms).and_return(true)
    @twilio_client.account.sms.stub(:messages).and_return(true)
  end

  def app
    Sinatra::Application
  end

  it "says hello" do
    get '/'
    last_response.should be_ok
    last_response.body.should == 'Hello.'
  end

  it "works with a mock" do
    @twilio_client.mocked.should == 'mock'
  end

  it "can send an SMS" do
    want = {
      :from => "+14155551212",
      :to => "ToNumber",
      :body => "MessageBody"}
    @twilio_client.account.sms.messages.should_receive(:create).with(want)
    app.settings.stub(:twilio_client).and_return(@twilio_client)
    app.settings.stub(:twilio_from_number).and_return('+14155551212')

    post '/outgoing', {'To' => 'ToNumber', 'Body' => 'MessageBody'}
  end
  # properly handles an empty body
  # properly handles no phone number
  # properly handles a bad phone number

  # gives an error if ZendeskUpdate not called with client
  it "searches for a user" do
    phone_number = '+14155551212'
    @zendesk_client.users.stub(:search).and_return([@zendesk_user])
    @zendesk_client.users.should_receive(:search).with({:external_id => phone_number})
    update = ZendeskUpdate.new @zendesk_client
    update.for_user(phone_number)
  end

  it "creates a user if one doesn't exist" do
    phone_number = '+14155551212'
    @zendesk_client.users.stub(:search).and_return([])
    want_created = {
      :verified => true,
      :name => phone_number,
      :phone => phone_number,
      :external_id => phone_number}
    @zendesk_client.users.should_receive(:create).with(want_created)
    update = ZendeskUpdate.new @zendesk_client
    update.for_user(phone_number)
  end

  it "will fail if with_comment called before for_user" do
    update = ZendeskUpdate.new @zendesk_client
    rv = update.with_comment('test')
    rv.should == false
  end

  it "finds and updates a ticket if one exists" do
    @ticket_1.stub(:status).and_return('closed')
    @ticket_2.stub(:status).and_return('closed')
    @ticket_3.stub(:status).and_return('open')
    @ticket_3.should_receive(:comment=).with({:value => 'test comment'})
    @ticket_3.should_receive(:save)

    @zendesk_user.stub(:requested_tickets).and_return([@ticket_1, @ticket_2, @ticket_3])
    @zendesk_client.users.stub(:search).and_return([@zendesk_user])
    update = ZendeskUpdate.new @zendesk_client
    update.for_user('+14155551212')
    update.with_comment('test comment')
  end

  it "creates a new ticket if no open tickets found" do
    expected_text = 'test comment'
    expected_user = 'mock_user'
    want_ticket = {
      :subject => expected_text,
      :comment => {:value => expected_text},
      :requester_id => expected_user,
      :submitter_id => expected_user}
    @ticket_1.stub(:status).and_return('closed')
    @ticket_2.stub(:status).and_return('closed')
    @ticket_3.stub(:status).and_return('closed')

    @zendesk_user.stub(:requested_tickets).and_return([@ticket_1, @ticket_2, @ticket_3])
    @zendesk_client.users.stub(:search).and_return([@zendesk_user])
    @zendesk_client.tickets.should_receive(:create).with(want_ticket)
    update = ZendeskUpdate.new @zendesk_client
    update.for_user('+14155551212')
    update.with_comment('test comment')
  end

  it "creates a new ticket if no tickets found" do
    phone_number = '+14155551212'
    expected_text = 'test comment'
    expected_user = 'mock_user'
    want_ticket = {
      :subject => expected_text,
      :comment => {:value => expected_text},
      :requester_id => expected_user,
      :submitter_id => expected_user
    }

    @zendesk_user.stub(:requested_tickets).and_return([])
    @zendesk_client.users.stub(:search).and_return([@zendesk_user])
    @zendesk_client.tickets.should_receive(:create).with(want_ticket)
    update = ZendeskUpdate.new @zendesk_client
    update.for_user(phone_number)
    update.with_comment('test comment')
  end

  it "handles no 'From' or 'Body' POSTed to /sms" do
    post '/sms', {}
    last_response.status == 400
  end

  it "creates a ZendeskUpdate" do
    update = mock(ZendeskUpdate)
    update.should_receive(:for_user).with('MockFrom')
    update.should_receive(:with_comment).with('MockBody')
    app.settings.stub(:zendesk_update).and_return(update)
    post '/sms', {'From' => 'MockFrom', 'Body' => 'MockBody'}
    last_response.should be_ok
    last_response.body.should == '<Response></Response>'
  end

end
