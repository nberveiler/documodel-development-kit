CONFIGS = FileList['Procfile', 'nginx/conf/nginx.conf', 'documodel/config/documodel.yml']
CLOBBER.include(*CONFIGS, 'dmdk.example.yml')

def config
  @config ||= DMDK::Config.new
end

desc 'Dump the configured settings'
task 'dump_config' do
  DMDK::Config.new.dump!(STDOUT)
end

desc 'Generate an example config file with all the defaults'
file 'dmdk.example.yml' => 'clobber:dmdk.example.yml' do |t|
  File.open(t.name, File::CREAT | File::TRUNC | File::WRONLY) do |file|
    config = Class.new(DMDK::Config)
    config.define_method(:dmdk_root) { Pathname.new('/home/git/dmdk') }
    config.define_method(:username) { 'git' }
    config.define_method(:read!) { |_| nil }

    config.new(yaml: {}).dump!(file)
  end
end

desc 'Regenerate all config files from scratch'
task reconfigure: [:clobber, :all]

desc 'Generate all config files'
task all: CONFIGS

task 'clobber:dmdk.example.yml' do |t|
  Rake::Cleaner.cleanup_files([t.name])
end

file DMDK::Config::FILE do |t|
  FileUtils.touch(t.name)
end

desc 'Generate Procfile that defines the list of services to start'
file 'Procfile' => ['Procfile.erb', DMDK::Config::FILE] do |t|
  DMDK::ErbRenderer.new(t.source, t.name, config: config).render!
end

# Define as a task instead of a file, so it's built unconditionally
task 'dmdk-config.mk' => 'dmdk-config.mk.erb' do |t|
  DMDK::ErbRenderer.new(t.source, t.name, config: config).render!
  puts t.name # Print the filename, so make can include it
end

desc 'Generate nginx configuration'
file 'nginx/conf/nginx.conf' => ['nginx/conf/nginx.conf.erb', DMDK::Config::FILE] do |t|
  DMDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate sshd configuration'
file 'openssh/sshd_config' => ['openssh/sshd_config.erb', DMDK::Config::FILE] do |t|
  DMDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate redis configuration'
file 'redis/redis.conf' => ['support/templates/redis.conf.erb', DMDK::Config::FILE] do |t|
  DMDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the database.yml config file'
file 'documodel/config/database.yml' => ['support/templates/database.yml.erb', DMDK::Config::FILE] do |t|
  DMDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the cable.yml config file'
file 'documodel/config/cable.yml' => ['support/templates/cable.yml.erb', DMDK::Config::FILE] do |t|
  DMDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the resque.yml config file'
file 'documodel/config/resque.yml' => ['support/templates/resque.yml.erb', DMDK::Config::FILE] do |t|
  DMDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the documodel.yml config file'
file 'documodel/config/documodel.yml' => ['support/templates/documodel.yml.erb'] do |t|
  DMDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

file 'registry/config.yml' => ['support/templates/registry.config.yml.erb'] do |t|
  DMDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end
