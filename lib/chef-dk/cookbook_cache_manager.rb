#
# Copyright:: Copyright (c) 2014 Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'json'
require 'fileutils'
require 'chef-dk/cookbook_omnifetch'
require 'chef-dk/exceptions'
require 'chef-dk/shell_out'
# TODO: chef bug. Chef::HTTP::Simple needs to require this itself.
require 'chef/http/cookie_manager'
require 'chef/http/validate_content_length'
require 'chef/http/simple'

# TODO: fix hardcoding
Chef::Config.ssl_verify_mode = :verify_peer

module ChefDK

  class CookbookCacheManager

    attr_reader :policyfile
    attr_reader :relative_root
    attr_reader :cache_path

    def initialize(policyfile, config={})
      @policyfile = policyfile
      @relative_root = config[:relative_root] || Dir.pwd
      @cache_path = config[:cache_path]
      @local_cookbooks_metadata = {}
      @http_connections = {}
    end

    def ensure_cache_dir_exists
      unless File.exist?(CookbookOmnifetch.storage_path)
        FileUtils.mkdir_p(CookbookOmnifetch.storage_path)
      end
    end

    def universe_graph
      @universe_graph ||= case default_source
      when Policyfile::CommunityCookbookSource
        community_universe_graph
      when nil
        {}
      else
        raise UnsupportedFeature, 'ChefDK does not support alternative cookbook default sources at this time'
      end
    end

    private

    def http_connection_for(base_url)
      @http_connections[base_url] ||= Chef::HTTP::Simple.new(base_url)
    end

    def community_universe_graph
      full_graph = fetch_community_universe
      full_graph.inject({}) do |normalized_graph, (cookbook_name, metadata_by_version)|
        normalized_graph[cookbook_name] = metadata_by_version.inject({}) do |deps_by_version, (version, metadata)|
          deps_by_version[version] = metadata["dependencies"]
          deps_by_version
        end
        normalized_graph
      end
    end

    def fetch_community_universe
      graph_json = http_connection_for(default_source.uri).get("/universe")
      JSON.parse(graph_json)
    end

    def default_source
      policyfile.default_source
    end

  end
end