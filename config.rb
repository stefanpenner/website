require 'redcarpet'
require 'active_support/core_ext'


Dir['./lib/*'].each { |f| require f }

# Debugging
set(:logging, ENV['RACK_ENV'] != 'production')

set :markdown_engine, :redcarpet
set :markdown, :layout_engine => :erb,
         :fenced_code_blocks => true,
         :lax_html_blocks => true,
         :renderer => Highlighter::HighlightedHTML.new

activate :directory_indexes
activate :toc
activate :highlighter

activate :api_docs,
  default_class: 'Ember',
  repo_url: 'https://github.com/emberjs/ember.js'

###
# Blog
###

activate :blog do |blog|
  blog.prefix = 'blog'
  blog.layout = 'layouts/blog'
  blog.tag_template = 'blog/tag.html'
end

page '/blog/feed.xml', layout: false

###
# Pages
###

repo = Grit::Repo.new(
  File.join( File.dirname(__FILE__), ".git" )
)

def reach_into_guides(content, path=[], &block)
  if content.is_a? Grit::Tree
    content.contents.each do |sub_content|
      reach_into_guides(sub_content, path.dup << content.name, &block)
    end
  elsif content.is_a? Grit::Blob
    if content.name == "index.md" && path[1]
      yield "#{path * '/'}", content.data
    else
      yield "#{path * '/'}/#{content.name}".sub('.md', ''), content.data
    end
  end 
end

data.guide_versions.each do |name, sha|
  next if name == "Current"
  commit = repo.commits(sha).first
  guides_data = ::Middleman::Util.recursively_enhance(
    YAML.load (commit.tree / "data" / "guides.yml").data
  )
  tree = commit.tree / "source" / "guides"
  reach_into_guides(tree) do |path, data_at_sha|
    sha_path = path.dup.sub("guides/", "guides/#{sha}/")
    page sha_path, 
      :proxy => "guides/versioned.html",
      :layout => "guide"  do
        @guides = guides_data
        @template = data_at_sha
        @path = path + ".md"
        @sha = sha
    end
  end

  page "/guides/#{sha}", 
    :proxy => "guides/index.html",
    :layout => "guide" do
      @guides = guides_data
      @sha = sha
  end
end

page 'community.html'

page 'index.html', proxy: 'about.html'

page '404.html', directory_index: false

# Don't build layouts standalone
ignore '*_layout.erb'

# Don't build API layouts
ignore 'api/class.html.erb'
ignore 'api/module.html.erb'

###
# Helpers
###

helpers do
  # Workaround for content_for not working in nested layouts
  def partial_for(key, partial_name=nil)
    @partial_names ||= {}
    if partial_name
      @partial_names[key] = partial_name
    else
      @partial_names[key]
    end
  end

  def rendered_partial_for(key)
    partial_name = partial_for(key)
    partial(partial_name) if partial_name
  end

  def link_to_page name, url
    path = request.path
    current = path =~ Regexp.new('^' + url[1..-1] + '.*\.html')

    if path == 'index.html' and name == 'about'
      current = true
    end

    class_name = current ? ' class="active"' : ''

    "<li#{class_name}><a href=\"#{url}\">#{name}</a></li>"
  end

  def page_classes
    classes = super
    return 'not-found' if classes == '404'
    classes
  end
end
