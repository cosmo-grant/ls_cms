ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'

require_relative '../cms'

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get '/'

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.txt"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_about
    get '/about.txt'

    expected_body = <<~EOM.chomp
      first line of about
      second line of about
      third line of about
    EOM

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal expected_body, last_response.body
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

  def test_view_markdown_doc
    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>This is a header</h1>"
  end

  def test_edit_page
    get '/changes.txt/edit'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Edit contents of changes.txt:"
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_updating_doc
    post '/changes.txt', content: "new content"

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, "changes.txt has been updated."

    get '/changes.txt'

    assert_equal 200, last_response.status
    assert_includes "new content", last_response.body
  end
end