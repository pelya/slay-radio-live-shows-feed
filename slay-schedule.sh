#!/bin/sh

curl 'http://www.slayradio.org/api.php?query=nextshows' > shows-new.py || exit 1
mv -f shows.py shows-prev.py
mv -f shows-new.py shows.py

rm -f rss.xml ical.ics
cat > rss.xml <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
 <title>SLAY Radio live shows</title>
 <description>Live show schedule</description>
 <link>http://www.slayradio.org/home.php#schedule</link>
 <lastBuildDate>`date -R`</lastBuildDate>
 <pubDate>`date -R`</pubDate>
 <ttl>240</ttl>
EOF

cat > ical.ics <<EOF
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//SLAY Radio//Live show schedule//EN
CALSCALE:GREGORIAN
METHOD:PUBLISH
X-WR-TIMEZONE:UTC
X-WR-CALNAME:slay.shows
X-WR-CALDESC:SLAY Radio live shows schedule
UID:live-show-schedule@slayradio.org
EOF

DST="`python -c 'import time ; print time.daylight'`"

#TZ="Europe/Stockholm"
TZ="UTC"
[ "$DST" = 1 ] && TZ="UTC"

IFS='	
'
python -c "
shows = `cat shows.py`
showsPrev = `cat shows-prev.py`
data = shows['data']
for s in showsPrev['data']:
	if not (s['show_ID'] in [i['show_ID'] for i in data]):
		data.append(s)
for s in shows['data']:
	print s['show_ID'] + '\t' + s['airdate'] + '\t' + s['DJ'].replace('\n','').replace('\"','') + '\t' + s['showname'].replace('\n','').replace('\"','') + '\t' + s['blurb'].replace('\n','').replace('\"','')
" | while read UID DATE DJ TITLE DESCRIPTION; do
	echo "'$UID' '$DATE' '$DJ' '$TITLE' '$DESCRIPTION'"

	DATE_UTC="`python -c \"import os, time ; os.environ['TZ'] = '$TZ' ; time.tzset() ; print time.strftime('%a, %d %b %Y %H:%M:%S %z', time.localtime($DATE))\"`"
	echo "Timezone: $TZ DST: $DST DATE UTC: $DATE_UTC"

	DESCRIPTION="`echo \"$DESCRIPTION\" | sed 's/^- *//'`"
	TITLE="`echo \"$DJ - $TITLE\" | sed 's/^- *//'`"
	# Unescape XML special chars
	TITLE1="`echo $TITLE | sed 's/>/&gt;/g' | sed 's/</&lt;/g' | sed 's/&/&amp;/g'`"
	DESCRIPTION1="`echo $DESCRIPTION | sed 's/>/&gt;/g' | sed 's/</&lt;/g' | sed 's/&/&amp;/g'`"
	#echo "DATE formatted $DATE2"
	echo " <item>" >> rss.xml
	echo "  <title>`echo $TITLE | sed \"s/'/\&quot;/g\"`</title>" >> rss.xml
	echo "  <description>`echo $DESCRIPTION | sed \"s/'/\&quot;/g\"`</description>" >> rss.xml
	echo "  <link>http://www.slayradio.org/home.php#schedule</link>" >> rss.xml
	echo "  <guid>$UID</guid>" >> rss.xml
	echo "  <pubDate>$DATE_UTC</pubDate>" >> rss.xml
	echo " </item>" >> rss.xml

	DTSTART=`env TZ=UTC date -d "$DATE_UTC" '+%Y%m%dT%H%M00Z'`
	DTEND=`env TZ=UTC date -d "$DATE_UTC +3 hours" '+%Y%m%dT%H%M00Z'`
	echo "BEGIN:VEVENT" >> ical.ics
	echo "DTSTART:$DTSTART" >> ical.ics
	echo "DTEND:$DTEND" >> ical.ics
	echo "SUMMARY:$TITLE" >> ical.ics
	echo "DESCRIPTION:$DESCRIPTION" >> ical.ics
	echo "UID:$UID@slayradio.org" >> ical.ics
	echo "CLASS:PUBLIC" >> ical.ics
	echo "SEQUENCE:0" >> ical.ics
	echo "STATUS:CONFIRMED" >> ical.ics
	echo "TRANSP:TRANSPARENT" >> ical.ics
	echo "BEGIN:VALARM" >> ical.ics
	echo "ACTION:DISPLAY" >> ical.ics
	echo "DESCRIPTION:This is an event reminder" >> ical.ics
	echo "TRIGGER:-PT5M" >> ical.ics
	echo "END:VALARM" >> ical.ics
	echo "END:VEVENT" >> ical.ics

done

echo '</channel>\n</rss>' >> rss.xml
echo 'END:VCALENDAR' >> ical.ics

todos ical.ics || exit 1 # Convert iCal to Windows-style newlines, this is required by iCal format
mv -f rss.xml SLAY-Radio-live-shows.xml
rm -f SLAY-Radio-live-shows.xml # RSS feeds are available directly from SLAYRadio.org
mv -f ical.ics SLAY-Radio-live-shows.ics

# Upload it to server

echo "AddType 'text/calendar; charset=UTF-8' .ics" > .htaccess

# If we're running from cronjob, set correct SSH agent variables
eval `keychain --nogui --eval`

# Upload to sourceforge.net
#echo '
#put *.xml
#put *.ics
#put *.sh
#put *.html
#put .htaccess
#exit' | \
#sftp -b - "pelya@web.sourceforge.net:/home/project-web/libsdl-android/htdocs/slay"

# Upload to Github

git commit -a -m "Updated feeds"
git push

MYDIR="`realpath $0`"
MYDIR="`dirname $MYDIR`"
echo "Launch command"
echo "crontab -e"
echo "and add line"
echo "0 0-23/1 * * * cd $MYDIR && ./slay-schedule.sh"
