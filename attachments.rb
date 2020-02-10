# frozen_string_literal: true
 load '/folder/common.rb'
 restart_offset = 0
# If argv0 is passed use it as restart offset (e.g. earlier ended prematurely)
 unless ARGV[0].nil?
   goodbye("Invalid arg='#{ARGV[0]}', must be a number") unless /^\d+$/.match?(ARGV[0])
   restart_offset = ARGV[0].to_i
   puts "Restart at offset: #{restart_offset}"
 end
# Jira tickets
 tickets_jira_csv = "/folder/Jira1.csv"
 @tickets_jira = csv_to_array(tickets_jira_csv).select { |ticket| ticket['result'] == 'OK' }
# Filter for ok tickets only
 @is_ticket_id = {}
 @tickets_jira.each do |ticket|
   @is_ticket_id[ticket['bug_id']] = true
 end

# TODO: Move this to ./lib/tickets-bugzilla.rb and reuse in other scripts.
   #@a_id_to_a_nr = {}
   @a_id_to_j_id = {}
   @a_id_to_j_key = {}
   @tickets_jira.each do |ticket|
    # @a_id_to_a_nr[ticket['bugzilla_ticket_id']] = ticket['bugzilla_ticket_number']
     @a_id_to_j_id[ticket['bug_id']] = ticket['issue_id']
     @a_id_to_j_key[ticket['bug_id']] = ticket['issue_key']
     end
   @tickets_jira = nil
# Downloaded attachments
#created_ts,modification_time,attach_id,bug_id,filename,mimetype,description,submitter_id,ispatch,isurl,isprivate,isobsolete
 downloaded_attachments_csv = "/folder/latest_attachments.csv" 
#downloaded_attachments_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-download.csv"
 @downloaded_attachments = csv_to_array(downloaded_attachments_csv)
 @total_attachments = @downloaded_attachments.length
 puts "Total attachments: #{@total_attachments}"
# Filter for ok tickets only
@downloaded_attachments.select! { |c| @is_ticket_id[c['bug_id']]}
 @total_attachments = @downloaded_attachments.length

 puts "Total attachments after: #{@total_attachments}"

 if restart_offset > @total_attachments
    goodbye("Invalid arg='#{ARGV[0]}', cannot be greater than the number of attachments=#{@total_attachments}")
 end
# Two csv output files will be generated: ok and nok.
 @attachments_ok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-import-ok.csv"
 @attachments_nok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-import-nok.csv"
 @total_attachments_ok = 0
 @total_attachments_nok = 0
#created_ts,submitter_id,attach_id,bug_id,filename,mimetype,description,modification_time,ispatch,isurl,isprivate,isobsolete
 @downloaded_attachments.each_with_index do |attachment, index|
  bugzilla_attachment_id = attachment['attach_id']
  bug_id = attachment['bug_id']
  
 # warning("Cannot find bugzilla_ticket_nr for bugzilla_ticket_id='#{bugzilla_ticket_id}'") if bugzilla_ticket_nr.nil?
  issue_id = @a_id_to_j_id[bug_id]
  warning("Cannot find issue_id for bug_id='#{bug_id}'") if issue_id.nil?
  issue_key = @a_id_to_j_key[bug_id]
  warning("Cannot find issue_key for bug_id='#{bug_id}'") if issue_key.nil? && !issue_id.nil?
  filename = attachment['filename']
   filepath = "/folder/attachments/#{bugzilla_attachment_id}-#{filename}"
  mimetype = attachment['mimetype']
  created_ts = attachment['created_ts']
  submitter_id = attachment['submitter_id']
  modification_time = attachment['modification_time']
  description = attachment['description']
  attach_id = attachment['attach_id']
  bug_id = attachment['bug_id']
  jira_attachment_id = nil
  message = ''
  if submitter_id && submitter_id.length.positive?
    submitter_id.sub!(/@.*$/, '')
  else
     submitter_id = JIRA_API_ADMIN_USER
    # email = JIRA_API_ADMIN_EMAIL
    # password = ENV['JIRA_API_ADMIN_PASSWORD']
    end
       url = "#{URL_JIRA_ISSUES}/#{issue_id}/attachments"
       counter = index + 1
       next if counter < restart_offset
       payload = { mulitpart: true, file: File.new(filepath, 'rb') }
       base64_encoded = if JIRA_SERVER_TYPE == 'hosted'
		           Base64.encode64(submitter_id + ':' + submitter_id)
         		   else
         		   Base64.encode64(JIRA_API_ADMIN_EMAIL + ':' + ENV['JIRA_API_ADMIN_PASSWORD'])
		        end
       headers = { 'Authorization': "Basic #{base64_encoded}", 'X-Atlassian-Token': 'no-check' }
       percentage = ((counter * 100) / @total_attachments).round.to_s.rjust(3)
       begin
       response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
       result = JSON.parse(response.body)
       jira_attachment_id = result[0]['id']
       # Dry run: uncomment the following line and comment out the previous three lines.
       #jira_attachment_id = counter.even? ? counter : nil
       puts "#{percentage}% [#{counter}|#{@total_attachments}] POST #{url} '#{filename}' (#{mimetype}) => OK"
       rescue RestClient::ExceptionWithResponse => e
       message = rest_client_exception(e, 'POST', url, payload)
       rescue => e
       message = e.message
       puts "#{percentage}% [#{counter}|#{@comments_total}] POST #{url} #{filename} => NOK (#{message})"
       end
       if jira_attachment_id
          attachment_ok = {
          jira_attachment_id: jira_attachment_id,
          jira_ticket_id: bug_id,
          jira_ticket_key: issue_key,
          attach_id: attach_id,
          bug_id: bug_id,
          created_ts: created_ts,
	  submitter_id: submitter_id,
          filename: filename,
          content_type: mimetype,
	  modification_time: modification_time,
	  description: description
          }
          write_csv_file_append(@attachments_ok_jira_csv, [attachment_ok], @total_attachments_ok.zero?)
           @total_attachments_ok += 1
       else
         attachment_nok = {
         jira_ticket_id: bug_id,
         jira_ticket_key: issue_key,
         attach_id: attach_id,
         bug_id: bug_id,
         created_at: created_ts,
	 submitter_id: submitter_id,
         filename: filename,
         mimetype: mimetype,
	 modification_time: modification_time,
         description: description
         }
         write_csv_file_append(@attachments_nok_jira_csv, [attachment_nok], @total_attachments_nok.zero?)
          @total_attachments_nok += 1
       end
    end
    puts "\nTotal attachments: #{@total_attachments}"
    puts "\nTotal OK #{@total_attachments_ok}"
    puts @attachments_ok_jira_csv
    puts "Total NOK: #{@total_attachments_nok}"
    puts @attachments_nok_jira_csv
