# test/seedr_test.rb
require File.join(File.dirname(__FILE__), '..', 'lib', 'seedr')
require 'test/unit'

class SeedrTest < Test::Unit::TestCase

  def test_new
    %w{rutube.ru youtube.com smotri.com yandex.ru}.each do |site|
      bot = Seedr::Bot.new(site)
      assert_instance_of Seedr::Bot, bot
    end
  end

#  def test_bot
#    bot = Seedr::Bot.new('rutube.ru') do |b|
#      b.login('test_user', 'test_password')
#    end
#    assert_instance_of Seedr::Bot, bot
#    assert_equal 'test_user', bot.username
#    assert_equal 'test_password', bot.password
#    assert bot.authorized?
#
#    bot.logout
#    assert ! bot.authorized?
#  end

end
