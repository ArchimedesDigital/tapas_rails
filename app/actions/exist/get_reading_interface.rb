module Exist
  class GetReadingInterface
    include Exist::Concerns::Helpers
    include TapasRails::ViewPackages
    attr_reader :xml_blob, :type

    def initialize(xml_blob, type)
      # TODO - test this
      array = available_view_packages
      if array.blank? # set defaults for now
        array = ["teibp", "tapas-generic"]
      else
        array.each do |r|
          r.sub!("_","-")
        end
      end
      valid_types = array
      # valid_types = ["teibp", "tapas-generic"]

      @xml_blob = xml_blob
      if type.in? valid_types
        @type = type
      else
        raise Exceptions::ExistError.new 'Invalid reading interface type '\
          "was #{type}, must be one of: #{valid_types}"
      end
    end

    def self.execute(xml_blob, type)
      self.new(xml_blob, type).execute
    end

    def build_resource
      url  = build_url "derive-reader/#{type}"
      options = options_hash.merge(:headers => {
        :content_type => 'application/xml',
        :accept => 'text/html'
      })

      self.resource = RestClient::Resource.new(url, options, :timeout => 300)
    end

    def execute
      build_resource
      params = {
        :file => xml_blob,
        :"assets-base" => Settings['base_url'] + "/reading_interface"
      }
      send_request { resource.post params }
    end
  end
end
