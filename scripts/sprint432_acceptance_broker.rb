# frozen_string_literal: true

require 'json'
require 'webrick'

state = {
  invitation_path: nil,
  accepted: false,
  owner_ready: false,
  driver_ready: false
}
lock = Mutex.new

server = WEBrick::HTTPServer.new(
  Port: Integer(ENV.fetch('SPRINT432_BROKER_PORT', '8099')),
  BindAddress: '127.0.0.1',
  Logger: WEBrick::Log.new(File::NULL, WEBrick::Log::FATAL),
  AccessLog: []
)

server.mount_proc('/') do |request, response|
  response['Access-Control-Allow-Origin'] = '*'
  response['Access-Control-Allow-Headers'] = 'Content-Type'
  response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
  if request.request_method == 'OPTIONS'
    response.status = 204
    next
  end

  case [request.request_method, request.path]
  when ['GET', '/health']
    response['Content-Type'] = 'application/json'
    response.body = JSON.generate(ok: true)
  when ['POST', '/invitation']
    payload = JSON.parse(request.body)
    path = payload.fetch('path')
    raise ArgumentError, 'invalid invitation path' unless path.start_with?('/accept-invitation?token=')

    lock.synchronize { state[:invitation_path] = path }
    response.status = 204
  when ['GET', '/invitation']
    path = lock.synchronize { state[:invitation_path] }
    if path
      response['Content-Type'] = 'application/json'
      response.body = JSON.generate(path: path)
    else
      response.status = 204
    end
  when ['POST', '/accepted']
    lock.synchronize { state[:accepted] = true }
    response.status = 204
  when ['GET', '/accepted']
    response['Content-Type'] = 'application/json'
    response.body = JSON.generate(accepted: lock.synchronize { state[:accepted] })
  when ['POST', '/owner-ready']
    lock.synchronize { state[:owner_ready] = true }
    response.status = 204
  when ['GET', '/owner-ready']
    response['Content-Type'] = 'application/json'
    response.body = JSON.generate(ready: lock.synchronize { state[:owner_ready] })
  when ['POST', '/driver-ready']
    lock.synchronize { state[:driver_ready] = true }
    response.status = 204
  when ['GET', '/driver-ready']
    response['Content-Type'] = 'application/json'
    response.body = JSON.generate(ready: lock.synchronize { state[:driver_ready] })
  else
    response.status = 404
  end
rescue JSON::ParserError, KeyError, ArgumentError
  response.status = 400
  response.body = ''
end

trap('INT') { server.shutdown }
trap('TERM') { server.shutdown }
server.start
