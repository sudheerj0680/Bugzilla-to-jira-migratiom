# frozen_string_literal: true

 load '/folder/common.rb'
 load '/folder/users-jira.rb'
 #load '/folder/users-bugzilla.rb'
# Jira tickets
# Issue Type,Issue key,Issue id,Summary,Assignee,Reporter,Status,Resolution,Created,Updated,Due date,Description,Environment,bug_id
tickets_jira_csv = "/folder/Jira.csv"
@tickets_jira = csv_to_array(tickets_jira_csv).select {|ticket| ticket['result'] == 'OK'}
@is_ticket_id = {}
@tickets_jira.each do |ticket|
  @is_ticket_id[ticket['bug_id']] = true
end
# Bugzilla comments
# bug_id,login_name,bug_when,work_time,thetext,isprivate,already_wrapped,comment_id,type,extra_data
comments_bugzilla_csv = "/folder/comments.csv"
@comments_bugzilla = csv_to_array(comments_bugzilla_csv)

puts "Total comments: #{@comments_bugzilla.length}"
# TEST
@comments_bugzilla.select! { |c| @is_ticket_id[c['bug_id']]}

puts "Total comments after: #{@comments_bugzilla.length}"

# Ignore empty comments?
#if JIRA_API_SKIP_EMPTY_COMMENTS
#  comments_bugzilla_empty = @comments_bugzilla.select {|comment| comment['comment'].nil? || comment['comment'].strip.empty?}
#  if comments_bugzilla_empty && comments_bugzilla_empty.length.nonzero?
#    @comments_bugzilla.reject! {|comment| comment['comment'].nil? || comment['comment'].strip.empty?}
##    comments_empty_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments-skipped-empty.csv"
#    write_csv_file(comments_empty_jira_csv, comments_bugzilla_empty)
#    puts "Empty: #{comments_bugzilla_empty.length}"
#    comments_bugzilla_empty = nil
#  else
#    puts "Empty: None"
#  end
#end

# Ignore commit comments?
#if JIRA_API_SKIP_COMMIT_COMMENTS
#  comments_bugzilla_commit = @comments_bugzilla.select {|comment| /Commit: \[\[r:/.match(comment['comment'])}
#  if comments_bugzilla_commit && comments_bugzilla_commit.length.nonzero?
#    @comments_bugzilla.reject! {|comment| /Commit: \[\[r:/.match(comment['comment'])}
#    comments_commit_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments-skipped-commit.csv"
#    write_csv_file(comments_commit_jira_csv, comments_bugzilla_commit)
#    puts "Commit: #{comments_bugzilla_commit.length}"
#    comments_bugzilla_commit = nil
#  else
#    puts "Commit: None"
#  end
#end

puts "Remaining: #{@comments_bugzilla.length}" if JIRA_API_SKIP_EMPTY_COMMENTS || JIRA_API_SKIP_COMMIT_COMMENTS

# @users_jira => userid,realname,login_name,who
users_jira_csv = "/folder/profile.csv"
@users_jira = csv_to_array(users_jira_csv)

 @user_id_to_login = {}
 @user_id_to_email = {}
 @bugzilla_login_to_jira_name = {}
 @bugzilla_id_to_jira_name = {}
 @users_jira.each do |user|
  id = user['userid']
  login = user['realname'].sub(/@.*$/, '')
  email = user['login_name']
  user_login = user['who']
  if email.nil? || email.empty?
   email  = "#{login}@#{JIRA_API_DEFAULT_EMAIL}"
  end

   @user_id_to_login[id] = user_login
   @user_id_to_email[id] = email
   @bugzilla_id_to_jira_name[id] = user['login_name']
   @bugzilla_login_to_jira_name[user['bugzillalogin']] = user['realname']
 end
#puts @bugzilla_id_to_jira_name
#puts "$$$$$"
# Convert bugzilla_ticket_id to jira_ticket_id and bugzilla_ticket_id to jira_ticket_key
 @bugzilla_id_to_jira_id = {}
 @bugzilla_id_to_jira_key = {}
 @tickets_jira.each do |ticket|
   @bugzilla_id_to_jira_id[ticket['bug_id']] = ticket['issue_id']
   @bugzilla_id_to_jira_key[ticket['bug_id']] = ticket['issue_key']
     end
#jira attachment (images)
downloaded_attachments_csv  = "/folder/latest_attachments.csv"
@downloaded_attachments = csv_to_array(downloaded_attachments_csv)
@list_of_images = {}
@downloaded_attachments.each do |attachment|
  @list_of_images[attachment['bugzilla_attachment_id']] = attachment['attach_id']
end

puts "Attachments: #{@downloaded_attachments.length}"
puts

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "Filter newer than: #{tickets_created_on}"
  comments_initial = @comments_bugzilla.length
  # Only want comments which belong to remaining tickets
  @comments_bugzilla.select! {|item| @bugzilla_id_to_jira_id[item['bug_id']]}
  puts "Comments: #{comments_initial} => #{@comments_bugzilla.length} ∆#{comments_initial - @comments_bugzilla.length}"
end

 puts "Tickets: #{@tickets_jira.length}"

