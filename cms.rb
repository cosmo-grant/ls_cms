require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(text)
  md = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  md.render(text)
end

def load_file_content(file_path)
  case File.extname(file_path)
  when ".md"
    render_markdown(File.read(file_path))
  else
    headers['Content-Type'] = 'text/plain'
    File.read(file_path)
  end
end

get '/' do
  pattern = File.join(data_path, '*')
  @filenames = Dir.glob(pattern)
  erb :index
end

get '/:filename' do
  file_path = File.join(data_path, params[:filename])
  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

get '/:filename/edit' do
  @filename = params[:filename]
  file_path = File.join(data_path, @filename)
  @file_contents = File.read(file_path)
  erb :edit
end

post '/:filename' do
  @filename = params[:filename]
  file_path = File.join(data_path, @filename)
  File.write(file_path, params[:updated_contents])
  session[:success] = "#{@filename} has been updated."
  redirect '/'
end