require 'rails_helper'

RSpec.describe PostmarkController, type: :controller do
  describe 'a request from an invalid server' do
    it 'should return an unauthorized response' do
      @json_data = { "ID" => "42" }
      post 'bounce_handler', format: :json, :d => @json_data
      expect(response.status).to eq(401)
    end
  end

  describe 'a request from an authorized server' do
    it 'should accept the request' do
      @json_data = { "ID" => "42", "Type" => "HardBounce", "TypeCode" => 1, "Name" => "Hard bounce", "Tag" => "Test", "MessageID" => "883953f4-6105-42a2-a16a-77a8eac79483", "Description" => "The server was unable to deliver your message (ex => unknown user, mailbox not found).", "Details" => "Test bounce details", "Email" => "john@example.com", "BouncedAt" => "2014-08-01T13 =>28 =>10.2735393-04 =>00", "DumpAvailable" => "true", "Inactive" => "true", "CanActivate" => true, "Subject" => "Test subject" }
      request.env['REMOTE_ADDR'] = '1.2.3.4'      
      post 'bounce_handler', format: :json, d: @json_data
      expect(response.status).to eq(200)
      email = ActionMailer::Base.deliveries.last
      expect(email.Subject.to_s).to eq('Email Undeliverable')
    end
    it 'should notify admins of transient bounces' do
      @json_data = { "ID" => "42", "Type" => "Transient", "TypeCode" => 2, "Name" => "Hard bounce", "Tag" => "Test", "MessageID" => "883953f4-6105-42a2-a16a-77a8eac79483", "Description" => "The server could not temporarily deliver your message (ex: Message is delayed due to network troubles).", "Details" => "Test bounce details", "Email" => "john@example.com", "BouncedAt" => "2014-08-01T13 =>28 =>10.2735393-04 =>00", "DumpAvailable" => "true", "Inactive" => "true", "CanActivate" => true, "Subject" => "Test subject" }
      request.env['REMOTE_ADDR'] = '1.2.3.4'      
      post 'bounce_handler', format: :json, d: @json_data
      expect(response.status).to eq(200)
      email = ActionMailer::Base.deliveries.last
      expect(email.Subject.to_s).to eq('Transient')
    end
    it 'should notify admins of unknown bounces' do
      @json_data = { "ID" => "42", "Type" => "NotValid", "TypeCode" => 99, "Name" => "Wrong", "Tag" => "Test", "MessageID" => "883953f4-6105-42a2-a16a-77a8eac79483", "Description" => "Someone is probably trying to hack us.", "Details" => "Test bounce details", "Email" => "john@example.com", "BouncedAt" => "2014-08-01T13 =>28 =>10.2735393-04 =>00", "DumpAvailable" => "true", "Inactive" => "true", "CanActivate" => true, "Subject" => "Test subject" }
      request.env['REMOTE_ADDR'] = '1.2.3.4'      
      post 'bounce_handler', format: :json, d: @json_data
      expect(response.status).to eq(200)
      email = ActionMailer::Base.deliveries.last
      expect(email.Subject.to_s).to eq('Unknown Bounce')
    end
  end
end
