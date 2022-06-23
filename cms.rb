require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

root = File.expand_path('..', __FILE__) # absolute path of parent directory of this file

configure do
  enable :sessions
  set :session_secret, 'secret'
end

get '/' do
  @filenames = Dir.glob('*', base: root + '/data')
  erb :index
end

get '/:filename' do
  @filename = params[:filename]
  file_path = root + '/data/' + @filename
  begin
    headers['Content-Type'] = 'text/plain'
    File.read(file_path)
  rescue Errno::ENOENT
    session[:error] = "#{@filename} does not exist."
    redirect '/'
  end
end