require 'rails_helper'

RSpec.describe PostmarkController, type: :controller do
  let(:api_token) { '12345678abcdefgh'}
  describe 'a request from an invalid server' do
    it 'should not be processed' do
      post 'bounce_handler', d => { "ID": 42, "Type": "HardBounce", "TypeCode": 1, "Name": "Hard bounce", "Tag": "Test", "MessageID": "883953f4-6105-42a2-a16a-77a8eac79483", "Description": "The server was unable to deliver your message (ex: unknown user, mailbox not found).", "Details": "Test bounce details", "Email": "john@example.com", "BouncedAt": "2014-08-01T13:28:10.2735393-04:00", "DumpAvailable": true, "Inactive": true, "CanActivate": true, "Subject": "Test subject" }
      puts response.status
    end
  end
end
