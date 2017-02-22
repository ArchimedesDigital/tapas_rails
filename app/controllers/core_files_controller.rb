class CoreFilesController < CatalogController
  include ApiAccessible
  include ModsDisplay::ControllerExtension

  configure_mods_display do
    identifier { ignore! }
  end

  skip_before_filter :load_asset, :load_datastream, :authorize_download!

  #This method displays all the core files created in the database
  def index
    @page_title = "All CoreFiles"
    self.search_params_logic += [:communities_filter]
    (@response, @document_list) = search_results(params, search_params_logic)
    render 'shared/index'
  end

  #This method is the helper method for index. It basically gets the core files
  # using solr queries
  def communities_filter(solr_parameters, user_parameters)
    model_type = RSolr.solr_escape "info:fedora/afmodel:CoreFile"
    query = "has_model_ssim:\"#{model_type}\""
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  #This method is used to create a new core file
  def new
    @page_title = "Create New Core File"
    model_type = RSolr.solr_escape "info:fedora/afmodel:Collection"
    count = ActiveFedora::SolrService.count("has_model_ssim:\"#{model_type}\"")
    results = ActiveFedora::SolrService.query("has_model_ssim:\"#{model_type}\"", fl: 'did_ssim, title_info_title_ssi', rows: count)

    @arr =[]
    results.each do |res|
      if !res['title_info_title_ssi'].blank? && !res['did_ssim'].blank? && res['did_ssim'].count > 0
        @arr << [res['title_info_title_ssi'],res['did_ssim'][0]]
      end
    end
    @core_file = CoreFile.new
  end

  #This method contains the actual logic for creating a new core file
  def create
    begin
      params[:collection_dids] = params[:core_file][:collection]
      params[:depositor] = "000000000" #temp setting this until users integrated

      # Step 1: Find or create the CoreFile Object -
      # we do this here so that we have a stub record to
      # attach error messages & status tracking to.
      core_file = CoreFile.create(did: params[:did],
                                    depositor: params[:depositor])
      core_file.mark_upload_in_progress!

      # Step 1: Extract uploaded files to temporary locations if they exist
      if params[:tei]
        params[:tei] = create_temp_file params[:tei]
      end

      if params[:support_files]
        params[:support_files] = create_temp_file params[:support_files]
      end

      # Step 2: If TEI was provided, generate a MODS record that can be sent back
      # to Drupal to populate the validate metadata page provided after initial
      # file upload
      if params[:tei]
        opts = {
          :authors => params[:authors],
          :contributors => params[:contributors],
          :"timeline-date" => params[:display_date],
          :title => params[:title]
        }

        @mods = Exist::GetMods.execute(params[:tei], opts)
      end

      # Step 3: Kick off an upsert job
      job = TapasObjectUpsertJob.new params
      # TapasRails::Application::Queue.push job
      job.run

      # Step 4: Respond with MODS if it is available, otherwise send a generic
      # success message
      # if @mods
      #   render :xml => @mods, :status => 202
      # else
      #   @response[:message] = "Job processing"
      #   pretty_json(202) and return
      # end
      # @core_file = CoreFile.find_by_did(pid)
      flash[:notice] = "Your file is being created. Check back soon."
      redirect_to "/core_files"
    rescue => e
      core_file.set_default_display_error
      core_file.set_stacktrace_message(e)
      core_file.mark_upload_failed!
      raise e
    end
  end

  #This method is used to edit a particular core file
  def edit
    model_type = RSolr.solr_escape "info:fedora/afmodel:Collection"
    count = ActiveFedora::SolrService.count("has_model_ssim:\"#{model_type}\"")
    results = ActiveFedora::SolrService.query("has_model_ssim:\"#{model_type}\"", fl: 'did_ssim, title_info_title_ssi', rows: count)

    @arr =[]
    results.each do |res|
      # @arr << [res['title_info_title_ssi'],res['did_ssim'][0]]
      if !res['title_info_title_ssi'].blank? && !res['did_ssim'].blank? && res['did_ssim'].count > 0
        @arr << [res['title_info_title_ssi'],res['did_ssim'][0]]
      end
    end
    @core_file = CoreFile.find(params[:id])

    @page_title = "Edit #{@core_file.title}"
  end

  #This method contains the actual logic for editing a particular core file
  def update
    cf = CoreFile.find(params[:id])
    params[:did] = cf.did
    logger.warn("we are about to edit #{params[:did]}")
    create
  end

  def view_package_html
    @core_file = CoreFile.find_by_did(params[:did])
    if @core_file.blank?
      render :text => "Resource not found", :status => 404
    else
      @core_file.create_view_package_methods
      view_package = ViewPackage.where(:machine_name => "#{params[:view_package]}").to_a.first
      if !view_package.blank?
        e = "Could not find a #{view_package.human_name} representation of this object."\
          "Please retry in a few minutes."
        html = @core_file.send("#{view_package.machine_name}".to_sym)
        render_content_asset html, e
      else
        render :text => "The view package #{params[:view_package]} could not be found", :status => 422
      end
    end
  end

  def mods
    @html = render_mods_display(@core_file).to_html
    render :text => @html
  end

  def tei
    e = "Could not find TEI associated with this file.  Please retry in a "\
      "few minutes and contact an administrator if the problem persists."
    render_content_asset @core_file.canonical_object, e
  end

  def rebuild_reading_interfaces
    RebuildReadingInterfaceJob.perform(params[:did])
    @response[:message] = "Record updated successfully"
    pretty_json(200) and return
  end

  def show #inherited from catalog controller
    @core_file = CoreFile.find(params[:id])
    @mods_html = render_mods_display(@core_file).to_html.html_safe
    e = "Could not find TEI associated with this file.  Please retry in a "\
      "few minutes and contact an administrator if the problem persists."
  end

  def api_show
    @core_file = CoreFile.find_by_did(params[:did])

    if @core_file.upload_status.blank?
      @core_file.retroactively_set_status!
    end

    if @core_file.stuck_in_progress?
      @core_file.set_default_display_error
      @core_file.errors_system = ['Object was processing for more than five minutes']
      @core_file.mark_upload_failed!
    end

    @response = @core_file.as_json
    pretty_json(200) and return
  end

  def upsert
    begin
      # Step 1: Find or create the CoreFile Object -
      # we do this here so that we have a stub record to
      # attach error messages & status tracking to.
      if CoreFile.exists_by_did?(params[:did])
        core_file = CoreFile.find_by_did(params[:did])
        core_file.mark_upload_in_progress!
      else
        core_file = CoreFile.create(did: params[:did],
                                    depositor: params[:depositor])
        core_file.mark_upload_in_progress!
      end

      # Step 2: Extract uploaded files to temporary locations if they exist
      if params[:tei]
        params[:tei] = create_temp_file params[:tei]
      end

      if params[:support_files]
        params[:support_files] = create_temp_file params[:support_files]
      end

      # Step 3: If TEI was provided, generate a MODS record that can be sent back
      # to Drupal to populate the validate metadata page provided after initial
      # file upload
      if params[:tei]
        opts = {
          :authors => params[:display_authors],
          :contributors => params[:display_contributors],
          :"timeline-date" => params[:display_date],
          :title => params[:title]
        }

        @mods = Exist::GetMods.execute(params[:tei], opts)
      end

      # Step 4: Kick off an upsert job
      job = TapasObjectUpsertJob.new params
      TapasRails::Application::Queue.push job

      # Step 5: Respond with MODS if it is available, otherwise send a generic
      # success message
      if @mods
        render :xml => @mods, :status => 202
      else
        @response[:message] = "Job processing"
        pretty_json(202) and return
      end
    rescue => e
      core_file.set_default_display_error
      core_file.set_stacktrace_message(e)
      core_file.mark_upload_failed!
      logger.error e
      raise e
    end
  end

  private

  def render_content_asset(asset, error_msg)
    if asset && asset.content.content.present?
      render :text => asset.content.content
    else
      render :text => error_msg, :status => 404
    end
  end
end
