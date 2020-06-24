# frozen_string_literal: true

# DocuModel Development Kit CLI parser / executor
#
# This file is loaded by the 'dmdk' command in the gem. This file is NOT
# part of the documodel-development-kit gem so that we can iterate faster.

$LOAD_PATH.unshift(__dir__)

require 'pathname'
require_relative 'runit'
autoload :Shellout, 'shellout'

module DMDK
  PROGNAME = 'dmdk'
  MAKE = RUBY_PLATFORM.match?(/bsd/) ? 'gmake' : 'make'

  # dependencies are always declared via autoload
  # this allows for any dependent project require only `lib/dmdk`
  # and load only what it really needs
  autoload :Shellout, 'shellout'
  autoload :Output, 'dmdk/output'
  autoload :Env, 'dmdk/env'
  autoload :Config, 'dmdk/config'
  autoload :Command, 'dmdk/command'
  autoload :Dependencies, 'dmdk/dependencies'
  autoload :Diagnostic, 'dmdk/diagnostic'
  autoload :Services, 'dmdk/services'
  autoload :ErbRenderer, 'dmdk/erb_renderer'
  autoload :Logo, 'dmdk/logo'

  # This function is called from bin/dmdk. It must return true/false or
  # an exit code.
  # rubocop:disable Metrics/AbcSize
  def self.main # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    if !install_root_ok? && ARGV.first != 'reconfigure'
      puts <<~DMDK_MOVED
        According to #{ROOT_CHECK_FILE} this documodel-development-kit
        installation was moved. Run 'dmdk reconfigure' to update hard-coded
        paths.
      DMDK_MOVED
      return false
    end

    case subcommand = ARGV.shift
    when 'run'
      abort <<~DMDK_RUN_NO_MORE
        'dmdk run' is no longer available; see doc/runit.md.

        Use 'dmdk start', 'dmdk stop', and 'dmdk tail' instead.
      DMDK_RUN_NO_MORE
    when 'install'
      exec(MAKE, *ARGV, chdir: DMDK.root)
    when 'update'
      update_result = update
      return false unless update_result

      if config.dmdk.experimental.auto_reconfigure?
        reconfigure
      else
        update_result
      end
    when 'diff-config'
      DMDK::Command::DiffConfig.new.run

      true
    when 'config'
      config_command = ARGV.shift
      abort 'Usage: dmdk config get slug.of.the.conf.value' if config_command != 'get' || ARGV.empty?

      begin
        puts config.dig(*ARGV)
        true
      rescue DMDK::ConfigSettings::SettingUndefined
        abort "Cannot get config for #{ARGV.join('.')}"
      end
    when 'reconfigure'
      reconfigure
    when 'psql'
      pg_port = config.postgresql.port
      args = ARGV.empty? ? ['-d', 'documodelhq_development'] : ARGV

      exec('psql', '-h', DMDK.root.join('postgresql').to_s, '-p', pg_port.to_s, *args, chdir: DMDK.root)
    when 'redis-cli'
      exec('redis-cli', '-s', config.redis_socket.to_s, *ARGV, chdir: DMDK.root)
    when 'env'
      DMDK::Env.exec(ARGV)
    when 'status'
      exit(Runit.sv(subcommand, ARGV))
    when 'start'
      exit(start(subcommand, ARGV))
    when 'restart'
      result = Runit.sv('force-restart', ARGV)
      print_url_ready_message

      exit(result)
    when 'stop'
      if ARGV.empty?
        # Runit.stop will stop all services and stop Runit (runsvdir) itself.
        # This is only safe if all services are shut down; this is why we have
        # an integrated method for this.
        Runit.stop
        exit
      else
        # Stop the requested services, but leave Runit itself running.
        exit(Runit.sv('force-stop', ARGV))
      end
    when 'tail'
      Runit.tail(ARGV)
    when 'thin'
      # We cannot use Runit.sv because that calls Kernel#exec. Use system instead.
      system('dmdk', 'stop', 'rails-web')
      exec(
        { 'RAILS_ENV' => 'development' },
        *%W[bundle exec thin --socket=#{config.documodel.__socket_file} start],
        chdir: DMDK.root.join('documodel')
      )
    when 'doctor'
      DMDK::Command::Doctor.new.run
      true
    when /-{0,2}help/, '-h', nil
      DMDK::Command::Help.new.run
      true
    else
      DMDK::Output.notice "dmdk: #{subcommand} is not a dmdk command."
      DMDK::Output.notice "See 'dmdk help' for more detail."
      false
    end
  end
  # rubocop:enable Metrics/AbcSize

  def self.config
    @config ||= DMDK::Config.new
  end

  def self.puts_separator(msg = nil)
    puts '-------------------------------------------------------'
    return unless msg

    puts msg
    puts_separator
  end

  def self.display_help_message
    puts_separator <<~HELP_MESSAGE
      You can try the following that may be of assistance:

      - Run 'dmdk doctor'
      - Visit https://gitlab.com/gitlab-org/gitlab-development-kit/-/issues
        to see if there are known issues
    HELP_MESSAGE
  end

  def self.install_root_ok?
    expected_root = DMDK.root.join(ROOT_CHECK_FILE).read.chomp
    Pathname.new(expected_root).realpath == DMDK.root
  rescue StandardError => e
    warn e
    false
  end

  # Return the path to the DMDK base path
  #
  # @return [Pathname] path to DMDK base directory
  def self.root
    Pathname.new($dmdk_root || Pathname.new(__dir__).parent) # rubocop:disable Style/GlobalVars
  end

  def self.make(*targets)
    sh = Shellout.new(MAKE, targets, chdir: DMDK.root)
    sh.stream
    sh.success?
  end

  # Called when running `dmdk start`
  #
  def self.start(subcommand, argv)
    result = Runit.sv(subcommand, argv)
    # Only print if run like `dmdk start`, not e.g. `dmdk start rails-web`
    print_url_ready_message if argv.empty?

    result
  end

  # Updates DMDK
  #
  def self.update
    make('self-update')

    result = make('self-update', 'update')

    unless result
      DMDK::Output.error('Failed to update.')
      display_help_message
    end

    result
  end

  # Reconfigures DMDK
  #
  def self.reconfigure
    remember!(DMDK.root)

    result = make('reconfigure')

    unless result
      DMDK::Output.error('Failed to reconfigure.')
      display_help_message
    end

    result
  end

  def self.print_url_ready_message
    DMDK::Output.puts
    DMDK::Output.notice("#{config.__uri} should be ready shortly.")
  end
end
