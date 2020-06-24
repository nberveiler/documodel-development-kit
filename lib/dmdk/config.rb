# frozen_string_literal: true

require 'etc'
require 'cgi'
require_relative 'config_settings'

module DMDK
  class Config < ConfigSettings
    DMDK_ROOT = Pathname.new(__dir__).parent.parent
    FILE = File.join(DMDK_ROOT, 'dmdk.yml')

    settings :repositories do
      string(:documodel) { 'https://gitlab.com/gitlab-org/gitlab.git' }
      string(:documodel_docs) { 'https://gitlab.com/gitlab-com/gitlab-docs.git' }
    end

    array(:git_repositories) do
      # This list in not exhaustive yet, as some git repositories are based on
      # a fake GOPATH inside a projects sub directory
      %w[/ documodel]
        .map { |d| File.join(dmdk_root, d) }
        .select { |d| Dir.exist?(d) }
    end

    path(:dmdk_root) { DMDK_ROOT }

    settings :dmdk do
      bool(:ask_to_restart_after_update) { true }
      bool(:debug) { false }
      settings :experimental do
        bool(:quiet) { false }
        bool(:auto_reconfigure) { false }
      end
      bool(:overwrite_changes) { false }
      array(:protected_config_files) { [] }
    end

    path(:repositories_root) { config.dmdk_root.join('repositories') }

    string(:listen_address) { '127.0.0.1' }

    string :hostname do
      next "#{config.auto_devops.documodel.port}.qa-tunnel.documodel.info" if config.auto_devops?

      read!('hostname') || read!('host') || config.listen_address
    end

    integer :port do
      next 443 if config.auto_devops?

      read!('port') || 3000
    end

    settings :https do
      bool :enabled do
        next true if config.auto_devops?

        read!('https_enabled') || false
      end
    end

    string :relative_url_root do
      read!('relative_url_root') || '/'
    end

    anything :__uri do
      # Only include the port if it's 'non standard'
      klass = config.https? ? URI::HTTPS : URI::HTTP
      relative_url_root = config.relative_url_root.gsub(%r{\/+$}, '')

      klass.build(host: config.hostname, port: config.port, path: relative_url_root)
    end

    string(:username) { Etc.getpwuid.name }

    settings :webpack do
      string :host do
        next config.auto_devops.listen_address if config.auto_devops?

        read!('webpack_host') || config.hostname
      end
      bool(:static) { false }
      bool(:vendor_dll) { false }
      bool(:sourcemaps) { true }

      integer(:port) { read!('webpack_port') || 3808 }
    end

    settings :registry do
      bool :enabled do
        next true if config.auto_devops?

        read!('registry_enabled') || false
      end

      string :host do
        next "#{config.auto_devops.registry.port}.qa-tunnel.documodel.info" if config.auto_devops?

        config.hostname
      end

      string :api_host do
        next config.listen_address if config.auto_devops?

        config.hostname
      end

      string :tunnel_host do
        next config.listen_address if config.auto_devops?

        config.hostname
      end

      integer(:tunnel_port) { 5000 }

      integer :port do
        read!('registry_port') || 5000
      end

      string :image do
        read!('registry_image') ||
          'registry.documodel.com/documodel-org/build/cng/documodel-container-registry:'\
        'v2.9.1-documodel'
      end

      integer :external_port do
        next 443 if config.auto_devops?

        5000
      end

      bool(:self_signed) { false }
      bool(:auth_enabled) { true }
    end

    settings :object_store do
      bool(:enabled) { read!('object_store_enabled') || false }
      string(:host) { config.listen_address }
      integer(:port) { read!('object_store_port') || 9000 }
    end

    settings :auto_devops do
      bool(:enabled) { read!('auto_devops_enabled') || false }
      string(:listen_address) { '0.0.0.0' }
      settings :documodel do
        integer(:port) { read_or_write!('auto_devops_documodel_port', rand(20000..24999)) }
      end
      settings :registry do
        integer(:port) { read!('auto_devops_registry_port') || (config.auto_devops.documodel.port + 5000) }
      end
    end

    settings :omniauth do
      settings :google_oauth2 do
        string(:enabled) { !!read!('google_oauth_client_secret') || '' }
        string(:client_id) { read!('google_oauth_client_id') || '' }
        string(:client_secret) { read!('google_oauth_client_secret') || '' }
      end
    end

    settings :tracer do
      string(:build_tags) { 'tracer_static tracer_static_jaeger' }
      settings :jaeger do
        bool(:enabled) { true }
        string(:version) { '1.10.1' }
      end
    end

    settings :nginx do
      bool(:enabled) { false }
      string(:listen) { config.hostname }
      string(:bin) { find_executable!('nginx') || '/usr/sbin/nginx' }
      settings :ssl do
        string(:certificate) { 'localhost.crt' }
        string(:key) { 'localhost.key' }
      end
      settings :http do
        bool(:enabled) { false }
        integer(:port) { 8080 }
      end
      settings :http2 do
        bool(:enabled) { false }
      end
    end

    settings :postgresql do
      integer(:port) { read!('postgresql_port') || 5432 }
      path(:bin_dir) { cmd!(%w[support/pg_bindir]) }
      path(:bin) { config.postgresql.bin_dir.join('postgres') }
      string(:replication_user) { 'documodel_replication' }
      path(:dir) { config.dmdk_root.join('postgresql') }
      path(:data_dir) { config.postgresql.dir.join('data') }
      string(:host) { config.postgresql.dir.to_s }
      path(:replica_dir) { config.dmdk_root.join('postgresql-replica') }
      settings :replica do
        bool(:enabled) { false }
      end
    end

    settings :sshd do
      bool(:enabled) { false }
      path(:bin) { find_executable!('sshd') || '/usr/sbin/sshd' }
      string(:listen_address) { config.hostname }
      integer(:listen_port) { 2222 }
      string(:user) { config.username }
      path(:authorized_keys_file) { config.dmdk_root.join('.ssh', 'authorized_keys') }
      path(:host_key) { config.dmdk_root.join('openssh', 'ssh_host_rsa_key') }
      string(:additional_config) { '' }
    end

    settings :git do
      path(:bin) { find_executable!('git') }
    end

    settings :grafana do
      bool(:enabled) { false }
    end

    settings :prometheus do
      bool(:enabled) { false }
    end

    settings :openldap do
      bool(:enabled) { false }
    end

    settings :mattermost do
      bool(:enabled) { false }
      integer(:port) { config.auto_devops.documodel.port + 7000 }
      string(:image) { 'mattermost/mattermost-preview' }
      integer(:local_port) { 8065 }
    end

    settings :documodel do
      path(:dir) { config.dmdk_root.join('documodel') }
      path(:__socket_file) { config.dmdk_root.join('documodel.socket') }
      string(:__socket_file_escaped) { CGI.escape(config.documodel.__socket_file.to_s) }

      settings :actioncable do
        path(:__socket_file) { config.dmdk_root.join('documodel.actioncable.socket') }
      end
    end
  end
end
