require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

root = File.expand_path('..', __FILE__) # absolute path of parent directory of this file

configure do
  enable :sessions
  set :session_secret, 'secret'
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
  @filenames = Dir.glob('*', base: root + '/data')
  erb :index
end

get '/:filename' do
  @filename = params[:filename]
  file_path = root + '/data/' + @filename
  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{@filename} does not exist."
    redirect '/'
  end
end

get '/:filename/edit' do
  @filename = params[:filename]
  file_path = root + '/data/' + @filename
  @file_contents = File.read(file_path)
  erb :edit
end

post '/:filename' do
  @filename = params[:filename]
  @updated_contents = params[:updated_contents]
  file_path = root + '/data/' + @filename
  File.write(file_path, @updated_contents)
  session[:success] = "#{@filename} has been updated."
  redirect '/'
end