ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def session
    last_request.env["rack.session"]
  end

  def create_document(name, content="")
    File.write(File.join(data_path, name), content)
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_viewing_txt_file
    content = <<~EOM.chomp
    first line of about
    second line of about
    third line of about
    EOM

    create_document "file.txt", content
    
    get '/file.txt' 

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal content, last_response.body
  end

  def test_viewing_md_file
    content = <<~EOM.chomp
    # This is a heading
    
    Here comes a list
      - first
      - second

    And a blockquote:

    > blah blah blah
    EOM

    create_document "file.md", content
    
    get '/file.md' 

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, render_markdown(content)
  end

  def test_no_such_doc
    get '/nosuchdoc.ext'

    assert_equal 302, last_response.status
    assert_equal "nosuchdoc.ext does not exist.", session[:error]
  end

  def test_edit_page
    content = "line in file"
    create_document "file.txt", content

    get '/file.txt/edit', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Edit contents of file.txt:"
    assert_includes last_response.body, content
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_edit_page_signed_out
    create_document "file.txt"

    get "/file.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_updating_doc
    create_document "file.txt", "original content"

    post '/file.txt', {content: "new content"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "file.txt has been updated.", session[:success]

    get '/file.txt'

    assert_equal 200, last_response.status
    assert_includes "new content", last_response.body
  end

  def test_updating_doc_signed_out
    create_document "file.txt", "original content"

    post '/file.txt', content: "new content"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_making_new_doc
    get '/new', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input type="text"'
    assert_includes last_response.body, '<input type="submit"'

    post '/create', filename: 'file.txt'

    assert_equal 302, last_response.status
    assert_equal 'file.txt has been created.', session[:success]

    get '/'

    assert_includes last_response.body, '<a href="/file.txt">file.txt</a>'
  end

  def test_visiting_new_doc_page_signed_out
    get '/new'

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_making_new_doc_signed_out
    post '/create', filename: 'file.txt'

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_new_doc_lacks_filename
    post '/create', {content: ''}, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_deleting_document
    create_document("test.txt")

    post "/test.txt/delete", {}, admin_session

    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted.", session[:success]

    get "/"
    
    refute_includes last_response.body, "test.txt</a>"
  end

  def test_deleting_document_signed_out
    create_document("test.txt")

    post "/test.txt/delete"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:success]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin."
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials."
  end

  def test_signout
    get "/", {}, {"rack.session" => { username: "admin" } }
    assert_includes last_response.body, "Signed in as admin."

    post "/users/signout"
    assert_equal "You have been signed out.", session[:success]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end
end