#!/bin/bash

if [ -f /tmp/tmphold ]; then 
echo holding
exit 0
fi

APACHECHECK=`sudo ps ax | grep -Ev '(grep|lshttpd|lscgid|domlogs)' | grep -E '(httpd|apache)'`

NGINXCHECK=$(ps ax | awk '/nginx/' | awk '!/awk/')

MAIL_ADDR=support@iserversupport.com
servername=$(hostname)
echo "$servername"
#setting file to redirect the command output


TEMPFILE="/tmp/isscpumonitorcontent7266262.txt"
> $TEMPFILE

### Client info check ############

cat /home/iss/c1l2i3e4n5t.txt >> /dev/null

if [ $? -ne 0 ]
then
echo "need to add client info"
echo "ServerName:" $(hostname) | mail -s "Need to add Client info to Server"  $MAIL_ADDR
exit 1;
else
clientid=$(cat /home/iss/c1l2i3e4n5t.txt)

if ! curl https://iserversupport.com/script/idkkshhekc.txt | grep -w "$clientid" > /dev/null ; then

exit 0

fi

fi

##SERVER INFO#####################
echo " " >> $TEMPFILE
#echo "###SERVER HOSTNAME     ###" >> $TEMPFILE
echo "Hostname: $(hostname)" >> $TEMPFILE
echo " " >> $TEMPFILE
echo "Local Date & Time: $(date)" >> $TEMPFILE
echo " " >> $TEMPFILE
DATE=$(date)

namedate=`date +%F-%H:%M`
##CHECK LOAD

if [ ! -f /home/iss/cputhreashold ] ; then

nproc > /home/iss/cputhreashold

else

thrshld=`cat /home/iss/cputhreashold`

fi


ldavg=`w| awk -F'average:' '{print $2}' | head -1 | cut -d',' -f2 | xargs`

ldavg5=`w| awk -F'average:' '{print $2}' | head -1 | cut -d',' -f3 | xargs`



if [[  ${ldavg%.*} -ge $thrshld ]] && [[  ${ldavg5%.*} -ge $thrshld ]]; then
echo high

echo "Hello [FIRSTNAME]," >> $TEMPFILE
echo " " >> $TEMPFILE
#echo "Greetings from iServersupport" >> $TEMPFILE
echo " " >> $TEMPFILE
echo "While we are monitoring your server as part of the Monthly server support plan. we have detected a high CPU load average: $ldavg on  the server. " >> $TEMPFILE
echo " we are checking on this cpu load spike incident and will update you with further details." >> $TEMPFILE

echo " " >> $TEMPFILE
echo " " >> $TEMPFILE
echo " " >> $TEMPFILE
echo " " >> $TEMPFILE

sar -q | tail -4 | grep -v Average  >> $TEMPFILE

> /tmp/oomevents
cat /var/log/syslog |grep 'oom-killer' >> /tmp/oomevents
cat /var/log/messages |grep 'oom-killer'>> /tmp/oomevents

if  [[ ! -s /tmp/oomevents ]] ; then

echo "
Recent OOM invoke events
"  >> $TEMPFILE

cat /tmp/oomevents  >> $TEMPFILE
echo " " >> $TEMPFILE

fi

html=""
if [ -z "$APACHECHECK" ]; then
html=`echo '<html>'`
fi

echo '
'"$html"'
<style>
table, th, td {
border: 1px solid black;
border-collapse: collapse;
}
</style>

<h1>Server Porcess Listing & Apache status page</h1>
<table style="width:100%">

 <tr>
    <th colspan="6"><h3>Server Porcess Listing</h3></th>
  </tr>
<tr>
<th>USER</th>
<th>PID</th>
<th>CPU</th>
<th>TT</th>
<th>TIME</th>
<th>CMD</th>
</tr >
' > /tmp/process$namedate.txt
ps -eo user,pid,%cpu,tty,time,cmd |sort -nrk 3 | awk '{print "<tr><td>"$1"</td><td>"$2"</td><td>"$3"</td><td>"$4"</td><td>"$5"</td><td>"$6,$7,$8,$9,$10.$11,$12,$13,$14,$15,$16,$17"</tr></td>"}' | grep -v USER >>  /tmp/process$namedate.txt


cat  /tmp/process$namedate.txt > /tmp/ps.txt



if [ ! -z "$APACHECHECK" ]; then

apachest=1

if curl -m 30 -Ls -o /dev/null -w "%{http_code}\n" http://`hostname -i`/server-status | egrep '[2,3][0][0-9]' ; then

curl -o /tmp/status_page$namedate.html http://`hostname -i`/server-status

else

echo "Webserver status page is not enabled" >> $TEMPFILE


fi
fi

if [ "${NGINXCHECK}" ] && [ ! $apachest -eq 1 ]; then
echo ""
echo "---------------"
echo "You are running Nginx"
echo "---------------"
echo '</html>' >> /tmp/process$namedate.txt

fi


echo " " >> $TEMPFILE

echo "Top IP connections to webserver" >> $TEMPFILE

netstat -antu | egrep ':80\ |:443\ '  |grep -v LISTEN | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -h | tail -20 >> $TEMPFILE
echo " " >> $TEMPFILE

check_timea=$( date +%d/%b/%Y:%H:%M -d "-1 Minute")

