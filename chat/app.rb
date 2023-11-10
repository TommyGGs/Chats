require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require 'sinatra/streaming'
require './models'
require 'faye/websocket'
require 'date'
require 'openai'
require 'faker'
require 'rufus-scheduler'
require 'et-orbi'

scheduler = Rufus::Scheduler.new

set :sockets, []

enable :sessions

set :views, File.dirname(__FILE__) + '/views'

helpers do 
  def current_user 
    User.find_by(id: session[:user])
  end 
end 

before do
  Dotenv.load
  Cloudinary.config do |config| 
      config.cloud_name = ENV['CLOUD_NAME']
      config.api_key   = ENV['CLOUDINARY_API_KEY']
      config.api_secret = ENV['CLOUDINARY_API_SECRET']
  end 
  Request.all.each do |request|
    if request.get_id == request.sent_id 
      request.delete
    end 
    if request.get_id == nil
      request.delete
    end 
    if request.sent_id == nil
      request.delete
    end 
  end 
  if Match.find_by(user_id: session[:user])
      matchh = Match.find_by(user_id: session[:user]).matched_id
      @matched = User.find(matchh)
  end 
  if Waiting.count > 1 
    ma = Waiting.first
    mama = ma.user_id
    pa = Waiting.second
    papa = pa.user_id
    Match.create(
      user_id: papa,
      matched_id: mama)
    Match.create(
      user_id: mama,
      matched_id: papa)
    ma.delete 
    pa.delete
  end 
  Waiting.all.each do |waiting|
    wa = waiting.user_id 
    if Match.find_by(user_id: wa)
      Waiting.find_by(user_id: wa).delete
    end 
  end 
  
  Match.all.each do |match|
    mo = match.created_at
    ti = Time.now
    if (ti - mo).to_i > 660
      if match.user_id.to_i < match.matched_id.to_i 
        if Chat_id.find_by(user_id: match.user_id, user_id2: match.matched_id)
          chat = Chat_id.find_by(user_id: match.user_id, user_id2: match.matched_id)
          Chat.where(chat_id: chat.id).delete_all
          chat.delete
        end 
      elsif match.user_id.to_i > match.matched_id.to_i
        if Chat_id.find_by(user_id: match.matched_id, user_id2: match.user_id)
          chat = Chat_id.find_by(user_id: match.matched_id, user_id2: match.user_id) 
          Chat.where(chat_id: chat.id).delete_all
          chat.delete
        end 
      end 
      match.delete
    end 
  end 
end 

get '/websocket' do
  if Faye::WebSocket.websocket?(request.env)
    ws = Faye::WebSocket.new(request.env)

    ws.on :open do |event|
      settings.sockets << ws
    end

    ws.on :message do |event|
      settings.sockets.each do |socket|
        socket.send(event.data)
      end
    end

    ws.on :close do |event|
      ws = nil
      settings.sockets.delete(ws)
    end

    ws.rack_response
  end
end

get '/' do 
  if session[:user]
    if Match.find_by(user_id: session[:user])
      matchh = Match.find_by(user_id: session[:user]).matched_id
      @matched = User.find(matchh)
    end 
  end 
  erb :index
end

get '/signin' do 
  erb :sign_in
end 

get '/signup' do
  erb :sign_up
end 

post '/signin' do 
  params = JSON.parse(request.body.read)
  content_type :json
  
  user = User.find_by(mail: params['mail'])
  if user && user.authenticate(params['password'])
    session[:user] = user.id
    msg = 'redirect'
  else 
    msg = 'Password or Email inncorrect'
  end 
  
  {msg: msg}.to_json
end 

post '/signup' do 
  params = JSON.parse(request.body.read)
  content_type :json
  
  if User.where(name: params['name']).exists?
    msg = 'Username Taken'
  elsif User.where(mail: params['mail']).exists?
    msg = 'Mail taken'
  else 
  user = User.create(
    name: params['name'], 
    mail: params['mail'], 
    password: params['password'], 
    password_confirmation: params['password_confirmation'])
      
    if user.valid?
      session[:user] = user.id
      msg = 'create_profile'
    else 
      msg = user.errors.full_messages
    end 
  end 
  

  {msg: msg}.to_json
end


get '/signout' do 
  session[:user] = nil 
  redirect '/'
end 

get '/create_profile' do 
  erb :create_profile 
end 

