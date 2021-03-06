# config valid only for Capistrano 3.1
lock '3.1.0'

set :application, 'fairnopoly'
set :repo_url, 'git://github.com/fairnopoly/fairnopoly.git'

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

set :deploy_to,   "/var/www/fairnopoly"

# Default value for :scm is :git
set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
set :log_level, :info

# Default value for :linked_files is []
set :linked_files, %w{config/database.yml config/newrelic.yml config/actionmailer.yml config/api.yml config/email_addresses.yml config/initializers/secret_token.rb}

# Default value for linked_dirs is []
set :linked_dirs, %w{log tmp/pids public/system}

set :keep_releases, 10

set :ssh_options, {
  forward_agent: true
}

# Sidekiq
set :sidekiq_role, :sidekiq
set :sidekiq_pid, ->{ "tmp/pids/sidekiq.pid" }

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
       within release_path do
         with rails_env: fetch(:rails_env) do
            execute :rake, 'memcached:flush'
         end
       end
    end
  end

  after :finishing, "deploy:cleanup"

end



namespace :rails do
  desc "Open the rails console on each of the remote servers"
  task :console do
    on roles(:console), :primary => true do |host|
      rails_env = fetch(:stage)
      within current_path do
        execute_interactively "bundle exec rails console #{rails_env}",host
      end
    end
  end

  desc "Open the rails dbconsole on each of the remote servers"
  task :dbconsole do
    on roles(:db), :primary => true do |host|
      rails_env = fetch(:stage)
      within current_path do
        execute_interactively "bundle exec rails dbconsole #{rails_env}",host
      end
    end
  end

  def execute_interactively(command,host)
    puts "ssh -l #{host.user} #{host} -p 22 -t 'cd #{deploy_to}/current && #{command}'"
    exec "ssh -l #{host.user} #{host} -p 22 -t 'cd #{deploy_to}/current && #{command}'"
  end
end
