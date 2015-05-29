class PostmarkController < ApplicationController
  before_filter :require_postmark_ip

  def bounce_handler
    if request.params && request.params[:d].present?
      case request.params[:d][:Type]
      when 'HardBounce'
        puts 'hard'
        handle_hard_bounce
      when 'Transient'
        handle_transient_bounce
      else
        handle_unknown_bounce
      end
    end
    render :nothing => true, :status => 200
  end

  private

  def handle_hard_bounce 
    if request.params[:d][:Description].include?('unknown user')
      # here we would notify the User to confirm the email address
      Notification.notify_bounce('test@example.com', 'Email Undeliverable', 'Check the email address for proposal [n], it was undeliverable.').deliver
    end
  end

  def handle_transient_bounce # this message should go to a system admin
    # code to attempt to reactivate bounce using Postmark API here
    Notification.notify_bounce('test@example.com', 'Transient', 'This email bounce has been reactivated.').deliver
  end

  def handle_unknown_bounce # this message should go to a system admin
    Notification.notify_bounce('test@example.com', 'Unknown Bounce', 'Check the email address for proposal [n], it was undeliverable.').deliver
  end

  def require_postmark_ip
    unless request.env["REMOTE_ADDR"] == '1.2.3.4'
      render :nothing => true, :status => 401
    end
  end

end
