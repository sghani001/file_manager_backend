class Rack::Attack
  throttle('logins/ip', limit: 5, period: 60.seconds) do |req|
    req.ip if req.path == '/api/v1/login' && req.post?
  end

  throttle('signups/ip', limit: 3, period: 60.seconds) do |req|
    req.ip if req.path == '/api/v1/signup' && req.post?
  end

  throttle('api/ip', limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/')
  end
end
