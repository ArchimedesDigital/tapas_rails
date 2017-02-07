class ViewPackage < ActiveRecord::Base
  include TapasRails::ViewPackages
  attr_accessible :human_name, :machine_name, :description, :file_type, :css_files, :js_files, :parameters, :run_process if Rails::VERSION::MAJOR < 4

  serialize :file_type, Array
  serialize :css_files, Array
  serialize :js_files, Array
  serialize :parameters, Hash
  serialize :run_process, Hash


  # TODO make a job which communicates with github to dynamically add these
  # TODO need to figure out where the assets will be stored for each of these and how to retrieve them in the interface when necessary

  after_destroy :clear_cache
  after_save :clear_cache

  def clear_cache
    arr_before = available_view_packages
    Rails.cache.delete("view_packages")
    arr_after = available_view_packages
    arr_before.reject!{|x| arr_after.include? x}
    CoreFile.remove_view_package_methods(arr_before)
  end
end
