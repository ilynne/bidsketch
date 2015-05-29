class Notification < ActionMailer::Base

  def notify_bounce(to, subject, message)
    mail(:to => to, :from => 'test@example.com', :subject => subject) do |format|
      format.text {render :text => message}
    end
  end

end
