# frozen_string_literal: true

# bugzilla users which have been exported into the users.csv file.
# userid,login_name,realname,cryptpassword,disabledtext,mybugslink,extern_id,disable_mail
@users_bugzilla = []
#users_bugzilla_csv = "/folder/profiles.csv"
users_bugzilla_csv = "/folder/pf.csv"
@users_bugzilla = csv_to_array(users_bugzilla_csv)
goodbye('Cannot get users!') unless @users_bugzilla.length.nonzero?
@user_id_to_realname = {}
@user_id_to_login_name = {}
@user_login_to_login_name = {}
@list_of_user_logins = {}
@users_bugzilla.each do |user|
  userid = user['userid']
  who = user['who'] #.sub(/@.*$/, '')
  realname = user['realname']
  if who.nil? || who.empty?
     who = "#{userid}@#{JIRA_API_DEFAULT_EMAIL}"
  end
  @user_id_to_login_name[userid] = userid
  @user_id_to_realname[realname] = realname
  @user_login_to_login_name[who] = who
  @list_of_user_logins[who] = true
end
