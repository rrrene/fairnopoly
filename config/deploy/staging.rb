#
# Farinopoly - Fairnopoly is an open-source online marketplace.
# Copyright (C) 2013 Fairnopoly eG
#
# This file is part of Farinopoly.
#
# Farinopoly is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# Farinopoly is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Farinopoly.  If not, see <http://www.gnu.org/licenses/>.
#

require 'debugger'

role :app, "78.109.61.137", :primary => true
role :web, "78.109.61.137", :primary => true
role :db, "78.109.61.137", :primary => true

set :rails_env, "staging"
set :branch, "release"


namespace :solr do
  desc "start solr"
  task :start, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec sunspot-solr start --data-directory=#{shared_path}/solr/data --pid-dir=#{shared_path}/pids"
  end
  desc "stop solr"
  task :stop, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec sunspot-solr stop --data-directory=#{shared_path}/solr/data --pid-dir=#{shared_path}/pids"
  end
  desc "restart solr"
  task :restart, :roles => :app, :except => { :no_release => true } do
    stop
    start
  end
  desc "reindex the whole database"
  task :reindex, :roles => :app do
    stop
    run "rm -rf #{shared_path}/solr/data"
    start
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec rake sunspot:solr:reindex"
  end
end

namespace :content do
  desc "Import content"
  task :import do
    upload "#{ARGV[2]}", "#{shared_path}/content_import.csv"
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec rake content:import #{shared_path}/upload/content_import.csv"
  end
end

#Sunspot Hooks
after "deploy:stop",    "solr:stop"
after "deploy:start",   "solr:start"
after "deploy:restart", "solr:restart"
