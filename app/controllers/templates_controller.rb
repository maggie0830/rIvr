class TemplatesController < ApplicationController
  #  doorkeeper_for :create
  skip_before_filter :verify_authenticity_token, :only => [:create]
  layout 'branch'

  def index
    @branch_name = params[:branch]
    @branch = Branch.find_me(@branch_name)
    set_variables
    @temp_partial = @branch.forum_type
    # params[:result] came from main.js branchManage.updateForumType
    if params[:result] && ['vote','poll'].include?(@branch.forum_type)
      @temp_partial = @temp_partial + "_result"
    end
    if @branch.forum_type != 'report'
      @moderated = SortedEntry.get(@branch.id, @branch.active_forum_session.id)
    else
      @moderated = []
    end
    @results = @moderated + @branch.entries.incomings
    unless @results.kind_of?(Array)
      @results = @results.page(p)
    else
      @results = Kaminari.paginate_array(@results).page(p)
    end
  end

  # For upload voice prompt voice forum
  # voice forum type must be one of report | bulletin | vote
  # prompt name must be one of introduction | goodbye | question
  # query format:
  # /templates/new?branch=tripoli&type=report&name=introduction
  def new
    flash[:notice] = nil
    @branch = Branch.find_me(params[:branch])
    # template created if not found
    @template = @branch.forum_type.camelcase.constantize.find_or_create(:branch_id=>@branch.id, 
       :name=>params[:name], :voting_session_id=>@branch.current_forum_session.id)
    #    if params[:name] == 'introduction'
    #      Template.delete_all("is_active=0")
    #    end

    #    @template.save :validate=>false
    set_variables
    #    if !!@template && !!@template.dropbox_file
    #      flash[:notice] = "#{params[:name].titleize} file " +
    #      File.basename(@template.dropbox_file) +
    #      " has been uploaded"
    #    end
    @preview = false
    session[:template_id] = @template.id
    render :layout=>false
  end

  def create
    branch=Branch.find_by_id params[:branch_id]
    temp = params[branch.forum_type.to_sym] # || params[:report] || params[:bulletin] || params[:vote]
    @template = Template.find_by_id temp.delete(:id)
    @template.description = temp[:description]
    sound_file = temp.delete(:sound)
    # identifier = temp.delete(:identifier)
    # if identifier
    #  vs = VotingSession.find_me identifier,branch
    #  @template.voting_session_id = branch.current_forum_session.id
    #  @template.save
    # end
   
    @preview = false
    if params[:todo] == 'preview'
      # Preview the sound
      if !sound_file
        @preview = true if !!@template.dropbox_file
      else
        @template.upload_to_dropbox(sound_file, branch.current_forum_session.name)
        @template.save :validate=>false
        @preview = true

        flash[:notice] = "#{@template.name_map(@template.name)} file " +
        File.basename(@template.dropbox_file) +
        " was uploaded"
      end
      
    # this is not called. replaced by VotingSession#activate_templates
    # save button pressed
    elsif params[:todo] == 'save'
      @template.is_active=true
      if @template.valid?
        @template.save
        @template.branch.generate_forum_feed_xml
        flash[:notice] = "#{@template.name_map(@template.name)} file " +
        File.basename(@template.dropbox_file) +
        " has been saved"
      else
        @save = true
        flash[:error] = @template.class.name + " : " + @template.errors.full_messages.first
      end
    end
    render :action=>'new', :layout => false
  end

  # save recording after user clicked Send Data
  def record
    branch_id = params[:branch_id]
    @branch = Branch.find_me(branch_id)
    if request.post?
      # arr = params[:record].split("ZZZ")
      filename = Time.now.strftime("%Y%m%d%H%M%S")+'.wav'
      data = request.raw_post
    # # TEST save recorded sound to file
    #    File.open(filename, 'wb') do |file|
    #      file.write(request.raw_post)
    #    end
    # id = arr[1]
      vs = @branch.current_forum_session
      id = session[:template_id]
      @template = Template.find_by_id id
      @template.voting_session_id = vs.id
      @template.save_recording_to_dropbox(data, filename)
      @template.save :validate=>false
      flash[:notice] = "#{@template.name_map(@template.name)} file " +
      File.basename(@template.dropbox_file) +
          " was saved to Dropbox"
      render :action=>'new', :layout => false
    else
      @template = Template.find_by_id params[:id]
      render :layout=>false, :partial=>'recorder'
      
    end
  end

  # UI for selecting feed source from upload or static rss
  def headline
    if request.post?
      if params[:todo] == 'save'
        # params[:configure][:branch_id] == 'oddi'
        opt = params[:branch]
        @branch = Branch.find_by_id opt[:id]
        [:feed_source, :feed_limit, :feed_url].each do | feed |
           val  = opt[feed]
           @branch.send(feed.to_s + "=", val)
           # @option = Configure.find_me(branch, feed.to_s)
           # @option.update_attribute :value, val
        end 
        # branch.generate_forum_feed_xml
        @option = @branch
        flash[:notice] = "FEED updated"
      end
      render :layout => false
    else
      @branch = Branch.find_me(params[:branch])
      @template = @branch.reports.headline
      session[:template_id] = @template.id
      # @template = Template.find_me @branch.id, params[:name]
      @option = @branch # Configure.find_me(@branch, "feed_source")
      render :layout => false
    end
  end

  def forum_feed
    branch = Branch.find_me(params[:b] || params[:branch])
    if branch
      if params[:p].to_i == 0
         branch.test_forum_feed_xml
      else
         branch.forum_feed_xml
      end
      tmp_file = "#{DROPBOX.tmp_dir}/#{branch.friendly_name}/forum_feed.xml"
      content = File.open(tmp_file, "r") {|file| file.read}
      send_data content,
      :filename=>"forum_feed.xml",
      :type=>"text",
      :disposition=>'inline'

    end
  end

  def schedule
     startdate = DateTime.parse params[:start_date]
     enddate =  DateTime.parse params[:end_date]

     branch_id= params[:branch_id]
     branch = Branch.find branch_id
     txt = '<span class="error">Schedule failed for unknown reason</span>'
     if branch
       is_active = branch.current_forum_session.is_active
       now = Time.now
       if (startdate < now) && (enddate < now)
          is_active=true
       else
          is_active=false
       end
       
       begin
          branch.current_forum_session.update_attributes :start_date=>startdate,
             :end_date=>enddate, :is_active=>is_active
          txt = '<span class="notice">Schedule successful</span>'
       rescue
          txt = '<span class="error">Schedule failed</span>'
       end
     end
     if is_active
        branch.generate_forum_feed_xml
     end
     render :inline=>txt.html_safe, :layout=>false, :content_type=>'application/html'
  end
  
  def forum_type(branch)
    branch.forum_type_ui
  end
  helper_method :forum_type

  protected

  def set_variables
    @goodbye=nil
    @headline = nil
    @question = nil
    @listen=nil
    @record=nil
    @comment = nil
    if @branch.forum_type == 'report'
      @headline="Headline News"
      @goodbye="Goodbye"
    elsif @branch.forum_type == 'bulletin'
      @question="Ask the community"
      @listen="Listen Messages"
      @record="Leave Message"
    elsif @branch.forum_type == 'vote'
      if params[:result].to_i == 1
        @question="Results"
        @listen="Opinion Board"
      else
        @question="Participate"
        @comment = 'Leave Comment'
      end
    end
  end

end