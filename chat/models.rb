ActiveRecord::Base.establish_connection

class User < ActiveRecord::Base
  has_secure_password
  validates :name, 
    presence: true,
    length: {in: 3..1000}
  validates :mail,
    presence: true,
    format: {with:/\A.+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+\z/}
  validates :password, 
    format: {with:/(?=.*?[a-zA-Z0-9-])(?=.*?[0-9])/},
    length: {in: 5..1000}
  belongs_to :profile
  has_many :chats
end 

class Profile < ActiveRecord::Base
  belongs_to :user
end 

class Request < ActiveRecord::Base 
  validates :get_id, 
    presence: true
  validates :sent_id, 
    presence: true
end 

class Friend < ActiveRecord::Base 
end

class Waiting < ActiveRecord::Base 
  after_create :back

  private
  def back
    puts "create"
  end
end

class Match < ActiveRecord::Base 
end

class Chat < ActiveRecord::Base
  belongs_to :user
  has_many :chat_ids
end 

class Chat_id < ActiveRecord::Base
  belongs_to :chat
end 