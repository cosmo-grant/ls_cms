require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

root = File.expand_path('..', __FILE__) # absolute path of parent directory of this file

get '/' do
  @filenames = Dir.glob('*', base: root + '/data')
  erb :index
end

get '/:filename' do
  file_path = root + '/data/' + params[:filename]
  headers['Content-Type'] = 'text/plain'
  File.read(file_path)
end