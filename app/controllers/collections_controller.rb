class CollectionsController < CatalogController
  include ApiAccessible
  self.copy_blacklight_config_from(CatalogController)

  def upsert
    if params[:thumbnail]
      params[:thumbnail] = create_temp_file(params[:thumbnail])
    end

    TapasRails::Application::Queue.push TapasObjectUpsertJob.new params
    @response[:message] = "Collection upsert accepted"
    pretty_json(202) and return
  end

  #This method displays all the collections present
  def index
    @page_title = "All Collections"
    self.search_params_logic += [:collections_filter]
    (@response, @document_list) = search_results(params, search_params_logic)
    render 'shared/index'
  end

  #This method is the helper method for index. It basically gets the collections
  # using solr queries
  def collections_filter(solr_parameters, user_parameters)
    model_type = RSolr.solr_escape "info:fedora/afmodel:Collection"
    query = "has_model_ssim:\"#{model_type}\""
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << query
  end

  #This method is used to display various attributes of a collection
  def show
    @collection = Collection.find(params[:id])
  end

  #This method is used to create a new collection
  def new
    @page_title = "Create New Collection"
    model_type = RSolr.solr_escape "info:fedora/afmodel:Community"
    count = ActiveFedora::SolrService.count("has_model_ssim:\"#{model_type}\"")
    results = ActiveFedora::SolrService.query("has_model_ssim:\"#{model_type}\"", fl: 'did_ssim, title_info_title_ssi', rows: count)

    @communities =[]
    results.each do |res|
      if !res['title_info_title_ssi'].blank? && !res['did_ssim'].blank? && res['did_ssim'].count > 0
        @communities << [res['title_info_title_ssi'],res['did_ssim'][0]]
      end
    end
    @collection = Collection.new
  end

  #This method contains the actual logic for creating a new collection
  def create
    # @collection = Collection.new
    community = Community.find("#{params[:collection][:community]}")
    params[:collection].delete("community")
    @collection = Collection.new(params[:collection])
    @collection.did = @collection.pid
    @collection.depositor = "000000000" #temporarily set until users implemented
    @collection.save! #object must be saved before community can be assigned
    @collection.community = community
    @collection.save!

    if params[:thumbnail]
      params[:thumbnail] = create_temp_file(params[:thumbnail])
      @collection.add_thumbnail(:filepath => params[:thumbnail])
    end
    # can this be used instead of individually spelling out the methods?
    # TapasRails::Application::Queue.push TapasObjectUpsertJob.new params

    redirect_to @collection and return
  end

  #This method is used to edit a particular collection
  def edit
    model_type = RSolr.solr_escape "info:fedora/afmodel:Community"
    count = ActiveFedora::SolrService.count("has_model_ssim:\"#{model_type}\"")
    results = ActiveFedora::SolrService.query("has_model_ssim:\"#{model_type}\"", fl: 'id, title_info_title_ssi', rows: count)
    @communities =[]
    results.each do |res|
      if !res['title_info_title_ssi'].blank? && !res['id'].blank?
        @communities << [res['title_info_title_ssi'],res['id']]
      end
    end
    @collection = Collection.find(params[:id])
    @page_title = "Edit #{@collection.title}"
  end

  #This method contains the actual logic for editing a particular collection
  def update
    community = Community.find("#{params[:collection][:community]}")
    params[:collection].delete("community")
    @collection = Collection.find(params[:id])
    # @core_files = CoreFile.find_by_did(params[:id])
    @collection.update_attributes(params[:collection])
    @collection.save!
    @collection.community = community
    @collection.save!

    if params[:thumbnail]
      params[:thumbnail] = create_temp_file(params[:thumbnail])
      @collection.add_thumbnail(:filepath => params[:thumbnail])
    end
    # can this be used instead of individually spelling out the methods?
    # TapasRails::Application::Queue.push TapasObjectUpsertJob.new params

    redirect_to @collection and return
  end
end