if [[ -f /usr/local/cpanel/version ]]; then

echo "Top websites by IP connection" >> $TEMPFILE

grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}.*$check_timea.*\ HTTP\/1.1\"\ *\ ([0-9]{3})"   /home*/*/access-logs/*  | sed 's/-ssl_log//1' | cut -d'/' -f5- | awk '{print $1}' | sort | uniq -c | sort -rh | head -20 >>  $TEMPFILE
echo " " >> $TEMPFILE

elif [[ -f /etc/plesk-release ]]; then

echo "Top websites by IP connection" >> $TEMPFILE

grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}.*$check_timea.*\ HTTP\/1.1\"\ *\ ([0-9]{3})"  /var/www/vhosts/*/logs/access_*log | sed -e 's/access_ssl_log//1' -e 's/access_log//1'| cut -d'/' -f5,7  | tr '/' ' ' | awk '{print $1,$2}'| tr -s ' :' ',' | sort | uniq -c | sort -rh | head -20  >>  $TEMPFILE
echo " " >> $TEMPFILE

fi

cat /tmp/status_page$namedate.html |sed '/^$/d' >> /tmp/ps.txt

echo " " >> $TEMPFILE

echo "Connection Status summary"  >>  $TEMPFILE

netstat -nat | awk '{print $6}' | sort | uniq -c | sort -n >>$TEMPFILE
echo " " >> $TEMPFILE


##CPU usage top

>cpulist
>memlist

ps -eo %cpu,%mem,user|grep -v USER > cpu

for v in $(ps -eo user | sort |uniq|grep -v USER)

do 

if cat cpu | grep $v > /dev/null ; then

awk  -v user=$v '$3==user && $1 > 0 {sum += $1} END {print user,sum}' cpu >> cpulist
awk  -v user=$v '$3==user && $2 > 0 {sum += $2} END {print user,sum}' cpu >> memlist

fi

done

echo >>  $TEMPFILE


cat cpu |awk '{print $3}'|sort |uniq -c | sort -nrk2 |head -10 >>$TEMPFILE

echo >>  $TEMPFILE


echo "Top CPU used users" >>  $TEMPFILE

cat cpulist | sort -nrk2  | head -10 >>  $TEMPFILE

echo >>  $TEMPFILE

echo "Top Memory used users" >>  $TEMPFILE

cat memlist| sort -nrk2  | head -10 >>  $TEMPFILE

echo >>  $TEMPFILE

echo >>  $TEMPFILE


echo "Top process commands" >>  $TEMPFILE

ps -eo cmd | sort |uniq -c|sort -rh | head
echo >>  $TEMPFILE

#####




echo "Regards," >> $TEMPFILE
echo " " >> $TEMPFILE

echo "Support team" >> $TEMPFILE


echo "THE AUDIT INFORMATION HAS BEEN MAILED TO" $MAIL_ADDR


cid=$(echo "$clientid"';')

echo 'client='"$cid"

rm -f /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo '<?php' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo '$path = "/tmp/isscpumonitorcontent7266262.txt";' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
servern="High load $ldavg on $servername"
echo '$server='\""$servern"\"';'  >> /tmp/m2o5n6i7t9o0r1i2s3s4.php

echo '$client='"$cid"  >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo '$fileContent = file_get_contents($path);' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo 'echo $fileContent;' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo '$ch = curl_init();' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'curl_setopt($ch, CURLOPT_URL, \'https://iserversupport.com/billing/includes/jshjekskse2j3422.php\');' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'curl_setopt($ch, CURLOPT_POST, 1);' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'curl_setopt($ch, CURLOPT_POSTFIELDS,' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'    http_build_query(' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo '        array( ' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'            \'action\' => \'OpenTicket\',' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'            // See https://developers.whmcs.com/api/authentication' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'            \'username\' => \'ZlKuEygGPAsahv2YqCCNWYCynUiJZHXP\',' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'           \'password\' => \'flJIFDz4PsyONMeEsDvPUTuld9xI9gHh\',' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'            \'deptid\' => \'1\',' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'            \'subject\' => $server ,' >>  /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'            \'content-type\' => \'text/html\',' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'            \'message\' => $fileContent,' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'            \'clientid\' => $client,' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
cd /tmp/
echo $'            \'attachments\' => base64_encode(json_encode([[\'name\' => \'ps.html\', 'data' => base64_encode(file_get_contents("/tmp/ps.txt"))]])),' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php

echo $'            \'priority\' => \'Medium\',' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'            \'admin\'    => \'davidapiuser1234\',' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'            \'markdown\' => true,' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'            \'responsetype\' => \'json\',' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'        )' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'    )' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $');' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'$response = curl_exec($ch);' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'if (curl_error($ch)) {' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'    die(\'Unable to connect: \' . curl_errno($ch) . \' - \' . curl_error($ch));' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'}' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'curl_close($ch);' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'$jsonData = json_decode($response, true);' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php
echo $'var_dump($jsonData); ' >> /tmp/m2o5n6i7t9o0r1i2s3s4.php


php /tmp/m2o5n6i7t9o0r1i2s3s4.php

#rm -f /tmp/m2o5n6i7t9o0r1i2s3s4.php
rm -f /tmp/isscpucontent7266262.txt

touch /tmp/tmphold
sleep 600
rm -f /tmp/tmphold

fi