post '/create_profile' do 
  params = JSON.parse(request.body.read)
  content_type :json
  
  user_id = session[:user]
  user_name = current_user.name
  icon_url = ''
  
  
  if params['icon']
    imageBlob = params['icon']
    upload = Cloudinary::Uploader.upload(imageBlob)
    icon_url = upload['url']
  end

  Profile.create(
    user_name: current_user.name, 
    user_id: user_id, 
    paragraph: params['paragraph'], 
    icon: icon_url,
    pronounce: params['pronounce'])
 
    msg = 'redirect'
    {msg: msg}.to_json
end 

get '/edit_profile' do 
  @profile = Profile.find_by(user_id: session[:user])
  erb :edit_profile
end 

post '/edit_profile' do 
  params = JSON.parse(request.body.read)
  content_type :json
  
  profile = Profile.find_by(user_id: session[:user])
  profile.update(
    pronounce: params['pronounce'],
    paragraph: params['paragraph'],
    icon: params['icon']
  )
  msg = "profile updated"
  {msg: msg}.to_json
end 

get '/profile/:id' do 
  @profile = Profile.find_by(user_id: params[:id])
  unless params[:id] == session[:user]
    if Match.find_by(user_id: session[:user], matched_id: params[:id])
      if session[:user].to_i < params[:id].to_i
        Match.find_by(user_id: session[:user], matched_id: params[:id])
        time = Match.find_by(user_id: session[:user], matched_id: params[:id]).created_at
        @timer = time.to_i + 660
      elsif session[:user].to_i > params[:id].to_i
        if Match.find_by(user_id: params[:id] , matched_id: session[:user])
          time = Match.find_by(user_id: params[:id], matched_id: session[:user]).created_at
          @timer = time.to_i + 660
        end 
      end 
    end 
  end 
  erb :profile
end 

get '/friends' do 
  @requests = Request.where(get_id: session[:user])
  @friends = Friend.where(get_friend_id: session[:user])
  erb :friends
end 

post '/send_request' do 
  params = JSON.parse(request.body.read)
  content_type :json
  
  if User.find_by(name: params['get_friend_name'])
    friend = User.find_by(name: params['get_friend_name'])
    if Request.find_by(get_id: friend.id, sent_id: session[:user])
      msg = 'request already sent'
    elsif friend.id == session[:user]
      msg ='you cannot add yourself'
    else 
      Request.create(
        get_id: friend.id, 
        sent_id: session[:user]
        )
      msg = 'success' 
    end 
  else  
      msg ='user does not exist'
  end 
  
  {msg: msg}.to_json
end 

post '/request' do 
  params = JSON.parse(request.body.read)
  content_type :json
  get_friend = Request.find(params['request_id']).get_id
  sent_friend = Request.find(params['request_id']).sent_id
  if Match.find_by(user_id: get_friend, matched_id: sent_friend)
    msg = "try again later"
  else 
    if params['answer'] == 'accept'
      Friend.create(
        get_friend_id: get_friend,
        sent_friend_id: sent_friend 
        )
      Friend.create(
        get_friend_id: sent_friend,
        sent_friend_id: get_friend 
        )
      if Request.find_by(get_id: get_friend, sent_id: sent_friend)
        Request.find_by(get_id: get_friend, sent_id: sent_friend).delete
      end 
      if Request.find_by(get_id: sent_friend, sent_id: get_friend)
        Request.find_by(get_id: sent_friend, sent_id: get_friend).delete
      end 
      if get_friend.to_i < sent_friend.to_i
        Chat_id.create(
          user_id: get_friend,
          user_id2: sent_friend
        )
      elsif get_friend.to_i > sent_friend.to_i
        Chat_id.create(
          user_id: sent_friend,
          user_id2: get_friend
          )
      end 
      friends = User.find(sent_friend).name
      msg = "You have became friends with #{friends}"
    elsif params['answer'] == 'decline'
      Request.find(params['request_id']).delete 
      if Request.find_by(get_id: get_friend, sent_id: sent_friend)
        Request.find_by(get_id: get_friend, sent_id: sent_friend).delete
      end 
      if Request.find_by(get_id: sent_friend, sent_id: get_friend)
        Request.find_by(get_id: sent_friend, sent_id: get_friend).delete
      end 
      msg = 'request declined'
    end 
  end 
  {msg: msg}.to_json
end 

