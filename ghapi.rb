require 'pry'
require 'etc'
require 'octokit'

# Check all clients rate limit or only check rate limit given by last_hint >= 0
# You can use last_hint when you know that you only used client[last_hint] to avoid checking the remaining ones.
$g_rls = []
def rate_limit(clients, last_hint = -1, debug = 1)
  if clients.length == 0
    puts 'No usable clients'
    exit 1
  end
  # This is to force checking other clients state with 1/N probablity.
  # Even if we don't use them, they can reset to a higher API points after <= 1h
  failed = []
  last_hint = -1 if last_hint >= 0 && Time.now.to_i % clients.length == 0
  rls = []
  if $g_rls.length > 0 && last_hint >= 0
    rls = $g_rls
    puts "Checking rate limit for #{last_hint}" if debug >= 2
    rls[last_hint] = clients[last_hint].rate_limit
  else
    thrs = []
    n_thrs = ENV['NCPUS'].nil? ? Etc.nprocessors : ENV['NCPUS'].to_i
    clients.each_with_index do |client, idx|
      thrs << Thread.new(client, idx) do |client, idx|
        puts "Checking rate limit for #{idx}" if debug >= 2
        rate = nil
        begin
          rate = client.rate_limit
        rescue
          puts "idx #{idx} failed, either remove it #{client} via SKIP_TOKENS='#{idx}' or remove it from /etc/github/oauth(s)"
          failed << idx
        end
        puts "Rate limit for #{idx}: #{rate}" if debug >= 2
        rate
      end
      while thrs.length >= n_thrs
        rls << thrs.first.value
        puts "Checked rate limit for #{rls.length-1}" if debug >= 2
        thrs = thrs[1..-1]
      end
    end
    thrs.each_with_index do |thr, idx|
      rate = thr.value
      if rate
        rls << thr.value
      end
      puts "Checked rate limit for #{idx}" if debug >= 2
    end
  end
  if failed.length > 0
    puts "Failed indices: #{failed}"
    exit 1
  else
    puts "Tokens OK"
  end
  $g_rls = rls
  hint = 0
  rls.each_with_index do |rl, idx|
    if rl.remaining > rls[hint].remaining
      hint = idx
    elsif idx != hint && rl.remaining == rls[hint].remaining && rl.resets_in < rls[hint].resets_in
      hint = idx
    end
  end
  remainings = rls.map { |rl| rl.remaining }
  resets_ats = rls.map { |rl| rl.resets_at.strftime("%H:%M:%S") }
  resets_ins = rls.map { |rl| "#{rl.resets_in}s" }
  rem = (rls[hint].resets_at - Time.now).to_i + 1
  puts "Hint: #{hint}"
  remainings.each_with_index do |rem, idx|
    puts "#{idx}) remaining #{rem}, resets_at #{resets_ats[idx]}, resets_ins #{resets_ins[idx]}" if debug >= 1
  end
  puts "Suggested client nr #{hint}, remaining API points: #{remainings[hint]}, resets at #{resets_ats[hint]}, seconds till reset: #{rem}" if debug >= 0
  [hint, rem, remainings[hint]]
end

