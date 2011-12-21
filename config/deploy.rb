set :application, "babybrain"
set :repository,  "git://github.com/mrlauer/webgl-sandbox.git"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

set :deploy_to, "/home/mrlauer/webapps/babybrain"

role :web, "web22.webfaction.com"                          # Your HTTP server, Apache/etc
role :app, "web22.webfaction.com"                          # This may be the same as your `Web` server
role :db,  "web22.webfaction.com", :primary => true # This is where Rails migrations will run
#role :db,  "web22.webfaction.com"

set :user, "mrlauer"
set :scm_username, "mrlauer"
set :use_sudo, false
default_run_options[:pty] = true

namespace :deploy do
  desc "Restart nginx"
  task :restart do
    run "#{deploy_to}/bin/restart"
  end
end

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end
