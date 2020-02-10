import csv
with open("aGalaxy_full_comments.csv", "r") as csv_file:
   csv_reader = csv.DictReader(csv_file, delimiter=',')
   for lines in csv_reader:
     decodestr = lines['bug_id']
     print decodestr