# Reads comma separated OAuth keys from '/etc/github/oauths' fallback to single OAuth key from '/etc/github/oauth'
# Reads comma separated OAuth application client IDs from '/etc/github/client_ids' fallback to single client ID from '/etc/github/client_id'
# Reads comma separated OAuth application client secrets from '/etc/github/client_secrets' fallback to single client secret from '/etc/github/client_secret'
# If multiple keys, client IDs and client secrets are used then you need to have the same number of entries in all 3 files and in the same order line
# '/etc/github/oauths': key1,key2,key3 (3 different github accounts)
# '/etc/github/client_ids' id1,id2,id3 (the same 3 github accounts in the same order)
# '/etc/github/client_secrets' secret1,secret2,secret3 (the same 3 github accounts in the same order)
def octokit_init()
  # Auto paginate results, this uses maximum page size 100 internally and calls API # of results / 100 times.
  # Octokit.auto_paginate = true
  Octokit.configure do |c|
    c.auto_paginate = true
  end

  # Login with standard OAuth token
  # https://github.com/settings/tokens --> Personal access tokens
  puts "Processing OAuth data."
  tokens = []
  begin
    data = File.read('/etc/github/oauths').strip
    tokens = data.split(',').map(&:strip)
  rescue Errno::ENOENT => e
    begin
      data = File.read('/etc/github/oauth').strip
    rescue Errno::ENOENT => e
      puts "No OAuth token(s) found"
      exit 1
    end
    tokens = [data]
  end

  # Increase rate limit from 60 to 5000
  # You will need Your own client_id & client_secret
  # See: https://github.com/settings/ --> OAuth application
  client_ids = []
  begin
    data = File.read('/etc/github/client_ids').strip
    client_ids = data.split(',').map(&:strip)
  rescue Errno::ENOENT => e
    begin
      data = File.read('/etc/github/client_id').strip
    rescue Errno::ENOENT => e
      puts "No client ID(s) tokens found"
      exit 1
    end
    client_ids = [data]
  end
  client_secrets = []
  begin
    data = File.read('/etc/github/client_secrets').strip
    client_secrets = data.split(',').map(&:strip)
  rescue Errno::ENOENT => e
    begin
      data = File.read('/etc/github/client_secret').strip
    rescue Errno::ENOENT => e
      puts "No client ID(s) tokens found"
      exit 1
    end
    client_secrets = [data]
  end

  # You can select subset of tokens with something like ONLY_TOKENS='1,3,5'
  selected = ENV['ONLY_TOKENS']
  if !selected.nil? && selected != ''
    sel = selected.strip
    idxa = sel.split(',').map(&:to_i)
    ary = []
    tokens.each_with_index { |token, idx| ary << token if idxa.include?(idx) }
    tokens = ary
    ary = []
    client_ids.each_with_index { |client_id, idx| ary << client_id if idxa.include?(idx) }
    client_ids = ary
    ary = []
    client_secrets.each_with_index { |client_secret, idx| ary << client_secret if idxa.include?(idx) }
    client_secrets = ary
  end

  skipped = ENV['SKIP_TOKENS']
  if !skipped.nil? && skipped != ''
    ski = skipped.strip
    idxa = skipped.split(',').map(&:to_i)
    ary = []
    tokens.each_with_index { |token, idx| ary << token unless idxa.include?(idx) }
    tokens = ary
    skipped = []
    tokens.each_with_index { |token, idx| skipped << token if idxa.include?(idx) }
    puts "Tokens: #{tokens}"
    puts "Skipped tokens: #{skipped}"
    # exit 1
  end

  puts "Connecting #{tokens.length} clients."
  # Process tripples, create N threads to handle client creations
  clients = []
  thrs = []
  n_thrs = ENV['NCPUS'].nil? ? Etc.nprocessors : ENV['NCPUS'].to_i
  tokens.each_with_index do |token, idx|
    thrs << Thread.new(token, idx) do |token, idx|
      puts "Connecting client nr #{idx} #{token}"
      client = Octokit::Client.new(
        access_token: token,
        client_id: client_ids[idx],
        client_secret: client_secrets[idx]
      )
    end
    while thrs.length >= n_thrs
      begin
        client =  thrs.first.value
        thrs = thrs[1..-1]
        clients << client
        puts "Connected #{clients.length}"
      rescue Octokit::TooManyRequests => e
        puts e
      end
    end
  end
  thrs.each do |thr|
    begin
      # user = client.user
      # user.login
      client = thr.value
      clients << client
      puts "Connected #{clients.length}"
    rescue Octokit::TooManyRequests => e
      puts e
    end
  end
  if clients.length == 0
    puts 'Unable to initialize any client'
    exit 1
  end

  # Use client array or eventually check it if CHECK_USABILITY is set.
  final_clients = []
  unless ENV['CHECK_USABILITY'].nil?
    clients.each_with_index do |client, idx|
      begin
        puts "Client nr #{idx}: #{client.user[:login]} ok"
        final_clients << client
      rescue Octokit::TooManyRequests => e
        hint, rem, pts = rate_limit [client], -1, -1
        puts "Client nr #{idx} unusable: points: #{pts}, resets in: #{rem}s"
      end
    end
  else
    final_clients = clients
  end
  puts "octoinit complete"
  final_clients
end
