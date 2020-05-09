module DrupalAccess
  extend ActiveSupport::Concern

  included do 
    class_attribute :drupal_access, datastream: "properties", multiple: false
  end
end
