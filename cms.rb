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
    erb render_markdown(File.read(file_path))
  else
    headers['Content-Type'] = 'text/plain'
    File.read(file_path)
  end
end

get '/' do
  @filenames = Dir.glob('*', base: data_path)
  erb :index
end

get '/new' do
  erb :new
end

post '/create' do
  filename = params[:filename].to_s
  # to_s is required because if no filename is given \
  # params[:filename] is nil, not an empty string
  if filename.empty?
    status 422
    session[:error] = "A name is required."
    erb :new # Won't this display under the "/create" url?
  else
    file_path = File.join(data_path, filename)
    File.write(file_path, "")
    session[:success] = "#{filename} has been created."
    redirect '/'
  end
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