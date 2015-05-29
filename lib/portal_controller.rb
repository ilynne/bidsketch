require 'hpricot'
require 'css_parser'

class Client::PortalController < ApplicationController

  include ProposalViewerControllerMethods
  include ClientAuthenticatedSystem
  include ApplicationHelper

  before_filter :load_proposal, :only => [:export_to_pdf, :canvas]
  before_filter :log_pdf_export, :only => [:export_to_pdf]
  before_filter :create, :only => [:info]
  skip_before_filter :login_required, :only => [:new_session]
  skip_before_filter :login_required, :only => [:canvas], :if => :onboarding
  before_filter :load_fee_precision, :only => [:show, :canvas, :export_to_pdf ]

  def index
    new_session
  end

  def info
    if params[:preview]
      redirect_to '/client/portal/show/' + @proposal_id.to_s + '?preview=true'
    else
      redirect_to :action => 'show', :id => @proposal_id
    end
  end

  def show
    @proposal = current_account.proposals.find(params[:id], :include => { :proposal_comments => [:user, :client] }, :order => "proposal_comments.created_at DESC")
    if @proposal.status.name == 'Pending' || @proposal.status.name == 'Sent'
      @proposal.update_attributes( :status_id => Status.find_by_name('Viewed').id, :client_viewed_at => Time.now) 
    end

    begin
      
      km.record('Viewed Demo') if request.subdomains.first == AppConfig['demo_subdomain']
      if params[:preview].blank?
        user_time_zone = current_account.time_zone || "Eastern Time (US & Canada)"
        ClientEmailer.deliver_proposal_viewed(@proposal, Time.new.in_time_zone(user_time_zone) )
      end

    rescue Exception => e
      notify_honeybadger(e)
    end

    unless !current_user || @proposal.client.email == current_user.email
      redirect_to :action => 'new_session', :id => 'logout'
      return
    end
    # Skip Client tracking if it is a demo account
    unless demo_subdomain?
      @proposal_visit = record_visit(:proposal => @proposal)
    end

    @comment_count = @proposal.proposal_comments.count
    @has_optional_fees = false
    @proposal.proposalfees.each{ |f| @has_optional_fees = true if f.optional } unless @proposal.proposalfees.empty? || (@proposal.status && @proposal.status.name == 'Accepted')
    @electronic_signature = current_account.account_integrations.find(:first,
                                                                        :include => [:integration_type],
                                                                        :conditions => ["account_integrations.sync_complete = 1 and integration_types.sync_type=?", "Electronic Signature"])

    render :layout => 'client/show'
  end


  def canvas
    template_type = @proposal.designable.class.to_s
    if template_type == 'CustomDesignTemplate'
      s3 = S3Uploader.instance
      @template_path = s3.object.url_for("#{template_uri}/index.html", s3.bucket_name, :authenticated => false).to_s.gsub!("index.html", "")
    else
      @template_path = "#{protocol_with_host}#{template_uri}"
    end
    @template_properties = merged_template_properties
    template_builder = TemplateDesignBuilder.new(@proposal, @template_properties)
    @proposal_content = template_builder.build_template(@template_path)
    # Removing the edit link from the template
    @proposal_content.search(".proposal-edit-comment").remove()
    render :layout => false, :template => '/proposal_preview/canvas'
  end

  def optional_fees
    @proposal = current_user.proposals.find(params[:proposal_id], :include => :proposalfees)
    hide_ids = params[:proposalfees] ? params[:proposalfees][:client_hide] : []

    @proposal.proposalfees.select{|f| f.optional }.each do |fee|
      fee.update_attributes(:client_hide => !hide_ids.include?(fee.id.to_s) )
    end

    @proposal.reload()

  end

  def set_status


    params[:proposal_status] = 'Viewed' if params[:proposal_status] == 'Pending'

    @electronic_signature = current_account.account_integrations.find(:first, :include => [:integration_type], :conditions => ["account_integrations.sync_complete = 1 and integration_types.sync_type=?", "Electronic Signature"])

    respond_to do |format|
      format.js do
        load_proposal

        if @proposal.status_id == 3
          @accepted = true
          return
        end

        @proposal.status = Status.find_by_name(params[:proposal_status])
        @proposal_settings = @proposal.default_proposal_settings
        @proposal_settings.approval_message = process_description(@proposal_settings.approval_message, {:account => current_account, :proposal => @proposal} )
        @proposal.save
        record_status_change

        #debugging output
        approvals_logger.info("=============== Proposal status (#{params[:proposal_status]}) change for proposal ##{@proposal.id} and account: #{current_account.full_domain} ")

        if params[:proposal_status] == 'Accepted'
          begin
            ClientEmailer.deliver_approval_message_to_client(@proposal) if !@proposal_settings.approval_message.blank?
            ClientEmailer.deliver_proposal_accepted(@proposal)
          rescue Exception => e
            notify_honeybadger(e)
          end

          approvals_logger.info("Has esign integration: #{!@electronic_signature.blank?}")
          send_to_esign_provider(@electronic_signature) if !@electronic_signature.blank?
          approvals_logger.info("After calling esign")

        elsif params[:proposal_status] == 'Declined'
          ClientEmailer.deliver_proposal_declined(@proposal)
        else
          ClientEmailer.deliver_proposal_status_change(@proposal)
        end
      end
    end
  end

  def accept_proposal
    respond_to do |format|
      format.js do
        proposal = current_user.proposals.find(params[:id])
        proposal.status = 'won'
        begin
         proposal.proposal_data.update_attributes( :accepted_at => Time.now )
        rescue Exception => e
          notify_honeybadger(e)
        end
        proposal.save
        ClientEmailer.deliver_proposal_accepted(proposal)
        render :nothing => true
      end
    end
  end

  def destroy_comment

    proposal = current_account.proposals.find(params[:proposal_id], :include => :proposal_comments )
    comment = proposal.proposal_comments.find(params[:id])

    if current_user.id != comment.user_id
      render :nothing => true and return
    end

    comment.destroy
    @comment_id = params[:id]
    @comment_count = proposal.proposal_comments.count
    render :template => '/proposal_comments/destroy'
  end

  def record_visit(params = {:proposal => nil})
    proposal = params[:proposal]
    
    # First try to retrieve current visit.
    proposal_visit = current_user.current_visit( :proposal_id => proposal.id,
                                        :email => session[:email],
                                        :session_id => request.session_options[:id]
                                        )
                                      
    # if there is no current visit, create one.
    if proposal_visit.blank?
      begin
        proposal_visit = ProposalVisit.create( :client => proposal.client,
                              :proposal => proposal,
                              :http_agent => request.env['HTTP_USER_AGENT'],
                              :ip_address => request.remote_ip,
                              :session_id => request.session_options[:id],
                              :left_at => Time.now,
                              :email => session[:email] ||= current_user.email ) if proposal
      rescue Exception => e
        notify_honeybadger(e)
      end
    end

    return proposal_visit
  end

  def accept

    respond_to do |format|

      format.json do

        result = Hash.new

        @proposal = current_account.proposals.find(params[:email_proposal_id])

        @proposal_settings = @proposal.default_proposal_settings

        @electronic_signature = current_account.account_integrations.find(:first,
                                                                          :include => [:integration_type],
                                                                          :conditions => ["account_integrations.sync_complete = 1 and integration_types.sync_type=?", "Electronic Signature"])

        if !@electronic_signature.blank?

            send_to_esign_provider(@electronic_signature) if !@electronic_signature.blank?

            @proposal.set_accepted
            send_accepted_emails

            result[:status] = 1
            result[:message] = @proposal_settings.approval_message.blank? ? "You have accepted the proposal ! Please check your email to sign the document electronically" : process_description(@proposal_settings.approval_message, {:account => current_account, :proposal => @proposal} )

        elsif @proposal.require_client_signature
          signature = ClientSignature.new(
            {
              :proposal_id    => params[:email_proposal_id],
              :name           => params[:name],
              :email          => session[:email],
              :signature_json => params[:output],
              :ip_address     => request.remote_ip,
              :browser        => request.env['HTTP_USER_AGENT']
            }
          )

          if signature.save && @proposal.set_accepted

            send_accepted_emails

            @proposal.reload

            proposal_download_link = @proposal.proposal_document.s3_file

            result[:status] = 1
            result[:message] = @proposal_settings.approval_message.blank? ? "You have accepted the proposal !" : process_description(@proposal_settings.approval_message, {:account => current_account, :proposal => @proposal} )
            result[:proposal_link] = proposal_download_link

          else

            signature.destroy
            SupportEmailer.deliver_pdf_failure(current_user, pdf_failure_email_for_support)

            ClientEmailer.deliver_pdf_failure(current_user, @proposal)

            result[:status] = 0
            result[:message] = "We're sorry but there seems to be a problem accepting this proposal. We'll be working on solving this problem but in the meantime you want to get in touch with the person that sent this proposal. Thanks."

          end

        end

        render :json => result

      end


    end


  end

  protected

  def log_pdf_export
    begin
      current_visit = last_visit
      current_visit.update_attributes( :downloaded_at => Time.now ) if current_visit

      @proposal.update_attributes(:exported_to_pdf_at => Time.now)
    rescue Exception => e
      notify_honeybadger(e)
    end
  end

  def record_status_change
    begin
      current_visit = last_visit
      current_visit.update_attributes( :status_updated_at => Time.now ) if current_visit

    rescue Exception => e
      notify_honeybadger(e)
    end
  end

  def last_visit
    @proposal.proposal_visits.find(:last, :conditions => ['email = ? and session_id = ?',  session[:email],
                                   request.session_options[:id] ] )
  end

  def note_failed_signin
    flash[:error] = "Couldn't log you in as '#{params[:login]}'"
    logger.warn "Failed login for '#{params[:login]}' from #{request.remote_ip} at #{Time.now.utc}"
  end

  def load_objects
    proposal_view_key = params[:id]

    key = proposal_view_key.split('-')
    @proposal_link_id = key.first.to_i(36) - 100000000
    @client_id = key[1].to_i(36) - 1000000
    @account_id = key.last.to_i(36) - 100
  end

  def scoper
    if params[:k] && params[:k] == "abc123"
      current_account.proposals
    else
      current_user.proposals
    end
  end

  def load_proposal
    if params[:onboarding].blank?
      @proposal = scoper.find(params[:id], :include => [{:proposalsections => { :section => :sectiontype }}, :designable, :theme])
    else
      demo_account = Account.find_by_full_domain("#{AppConfig['demo_subdomain']}.bidsketch.com")
      @proposal = Proposal.find(params[:id], :conditions => {:account_id => demo_account.id}, :include => { :proposal_comments => [:user, :client] }, :order => "proposal_comments.created_at DESC")
    end
  end

  private

  def send_accepted_emails
    begin
      ClientEmailer.deliver_approval_message_to_client(@proposal) unless @proposal_settings.approval_message.blank?
    rescue Postmark::InvalidMessageError => pe 
      logger.info pe.inspect
      error_message = "We're sorry, we tried to send the approval message to #{@proposal.to_email}, but it looks like the email bounced because it's an invalid email address. If you believe the email is valid, please forward this email to support@bidsketch.com. Thanks!" 
      ClientEmailer.deliver_email_reply_error_notifier(@proposal.user.email, "The approval message has not been sent", error_message)
    end

    begin
      ClientEmailer.deliver_proposal_accepted(@proposal)
    rescue Postmark::InvalidMessageError => pe 
      logger.info pe.inspect
    end
  end

  def pdf_failure_email_for_support
   <<-EOC
      Account ID : #{current_account.id}
      Account Name : #{current_account.name}
      Proposal ID : #{@proposal.id}
      Proposal Name : #{@proposal.project_name}
   EOC
  end

  def onboarding
    !params[:onboarding].blank?
  end

end