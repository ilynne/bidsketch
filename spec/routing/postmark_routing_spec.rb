require "spec_helper"

describe PostmarkController do
  describe "routing" do

    it "routes to #bounce_handler" do
      expect(post("/postmark/bounce_handler")).to route_to("postmark#bounce_handler")
    end

  end
end
