class ProjectController < ApplicationController
  layout 'application', :except => :index
  layout 'simple', :only => [:new, :create]

  def index
    if params[:update]
      @projects = Project.fetch
    else
      @projects = Project.approved.sort_by(&:age)
    end
    
    # generate statistics
    @stats = {}
    @stats['num_projects'] = @projects.size
    @stats['none'] = @projects.reject{|p| p.blog || p.wiki || p.source_code}.size
    @stats['all_three'] = @projects.select{|p| p.blog && p.wiki && p.source_code}.size
    @stats['last_week'] = @projects.select{|p| p.age < 7}.size

    @legit_coumns = Project.columns.find_all{|c| c.type == :string}.map(&:name).map{|name| name.gsub('_', ' ').capitalize} - ['Password', 'Blog feed', 'Source code feed', 'Website']
  end

  def create
    @project = Project.new
    @project.name = params[:name]
    @project.contributors = params[:contributors]
    
    if not params[:github].empty?
      @project.blog = params[:blog_url]
      @project.blog_feed = FeedDetector.fetch_feed_url(@project.blog) rescue ""
      components = params[:github].split('/')
      @project.source_code = "http://github.com/#{params[:github]}/"
      @project.source_code_feed = "http://github.com/feeds/#{components[0]}/commits/#{components[1]}/master"
      @project.wiki = "http://wiki.github.com/#{params[:github]}/"
    elsif not params[:redmine_home].empty?
      home = params[:redmine_home]
      name = home.split('/').last
      base = home.match("(https?://[^/]*)/.*")[1]
      @project.website = home
      @project.blog = "#{base}/projects/#{name}/news"
      @project.blog_feed = "#{base}/projects/#{name}/news?format=atom"
      @project.source_code = "#{base}/repositories/show/#{name}"
      @project.source_code_feed = "#{base}/repositories/show/#{name}?format=atom"
      @project.wiki = "#{base}/wiki/#{name}"
    elsif not params[:googlecode].empty?
      name = params[:googlecode]
      @project.blog = params[:blog_url]
      @project.blog_feed = FeedDetector.fetch_feed_url(@project.blog) rescue ""
      @project.source_code = 
      @project.website = "http://code.google.com/p/#{name}/"
      @project.source_code = "http://code.google.com/p/#{name}/source/browse/"
      @project.source_code_feed = "http://code.google.com/feeds/p/#{name}/svnchanges/basic"
      @project.wiki = "http://code.google.com/p/#{name}/w/list"
    else # custom
      @project.blog = params[:blog_url]
      @project.blog_feed = FeedDetector.fetch_feed_url(@project.blog)
      @project.source_code = params[:custom_url]
      @project.source_code_feed = FeedDetector.fetch_feed_url(@project.source_code)
      @project.wiki = params[:custom_wiki]
    end
    
    @project.password = generate_password
    @project.approved = false
    @project.save!
  end

  def update
    if ENV['ADMIN_PASSWORD'] != params[:admin_password]
      flash[:notice] = "Access denied"
      redirect_to :back
      return
    end

    @project = Project.find(params[:id])
    @project ||= Project.new
    @project.update_attributes!(params[:project])

    case params[:hosting]
    when 'Redmine'
      @project.source_code = params['redmine'].sub('projects/show', 'repositories/show')
      @project.source_code_feed = @project.source_code.sub('repositories/show', 'repositories/revisions')+'?format=atom'
    when 'GitHub'
      member, project = params['github'].split('/')
      @project.source_code = "http://github.com/#{member}/#{project}"
      @project.source_code_feed = "http://github.com/feeds/#{member}/commits/#{project}/master"
    when 'Google Code'
      project_name = params['googlecode']
      @project.source_code = "http://code.google.com/p/#{project_name}/source/browse/"
      @project.source_code_feed = "http://code.google.com/feeds/p/#{project_name}/svnchanges/basic"
    else
      raise "Unrecognized hosting type"
    end
    @project.save!

    redirect_to :action => :index
  end

  def approve
  end

  def new
  end

  def edit
    @project = Project.find(params[:id])
  end
  
  private
  
  def generate_password(size = 3)
    c = %w(b c d f g h j k l m n p qu r s t v w x z ch cr fr nd ng nk nt ph pr rd sh sl sp st th tr lt)
    v = %w(a e i o u y)
    f, r = true, ''
    (size * 2).times do
      r << (f ? c[rand * c.size] : v[rand * v.size])
      f = !f
    end
    r
  end
end
