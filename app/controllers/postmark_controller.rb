class PostmarkController < ApplicationController
  before_filter :require_postmark_ip

  def bounce_handler
    render :nothing => true, :status => 200
  end

  def require_postmark_ip
    unless request.env["REMOTE_ADDR"] == '1.2.3.4'
      render :nothing => true, :status => 401
    end
  end

end
