ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

class CmsTest < Minitest::Test
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

  def create_document(name, content="")
    File.write(File.join(data_path, name), content)
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

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, "nosuchdoc.ext does not exist."

    get '/'

    refute_includes last_response.body, "nosuchdoc.ext does not exist."
  end

  def test_edit_page
    content = "line in file"
    create_document "file.txt", content

    get '/file.txt/edit'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Edit contents of file.txt:"
    assert_includes last_response.body, content
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_updating_doc
    original_content = "original content"
    new_content = "new content"
    create_document "file.txt", original_content

    post '/file.txt', content: new_content

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, "file.txt has been updated."

    get '/file.txt'

    assert_equal 200, last_response.status
    assert_includes new_content, last_response.body
  end
end