require_relative 'worker'
require_relative 'metadata_helper'

class UploadWorker < Worker

  include MetadataHelper

  def initialize(options)
    @solr_queue_name = options[:solr_queue]
    @sesame_queue_name = options[:sesame_queue]
    @postgres_queue_name = options[:postgres_queue]
    super(options[:rabbitmq])
  end

  def connect
    super
    @solr_queue = add_queue(@solr_queue_name)
    @postgres_queue = add_queue(@postgres_queue_name)
    @sesame_queue = add_queue(@sesame_queue_name)
  end

  def process_message(headers, message)
    if headers['action'] == 'create'
      message['items'].each { |item|
        create_item(item)
      }
    end
  end

  def create_item(item)
    item['generated'] = generate_fields(item)
    message = item.to_json
    headers = {action: 'create'}
    properties = {routing_key: @postgres_queue.name, headers: headers}
    @exchange.publish(message, properties)
    properties = {routing_key: @solr_queue.name, headers: headers}
    @exchange.publish(message, properties)
    properties = {routing_key: @sesame_queue.name, headers: headers}
    @exchange.publish(message, properties)
  end

  def generate_fields(item)
    generated = {}
    generated['date_group'] = get_date_group(item)
    generated['types'] = get_types(item)
    collection = get_collection(item)
    generated['owner'] = collection[:owner]
    generated['collection_id'] = collection[:id]
    generated['handle'] = get_handle(item)
    generated
  end

end