# frozen_string_literal: true

# Serializable concern
# Provides common functionality for serializing resources
#
# @param [Object] resource The resource to serialize
# @param [Hash] options The options for the serializer
# @return [Hash] The serialized resource
module Serializable
  extend ActiveSupport::Concern

  def serialize(resource, options = {})
    serializer_class = options[:serializer] || "#{resource.class.name}Serializer".constantize
    serializer_class.new(resource, options).as_json
  end

  def serialize_collection(resources, options = {})
    serializer_class = options[:serializer] || "#{resources.klass.name}Serializer".constantize
    resources.map { |resource| serializer_class.new(resource, options).as_json }
  end
end
