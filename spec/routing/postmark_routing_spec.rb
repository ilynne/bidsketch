require "spec_helper"

describe PostmarkController do
  describe "routing" do

    it "routes to #bounce_handler" do
      post("/postmark/bounce_handler").should route_to("postmark/#bounce_handler")
    end

  end
end
