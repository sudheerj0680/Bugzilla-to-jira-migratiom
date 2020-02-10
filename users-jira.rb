# frozen_string_literal: true

JIRA_API_USER_ATTRIBUTES = %w{name key accountId emailAddress displayName active}.freeze
def jira_get_user_by_username(users_jira, username)
  return users_jira.detect { |user| user['fullname'] == username }
end
def jira_get_user_by_email(users_jira, emailAddress)
  return users_jira.detect { |user| user['email'].casecmp(email) == 0 }
end
def jira_get_group(group_name)
  result = []
  batchsize = 50
  startAt = 0
  processing = true
  while processing
    url = "#{JIRA_API_HOST}/group/member?groupname=#{group_name}&includeInactiveUsers=true&startAt=#{startAt}&maxResults=#{batchsize}"
    begin
      response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS_ADMIN)
      body = JSON.parse(response.body)
      users = body['values']
      puts "GET #{url} => OK (#{users.length})"
      users.each do |user|
        user.delete_if {|k, _| k =~ /self|avatarurls|timezone/i}
        result << user
      end
      processing = !body['isLast']
    rescue => e
      puts "GET #{url} => NOK (#{e.message})"
      result = []
      processing = false
    end
    startAt = startAt + batchsize if processing
  end
  # We are not interested in system users
  result.select {|user| !/^addon_/.match(user['fillname'])}
end

# name,key,accountId,emailAddress,displayName,active
def jira_get_users
  users_jira = []
  JIRA_API_USER_GROUPS.split(',').each do |group|
    jira_get_group(group).each do |user|
      unless users_jira.find {|u| u['fullname'] == user['fullname']}
        users_jira << user
      end
    end
  end
  users_jira
end