@comments_total = @comments_bugzilla.length
def headers_user_login_comment(realname, login_name)
  # Note: Jira cloud doesn't allow the user to create own comments, a user belonging to the jira-administrators
  # group must do that.
   headers_user_login(realname, login_name)
 #{'Authorization': "Basic #{Base64.encode64(user_login + ':' + user_login)}", 'Content-Type': 'application/json; charset=utf-8'}
   # {'Authorization': "Basic #{Base64.encode64(login_name + ':' + login_name)}", 'Content-Type': 'application/json; charset=utf-8'}
end

@comments_diffs_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments-diffs.csv"
@total_comments_diffs = 0
# POST /rest/api/2/issue/{issueIdOrKey}/comment
def jira_create_comment(issue_id, who, comment, counter) #login_name
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_id}/comment"
  id = who
  login_name = @bugzilla_id_to_jira_name[id]
  realname = @user_id_to_email['realname']
  headers = headers_user_login_comment(realname, login_name)
  reformatted_body = reformat_markdown(comment['thetext'], logins: @bugzilla_id_to_jira_id,
                                       images: @list_of_images, content_type: 'comment', strikethru: true)
  body = "created on #{date_time(comment['bug_when'])}\n\n#{reformatted_body}"
  if JIRA_SERVER_TYPE == 'cloud'
     author_link = login_name ? "[~#{login_name}]" : "unknown (#{who})"
     body = "Author #{author_link} | #{body}"
  end
  body = "Bugzilla | #{body}"
  # Ensure that the body is not too long.
  if body.length > 32767
    body = body[0..32760] + '...'
    warning('Comment body length is greater than 32767 => truncate')
  end
  payload = {
      body: body
  }.to_json
  percentage = ((counter * 100) / @comments_total).round.to_s.rjust(3)
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    result = JSON.parse(response.body)
    # Dry run: uncomment the following two lines and comment out the previous two lines.
    # result = {}
    # result['id'] = counter
    puts "#{percentage}% [#{counter}|#{@comments_total}] POST #{url} => OK"
  rescue RestClient::ExceptionWithResponse => e
    # TODO: use following helper method for all RestClient calls in other files.
    rest_client_exception(e, 'POST', url)
  rescue => e
    puts "#{percentage}% [#{counter}|#{@comments_total}] POST #{url} => NOK (#{e.message})"
  end
  if result && comment['comment'] != reformatted_body
    id = comment['id']
    bug_id = comment['bug_id']
    issue_id = @bugzilla_id_to_jira_id[bug_id]
    issue_key = @bugzilla_id_to_jira_key[bug_id]
    comment_id = result['id']
    comments_diff = {
      jira_comment_id: comment_id,
      jira_ticket_id: issue_id,
      jira_ticket_key: issue_key,
      bugzilla_comment_id: comment_id,
      bugzilla_ticket_id: bug_id,
      before: comment['comment'],
      after: reformatted_body
    }
    write_csv_file_append(@comments_diffs_jira_csv, [comments_diff], @total_comments_diffs.zero?)
    @total_comments_diffs += 1
  end
  result
end
# IMPORTANT: Make sure that the comments are ordered chronologically from first (oldest) to last (newest)
@comments_bugzilla.sort! {|x, y| x['bug_when'] <=> y['bug_when']}
@total_imported = 0
@total_imported_nok = 0
@comments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments.csv"
@comments_jira_nok_csv = "#{OUTPUT_DIR_JIRA}/jira-comments-nok.csv"
@comments_bugzilla.each_with_index do |comment, index|
  result = nil
  id = comment['comment_id']
  counter = index + 1
  bug_id = comment['bug_id']
  bug_when = comment['bug_when']
  thetext = comment['thetext']
  who = comment['who']
  issue_id = @bugzilla_id_to_jira_id[bug_id]
  issue_key = @bugzilla_id_to_jira_key[issue_key]
  user_login = @user_id_to_login[who]
  body = comment['comment']  

if issue_id.nil? || issue_id.length.zero?
    warning("Cannot find jira_issue_id for bugzilla_ticket_id='#{bug_id}'")
  else
    result = jira_create_comment(issue_id,  who, comment, counter) 
  end
  if result
    comment_id = result['id']
    comment = {
      jira_comment_id: comment_id,
      jira_ticket_id: issue_id,
      jira_ticket_key: issue_key,
      bugzilla_comment_id: comment_id,
      bugzilla_ticket_id: bug_id,
      realname: who,
      bug_when: bug_when,
      body: body
    }
    write_csv_file_append(@comments_jira_csv, [comment], @total_imported.zero?)
    @total_imported += 1
  else
    comment_nok = {
        error: issue_id.nil? ? 'invalid bug_id' : 'create failed',
        bugzilla_ticket_id: bug_id,
        bugzilla_comment_id: comment_id,
        realname: who,
	bug_when: bug_when,
        body: body
    }
    write_csv_file_append(@comments_jira_nok_csv, [comment_nok], @total_imported_nok.zero?)
    @total_imported_nok += 1
  end
end

puts "Total imported: #{@total_imported}"
puts @comments_jira_csv

puts "Total diffs: #{@total_comments_diffs}"
puts @comments_diffs_jira_csv

puts "Total NOK: #{@total_imported_nok}"
puts @comments_jira_nok_csv
