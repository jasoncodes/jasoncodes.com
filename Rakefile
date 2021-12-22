def jekyll(opts = "")
  sh "rm -rf _site"
  sh "mkdir -p _site"
  sh "bundle exec jekyll " + opts
  sh "cd _site && ln -s assets/favicon-*.ico favicon.ico"
  sh "cp -a _deploy.php _deploy.sh _site/"
end

task :default => :server

desc "Build site using Jekyll"
task :build do
  jekyll 'build'
end

desc "Serve on localhost with port 4000"
task :server do
  jekyll 'serve --watch'
end
