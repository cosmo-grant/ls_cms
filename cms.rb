require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'psych'

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

def valid_credentials?(username, password)
  if ENV["RACK_ENV"] == "test"
    credentials_path = File.expand_path("../test/users.yml", __FILE__)
  else
    credentials_path = File.expand_path("../users.yml", __FILE__)
  end
  users = Psych.load_file(credentials_path)
  users[username] == password
end

def signed_in?
  session[:username]
end

def redirect_if_not_signed_in
  if !signed_in?
    session[:error] = "You must be signed in to do that."
    redirect '/'
  end
end

get '/' do
  @filenames = Dir.glob('*', base: data_path)
  erb :index
end

get '/users/signin' do
  erb :signin
end

post '/users/signin' do
  @username = params[:username].to_s
  password = params[:password].to_s
  if valid_credentials?(@username, password)
    session[:username] = @username
    session[:success] = "Welcome!"
    redirect '/'
  else
    status 422
    session[:error] = "Invalid credentials."
    erb :signin
  end
end

post '/users/signout' do
  session[:success] = "You have been signed out."
  session.delete(:username)
  redirect '/'
end

get '/new' do
  redirect_if_not_signed_in
  erb :new
end

post '/create' do
  redirect_if_not_signed_in
  filename = params[:filename].to_s
  # to_s is required because if no filename is given \
  # params[:filename] is nil, not an empty string
  if filename.empty?
    status 422
    session[:error] = "A name is required."
    erb :new # This displays under the "/create" url. Problem?
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
  redirect_if_not_signed_in
  @filename = params[:filename]
  file_path = File.join(data_path, @filename)
  @file_contents = File.read(file_path)
  erb :edit
end

post '/:filename' do
  redirect_if_not_signed_in
  @filename = params[:filename]
  file_path = File.join(data_path, @filename)
  File.write(file_path, params[:updated_contents])
  session[:success] = "#{@filename} has been updated."
  redirect '/'
end

post '/:filename/delete' do
  redirect_if_not_signed_in
  filename = params[:filename]
  file_path = File.join(data_path, filename)
  File.delete(file_path)
  session[:success] = "#{filename} has been deleted."
  redirect '/'
end