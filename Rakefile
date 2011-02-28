def jekyll(opts = "")
  sh "pygmentize -V > /dev/null" do |ok, res|
    ok or fail "Pygments not found: Install it with `sudo apt-get install python-pygments` or `sudo easy_install 'Pygments>=1.3'`."
  end
  sh "rm -rf _site"
  sh "mkdir -p _site"
  sh "bundle exec jekyll " + opts
  sh "ln -s images/favicon.ico _site/"
  sh "cp -a _deploy.{php,sh} _site/"
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
