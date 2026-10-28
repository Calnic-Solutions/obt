# -*- coding: utf-8 -*-
"""Builds the printable phone manual (HTML -> PDF via headless Chrome)
from real emulator screenshots in <shots>/figs/<name>.png."""
import base64
import io
import os
import sys

from PIL import Image, ImageDraw

S = sys.argv[1]
OUT = sys.argv[2]
SHOTS = S + '/figs/'


def img(name, w=400, boxes=()):
    path = SHOTS + name + '.png'
    if not os.path.exists(path):
        return None
    im = Image.open(path).convert('RGB')
    # The button to tap, boxed in red: (x1, y1, x2, y2) in the screenshot's
    # own pixels, drawn before scaling so the line keeps its weight.
    draw = ImageDraw.Draw(im)
    line = max(5, im.width // 110)
    pad = im.width // 90
    for x1, y1, x2, y2 in boxes:
        draw.rounded_rectangle((x1 - pad, y1 - pad, x2 + pad, y2 + pad), radius=pad * 2,
                               outline='#E11D2E', width=line)
    im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
    b = io.BytesIO()
    im.save(b, 'JPEG', quality=82, optimize=True)
    return 'data:image/jpeg;base64,' + base64.b64encode(b.getvalue()).decode()


def fig(name, caption, size='m', boxes=()):
    src = img(name, boxes=boxes)
    if src is None:  # no screenshot of this screen yet: leave it out
        print('missing screenshot:', name)
        return ''
    return ('<figure class="%s"><img src="%s" alt=""><figcaption>%s</figcaption></figure>'
            % (size, src, caption))


def figs(items, size='m'):
    # Each item is (name, caption) or (name, caption, [boxes]).
    return '<div class="row">' + ''.join(fig(it[0], it[1], size, *it[2:]) for it in items) + '</div>'


def logo():
    svg = io.open('assets/brand/livuka-logo-stacked.svg', encoding='utf-8').read()
    return svg.replace('<svg ', '<svg class="logo" ', 1)


def font_faces():
    # Montserrat, the brand face of the app and the website, embedded so the
    # PDF looks the same on any machine that builds it.
    out = []
    for weight, name in ((400, 'Regular'), (500, 'Medium'), (600, 'SemiBold'), (700, 'Bold'), (800, 'ExtraBold')):
        data = base64.b64encode(open('assets/fonts/Montserrat-%s.ttf' % name, 'rb').read()).decode()
        out.append('@font-face { font-family: "Montserrat"; font-weight: %d; src: url(data:font/ttf;base64,%s) format("truetype"); }'
                   % (weight, data))
    return '\n'.join(out)


B = lambda t: '<b class="btn">%s</b>' % t  # a button on screen

CSS = '''
@page { size: A4; margin: 18mm 16mm 18mm 16mm; }
* { box-sizing: border-box; }
body { font-family: "Noto Sans", "Segoe UI", Arial, sans-serif; font-size: 10.5pt; line-height: 1.5; color: #040134; margin: 0; }
h1, h2, h3, .btn, .pill, figcaption, th, .cover { font-family: "Montserrat", "Segoe UI", sans-serif; }
h1 { font-size: 19pt; font-weight: 800; color: #040134; padding-bottom: 6px; margin: 0 0 12px; page-break-after: avoid;
     background: linear-gradient(90deg, #CD572D 0 18mm, #E7E5EE 18mm) bottom / 100% 3px no-repeat; }
h2 { font-size: 12.5pt; font-weight: 700; color: #040134; margin: 18px 0 6px; page-break-after: avoid; }
h2::before { content: ""; display: inline-block; width: 7px; height: 7px; border-radius: 50%; background: #5DA0D3; margin: 0 8px 2px 0; }
h3 { font-size: 11pt; font-weight: 700; margin: 14px 0 4px; page-break-after: avoid; }
p { margin: 5px 0; }
ol, ul { margin: 4px 0 8px; padding-left: 22px; }
li { margin: 3px 0; }
li ul { margin: 2px 0; }
section { page-break-before: always; }
section.first { page-break-before: auto; }
.btn { background: #FBEBE4; color: #A9441F; border-radius: 4px; padding: 0 5px; font-weight: 600; white-space: nowrap; }
.note { border-left: 4px solid #5DA0D3; background: #EAF3FA; border-radius: 6px; padding: 8px 12px; margin: 10px 0; page-break-inside: avoid; }
.note.warn { border-color: #D97706; background: #FEF3C7; }
.note.good { border-color: #15803D; background: #DCFCE7; }
.note.bad { border-color: #DC2626; background: #FEE2E2; }
table { border-collapse: collapse; width: 100%; margin: 8px 0 12px; font-size: 10pt; page-break-inside: auto; }
th, td { border: 1px solid #E5E7EB; padding: 6px 9px; text-align: left; vertical-align: top; }
th { background: #F5F4F1; font-weight: 700; font-size: 9.5pt; }
tr { page-break-inside: avoid; }
.row { display: flex; gap: 10px; justify-content: center; align-items: flex-start; flex-wrap: wrap; margin: 10px 0; page-break-inside: avoid; }
figure { margin: 10px auto; text-align: center; page-break-inside: avoid; }
figure img { border: 6px solid #040134; border-radius: 22px; background: #000; display: block; margin: 0 auto; }
figure.m img { width: 58mm; }
figure.s img { width: 46mm; }
figure.l img { width: 72mm; }
figure.xs img { width: 40mm; border-width: 5px; border-radius: 18px; }
figure.xs { margin: 6px 0; }
figure.xs figcaption { max-width: 39mm; }
figcaption { font-size: 8.5pt; font-weight: 500; color: #4B4870; margin-top: 5px; max-width: 60mm; margin-left: auto; margin-right: auto; }
figure.l figcaption { max-width: 80mm; }
.pill { display: inline-block; background: #FBEBE4; color: #A9441F; border-radius: 999px; padding: 1px 9px; font-size: 9.5pt; font-weight: 600; margin: 2px 2px; }
.arrow { color: #9CA3AF; margin: 0 2px; }
.cover { height: 258mm; display: flex; flex-direction: column; }
.cover .logo { width: 62mm; height: auto; margin: 34mm 0 30mm -3mm; }
.cover h1 { font-size: 30pt; background: none; padding: 0; margin: 0 0 8px; }
.cover .sub { font-size: 13.5pt; font-weight: 500; color: #4B4870; max-width: 140mm; }
.cover .band { margin-top: auto; background: #040134; color: #fff; border-radius: 14px; padding: 9mm 10mm; font-size: 10.5pt; line-height: 1.6;
               display: flex; justify-content: space-between; align-items: flex-end; }
.cover .band b { color: #5DA0D3; font-weight: 700; }
.toc ol { columns: 1; }
.toc li { margin: 2px 0; }
small.muted { color: #4B4870; }
'''


def page(title, body, first=False):
    return '<section%s><h1>%s</h1>%s</section>' % (' class="first"' if first else '', title, body)


html = []
html.append('<!doctype html><html><head><meta charset="utf-8"><title>LIVUKA for Android - User manual</title><style>' + font_faces() + CSS + '</style></head><body>')

# ------------------------------------------------------------- cover
html.append('''<section class="first"><div class="cover">%s
<h1>LIVUKA for Android</h1>
<div class="sub">User manual: installing the app on your phone and doing your work in it</div>
<div class="band"><div><b>Version 0.1.6</b> &middot; October 2026<br>For Drafters, Peer Checkers, Back Translators and Consultants</div><div>&copy; 2026 LIVUKA</div></div>
</div></section>''' % logo())

# ------------------------------------------------------------- contents
html.append(page('Contents', '''
<div class="toc"><ol>
<li>Before you start</li><li>Installing LIVUKA on your phone</li><li>Signing in</li><li>Finding your way around</li>
<li>Sending your work and getting new work</li><li>The Drafter: recording a Set</li><li>The Drafter: a Set that was sent back</li>
<li>The Drafter: Community Setup and Community Test</li><li>The Peer Checker: Peer Check and Community Review</li>
<li>The Back Translator</li><li>The Consultant</li><li>The built-in handbook</li><li>Keeping your work safe</li>
<li>Updating and uninstalling</li><li>Problems and what to do</li>
</ol></div>
<h2>How a Set moves through the team</h2>
<p>Each Set of Bible passages goes through the same stages. Only one person holds a Set at a time. When they finish, they send it on to the next person.</p>
<p><span class="pill">Draft</span><span class="arrow">&rarr;</span><span class="pill">Peer Check</span><span class="arrow">&rarr;</span><span class="pill">Community Setup</span><span class="arrow">&rarr;</span><span class="pill">Community Test</span><span class="arrow">&rarr;</span><span class="pill">Community Review</span><span class="arrow">&rarr;</span><span class="pill">Back Translation</span><span class="arrow">&rarr;</span><span class="pill">Consultant Check</span><span class="arrow">&rarr;</span><span class="pill">Approved</span></p>
<p>A reviewer can <b>send a Set back</b> when something needs to change. It then returns to the Drafter (or, from the Consultant, to the Back Translator) with comments that explain what to fix.</p>
<table><tr><th>Role</th><th>Tiles you work on</th></tr>
<tr><td>Drafter</td><td>Sent back, Draft, Community Setup, Community Test, Feedback, Approved</td></tr>
<tr><td>Peer Checker</td><td>Peer Check, Community Review</td></tr>
<tr><td>Back Translator</td><td>Back Translation</td></tr>
<tr><td>Consultant</td><td>Consultant Check (approve or send back)</td></tr></table>
'''))

# ------------------------------------------------------------- 1 before
html.append(page('1. Before you start', '''
<h2>You need</h2>
<ul>
<li>An <b>Android phone or tablet</b> with Android 7.0 or newer. About <b>60 MB</b> free for the app itself, plus room for the audio of the Sets you are working on (a few hundred MB is typical).</li>
<li>A quiet place to record. The phone&rsquo;s own microphone is fine; a headset microphone gives cleaner takes. Headphones help when you check recordings.</li>
<li>An <b>internet connection</b> (Wi-Fi or mobile data) to download the app, the first time you sign in, and whenever you send your work. You can record and review without internet in between.</li>
<li>Your <b>LIVUKA email address and password</b>. Your project administrator gives you these. They are the same ones you use on the LIVUKA website, and you need them both to download the app and to sign in to it.</li>
<li>The phone&rsquo;s web browser, <b>Chrome</b>. You download the app from the LIVUKA website, <b>obt.calnicsolutions.in/download-app</b> (section 2).</li>
</ul>
<div class="note">You do not need to install anything else. Everything the app needs comes inside the one downloaded file.</div>
<div class="note warn">Download LIVUKA from obt.calnicsolutions.in only. Do not install a LIVUKA file that arrived from anywhere else.</div>
'''))

# ------------------------------------------------------------- 2 install
html.append(page('2. Installing LIVUKA on your phone', '''
<p>LIVUKA is not in the Play Store. You download it from the LIVUKA website on the phone itself and install it from there. Android checks with you several times before it lets such an app in. Every box below is normal. Answer them as shown.</p>
<h2>Download the app</h2>
<ol>
<li>On the phone, open <b>Chrome</b>, tap the address bar at the top and type <b>obt.calnicsolutions.in/download-app</b>. Tap the arrow on the keyboard to go.</li>
<li>The LIVUKA sign-in page opens. Type your LIVUKA <b>email</b> and <b>password</b> and tap %s. If Chrome offers to save the password, you can tap past it.</li>
<li>The <b>Download offline app</b> page opens. (If you are already signed in to the website, you can also reach it from the Workbench: tap the <b>&#8942;</b> three dots at the top right, then <b>Download offline app</b>.)</li>
<li>Under <b>Android app</b>, tap %s.</li>
</ol>
%s
''' % (
    B('Sign in'), B('Download'),
    figs([('w-menu', 'From the website: &#8942; &rarr; Download offline app.', [(316, 423, 703, 510)]), ('w-download', 'Under Android app, tap Download.', [(270, 968, 450, 1022)])], 'm'),
)))

html.append(page('2. Installing LIVUKA on your phone (continued)', '''
<ol start="5">
<li>Chrome asks <b>&ldquo;File might be harmful&rdquo;</b>, because it is an app file. It comes from the LIVUKA website, so tap %s.</li>
<li>When the download has finished, <b>File downloaded</b> appears at the top of the screen for a few seconds. Tap %s. (Missed it? Tap Chrome&rsquo;s <b>&#8942;</b> &rarr; <b>Downloads</b> and tap the LIVUKA file.)</li>
</ol>
<h2>Install the app</h2>
<ol start="7">
<li>The first time, Android says <b>&ldquo;For your security, your phone is not allowed to install unknown apps from this source&rdquo;</b>. Tap %s.</li>
<li>Switch on <b>Allow from this source</b>, then tap the <b>&larr;</b> back arrow at the top left. You only do this once; you can switch it off again later under <b>Settings &rarr; Apps &rarr; Special app access &rarr; Install unknown apps &rarr; Chrome</b>.</li>
</ol>
%s
''' % (
    B('Download anyway'), B('Open'), B('Settings'),
    figs([('w-harmful', 'File might be harmful: tap Download anyway.', [(424, 855, 663, 939)]),
          ('w-unknown', 'Not allowed from this source: tap Settings.', [(519, 840, 652, 915)]), ('w-allow', 'Switch on Allow from this source, then go back.', [(608, 428, 690, 476)])], 'xs'),
)))

html.append(page('2. Installing LIVUKA on your phone (continued)', '''
<ol start="9">
<li>The box <b>&ldquo;Do you want to install this application?&rdquo;</b> shows the LIVUKA icon. Tap %s.</li>
<li><b>App installed.</b> Tap %s to start LIVUKA now. Later, open it from the LIVUKA icon in your app list. The app opens on its own sign-in page (section 3).</li>
</ol>
<div class="note">Some phones show <b>Google Play Protect</b> after Install: <b>&ldquo;App scan recommended&rdquo;</b> &mdash; tap <b>Scan app</b>, and when it says <b>&ldquo;This app looks safe&rdquo;</b>, tap <b>Install</b>. Older phones may show <b>&ldquo;Blocked by Play Protect&rdquo;</b>: tap <b>More details</b> and then <b>Install anyway</b>.</div>
<h2>Let the app use your microphone</h2>
<p>The first time you record, Android asks <b>&ldquo;Allow LIVUKA to record audio?&rdquo;</b>. Tap <b>While using the app</b>. If you tapped <b>Don&rsquo;t allow</b> by mistake, the record button says <i>Microphone is off</i>: tap <b>Open settings</b>, choose <b>Permissions &rarr; Microphone &rarr; Allow only while using the app</b>, and come back.</p>
%s
''' % (
    B('Install'), B('Open'),
    figs([('w-install', 'Do you want to install this application? Tap Install.', [(540, 850, 652, 925)]), ('w-installed', 'App installed: tap Open.', [(540, 850, 652, 925)]),
          ('m-mic-permission', 'The first recording asks for the microphone. Tap While using the app.', [(137, 1107, 943, 1239)])], 's'),
)))

# ------------------------------------------------------------- 3 sign in
html.append(page('3. Signing in', '''
<ol>
<li>Type your <b>email</b> and <b>password</b>. Tap the eye icon to check what you typed.</li>
<li>Tap %s.</li>
<li>The app now <b>collects your data</b>: the source audio, the scripts, recordings, questions and comments for your Sets. The bar counts the files. The first download can take a few minutes on a slow connection. Keep the app open until it reaches 100%%.</li>
</ol>
%s
<h2>If some files did not download</h2>
<p>A weak connection can stop a few files. The app then lists every file it could not get: which Set and passage it belongs to, what it is used for, and what went wrong. For each one choose %s (fetch it once more) or %s (go on without it). %s and the big button at the bottom do all files at once.</p>
<p>A skipped file is fetched again at the next <b>Check for updates</b>, so nothing is lost &mdash; but a passage whose source audio is missing cannot be recorded until then.</p>
%s
<div class="note">You sign in every time you open the app. With internet the server checks your password; without it the phone checks it against your last sign-in, and your work is there as you left it. The first sign-in on a phone needs internet, because that is when your work is downloaded.</div>
''' % (
    B('Sign in'),
    figs([('m-login-empty', 'The sign-in screen.', [(66, 1549, 1014, 1686)]), ('i-loading', 'Collecting your data. Wait until it finishes.')]),
    B('Try again'), B('Skip'), B('Try all again'),
    figs([('n-dlprob', 'Files that did not download, each with Try again and Skip.', [(129, 979, 951, 1086)])]),
)))

# ------------------------------------------------------------- 4 around
html.append(page('4. Finding your way around', '''
<p>After the download you see the <b>Workbench</b>. Each tile is one list of Sets waiting for you and shows how many are there. The tile with the soft pulsing glow is where the app suggests you go next. Tap a tile to see its Sets.</p>
%s
<h2>The bar at the top</h2>
<table><tr><th>Item</th><th>What it does</th></tr>
<tr><td><b>&larr;</b> Back arrow</td><td>Goes back one screen. The phone&rsquo;s own back gesture does the same.</td></tr>
<tr><td>Home icon</td><td>Goes straight back to the Workbench.</td></tr>
<tr><td><b>EN | SRC</b></td><td>Shows the names of books and Sets in English or in the source language.</td></tr>
<tr><td><b>&#8942;</b> three dots</td><td>Opens <b>Settings</b>: your languages and roles, the app language (English, Hindi or Urdu), storage used, Sync status, the User manual, and Sign out.</td></tr></table>
%s
<h2>Choosing a Set</h2>
<p>Inside a tile, the Sets waiting for you are shown as cards with their progress. The box at the top, <b>Jump to a pending work item</b>, lists every Set you still have to do; pick one to go straight to it.</p>
''' % (
    figs([('n-home', 'A Drafter’s Workbench. Nothing waits to be sent, so the bar says Check for updates.', [(560, 352, 1030, 821)]), ('m-sentback-list', 'The Sent back tile opened: the Set says which stage returned it.', [(49, 270, 1030, 790)])]),
    figs([('n-drawer', 'Settings, behind the three dots.'), ('m-draft-list2', 'The Draft tile: a Set card with its progress bar.', [(49, 580, 1030, 1113)])]),
)))

# ------------------------------------------------------------- 5 send
html.append(page('5. Sending your work and getting new work', '''
<p>LIVUKA keeps your work on the phone until you send it. Nothing leaves the phone on its own, so you can keep working where there is no internet.</p>
<p>The <b>bar at the bottom of the Workbench</b> does the sending. It only appears while the phone has internet; without it you see a grey line such as <i>No network. 3 changes are waiting to be sent.</i></p>
<ul>
<li><b>Send (3)</b> &mdash; three Sets have changes on this phone: new takes, final choices, comments, questions, answers, verdicts, back translations or stage moves. <b>Slide the orange knob to the right</b> (do not just tap). Keep the screen open until it finishes.</li>
<li><b>Check for updates</b> &mdash; shown when nothing is waiting. Sliding it fetches new work: Sets assigned to you, Sets sent back to you, and files skipped earlier. Sets that are no longer yours are removed from the phone with their audio.</li>
</ul>
<p>Each send also carries the time you worked and a record of what you did (for example &ldquo;take recorded&rdquo;), for your administrator&rsquo;s reports.</p>
%s
<div class="note good">When you move a Set to the next stage, it leaves your list at once &mdash; but the next person only receives it after you slide <b>Send</b>.</div>
<h2>Sync status</h2>
<p>Open <b>&#8942; &rarr; Sync status</b> to see what is still waiting and when the last full send was. If the server refused a Set, it is listed with the reason in red, and your work on it stays on the phone. Two buttons can appear: %s keeps a copy of that Set&rsquo;s recordings in the phone&rsquo;s Download folder, and %s discards the refused work (only when the server cannot ever accept it).</p>
''' % (
    figs([('m-home-send', 'Four Sets waiting: slide Send.', [(50, 2021, 1031, 2176)]), ('n-offline', 'No internet: the bar is gone until the phone is connected.'), ('n-sync', 'Sync status when everything has been sent.')], 's'),
    B('Save recordings'), B('Give up this work'),
)))

# ------------------------------------------------------------- 6 draft
html.append(page('6. The Drafter: recording a Set', '''
<p>Open <b>Draft</b> and tap a Set. You see its passages. Each one shows whether it is <b>Not started</b>, has takes, or is <b>Finalized</b>. The grey note at the top says how many still need a final take.</p>
<h2>Recording a passage</h2>
<p>Tap %s on a passage. The passage screen has the <b>source audio</b>, the <b>source script</b> and the <b>target script</b> at the top, the take strip below, and the record button at the bottom. The microphone stays grey until you have listened and read:</p>
<ol>
<li><b>Listen</b> to the source audio all the way to the end. Tap the waveform to jump to a spot; <b>1x</b> changes the speed.</li>
<li><b>Read</b> the source script and the target script, and tick <b>I have read</b> under each one. The arrows in the corners open a script full screen.</li>
<li>Tap the orange <b>microphone</b> and speak the passage. A red clock counts the seconds. The orange button <b>pauses</b>; the red button <b>stops</b> and saves the take.</li>
<li>The app checks the take at once (<b>Automated QC</b>): clipping, silence at the ends, noise, length against the source, whether a voice was found, even volume. Green ticks pass, red crosses tell you what to fix. The take gets <b>QC: Good</b> or <b>QC: Bad</b>.</li>
<li>You can record up to <b>6 takes</b> per passage. The squares in the strip show which are recorded.</li>
</ol>
%s
<div class="note">The phone remembers that you heard the source and read the scripts for this round of the Set. Coming back tomorrow to record take three, you go straight to the microphone.</div>
''' % (
    B('Record'),
    figs([('m-set-new', 'A new Set with three passages.', [(728, 479, 1003, 580)]), ('m-recorder', 'Before listening: the microphone is grey.', [(62, 392, 162, 502)]), ('m-ready2', 'Both scripts ticked: ready to record.', [(808, 1990, 982, 2164)])], 's'),
)))

html.append(page('6. The Drafter: recording a Set (continued)', '''
%s
<h2>Choosing the final take</h2>
<p>Tap any square in the take strip to open the <b>Takes</b> page. Every take has its own player, a magnifier (runs the QC again and shows the checks), a <b>star</b> and a red <b>bin</b>.</p>
<ul>
<li>Play each take and tap the <b>star</b> on the best one: it turns green and the take is marked <b>Final</b>. Only a take graded <b>Good</b> can be made Final; on a Bad take the star stays grey and the reason is written on the card. Tap the star again to un-mark it.</li>
<li>The bin deletes a take. It asks first; a deleted take cannot be brought back.</li>
<li><b>Not synced</b> on a take means it is still only on this phone.</li>
<li>Use the round <b>&rsaquo;</b> arrow at the edge of the screen to move to the next passage, or the back arrow to the Set page.</li>
</ul>
%s
<h2>Sending the Set to Peer Check</h2>
<p>When every passage is Finalized, the Set page shows the <b>Target Recording</b>: all the final takes joined together. Play it to the end. The %s button then turns on. Tap it and confirm with <b>Send</b>. Then slide <b>Send</b> on the Workbench when you have internet.</p>
<p>Sets the Consultant has approved appear under <b>Approved</b>. Open one and tap %s to fetch its finished recording and hear it in the app.</p>
''' % (
    figs([('m-recording', 'Recording: pause (orange) and stop (red).', [(808, 1990, 982, 2164)]), ('m-qc', 'A bad take: the QC says what went wrong.'), ('m-qc-good', 'A good take.')], 's'),
    figs([('m-final', 'The Takes page: take 6 is Final.', [(779, 459, 889, 553)]), ('m-delete-dialog', 'Deleting a take asks first.', [(154, 1278, 524, 1399)]), ('549-takes', 'All passages final: hear the Target Recording, then send.', [(88, 1052, 190, 1156), (44, 2016, 1036, 2176)])], 's'),
    B('Send to Peer Check'), B('Listen'),
)))

# ------------------------------------------------------------- 7 sent back
html.append(page('7. The Drafter: a Set that was sent back', '''
<p>A Set that a reviewer sent back appears on the red <b>Sent back</b> tile, with a badge saying how long ago. At the top of the Set it says who sent it back, and the reviewer&rsquo;s comments are shown in a red box: from Community Review you see the question, the community&rsquo;s answer and the reviewer&rsquo;s reply, with a play button for each voice message. Passages that need a new take are outlined in red.</p>
<ol>
<li>Tap %s on a red passage. On the Takes page the old final take is marked <b>Sent back</b> with the reason, and a red <b>pin</b> on its waveform marks the exact spot of the comment. Tap the pin to read or hear the whole comment.</li>
<li>Record a new take and make it Final. The old take stays for comparison until you delete it.</li>
<li>When every passage has a Final take again, play the Target Recording to the end and send the Set on. The button says where it goes: back to <b>Peer Check</b>, or straight to <b>the Back Translator</b> when it was the Back Translator who returned it.</li>
<li>Slide <b>Send</b> on the Workbench.</li>
</ol>
%s
<h2>Feedback</h2>
<p>When a Community Reviewer <b>liked</b> an answer and added a comment for you, the <b>Feedback</b> tile shows it. Open the Set: a thumbs-up marker on the Target Recording shows where the praised answer belongs, and the question, answer and the reviewer&rsquo;s comment are listed under it. Nothing needs to be done with it &mdash; it is the only good news that travels back down the line.</p>
%s
''' % (
    B('Re-record'),
    figs([('m-sentback-set', 'Who sent it back, and the outlined passage.', [(728, 586, 1003, 688)]), ('548-set7', 'The returned take with its pin.', [(400, 875, 478, 1010)]), ('553-popup', 'The full comment, from the pin.', [(771, 2126, 1025, 2247)])], 's'),
    figs([('63-feedback-set', 'A Set under Feedback: the liked answer and the reviewer’s comment.')], 's'),
)))

# ------------------------------------------------------------- 8 community
html.append(page('8. The Drafter: Community Setup and Community Test', '''
<h2>Community Setup: writing the questions</h2>
<p>After Peer Check the Set comes back to you under <b>Community Setup</b>. Here you prepare the questions you will ask the community.</p>
<ul>
<li>Play the <b>Target Recording</b> and stop where a question belongs, then tap %s. The question is <b>pinned</b> at that spot (the sheet says <i>Pinned at 0:08</i>). Choose <b>Voice</b> and tap the red microphone to record it, or <b>Text</b> and type it, then <b>Save</b>.</li>
<li>%s asks about the whole Set. General questions are listed under the player; the red bin removes one.</li>
<li>Tap %s, confirm, then slide <b>Send</b> on the Workbench.</li>
</ul>
<div class="note">If the Set comes back after Community Review sent it back, Community Setup starts empty. The previous questions were about the old recording, so you write new ones.</div>
%s
<h2>Community Test: asking the community</h2>
<ol>
<li>Sit with the community and play the whole recording. The questions appear only after it has been heard to the end.</li>
<li>Tap %s under each question. Record the community&rsquo;s answer with <b>Voice</b> or type it with <b>Text</b>, then <b>Save</b>.</li>
<li>When every question is answered the bottom button becomes %s. Tap it, confirm, then slide <b>Send</b> when you have internet again.</li>
</ol>
%s
''' % (
    B('Add a question here'), B('Add a general question'), B('Send to Community Test'),
    figs([('533-setup', 'Community Setup with a general question.'), ('506-qsheet', 'The question sheet: Voice or Text.')], 's'),
    B('Answer'), B('Send to Community Review'),
    figs([('535-test', 'Community Test: one answered, one to go.'), ('512-answer-sheet', 'The answer sheet.')], 's'),
)))

# ------------------------------------------------------------- 9 peer
html.append(page('9. The Peer Checker: Peer Check and Community Review', '''
<h2>Peer Check</h2>
<p>Open a Set under <b>Peer Check</b>. The page shows the <b>Source script</b>, the <b>Target script</b>, the <b>Source audio</b> and the Drafter&rsquo;s <b>Target Recording</b>. The scripts follow the passage that is playing.</p>
<ol>
<li>Play <b>both</b> recordings to the end.</li>
<li>If something needs to change, stop at that spot and tap %s. Say it with <b>Voice</b> or type it, then <b>Save</b>. A pin appears on the waveform; tap it to review or delete the note.</li>
<li>Then choose: %s if you left notes, or %s if the recording is good. Open notes block the forward button &mdash; delete them, or send the Set back. Confirm, then slide <b>Send</b>.</li>
</ol>
%s
<h2>Community Review</h2>
<p>After the Community Test the Set comes to you under <b>Community Review</b>. Each card shows a question and the community&rsquo;s answer; voice ones have a play button.</p>
<ul>
<li>Tap %s when an answer shows the community understood. You may add a comment for the Drafter; it reaches them under <b>Feedback</b>.</li>
<li>Tap %s when they did not, and say what is wrong. The Drafter works from your comment.</li>
<li>Liked every answer? Tap %s. Disliked any? Tap %s. A question with no answer blocks both; the grey line above the buttons tells you.</li>
</ul>
%s
''' % (
    B('Add a note here'), B('Send back to the Drafter'), B('Send to Community Setup'),
    figs([('530-peercheck', 'Peer Check: both recordings and both scripts.', [(83, 1730, 998, 1857)]), ('275-voice-sheet', 'The note sheet, pinned at the spot you stopped.', [(50, 2099, 1031, 2231)])], 's'),
    B('Like'), B('Dislike'), B('Send to Back Translation'), B('Send back to the Drafter'),
    figs([('536-review2', 'Community Review: Like or Dislike each answer.', [(87, 945, 993, 1071)]), ('518-dislike', 'Dislike asks what is wrong.', [(50, 2099, 1031, 2231)])], 's'),
)))

# ------------------------------------------------------------- 10 BT
html.append(page('10. The Back Translator', '''
<p>Only the target audio is downloaded for this role &mdash; no source audio and no questions &mdash; so signing in is quick. Open a Set under <b>Back Translation</b>. The page shows the <b>Target Recording</b> at the top and a <b>Back translation</b> card under it (<i>text or voice &mdash; either is fine</i>).</p>
<ol>
<li>Play the <b>Target Recording</b> to the end. The submit button stays off until the whole recording has been heard.</li>
<li>Type the back translation into the box, or tap %s and speak it. You may do both. It is saved on the phone as you go.</li>
<li>If the Consultant sent the Set back, the card <b>The Consultant sent this back</b> lists their comments. Play each one and tap %s to answer it (voice or text). Submitting a new back translation closes those comments.</li>
<li>Tap %s, confirm with <b>Submit</b>, then slide <b>Send</b> on the Workbench.</li>
</ol>
<p>If the <b>recording itself</b> has a problem, stop at that spot and tap %s under the player, then %s. The Drafter fixes the passage and the Set comes straight back to you. An open comment of your own blocks Submit: send the Set back or delete the comment first.</p>
<div class="note">Audio never plays while you record. Starting a recording pauses anything that is playing.</div>
''' % (B('Tap to record audio'), B('Reply'), B('Submit to Consultant'), B('Not satisfied? Comment on it'), B('Send back to the Drafter'))))

# ------------------------------------------------------------- 11 consultant
html.append(page('11. The Consultant', '''
<p>Open a Set under <b>Consultant Check</b>. From the top: the <b>Source script</b>, the <b>Source audio</b>, the <b>Target script</b>, the <b>Target Recording</b>, and the <b>Back translation</b> with its text and recording. Under it are <b>Your comments</b> and the Back Translator&rsquo;s replies.</p>
<ol>
<li>Play the back translation recording to the end (Approve waits until it has been heard). Compare it with the source.</li>
<li>If something needs to change, tap %s. Voice or text, then <b>Save</b>. Add as many as you need; the bin deletes your own.</li>
<li>Then choose:
<ul><li>%s when all is well. Open comments block Approve, so delete them first. The Set moves to <b>Approved</b>.</li>
<li>%s when you left comments. Confirm with <b>Send back</b>. The Back Translator replies to each comment; when the Set returns you see the earlier round in grey with their replies under it.</li></ul></li>
<li>Slide <b>Send</b> on the Workbench.</li>
</ol>
''' % (B('Comment on the back translation'), B('Approve'), B('Send back to the Back Translator'))))

# ------------------------------------------------------------- 12 handbook
html.append(page('12. The built-in handbook', '''
<p>The app carries its own handbook, with short animated demos of every screen: watch the hand tap, then do the same on your phone. It works without internet.</p>
<ol>
<li>Tap the <b>&#8942;</b> three dots on any screen.</li>
<li>Under <b>Help</b>, tap <b>User manual</b>.</li>
<li>Use the <b>Steps</b> button to jump to a stage, or the search box to find a word. The <b>&larr;</b> arrow in the handbook&rsquo;s own bar brings you back to the app.</li>
</ol>
%s
''' % figs([('n-drawer', 'Settings: User manual under Help.', [(250, 1408, 1066, 1598)]), ('r-manual', 'The handbook inside the app.', [(795, 227, 1041, 340)]), ('m-steps', 'The Steps menu.')], 's')))

# ------------------------------------------------------------- 13 safe
html.append(page('13. Keeping your work safe', '''
<ul>
<li><b>Files stay inside the app.</b> Everything the app keeps on the phone (audio, scripts, your takes) is in its private storage, where other apps and the Files app cannot see it, and it is encrypted whenever you are signed out. Your sign-in is kept in the phone&rsquo;s secure keystore.</li>
<li><b>Nothing is kept longer than needed.</b> After a Check for updates the app removes Sets that are no longer yours, with their audio. Approved Sets keep only their list entry; the audio comes down again when you tap Listen.</li>
<li><b>No exports.</b> The app does not save recordings or scripts to Download or anywhere else, because the content is sensitive. The one exception is <b>Save recordings</b> on Sync status, for work the server refused.</li>
<li><b>Signing out keeps your work.</b> The sign-out box only asks whether you are sure. Your Sets, recordings and unsent work stay on the phone, locked, until you sign in again. The app also signs you out by itself after 15 minutes without a touch.</li>
<li><b>Do not share your sign-in.</b> Everything you do is recorded against your name.</li>
</ul>
%s
<div class="note">LIVUKA also records the time you spend on each stage and what you did (for example &ldquo;take recorded&rdquo; or &ldquo;sent to Peer Check&rdquo;). This goes to your administrator&rsquo;s reports with each send. Time only counts while a stage screen is open and you are touching the phone.</div>
''' % figs([('306-signout', 'The sign-out box: tap Sign Out. Cancel keeps you signed in.', [(644, 1201, 884, 1333)])], 's')))

# ------------------------------------------------------------- 14 update
html.append(page('14. Updating and uninstalling', '''
<h2>Installing a new version</h2>
<ol>
<li>Slide <b>Send</b> so nothing is waiting to be sent.</li>
<li>Download the new version from <b>obt.calnicsolutions.in/download-app</b> and open it, exactly as in section 2. Android asks <b>&ldquo;Do you want to update this app?&rdquo;</b>; tap <b>Update</b> (or <b>Install</b>). You stay signed in and your work is kept.</li>
</ol>
<div class="note warn">Never uninstall the old version first to update &mdash; uninstalling deletes everything the app holds, including unsent work.</div>
<h2>Uninstalling</h2>
<ol>
<li>Slide <b>Send</b>, then sign out (<b>&#8942; &rarr; Sign out</b>).</li>
<li>Touch and hold the LIVUKA icon and choose <b>Uninstall</b>, or open <b>Settings &rarr; Apps &rarr; LIVUKA &rarr; Uninstall</b>.</li>
</ol>
'''))

# ------------------------------------------------------------- 15 problems
html.append(page('15. Problems and what to do', '''
<table><tr><th style="width:38%%">What you see</th><th>What to do</th></tr>
<tr><td>&ldquo;Not allowed to install unknown apps&rdquo; when opening the downloaded file</td><td>Tap <b>Settings</b> on that box and switch on <b>Allow from this source</b> for Chrome (section 2).</td></tr>
<tr><td>Play Protect: &ldquo;App scan recommended&rdquo; or &ldquo;Blocked&rdquo;</td><td>Tap <b>Scan app</b>, then <b>Install</b>. On older phones: <b>More details &rarr; Install anyway</b> (section 2).</td></tr>
<tr><td>&ldquo;App not installed&rdquo;</td><td>The phone is out of space, or the file was cut short while it was being sent. Free some space and download the APK again.</td></tr>
<tr><td>Sign-in fails</td><td>Check the internet connection, and the email and password (use the eye icon). If it still fails, ask your administrator to check your account.</td></tr>
<tr><td>Some files did not download</td><td>Choose <b>Try again</b> or <b>Skip</b> in the list. Skipped files come with the next <b>Check for updates</b>.</td></tr>
<tr><td>The microphone button is grey</td><td>Read the text beside it: play the source to the end, tick <b>I have read</b> under both scripts, or all six takes are used &mdash; delete one.</td></tr>
<tr><td>&ldquo;Microphone is off&rdquo;</td><td>Tap <b>Open settings</b> and allow the microphone for LIVUKA (section 2). Then record again.</td></tr>
<tr><td>A take is graded <b>Bad</b></td><td>Open the QC. Record in a quiet room, hold the phone close, speak clearly and the whole passage. A silent or very short take never passes.</td></tr>
<tr><td>A Send button is grey</td><td>Play the recording to the end first. Also check that every passage is Finalized, every question is answered, and no comment is still open. The grey line above the button says what is missing.</td></tr>
<tr><td>The Send bar is missing on the Workbench</td><td>The phone has no internet. Connect, and the bar comes back.</td></tr>
<tr><td>A Set would not send</td><td>Open <b>&#8942; &rarr; Sync status</b> for the reason. Usually the Set was changed on the website meanwhile: slide <b>Check for updates</b>, then <b>Send</b> again. Your work stays on the phone until it goes.</td></tr>
<tr><td>I cannot see a Set I expect</td><td>Slide <b>Check for updates</b>. If it is still missing, the previous person may not have sent it yet.</td></tr>
<tr><td>The app was closed while recording</td><td>Open the passage again: the recording made so far is recovered and saved as a take.</td></tr>
<tr><td>The waveform does not appear at once</td><td>Long recordings take a moment to draw the first time. Playing works meanwhile.</td></tr>
</table>
<p>For anything else, contact your project administrator, or open the built-in handbook (<b>&#8942; &rarr; User manual</b>).</p>
'''))

html.append('</body></html>')
io.open(OUT, 'w', encoding='utf-8').write(''.join(html))
print('wrote', OUT)
