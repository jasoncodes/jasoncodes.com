def jekyll(opts = "")
  sh "pygmentize -V > /dev/null"
  sh "rm -rf _site"
  sh "mkdir -p _site"
  sh "ln -s images/favicon.ico _site/"
  sh "jekyll " + opts
end

task :default => :server

desc "Build site using Jekyll"
task :build do
  jekyll
end

desc "Serve on localhost with port 4000"
task :server do
  jekyll("--server --auto")
end