post '/queue' do
  content_type :json
    userid = session[:user]
  unless Waiting.find_by(user_id: session[:user])
    Waiting.create(
      user_id: userid)
      # msg = 'success'
  else 
    # msg = 'user already queued'
  end 
  
  if Waiting.find_by(user_id: session[:user])
    if Waiting.count == 1 
      unless Waiting.first.user_id == session[:user]
          Match.create(
            user_id: session[:user],
            matched_id: Waiting.first.user_id
            )
          Match.create(
            user_id: Waiting.first.user_id,
            matched_id: session[:user]
            )
          friendid = Waiting.first.user_id
          session_user_id = session[:user].to_i
          friendid_id = friendid.to_i
          
          if session_user_id < friendid_id
            Chat_id.create(
              user_id: session[:user],
              user_id2: friendid_id
              )
          elsif session_user_id > friendid_id
            Chat_id.create(
              user_id: friendid_id,
              user_id2: session[:user]
              )
          end
          Waiting.find_by(user_id: Waiting.first.user_id).delete
          Waiting.find_by(user_id: session[:user]).delete
      end 
    elsif Waiting.count == 2 
      if Waiting.second.user_id == session[:user]
        friendid = Waiting.first.user_id
        Match.create(
          user_id: session[:user],
          matched_id: friendid
          )
        Match.create(
          user_id: friendid,
          matched_id: session[:user]
          )
        session_user_id = session[:user].to_i
        friendid_id = friendid.to_i
        if session_user_id < friendid_id
          Chat_id.create(
            user_id: session[:user],
            user_id2: friendid_id
            )
        elsif session_user_id > friendid_id
          Chat_id.create(
            user_id: friendid_id,
            user_id2: session[:user]
            )
        end
        Waiting.find_by(user_id: friendid).delete
        Waiting.find_by(user_id: session[:user]).delete
        msg = "send"
        {msg: msg}.to_json
      end 
    end 
  end 
end

get '/chat/:id' do
  question_templates = [
    "What is your favorite color?",
    "If you could have dinner with any historical figure, who would it be?",
    "What is your dream travel destination?",
    # Add more questions as needed
  ]
  @chat = Chat.where(chat_id: params[:id])
  chat_id = Chat_id.find(params[:id])
  if Match.find_by(user_id: chat_id.user_id , matched_id: chat_id.user_id2)
    if Chat_id.find(params[:id]).user_id == session[:user]  
      @user = session[:user]
      @get_user = Chat_id.find(params[:id]).user_id2
    elsif Chat_id.find(params[:id]).user_id2 == session[:user]
      @user = session[:user]
      @get_user = Chat_id.find(params[:id]).user_id
    end 
      time = Match.find_by(user_id: Chat_id.find(params[:id]).user_id, matched_id: Chat_id.find(params[:id]).user_id2).created_at
      @timer = time.to_i + 600
  else
    @user = session[:user]
    if chat_id.user_id == session[:user]
      @get_user = chat_id.user_id2
    elsif chat_id.user_id2 == session[:user]
      @get_user = chat_id.user_id
    end 
  end 
  $daily_question ||= generate_random_question(question_templates)
  erb :chat, locals: { question: $daily_question }
end 
  
scheduler.every '1d', first_at: Time.now.tomorrow.midnight do
  $daily_question = generate_random_question(question_templates)
end


def generate_random_question(templates)
  templates.sample
end

post '/chat' do 
  content_type :json
  params = JSON.parse(request.body.read)
    sent_id = User.find_by(name: params['username']).id
    if params['get_user'].to_i < sent_id
    chat_id = Chat_id.find_by(user_id: params['get_user'], user_id2: sent_id).id
    elsif params['get_user'].to_i > sent_id
    chat_id = Chat_id.find_by(user_id: sent_id, user_id2: params['get_user']).id
    end 
    Chat.create(
      sent_id: sent_id,
      get_id: params['get_user'],
      chat_id: chat_id,
      sent_name: params['username'],
      text: params['message']
      )
end 

get '/websocket' do 
  if Faye::WebSocket.websocket?(request.env)
    ws = Faye::WebSocket.new(request.env)
    ws.on :open do |event|
      settings.sockets << ws
    end 
    ws.on :message do |event|
      settings.sockets.each do |socket|
        socket.send(event.data)
      end 
    end 
    ws.on :close do |event|
      ws = nil
      settings.sockets.delete(ws)
    end 
    ws.rack_response 
  end 
end 

post '/cancel_queue' do 
  content_type :json
    Waiting.find_by(user_id: session[:user]).delete
    if Waiting.find_by(user_id: session[:user])
      msg = "queue cancel failed"
    else 
      msg = "success"
    end 
  {msg: msg}.to_json
end 

post '/cancel_match' do 
  content_type :json
    Match.find_by(user_id: session[:user]).delete
    Match.find_by(matched_id: session[:user]).delete
    if Match.find_by(user_id: session[:user])
      msg = "match cancel failed"
    else 
      msg = "success"
    end 
  {msg: msg}.to_json
end 