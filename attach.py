import re
import requests

list = [3345, 3481, 3349, 3350, 3759]
for url in list:
        def download_file():
            global dump
            custom_cookies={"Bugzilla_login": "3766", "Bugzilla_logincookie" : "naGk4mfRT7" }
            resp = requests.get("http://coverity5/attachment.cgi?id=%s" %url, cookies=custom_cookies)
            global ffname
            fname = ''
            if "Content-Disposition" in resp.headers.keys():
                fname = re.findall("filename=(.+)", resp.headers["Content-Disposition"])[0]
            else:
                fname = url.split("/")[-1]             
        
	    print(fname)
            ffname = fname.strip('\n').replace('\"','')
            save_file(resp)
	
	def save_file(content):
            with open(r"\folder\attachments\%i-%s" %(url,ffname), 'wb') as f:
	   # with open(r"/folder/attachments/%i-%s" %(url,ffname), 'wb') as f:
                   f.write(content.content)
   	download_file()
