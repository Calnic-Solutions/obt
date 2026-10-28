/// Urdu. Keys are the English sentences exactly as the screens write them.
///
/// "Set", "Final", "QC" and "take" are left as the team says them - they are
/// the project's own words, used aloud in training, and a translated term
/// nobody has heard before is harder to follow than the one they know.
const Map<String, String> ur = {
  // ---- stages
  'Draft': 'مسودہ',
  'Sent back': 'واپس بھیجا گیا',
  'New Draft': 'نیا مسودہ',
  'In Progress': 'جاری ہے',
  'User Manual': 'صارف رہنما',
  'Peer Check': 'ساتھی کی جانچ',
  'Community Setup': 'کمیونٹی کی تیاری',
  'Community Test': 'کمیونٹی ٹیسٹ',
  'Community Review': 'کمیونٹی کا جائزہ',
  'Back Translation': 'واپسی ترجمہ',
  'Consultant Check': 'کنسلٹنٹ کی جانچ',
  'Finished': 'مکمل',
  'Feedback': 'رائے',
  'Workbench': 'ورک بینچ',

  // ---- roles
  'Drafter': 'مسودہ نگار',
  'Peer checker': 'ساتھی جانچ کار',
  'Back translator': 'واپسی مترجم',
  'Consultant': 'کنسلٹنٹ',

  // ---- stage actions
  'Send to Peer Check': 'ساتھی کی جانچ کو بھیجیں',
  'Send to the Back Translator': 'واپسی مترجم کو بھیجیں',
  'Send back to the Drafter': 'مسودہ نگار کو واپس بھیجیں',
  'Send to Community Setup': 'کمیونٹی کی تیاری کو بھیجیں',
  'Send to Community Test': 'کمیونٹی ٹیسٹ کو بھیجیں',
  'Send to Community Review': 'کمیونٹی کے جائزے کو بھیجیں',
  'Send to Back Translation': 'واپسی ترجمے کو بھیجیں',
  'Submit to Consultant': 'کنسلٹنٹ کو جمع کرائیں',
  'Send back to the Back Translator': 'واپسی مترجم کو واپس بھیجیں',
  'Approve': 'منظور کریں',

  // ---- confirmations
  'Send this Set to Peer Check?': 'کیا یہ Set ساتھی کی جانچ کو بھیجیں؟',
  'Send this Set to Community Test?': 'کیا یہ Set کمیونٹی ٹیسٹ کو بھیجیں؟',
  'Send this Set to Community Review?':
      'کیا یہ Set کمیونٹی کے جائزے کو بھیجیں؟',
  'Send this Set to Community Setup?': 'کیا یہ Set کمیونٹی کی تیاری کو بھیجیں؟',
  'Send this Set to Back Translation?': 'کیا یہ Set واپسی ترجمے کو بھیجیں؟',
  'Send this Set to the Back Translator?': 'کیا یہ Set واپسی مترجم کو بھیجیں؟',
  'Submit this back translation to the Consultant?':
      'کیا یہ واپسی ترجمہ کنسلٹنٹ کو جمع کرائیں؟',
  'Approve this Set? It will be marked finished.':
      'کیا یہ Set منظور کریں؟ اسے مکمل قرار دے دیا جائے گا۔',
  'Send this Set back to the Drafter?': 'کیا یہ Set مسودہ نگار کو واپس بھیجیں؟',
  'Send this Set back to the Back Translator?':
      'کیا یہ Set واپسی مترجم کو واپس بھیجیں؟',
  'Remove Final from this take? You can mark a different one Final afterward.':
      'کیا اس take سے Final ہٹائیں؟ آپ بعد میں کسی اور کو Final بنا سکتے ہیں۔',
  'Remove this take? This cannot be undone.':
      'کیا یہ take ہٹائیں؟ یہ واپس نہیں ہو سکتا۔',
  "Delete this comment? This can't be undone.":
      'کیا یہ تبصرہ حذف کریں؟ یہ واپس نہیں ہو سکتا۔',
  'Send': 'بھیجیں',
  'Send back': 'واپس بھیجیں',
  'Submit': 'جمع کرائیں',
  'Yes': 'ہاں',
  'Remove': 'ہٹائیں',
  'Delete': 'حذف کریں',
  'Cancel': 'منسوخ',
  'Close': 'بند کریں',
  'Reply': 'جواب دیں',
  'Try again': 'دوبارہ کوشش کریں',

  // ---- listen gates and other reasons a button is held
  'Play the source audio to the end before the first take.':
      'پہلے take سے پہلے اصل آڈیو آخر تک سنیں۔',
  'Play the recording to the end before deciding.':
      'فیصلہ کرنے سے پہلے ریکارڈنگ آخر تک سنیں۔',
  'Play the target recording to the end before sending it on.':
      'آگے بھیجنے سے پہلے ہدف ریکارڈنگ آخر تک سنیں۔',
  'Play the target recording to the end first.':
      'پہلے ہدف ریکارڈنگ آخر تک سنیں۔',
  'Play the target recording to the end before submitting.':
      'جمع کرانے سے پہلے ہدف ریکارڈنگ آخر تک سنیں۔',
  'Play the back translation recording to the end before approving.':
      'منظور کرنے سے پہلے واپسی ترجمے کی ریکارڈنگ آخر تک سنیں۔',
  'Skipping ahead does not count - play from where you left off to finish '
          'listening.':
      'آگے چھلانگ لگانا شمار نہیں ہوتا - جہاں چھوڑا تھا وہیں سے سن کر پورا کریں۔',
  'Leave a comment on the recording to send it back.':
      'واپس بھیجنے کے لیے ریکارڈنگ پر تبصرہ کریں۔',
  'Write or record the back translation before submitting it.':
      'جمع کرانے سے پہلے واپسی ترجمہ لکھیں یا ریکارڈ کریں۔',
  'You have open comments on the recording - send it back to the Drafter, '
          'or delete them first.':
      'ریکارڈنگ پر آپ کے کھلے تبصرے ہیں - اسے مسودہ نگار کو واپس بھیجیں، یا '
      'پہلے انہیں حذف کریں۔',
  'An open comment blocks Approve. Delete it, or send the Set back to the '
          'Back Translator.':
      'کھلا تبصرہ منظوری کو روکتا ہے۔ اسے حذف کریں، یا Set واپسی مترجم کو واپس '
      'بھیجیں۔',
  'There is no back translation to approve yet.':
      'ابھی منظور کرنے کے لیے کوئی واپسی ترجمہ نہیں ہے۔',
  'Comment on the back translation to send it back.':
      'واپس بھیجنے کے لیے واپسی ترجمے پر تبصرہ کریں۔',
  'Dislike at least one answer first, so the Drafter knows what to fix.':
      'پہلے کم از کم ایک جواب کو ناپسند کریں، تاکہ مسودہ نگار کو معلوم ہو کیا '
      'درست کرنا ہے۔',
  'A disliked answer has to go back to the Drafter - it cannot go on to Back '
          'Translation.':
      'ناپسند کیا گیا جواب مسودہ نگار کو واپس جانا ہے - یہ واپسی ترجمے کو نہیں '
      'جا سکتا۔',
  'Like every answer before sending this on.':
      'آگے بھیجنے سے پہلے ہر جواب کو پسند کریں۔',
  'No answer yet.': 'ابھی کوئی جواب نہیں۔',
  'Like': 'پسند',
  'Dislike': 'ناپسند',
  'A Dislike needs a comment.': 'ناپسند کے ساتھ تبصرہ ضروری ہے۔',
  'Only a take graded Good can be made Final.':
      'صرف وہی take جسے Good ملا ہو Final بن سکتا ہے۔',
  'Tap to record a take': 'take ریکارڈ کرنے کے لیے دبائیں',
  'Microphone is off - tap to try again':
      'مائیکروفون بند ہے - دوبارہ کوشش کے لیے دبائیں',

  // ---- sync
  'Sync status': 'ہم آہنگی کی حالت',
  'Help': 'مدد',
  'User manual': 'صارف دستی',
  'How to do each stage on this phone': 'اس فون پر ہر مرحلہ کیسے کریں',
  'Check for updates': 'تازہ کاری دیکھیں',
  'Done Synchronization.': 'ہم آہنگی مکمل ہوئی۔',
  'Everything is up to date.': 'سب کچھ تازہ ہے۔',
  'Everything has been sent.': 'سب کچھ بھیج دیا گیا ہے۔',
  'No connection': 'کنکشن نہیں ہے',
  'Waiting': 'انتظار میں',
  'Not sent': 'نہیں بھیجا گیا',
  'Save recordings': 'ریکارڈنگز محفوظ کریں',
  'Not sent. Your work stays on this phone until there is a connection.':
      'نہیں بھیجا گیا۔ کنکشن ملنے تک آپ کا کام اسی فون پر محفوظ ہے۔',

  // ---- settings
  'Settings': 'ترتیبات',
  'App language': 'ایپ کی زبان',
  'Roles': 'کردار',
  'Languages': 'زبانیں',
  'Sign Out': 'سائن آؤٹ',

  // ---- workbench and sending
  'The Offline OBT App': 'آف لائن OBT ایپ',
  'Starting up...': 'شروع ہو رہا ہے...',
  'The audio Bible translation recorder, powered by AI':
      'آڈیو بائبل ترجمہ ریکارڈر، AI کی مدد سے',
  '@count Set': '@count Set',
  '@count Sets': '@count Set',
  'Nothing assigned to you yet.\nAsk your admin.':
      'ابھی آپ کو کوئی کام نہیں دیا گیا۔\nاپنے ایڈمن سے پوچھیں۔',
  'Nothing assigned to you here yet.': 'یہاں ابھی آپ کو کوئی کام نہیں دیا گیا۔',
  'Send (@count)': 'بھیجیں (@count)',
  'Send now (@count)': 'ابھی بھیجیں (@count)',
  'Sending...': 'بھیجا جا رہا ہے...',
  'Sending Set @index of @total...':
      '@total میں سے Set @index بھیجا جا رہا ہے...',
  'Checking with the server...': 'سرور سے پوچھا جا رہا ہے...',
  'Checking for updates...': 'تازہ کاری دیکھی جا رہی ہے...',
  'Keep this screen open until it finishes.':
      'مکمل ہونے تک یہ اسکرین کھلی رکھیں۔',
  'Still sending. Please wait until this finishes.':
      'ابھی بھیجا جا رہا ہے۔ براہ کرم مکمل ہونے تک انتظار کریں۔',
  'A recording that was interrupted has been recovered. You will '
          'find it among the takes.':
      'جو ریکارڈنگ بیچ میں رک گئی تھی وہ واپس مل گئی ہے۔ وہ آپ کو takes '
      'میں ملے گی۔',
  'A recording that was interrupted has been recovered for @passage. '
          'You will find it among the takes.':
      '@passage کی جو ریکارڈنگ بیچ میں رک گئی تھی وہ واپس مل گئی ہے۔ وہ '
      'آپ کو takes میں ملے گی۔',
  'The update check failed: @reason': 'تازہ کاری نہیں دیکھی جا سکی: @reason',
  'Nothing new to download.': 'ڈاؤن لوڈ کے لیے کچھ نیا نہیں ہے۔',
  'Downloaded @count new file.': '@count نئی فائل ڈاؤن لوڈ ہوئی۔',
  'Downloaded @count new files.': '@count نئی فائلیں ڈاؤن لوڈ ہوئیں۔',
  'Sent @rows change.': '@rows تبدیلی بھیج دی گئی۔',
  'Sent @rows changes.': '@rows تبدیلیاں بھیج دی گئیں۔',
  'Sent @rows change and @files recording.':
      '@rows تبدیلی اور @files ریکارڈنگ بھیج دی گئی۔',
  'Sent @rows changes and @files recording.':
      '@rows تبدیلیاں اور @files ریکارڈنگ بھیج دی گئیں۔',
  'Sent @rows change and @files recordings.':
      '@rows تبدیلی اور @files ریکارڈنگز بھیج دی گئیں۔',
  'Sent @rows changes and @files recordings.':
      '@rows تبدیلیاں اور @files ریکارڈنگز بھیج دی گئیں۔',
  'Not sent.': 'نہیں بھیجا گیا۔',
  '@count Set was not sent.': '@count Set نہیں بھیجا گیا۔',
  '@count Sets were not sent.': '@count Set نہیں بھیجے گئے۔',
  'Not sent. Something went wrong. Your work is still here.':
      'نہیں بھیجا گیا۔ کچھ غلط ہو گیا۔ آپ کا کام اب بھی یہیں ہے۔',

  // ---- signing in and out
  'Welcome back': 'خوش آمدید',
  'Sign in to continue to your workbench.':
      'اپنے ورک بینچ پر جانے کے لیے سائن اِن کریں۔',
  'Email': 'ای میل',
  'Password': 'پاس ورڈ',
  'Sign in': 'سائن اِن',
  'Trouble signing in? Contact your project administrator.':
      'سائن اِن میں مشکل ہے؟ اپنے پروجیکٹ کے ایڈمن سے رابطہ کریں۔',
  'Are you sure you want to sign out?':
      'کیا آپ واقعی سائن آؤٹ کرنا چاہتے ہیں؟',
  'Cannot reach the OBT server. The first sign-in on this phone needs a connection - that is when your work is downloaded.':
      'OBT سرور تک رسائی نہیں ہو سکی۔ اس فون پر پہلی بار سائن اِن کرنے کے لیے کنکشن درکار ہے - تبھی آپ کا کام ڈاؤن لوڈ ہوتا ہے۔',
  'No connection, and this is not the password that signed in with this email on this phone.':
      'کنکشن نہیں ہے، اور یہ وہ پاس ورڈ نہیں جس سے اس ای میل نے اس فون پر سائن اِن کیا تھا۔',
  'Your last download did not finish. Connect to the internet and sign in again to complete it.':
      'آپ کا پچھلا ڈاؤن لوڈ مکمل نہیں ہوا۔ انٹرنیٹ سے جڑ کر دوبارہ سائن اِن کریں تاکہ وہ مکمل ہو سکے۔',
  'Please enter both email and password.':
      'براہ کرم ای میل اور پاس ورڈ دونوں لکھیں۔',
  'Cannot reach the OBT server. Check your connection and try again '
          '- your work is downloaded at sign-in.':
      'OBT سرور تک رسائی نہیں ہو رہی۔ اپنا کنکشن دیکھیں اور دوبارہ کوشش '
      'کریں - آپ کا کام سائن اِن کے وقت ڈاؤن لوڈ ہوتا ہے۔',
  'Invalid server response.': 'سرور کا جواب درست نہیں ہے۔',
  'Something went wrong. Please try again.':
      'کچھ غلط ہو گیا۔ براہ کرم دوبارہ کوشش کریں۔',
  'Sign in failed. Please try again.':
      'سائن اِن نہیں ہو سکا۔ براہ کرم دوبارہ کوشش کریں۔',
  'The download did not finish. Please sign in again.':
      'ڈاؤن لوڈ مکمل نہیں ہوا۔ براہ کرم دوبارہ سائن اِن کریں۔',
  'Preparing your files...': 'آپ کی فائلیں تیار کی جا رہی ہیں...',
  'Securing your files...': 'آپ کی فائلیں محفوظ کی جا رہی ہیں...',
  '@saved / @total files ready': '@saved / @total فائلیں تیار',
  'Swipe left for the next passage': 'اگلے حصے کے لیے بائیں سوائپ کریں',
  'Swipe right for the next passage': 'اگلے حصے کے لیے دائیں سوائپ کریں',
  'Collecting your data...': 'آپ کا ڈیٹا جمع کیا جا رہا ہے...',
  'Preparing...': 'تیاری ہو رہی ہے...',
  '@saved / @total files downloaded': '@saved / @total فائلیں ڈاؤن لوڈ ہو گئیں',
  'Ready for a fresh start?': 'نئے سرے سے شروع کرنا چاہتے ہیں؟',
  "You're currently offline": 'آپ اس وقت آف لائن ہیں',
  'Keep My Data': 'میرا ڈیٹا رکھیں',
  'Stay Signed In': 'سائن اِن رہیں',
  'Sign out': 'سائن آؤٹ',
  'Signed in': 'سائن اِن ہیں',
  'Signing out will remove the *sets, recordings, and scripts* '
          'stored on this device.':
      'سائن آؤٹ کرنے سے اس فون پر محفوظ *Sets، ریکارڈنگز اور اسکرپٹس* ہٹ '
      'جائیں گے۔',
  'Any work that has not been uploaded or synced will also be '
          'permanently removed.':
      'جو کام ابھی اپ لوڈ یا سِنک نہیں ہوا وہ بھی ہمیشہ کے لیے ہٹ جائے '
      'گا۔',
  'If you do not need the work saved on this device, you can sign '
          'out safely. *Sign in again any time to download your content '
          'fresh and get back to work.*':
      'اگر آپ کو اس فون پر محفوظ کام کی ضرورت نہیں تو آپ بے فکر ہو کر '
      'سائن آؤٹ کر سکتے ہیں۔ *کسی بھی وقت دوبارہ سائن اِن کر کے اپنا '
      'مواد نئے سرے سے ڈاؤن لوڈ کریں اور کام جاری رکھیں۔*',
  'There is no internet connection on this phone right now.':
      'اس وقت اس فون پر انٹرنیٹ کنکشن نہیں ہے۔',
  '*Signing out will remove everything stored on this device*, '
          'including your *sets, recordings, and scripts*. Any work that has '
          'not been uploaded or synced will also be permanently removed.':
      '*سائن آؤٹ کرنے سے اس فون پر محفوظ سب کچھ ہٹ جائے گا*، جس میں آپ '
      'کے *Sets، ریکارڈنگز اور اسکرپٹس* بھی شامل ہیں۔ جو کام ابھی اپ لوڈ '
      'یا سِنک نہیں ہوا وہ بھی ہمیشہ کے لیے ہٹ جائے گا۔',
  'To get your content back, you will need *to sign in again with an '
          'internet connection* and download it again.':
      'اپنا مواد واپس پانے کے لیے آپ کو *انٹرنیٹ کنکشن کے ساتھ دوبارہ '
      'سائن اِن* کر کے اسے پھر سے ڈاؤن لوڈ کرنا ہوگا۔',
  'No internet available? It is safest to stay signed in and '
          'continue working offline.':
      'انٹرنیٹ نہیں ہے؟ سب سے محفوظ یہی ہے کہ سائن اِن رہیں اور آف لائن '
      'کام جاری رکھیں۔',

  // ---- settings drawer
  'No role assigned yet.': 'ابھی کوئی کردار نہیں دیا گیا۔',
  'No Sets assigned yet.': 'ابھی کوئی Set نہیں دیا گیا۔',
  'Reading...': 'پڑھا جا رہا ہے...',
  'Source': 'اصل',

  // ---- Set lists and progress
  'Sent back - needs changes': 'واپس بھیجا گیا - تبدیلیاں درکار ہیں',
  'In progress': 'کام جاری ہے',
  'Add community questions': 'کمیونٹی کے سوال شامل کریں',
  'Run community test': 'کمیونٹی ٹیسٹ کریں',
  'Ready for your check': 'آپ کی جانچ کے لیے تیار',
  'Ready for review': 'جائزے کے لیے تیار',
  'Needs back translation': 'واپسی ترجمہ درکار ہے',
  'Ready for consultant check': 'کنسلٹنٹ کی جانچ کے لیے تیار',
  'Back Translator': 'واپسی مترجم',
  'Sent back from @stage': '@stage سے واپس بھیجا گیا',
  '@where - @done of @total recorded':
      '@where - @total میں سے @done ریکارڈ ہو گئے',
  '@count more Set after this one': 'اس کے بعد @count اور Set ہے',
  '@count more Sets after this one': 'اس کے بعد @count اور Set ہیں',
  'Jump to a pending work item (@count pending)':
      'کسی باقی کام پر جائیں (@count باقی)',
  '@done of @total passage recorded': '@total میں سے @done حصہ ریکارڈ ہو گیا',
  '@done of @total passages recorded': '@total میں سے @done حصے ریکارڈ ہو گئے',
  'No Set has been approved yet.': 'ابھی کوئی Set منظور نہیں ہوا۔',
  'Listen': 'سنیں',
  'Download': 'ڈاؤن لوڈ کریں',
  'Downloading @done of @total': '@total میں سے @done ڈاؤن لوڈ ہو رہا ہے',
  'Checking this device...': 'اس فون کو دیکھا جا رہا ہے...',
  'No finished recording': 'کوئی مکمل ریکارڈنگ نہیں',
  'On this device - @count passage': 'اس فون پر موجود ہے - @count حصہ',
  'On this device - @count passages': 'اس فون پر موجود ہیں - @count حصے',
  '@done of @total passage downloaded':
      '@total میں سے @done حصہ ڈاؤن لوڈ ہو گیا',
  '@done of @total passages downloaded':
      '@total میں سے @done حصے ڈاؤن لوڈ ہو گئے',
  'Tap to download @count passage': '@count حصہ ڈاؤن لوڈ کرنے کے لیے دبائیں',
  'Tap to download @count passages': '@count حصے ڈاؤن لوڈ کرنے کے لیے دبائیں',
  '@set is on this device.': '@set اس فون پر موجود ہے۔',
  'Task Done': 'کام مکمل',
  '@set has no finished recording to download.':
      '@set کی کوئی مکمل ریکارڈنگ ڈاؤن لوڈ کے لیے موجود نہیں۔',
  '@done of @total passages downloaded - the rest could not be '
          'fetched.':
      '@total میں سے @done حصے ڈاؤن لوڈ ہوئے - باقی نہیں مل سکے۔',
  'Could not download @set: @error': '@set ڈاؤن لوڈ نہیں ہو سکا: @error',
  'No feedback yet.\nLiked answers that come with a comment will '
          'show here.':
      'ابھی کوئی رائے نہیں۔\nپسند کیے گئے وہ جواب جن کے ساتھ تبصرہ ہو '
      'یہاں نظر آئیں گے۔',
  '@count comment': '@count تبصرہ',
  '@count comments': '@count تبصرے',

  // ---- sync status and problems
  'never': 'کبھی نہیں',
  'Last full sync: @when': 'آخری مکمل سِنک: @when',
  'Last full sync: @when · offline now': 'آخری مکمل سِنک: @when · ابھی آف لائن',
  '@count change is only on this phone.': '@count تبدیلی صرف اسی فون پر ہے۔',
  '@count changes are only on this phone.':
      '@count تبدیلیاں صرف اسی فون پر ہیں۔',
  '@count recording': '@count ریکارڈنگ',
  '@count recordings': '@count ریکارڈنگز',
  '@count comment / question': '@count تبصرہ / سوال',
  '@count comments / questions': '@count تبصرے / سوال',
  '@count other change': '@count اور تبدیلی',
  '@count other changes': '@count اور تبدیلیاں',
  'hand-off to @stage': '@stage کو حوالگی',
  'Set @id': 'Set @id',
  '@when · your work on this Set is still on this phone.':
      '@when · اس Set پر آپ کا کام اب بھی اسی فون پر ہے۔',
  '@when · your work on this Set is still on this phone and will be '
          'tried again.':
      '@when · اس Set پر آپ کا کام اب بھی اسی فون پر ہے اور اسے دوبارہ '
      'بھیجنے کی کوشش کی جائے گی۔',
  'Give up this work': 'یہ کام چھوڑ دیں',
  'Give up': 'چھوڑ دیں',
  'Give up the unsent work on this Set? It will not be sent. Save '
          'the recordings to Downloads first if you want to keep them.':
      'کیا اس Set کا نہ بھیجا گیا کام چھوڑ دیں؟ یہ نہیں بھیجا جائے گا۔ '
      'اگر ریکارڈنگز رکھنا چاہتے ہیں تو پہلے انہیں Downloads میں محفوظ '
      'کر لیں۔',
  'There were no recordings to save for this Set.':
      'اس Set کی محفوظ کرنے کے لیے کوئی ریکارڈنگ نہیں تھی۔',
  'Saved @count recording to Downloads.':
      '@count ریکارڈنگ Downloads میں محفوظ ہو گئی۔',
  'Saved @count recordings to Downloads.':
      '@count ریکارڈنگز Downloads میں محفوظ ہو گئیں۔',
  'A send is already running.': 'بھیجنے کا عمل پہلے سے جاری ہے۔',
  'This Set is no longer assigned to you. Your work on it is still '
          'on this phone - ask your manager before it is removed.':
      'یہ Set اب آپ کے ذمے نہیں رہا۔ اس پر آپ کا کام اب بھی اسی فون پر '
      'ہے - اسے ہٹانے سے پہلے اپنے مینیجر سے پوچھیں۔',
  'This Set was changed somewhere else while you were offline - it '
          'is now at "@stage". Your hand-off was not sent, and your work is '
          'still on this phone.':
      'جب آپ آف لائن تھے تو یہ Set کسی اور جگہ سے بدل دیا گیا - اب یہ '
      '"@stage" پر ہے۔ آپ کی حوالگی نہیں بھیجی گئی، اور آپ کا کام اب بھی '
      'اسی فون پر ہے۔',
  'A recording is missing from this phone (@file). Record it again, '
          'or remove that take.':
      'ایک ریکارڈنگ اس فون پر نہیں مل رہی (@file)۔ اسے دوبارہ ریکارڈ '
      'کریں، یا وہ take ہٹا دیں۔',
  'The server refused it (@code).': 'سرور نے اسے قبول نہیں کیا (@code)۔',
  'Your sign-in has expired. Sign in again to send your work - it '
          'stays on this phone until then.':
      'آپ کے سائن اِن کی مدت ختم ہو گئی ہے۔ اپنا کام بھیجنے کے لیے '
      'دوبارہ سائن اِن کریں - تب تک وہ اسی فون پر محفوظ ہے۔',
  'The server had a problem (@code). Your work stays on this phone - '
          'try again later.':
      'سرور میں کوئی مسئلہ تھا (@code)۔ آپ کا کام اسی فون پر محفوظ ہے - '
      'بعد میں دوبارہ کوشش کریں۔',
  'The connection was too slow to finish. Your work stays on this '
          'phone - try again where the signal is better.':
      'کنکشن اتنا سست تھا کہ کام مکمل نہ ہو سکا۔ آپ کا کام اسی فون پر '
      'محفوظ ہے - جہاں سگنل بہتر ہو وہاں دوبارہ کوشش کریں۔',
  'Could not reach the server.': 'سرور تک رسائی نہیں ہو سکی۔',
  'The server refused the refresh (@code).':
      'سرور نے تازہ کاری قبول نہیں کی (@code)۔',
  'The server sent something unusable.':
      'سرور نے ایسا جواب بھیجا جو استعمال نہیں ہو سکتا۔',
  '@action - saved. It will be sent with your next sync.':
      '@action - محفوظ ہو گیا۔ یہ آپ کے اگلے سِنک کے ساتھ بھیج دیا جائے '
      'گا۔',
  'Could not send it: @error': 'اسے بھیجا نہیں جا سکا: @error',

  // ---- players and recordings
  'Recording': 'ریکارڈنگ',
  'Merged recording': 'پوری ریکارڈنگ',
  'Merged draft audio': 'پورے مسودے کی آڈیو',
  'Source audio': 'اصل آڈیو',
  'Source script': 'اصل اسکرپٹ',
  'Target script': 'ترجمے کی اسکرپٹ',
  'Source Content': 'اصل مواد',
  'Target Content': 'ترجمے کا مواد',
  'No source audio yet.': 'ابھی کوئی اصل آڈیو نہیں۔',
  'No source script yet.': 'ابھی کوئی اصل اسکرپٹ نہیں۔',
  'No target script yet.': 'ابھی ترجمے کی کوئی اسکرپٹ نہیں۔',
  'No source script on this device yet. Press Send on the workbench '
          'to fetch it.':
      'اس فون پر ابھی کوئی اصل اسکرپٹ نہیں۔ اسے لانے کے لیے ورک بینچ پر '
      '"بھیجیں" دبائیں۔',
  'Full screen': 'پوری اسکرین',
  'Playback speed': 'چلانے کی رفتار',
  'ZOOM': 'زوم',
  'Back 5 seconds': '5 سیکنڈ پیچھے',
  'Forward 5 seconds': '5 سیکنڈ آگے',
  'Play': 'چلائیں',
  'Pause': 'روکیں',
  'Add comment': 'تبصرہ شامل کریں',
  'Comment here': 'یہاں تبصرہ کریں',
  'A passage could not be played, so this does not count as a full '
          'listen yet.':
      'ایک حصہ چل نہیں سکا، اس لیے ابھی اسے پورا سننا شمار نہیں کیا جائے '
      'گا۔',
  'This recording could not be read: @error':
      'یہ ریکارڈنگ پڑھی نہیں جا سکی: @error',
  'Audio file is not available offline': 'آڈیو فائل آف لائن موجود نہیں ہے',
  '@missing of @total passages are not in this recording.':
      '@total میں سے @missing حصے اس ریکارڈنگ میں نہیں ہیں۔',
  'No source audio has been added for this passage.':
      'اس حصے کے لیے کوئی اصل آڈیو شامل نہیں کی گئی۔',
  'The source audio has not been downloaded to this device yet.':
      'اصل آڈیو ابھی اس فون پر ڈاؤن لوڈ نہیں ہوئی۔',
  'This set has no passages on this device. Log out and back in to '
          're-sync.':
      'اس فون پر اس Set کا کوئی حصہ نہیں ہے۔ دوبارہ سِنک کے لیے سائن آؤٹ '
      'کر کے پھر سائن اِن کریں۔',
  'None of the @count passages here has a final take on this device. '
          'The final_takes table did not sync - check it in the database '
          'viewer.':
      'یہاں کے @count حصوں میں سے کسی کا بھی Final take اس فون پر نہیں '
      'ہے۔ final_takes جدول سِنک نہیں ہوئی - اسے ڈیٹا بیس ویور میں '
      'دیکھیں۔',
  '@missing of @total passages have no final take yet, so they are '
          'not in this recording.':
      '@total میں سے @missing حصوں کا ابھی کوئی Final take نہیں، اس لیے '
      'وہ اس ریکارڈنگ میں شامل نہیں ہیں۔',

  // ---- writing or recording a comment, question or answer
  'Type it here': 'یہاں لکھیں',
  'Save': 'محفوظ کریں',
  'Voice': 'آواز',
  'Text': 'تحریر',
  'Tap to stop': 'روکنے کے لیے دبائیں',
  'Tap to record': 'ریکارڈ کرنے کے لیے دبائیں',
  'Tap to record audio': 'آڈیو ریکارڈ کرنے کے لیے دبائیں',
  'Discard': 'رد کریں',
  'Record again': 'دوبارہ ریکارڈ کریں',
  'Discard recording': 'ریکارڈنگ رد کریں',
  'Previously recorded': 'پہلے کی ریکارڈنگ',
  'Microphone permission is needed to record.':
      'ریکارڈ کرنے کے لیے مائیکروفون کی اجازت ضروری ہے۔',
  'Could not start recording: @error': 'ریکارڈنگ شروع نہیں ہو سکی: @error',
  'At @time': '@time پر',
  'Pinned at @time': '@time پر لگایا گیا',
  'Reviewer': 'جائزہ کار',
  'You': 'آپ',
  'Voice note': 'آواز میں نوٹ',
  'Voice comment': 'آواز میں تبصرہ',
  'Voice answer': 'آواز میں جواب',
  'Voice reply': 'آواز میں جواب',
  'Voice question': 'آواز میں سوال',
  'Delete comment': 'تبصرہ حذف کریں',
  'Delete question': 'سوال حذف کریں',

  // ---- the Set screen
  'This set could not be opened.': 'یہ Set کھل نہیں سکا۔',
  'No passages in this set yet.': 'اس Set میں ابھی کوئی حصہ نہیں۔',
  '@count passage still needs a final take before this can go to '
          '@stage.':
      '@stage کو بھیجنے سے پہلے @count حصے کا Final take ابھی باقی ہے۔',
  '@count passages still need a final take before this can go to '
          '@stage.':
      '@stage کو بھیجنے سے پہلے @count حصوں کے Final take ابھی باقی ہیں۔',
  '@count passage still needs a final take before this can move on.':
      'آگے بڑھنے سے پہلے @count حصے کا Final take ابھی باقی ہے۔',
  '@count passages still need a final take before this can move on.':
      'آگے بڑھنے سے پہلے @count حصوں کے Final take ابھی باقی ہیں۔',
  'Tap the waveform to jump to a spot, then leave a note there.':
      'کسی جگہ پر جانے کے لیے لہر پر دبائیں، پھر وہاں نوٹ لکھیں۔',
  'Tap the waveform to jump to a spot.':
      'کسی جگہ پر جانے کے لیے لہر پر دبائیں۔',
  'Add a note here': 'یہاں نوٹ شامل کریں',
  'Note - @passage': 'نوٹ - @passage',
  'What needs to change here?': 'یہاں کیا بدلنا ضروری ہے؟',
  'Play the recording first, then leave a note there.':
      'پہلے ریکارڈنگ چلائیں، پھر وہاں نوٹ لکھیں۔',
  'Could not save the note: @error': 'نوٹ محفوظ نہیں ہو سکا: @error',
  'Could not delete the comment: @error': 'تبصرہ حذف نہیں ہو سکا: @error',
  'There is no finished audio on this device to save.':
      'اس فون پر محفوظ کرنے کے لیے کوئی مکمل آڈیو نہیں ہے۔',
  'Nothing could be saved - the audio is not on this device.':
      'کچھ بھی محفوظ نہیں ہو سکا - آڈیو اس فون پر نہیں ہے۔',
  'Could not save the audio: @error': 'آڈیو محفوظ نہیں ہو سکی: @error',
  '@count passage left': '@count حصہ باقی ہے',
  '@count passages left': '@count حصے باقی ہیں',
  'Finalized': 'Final ہو گیا',
  'No takes': 'کوئی take نہیں',
  '@count take': '@count take',
  '@count takes': '@count takes',

  // ---- the recorder
  '@count takes is the limit - remove one on the Takes screen to '
          'record another.':
      '@count takes کی حد ہے - نیا ریکارڈ کرنے کے لیے Takes اسکرین پر سے '
      'ایک ہٹائیں۔',
  'Source audio and source script are both missing.':
      'اصل آڈیو اور اصل اسکرپٹ دونوں موجود نہیں ہیں۔',
  'Source audio is missing.': 'اصل آڈیو موجود نہیں ہے۔',
  'Source script is missing.': 'اصل اسکرپٹ موجود نہیں ہے۔',
  'Microphone is off': 'مائیکروفون بند ہے',
  'Recording needs the microphone, and it has been turned off for '
          'this app. Open settings to switch it back on.':
      'ریکارڈنگ کے لیے مائیکروفون ضروری ہے، اور اس ایپ کے لیے اسے بند کر '
      'دیا گیا ہے۔ اسے دوبارہ چالو کرنے کے لیے ترتیبات کھولیں۔',
  'Recording needs the microphone. Tap record again to allow it.':
      'ریکارڈنگ کے لیے مائیکروفون ضروری ہے۔ اجازت دینے کے لیے ریکارڈ کا '
      'بٹن دوبارہ دبائیں۔',
  'Open settings': 'ترتیبات کھولیں',
  'Could not pause - the recording is still running.':
      'روکا نہیں جا سکا - ریکارڈنگ ابھی چل رہی ہے۔',
  'Could not resume. Stop to keep what has been recorded.':
      'دوبارہ شروع نہیں ہو سکا۔ جو ریکارڈ ہو چکا ہے اسے رکھنے کے لیے بند '
      'کریں۔',
  'No voice was detected. Speak clearly, close to the phone, and '
          'record again.':
      'کوئی آواز نہیں ملی۔ فون کے قریب صاف بولیں اور دوبارہ ریکارڈ کریں۔',
  'The recording the Drafter and the Peer listen to for this passage.':
      'وہ ریکارڈنگ جو Drafter اور Peer اس حصے کے لیے سنتے ہیں۔',
  'The text of this passage in the source language.':
      'ماخذ زبان میں اس حصے کا متن۔',
  'The text of this passage in the target language.':
      'ہدف زبان میں اس حصے کا متن۔',
  'Take recording': 'take کی ریکارڈنگ',
  'A recording of this passage. Without it the take cannot be played.':
      'اس حصے کی ریکارڈنگ۔ اس کے بغیر take چلایا نہیں جا سکتا۔',
  "A reviewer's spoken comment on a recording.":
      'ریکارڈنگ پر جائزہ لینے والے کا بولا ہوا تبصرہ۔',
  'Question recording': 'سوال کی ریکارڈنگ',
  'A community question or its answer, spoken.':
      'کمیونٹی کا سوال یا اس کا جواب، بولا ہوا۔',
  'Back translation recording': 'واپسی ترجمے کی ریکارڈنگ',
  'The spoken back translation of this Set.': 'اس Set کا بولا ہوا واپسی ترجمہ۔',
  'A recording this Set refers to.': 'اس Set سے متعلق ایک ریکارڈنگ۔',
  '@count file did not download': '@count فائل ڈاؤن لوڈ نہیں ہوئی',
  '@count files did not download': '@count فائلیں ڈاؤن لوڈ نہیں ہوئیں',
  'Choose for each file: try again, or skip it. A skipped file is tried again at the next Check for updates.':
      'ہر فائل کے لیے چنیں: دوبارہ کوشش کریں، یا چھوڑ دیں۔ چھوڑی گئی فائل اگلی بار تازہ کاری دیکھنے پر پھر آزمائی جائے گی۔',
  'Try all again': 'سب دوبارہ آزمائیں',
  'Skip all': 'سب چھوڑیں',
  'Continue without these files': 'ان فائلوں کے بغیر آگے بڑھیں',
  'Try @count file again': '@count فائل دوبارہ آزمائیں',
  'Try @count files again': '@count فائلیں دوبارہ آزمائیں',
  'Skip': 'چھوڑیں',
  'Used for': 'کس کام کی',
  'File': 'فائل',
  'Problem': 'مسئلہ',
  'The file could not be downloaded.': 'فائل ڈاؤن لوڈ نہیں ہو سکی۔',
  'The download stopped part way and was given up.':
      'ڈاؤن لوڈ بیچ میں رک گیا اور چھوڑ دیا گیا۔',
  'No connection to the server.': 'سرور سے رابطہ نہیں ہے۔',
  'The file could not be saved on this phone.':
      'فائل اس فون پر محفوظ نہیں ہو سکی۔',
  'The server sent an empty file.': 'سرور نے خالی فائل بھیجی۔',
  'The server did not send the file (error @code).':
      'سرور نے فائل نہیں بھیجی (خرابی @code)۔',
  'The server asked for a sign-in instead of sending the file.':
      'سرور نے فائل بھیجنے کے بجائے سائن اِن مانگا۔',
  'No network. @count change is waiting to be sent.':
      'نیٹ ورک نہیں ہے۔ @count تبدیلی بھیجے جانے کی منتظر ہے۔',
  'No network. @count changes are waiting to be sent.':
      'نیٹ ورک نہیں ہے۔ @count تبدیلیاں بھیجے جانے کی منتظر ہیں۔',
  'No answer was given.': 'کوئی جواب نہیں دیا گیا۔',
  'This take cannot be made Final': 'اس take کو Final نہیں بنایا جا سکتا',
  'Recording stopped because audio started playing.':
      'آڈیو چلنے لگی، اس لیے ریکارڈنگ روک دی گئی۔',
  'Nothing was recorded.': 'کچھ بھی ریکارڈ نہیں ہوا۔',
  'This phone cannot play this recording at another speed. Playing at '
          'normal speed.':
      'یہ فون اس ریکارڈنگ کو دوسری رفتار پر نہیں چلا سکتا۔ عام رفتار پر '
      'چل رہی ہے۔',
  'This recording could not be played. Tap play to try again.':
      'یہ ریکارڈنگ نہیں چل سکی۔ دوبارہ کوشش کے لیے پلے دبائیں۔',
  'No sound was picked up in this recording. Check the microphone and '
          'record again.':
      'اس ریکارڈنگ میں کوئی آواز نہیں آئی۔ مائیکروفون چیک کریں اور دوبارہ '
      'ریکارڈ کریں۔',
  'Too short to keep - a take must be at least @count seconds.':
      'رکھنے کے لیے بہت چھوٹا ہے - ایک take کم از کم @count سیکنڈ کا '
      'ہونا چاہیے۔',
  'Checking audio...': 'آڈیو جانچی جا رہی ہے...',
  'Saving...': 'محفوظ ہو رہا ہے...',
  'Deleting...': 'حذف ہو رہا ہے...',
  'This recording is not a WAV file and was not saved.':
      'یہ ریکارڈنگ WAV فائل نہیں ہے اور محفوظ نہیں کی گئی۔',
  'QC passed': 'QC میں پاس',
  'QC @status - see the take for why':
      'QC @status - وجہ جاننے کے لیے take دیکھیں',
  'QC @status': 'QC @status',
  'QC: @status': 'QC: @status',
  'The audio for this take is not on this device.':
      'اس take کی آڈیو اس فون پر نہیں ہے۔',
  'Unmark it as final before deleting it.':
      'حذف کرنے سے پہلے اس سے Final ہٹائیں۔',
  'Something went wrong: @error': 'کچھ غلط ہو گیا: @error',
  '@passage - Takes': '@passage - Takes',
  'Listen to the final take and mark anything that needs to change.':
      'Final take سنیں اور جو کچھ بدلنا ضروری ہو اس پر نشان لگائیں۔',
  'No takes yet': 'ابھی کوئی take نہیں',
  'All takes (@count/@max)': 'تمام takes (@count/@max)',
  'Takes recorded (@count/@max)': 'ریکارڈ شدہ takes (@count/@max)',
  'Nothing recorded on this passage yet. Step back to the recorder '
          'to make the first take.':
      'اس حصے پر ابھی کچھ ریکارڈ نہیں ہوا۔ پہلا take بنانے کے لیے '
      'ریکارڈر پر واپس جائیں۔',
  'Why this was sent back': 'یہ کیوں واپس بھیجا گیا',
  'Marks': 'نشانات',
  'Take @index': 'Take @index',
  'Not synced': 'سِنک نہیں ہوا',
  'Deleted': 'حذف شدہ',
  'Not run': 'نہیں چلایا گیا',
  'Run QC': 'QC چلائیں',
  'Run QC again': 'QC دوبارہ چلائیں',
  'Make final': 'Final بنائیں',
  'Remove final': 'Final ہٹائیں',
  'Delete take': 'take حذف کریں',
  'QC details (@count checks)': 'QC کی تفصیل (@count جانچیں)',
  '@failed of @count checks failed': '@count میں سے @failed جانچیں ناکام ہوئیں',
  'Clipping': 'آواز کا پھٹنا (Clipping)',
  // ---- QC feedback, in the recorder's words
  'Clear audio with no distortion from excessive volume.':
      'صاف آڈیو، زیادہ آواز سے کوئی بگاڑ نہیں۔',
  'Audio distortion detected due to excessive volume. Reduce speaking volume or increase the distance from the microphone.':
      'زیادہ آواز کی وجہ سے آڈیو میں بگاڑ ملا۔ بولنے کی آواز کم کریں یا مائیکروفون سے فاصلہ بڑھائیں۔',
  'Recording begins and ends naturally, with minimal silence.':
      'ریکارڈنگ قدرتی طور پر شروع اور ختم ہوتی ہے، بہت کم خاموشی کے ساتھ۔',
  'Excessive silence detected at the beginning or end. Start promptly and stop shortly after the final word.':
      'شروع یا آخر میں ضرورت سے زیادہ خاموشی ملی۔ فوراً بولنا شروع کریں اور آخری لفظ کے تھوڑی دیر بعد روک دیں۔',
  'A quiet recording environment ensures clear speech.':
      'خاموش ماحول میں ریکارڈنگ سے گفتگو صاف رہتی ہے۔',
  'Background noise is affecting speech clarity. Record in a quieter environment away from fans, traffic, and other people.':
      'پس منظر کا شور گفتگو کی وضاحت پر اثر ڈال رہا ہے۔ پنکھے، ٹریفک اور دوسرے لوگوں سے دور، خاموش ماحول میں ریکارڈ کریں۔',
  'Recording duration matches the expected passage length.':
      'ریکارڈنگ کا دورانیہ حصے کی متوقع لمبائی سے مطابقت رکھتا ہے۔',
  'Recording duration differs significantly from the expected length. Check passage completeness and avoid extra content.':
      'ریکارڈنگ کا دورانیہ متوقع لمبائی سے کافی مختلف ہے۔ دیکھیں کہ حصہ مکمل ہے اور اضافی مواد نہ ہو۔',
  'Audio format meets the project requirements.':
      'آڈیو فارمیٹ منصوبے کی ضروریات کے مطابق ہے۔',
  'Audio format does not meet project requirements. Record directly through the app to ensure compatibility.':
      'آڈیو فارمیٹ منصوبے کی ضروریات کے مطابق نہیں ہے۔ مطابقت کے لیے براہِ راست ایپ سے ریکارڈ کریں۔',
  'The complete passage is captured, including the final word.':
      'پورا حصہ ریکارڈ ہوا ہے، آخری لفظ سمیت۔',
  'The recording may have ended before speech was complete. Allow a brief pause after the final word before stopping.':
      'ریکارڈنگ شاید گفتگو مکمل ہونے سے پہلے ختم ہو گئی۔ روکنے سے پہلے آخری لفظ کے بعد تھوڑا رکیں۔',
  'Speech is clearly audible throughout the recording.':
      'پوری ریکارڈنگ میں گفتگو صاف سنائی دیتی ہے۔',
  'Little or no speech was detected. Improve speech clarity and maintain an appropriate distance from the microphone.':
      'گفتگو بہت کم یا بالکل نہیں ملی۔ صاف بولیں اور مائیکروفون سے مناسب فاصلہ رکھیں۔',
  'Speech volume remains consistent throughout the recording.':
      'پوری ریکارڈنگ میں گفتگو کی آواز یکساں رہتی ہے۔',
  'Significant volume variations detected. Maintain a steady speaking volume from beginning to end.':
      'آواز میں کافی اتار چڑھاؤ ملا۔ شروع سے آخر تک یکساں آواز میں بولیں۔',
  'Speech remains clear without distracting competing sounds.':
      'گفتگو صاف ہے، توجہ بٹانے والی دوسری آوازیں نہیں ہیں۔',
  'Competing sounds are affecting speech clarity. Choose a quieter recording environment for better results.':
      'دوسری آوازیں گفتگو کی وضاحت پر اثر ڈال رہی ہیں۔ بہتر نتیجے کے لیے خاموش جگہ چنیں۔',
  // ---- QC checks and their details
  'Voice detected':
      'آواز کی شناخت ہوئی',
  'Volume consistency':
      'آواز کی یکسانیت',
  'Background noise':
      'پس منظر کا شور',
  'Every Language. Beyond Words.':
      'ہر زبان۔ لفظوں سے آگے۔',
  'Language • Intelligence • Voice • Understanding • Knowledge • Augmentation':
      'زبان • ذہانت • آواز • فہم • علم • افزائش',
  'Peak @peak dBFS, @pct% samples at/near full scale':
      'چوٹی @peak dBFS، @pct% نمونے مکمل سطح پر/اس کے قریب',
  '@before before the first word, @after after the last (limit @limit)':
      'پہلے لفظ سے پہلے @before، آخری کے بعد @after (حد @limit)',
  'Recording is too uniform to isolate a background level - treated as clean':
      'ریکارڈنگ اتنی یکساں ہے کہ پس منظر کی سطح الگ نہیں ہو سکی - صاف سمجھی گئی',
  'Background level @level dBFS (limit @limit dBFS)':
      'پس منظر کی سطح @level dBFS (حد @limit dBFS)',
  '@seconds recorded. No source audio to compare against, expected roughly @range':
      '@seconds ریکارڈ ہوا۔ موازنے کے لیے ماخذ آڈیو نہیں، تقریباً @range متوقع',
  '@seconds recorded. Source audio is @source, expected roughly @range':
      '@seconds ریکارڈ ہوا۔ ماخذ آڈیو @source ہے، تقریباً @range متوقع',
  '@rate Hz, 1 channel':
      '@rate Hz، 1 چینل',
  '@rate Hz, @channels channels':
      '@rate Hz، @channels چینل',
  'Last @tail at @level dBFS (limit @limit dBFS)':
      'آخری @tail @level dBFS پر (حد @limit dBFS)',
  '@seconds (@pct%) of this take is a voice':
      'اس ٹیک کا @seconds (@pct%) آواز ہے',
  'Only @seconds (@pct%) of this take is a voice - speak clearly, close to the phone, and record again':
      'اس ٹیک کا صرف @seconds (@pct%) آواز ہے - صاف بولیں، فون کے قریب رہیں، اور دوبارہ ریکارڈ کریں',
  'No voice was detected in this recording - speak clearly, close to the phone, and record again':
      'اس ریکارڈنگ میں کوئی آواز نہیں ملی - صاف بولیں، فون کے قریب رہیں، اور دوبارہ ریکارڈ کریں',
  'Not enough speech detected to judge volume consistency':
      'آواز کی یکسانیت جانچنے کے لیے کافی گفتگو نہیں ملی',
  'Speech volume ranged @spread dB across the take (limit @limit dB) - stays fairly even throughout':
      'ٹیک میں گفتگو کی آواز @spread dB کے دائرے میں رہی (حد @limit dB) - تقریباً یکساں رہی',
  'Speech volume ranged @spread dB across the take (limit @limit dB) - volume changes noticeably partway through':
      'ٹیک میں گفتگو کی آواز @spread dB کے دائرے میں رہی (حد @limit dB) - درمیان میں آواز نمایاں طور پر بدلتی ہے',
  'Not enough speech detected to judge background noise':
      'پس منظر کا شور جانچنے کے لیے کافی گفتگو نہیں ملی',
  'Found @seconds of sound that is not the voice and is about as loud (limit @limit) - have a listen, this may be background noise':
      '@seconds ایسی آواز ملی جو گفتگو نہیں اور تقریباً اتنی ہی اونچی ہے (حد @limit) - سن کر دیکھیں، یہ پس منظر کا شور ہو سکتا ہے',
  'No other sound near the level of the voice':
      'آواز کی سطح کے قریب کوئی اور آواز نہیں',
  'Head / tail silence': 'شروع / آخر کی خاموشی',
  'Noise floor': 'پس منظر کا شور',
  'Duration': 'دورانیہ',
  'Sample rate / channels': 'Sample rate / channels',
  'Truncation': 'ریکارڈنگ کا کٹ جانا',

  // ---- community setup, test and review
  'Community setup': 'کمیونٹی کی تیاری',
  'Community test': 'کمیونٹی ٹیسٹ',
  'Community review': 'کمیونٹی کا جائزہ',
  'Question - @passage': 'سوال - @passage',
  'What should the community be asked here?': 'یہاں کمیونٹی سے کیا پوچھا جائے؟',
  'General question': 'عمومی سوال',
  'General questions': 'عمومی سوالات',
  'About the whole set, not one passage.':
      'پورے Set کے بارے میں، کسی ایک حصے کے بارے میں نہیں۔',
  'What should the community be asked?': 'کمیونٹی سے کیا پوچھا جائے؟',
  'Could not save the question: @error': 'سوال محفوظ نہیں ہو سکا: @error',
  'Add a question here': 'یہاں سوال شامل کریں',
  'Add a general question': 'عمومی سوال شامل کریں',
  'Add a question first': 'پہلے ایک سوال شامل کریں',
  'Tap the waveform to jump to the spot you mean, then add the '
          'question there.':
      'جس جگہ کی بات ہے وہاں جانے کے لیے لہر پر دبائیں، پھر وہاں سوال '
      'شامل کریں۔',
  '@count question pinned to the recording - tap a marker to read '
          'one.':
      '@count سوال ریکارڈنگ پر لگا ہے - پڑھنے کے لیے نشان پر دبائیں۔',
  '@count questions pinned to the recording - tap a marker to read '
          'one.':
      '@count سوال ریکارڈنگ پر لگے ہیں - کوئی پڑھنے کے لیے نشان پر '
      'دبائیں۔',
  'Questions': 'سوالات',
  'all answered': 'سب کے جواب مل گئے',
  '@count unanswered': '@count کا جواب باقی',
  '@count question left': '@count سوال باقی ہے',
  '@count questions left': '@count سوال باقی ہیں',
  'Listen to the whole recording above first - the questions will '
          'appear here once you have.':
      'پہلے اوپر والی پوری ریکارڈنگ سنیں - اس کے بعد سوالات یہاں نظر '
      'آئیں گے۔',
  'Answer': 'جواب دیں',
  'Answered': 'جواب مل گیا',
  'Answered - @answer': 'جواب مل گیا - @answer',
  'Answer this question': 'اس سوال کا جواب دیں',
  'Type what they said': 'جو انہوں نے کہا وہ لکھیں',
  'Could not save the answer: @error': 'جواب محفوظ نہیں ہو سکا: @error',
  'Passage': 'حصہ',
  'No questions to test yet.': 'ابھی ٹیسٹ کے لیے کوئی سوال نہیں۔',
  'One question has no answer yet. It needs one before this Set can '
          'go anywhere.':
      'ایک سوال کا ابھی کوئی جواب نہیں۔ اس کا جواب ملے بغیر یہ Set کہیں '
      'نہیں جا سکتا۔',
  '@count questions have no answer yet. They need one before this '
          'Set can go anywhere.':
      '@count سوالوں کے ابھی کوئی جواب نہیں۔ ان کے جواب ملے بغیر یہ Set '
      'کہیں نہیں جا سکتا۔',
  'Tell the Drafter what worked': 'مسودہ نگار کو بتائیں کیا اچھا رہا',
  'Optional - this is the only praise the Drafter sees.':
      'اختیاری - مسودہ نگار کو صرف یہی تعریف نظر آتی ہے۔',
  'What is wrong with this answer?': 'اس جواب میں کیا غلط ہے؟',
  'A Dislike needs a comment - the Drafter works from it.':
      'ناپسند کے ساتھ تبصرہ ضروری ہے - مسودہ نگار اسی کو دیکھ کر کام '
      'کرتا ہے۔',
  'Could not save it: @error': 'اسے محفوظ نہیں کیا جا سکا: @error',
  'Change your comment': 'اپنا تبصرہ بدلیں',
  'Add a comment for the Drafter (optional)':
      'مسودہ نگار کے لیے تبصرہ شامل کریں (اختیاری)',
  'The community test produced no questions.':
      'کمیونٹی ٹیسٹ سے کوئی سوال نہیں ملا۔',

  // ---- back translation and consultant check
  'Back translation': 'واپسی ترجمہ',
  'Consultant check': 'کنسلٹنٹ کی جانچ',
  'Reply to the Consultant': 'کنسلٹنٹ کو جواب دیں',
  'What would you like to say back?': 'آپ جواب میں کیا کہنا چاہیں گے؟',
  'Could not save the reply: @error': 'جواب محفوظ نہیں ہو سکا: @error',
  'Could not delete it: @error': 'اسے حذف نہیں کیا جا سکا: @error',
  'Comment - @passage': 'تبصرہ - @passage',
  'What is wrong here?': 'یہاں کیا غلط ہے؟',
  'Could not save the comment: @error': 'تبصرہ محفوظ نہیں ہو سکا: @error',
  'Tap the waveform to jump to the spot you mean, then comment there.':
      'جس جگہ کی بات ہے وہاں جانے کے لیے لہر پر دبائیں، پھر وہاں تبصرہ '
      'کریں۔',
  'Not satisfied? Comment on it': 'مطمئن نہیں؟ اس پر تبصرہ کریں',
  "The Consultant's comments": 'کنسلٹنٹ کے تبصرے',
  'Submitting a new back translation closes all of these.':
      'نیا واپسی ترجمہ جمع کرانے سے یہ سب بند ہو جاتے ہیں۔',
  'Back translation (text or voice - either is fine)':
      'واپسی ترجمہ (تحریر یا آواز - دونوں میں سے کوئی بھی ٹھیک ہے)',
  'Type the back translation...': 'واپسی ترجمہ یہاں لکھیں...',
  'Comment on the back translation': 'واپسی ترجمے پر تبصرہ کریں',
  'What does not match?': 'کیا چیز میل نہیں کھاتی؟',
  'Your comments': 'آپ کے تبصرے',
  'The back translator has not submitted one yet.':
      'واپسی مترجم نے ابھی کوئی جمع نہیں کرایا۔',
  'An open comment blocks sending this on. Delete it, or send the Set back to the Drafter.':
      'کھلا تبصرہ آگے بھیجنے کو روکتا ہے۔ اسے حذف کریں، یا Set مسودہ نگار کو واپس بھیجیں۔',
  'This recording has not been downloaded to this phone yet. Use Check for updates when there is a connection.':
      'یہ ریکارڈنگ ابھی اس فون پر ڈاؤن لوڈ نہیں ہوئی۔ کنکشن ملنے پر "تازہ کاری دیکھیں" استعمال کریں۔',
  'Automated QC': 'خودکار QC',
  'QC: @status - passed automatically': 'QC: @status - خود بخود پاس ہو گیا',
  'This is a mechanical check, not a judgement on the translation - use your own judgement too.':
      'یہ ایک مشینی جانچ ہے، ترجمے پر فیصلہ نہیں - اپنی سمجھ بھی استعمال کریں۔',
  'OK': 'ٹھیک ہے',
  '@length window': '@length کی کھڑکی',
  'Zoom in': 'قریب کریں',
  'Zoom out': 'دور کریں',
  'Re-record': 'دوبارہ ریکارڈ کریں',
  'Record': 'ریکارڈ کریں',
  'Not started': 'شروع نہیں ہوا',
  'Sent back from @stage - needs changes':
      '@stage سے واپس بھیجا گیا - تبدیلیاں درکار ہیں',
  'Your recording': 'آپ کی ریکارڈنگ',
  'Home': 'ہوم',
  'This take was sent back with a comment from @reviewer - record a new take to fix it before marking one Final.':
      'یہ take @reviewer کے تبصرے کے ساتھ واپس بھیجا گیا تھا - اسے درست کرنے کے لیے نیا take ریکارڈ کریں، پھر کسی کو Final بنائیں۔',
  'This take was sent back with a reply from @reviewer - record a new take to fix it before marking one Final.':
      'یہ take @reviewer کے جواب کے ساتھ واپس بھیجا گیا تھا - اسے درست کرنے کے لیے نیا take ریکارڈ کریں، پھر کسی کو Final بنائیں۔',
  'This passage was sent back with a comment from @reviewer - record a new take to fix it before marking one Final.':
      'یہ حصہ @reviewer کے تبصرے کے ساتھ واپس بھیجا گیا تھا - اسے درست کرنے کے لیے نیا take ریکارڈ کریں، پھر کسی کو Final بنائیں۔',
  'the Back Translator': 'واپسی مترجم',
  'a reviewer': 'جائزہ لینے والے',
  'This take is no longer Final - it did not pass QC this time. Mark another take Final, or record a new one.':
      'یہ take اب Final نہیں رہا - اس بار یہ QC میں پاس نہیں ہوا۔ کسی اور take کو Final بنائیں، یا نیا ریکارڈ کریں۔',
  'Play both recordings to the end to send this on - or leave a comment to send it back.':
      'آگے بھیجنے کے لیے دونوں ریکارڈنگز آخر تک سنیں - یا واپس بھیجنے کے لیے تبصرہ کریں۔',
  'Approved': 'منظور شدہ',
  'CC Checked': 'CC چیک شدہ',
  'just now': 'ابھی ابھی',
  '@count minute ago': '@count منٹ پہلے',
  '@count minutes ago': '@count منٹ پہلے',
  '@count hour ago': '@count گھنٹہ پہلے',
  '@count hours ago': '@count گھنٹے پہلے',
  '@count day ago': '@count دن پہلے',
  '@count days ago': '@count دن پہلے',
  '@count week ago': '@count ہفتہ پہلے',
  '@count weeks ago': '@count ہفتے پہلے',
  '@count month ago': '@count مہینہ پہلے',
  '@count months ago': '@count مہینے پہلے',
  '@count year ago': '@count سال پہلے',
  '@count years ago': '@count سال پہلے',
  'Asking the server what is new...':
      'سرور سے پوچھا جا رہا ہے کہ نیا کیا ہے...',
  'Downloading file @count...': 'فائل @count ڈاؤن لوڈ ہو رہی ہے...',
  'Updating @table (@count)': '@table اپ ڈیٹ ہو رہے ہیں (@count)',
  'Attaching recording @index of @total':
      'ریکارڈنگ @index از @total شامل ہو رہی ہے',
  'Sending @count changes...': '@count تبدیلیاں بھیجی جا رہی ہیں...',
  'Uploading @count recordings...': '@count ریکارڈنگز اپ لوڈ ہو رہی ہیں...',
  'Set @index of @total - @what': 'Set @index از @total - @what',
  'assignments': 'تفویضات',
  'Sets': 'Sets',
  'books': 'کتابیں',
  'passages': 'حصے',
  'sub-passages': 'ذیلی حصے',
  'takes': 'takes',
  'final takes': 'Final takes',
  'comments and questions': 'تبصرے اور سوالات',
  'back translations': 'واپسی ترجمے',
  'workflow': 'ورک فلو',
  'users': 'صارفین',
  'App preferences': 'ایپ کی ترجیحات',
  'Data & storage': 'ڈیٹا اور اسٹوریج',
  'Storage used': 'استعمال شدہ اسٹوریج',
  'Measuring...': 'ناپا جا رہا ہے...',
  '@size on this phone': 'اس فون پر @size',
  'Downloaded recordings': 'ڈاؤن لوڈ کی گئی ریکارڈنگز',
  'Your recordings': 'آپ کی ریکارڈنگز',
  'Scripts': 'اسکرپٹس',
  'Database': 'ڈیٹا بیس',
  'Other': 'دیگر',
  '@count Set was not sent': '@count Set نہیں بھیجا گیا',
  '@count Sets were not sent': '@count Sets نہیں بھیجے گئے',
  '@count change waiting to send': '@count تبدیلی بھیجنے کے انتظار میں',
  '@count changes waiting to send': '@count تبدیلیاں بھیجنے کے انتظار میں',
  'I have read': 'میں نے پڑھ لیا',
  'Tick "I have read" under the source script.':
      'اصل اسکرپٹ کے نیچے "میں نے پڑھ لیا" پر نشان لگائیں۔',
  'Tick "I have read" under the target script.':
      'ہدف اسکرپٹ کے نیچے "میں نے پڑھ لیا" پر نشان لگائیں۔',
  'Part of a whole-Set send back - record a new take to replace it.':
      'پورے Set کی واپسی کا حصہ - اس کی جگہ نیا take ریکارڈ کریں۔',
  'Someone': 'کوئی',
  'Peer Checker': 'ساتھی جانچ کار',
  'Community Reviewer': 'کمیونٹی جائزہ کار',
  '- tap mic to continue': '- جاری رکھنے کے لیے مائیک دبائیں',
  '- tap to stop': '- روکنے کے لیے دبائیں',
  '@count change not sent yet': '@count تبدیلی ابھی نہیں بھیجی گئی',
  '@count changes not sent yet': '@count تبدیلیاں ابھی نہیں بھیجی گئیں',
  '@count feedback item': '@count رائے',
  '@count feedback items': '@count آراء',
  '@count item could not be sent': '@count آئٹم نہیں بھیجا جا سکا',
  '@count items could not be sent': '@count آئٹمز نہیں بھیجے جا سکے',
  '@done of @total recorded': '@total میں سے @done ریکارڈ ہو چکے',
  'Add a comment here': 'یہاں تبصرہ شامل کریں',
  'Audio already recorded': 'آڈیو پہلے ہی ریکارڈ ہو چکی ہے',
  'Automated QC result': 'خودکار QC کا نتیجہ',
  'Back to list': 'فہرست پر واپس',
  'Back to passage': 'اقتباس پر واپس',
  'Choose a Set…': 'ایک سیٹ چنیں…',
  'Comment': 'تبصرہ',
  'Community Review feedback': 'کمیونٹی جائزے کی رائے',
  'Download audio to this computer': 'آڈیو اس کمپیوٹر پر ڈاؤن لوڈ کریں',
  'Eng': 'انگریزی',
  'Enter your email': 'اپنا ای میل درج کریں',
  'Enter your password': 'اپنا پاس ورڈ درج کریں',
  'Final': 'حتمی',
  'Interface language': 'ایپ کی زبان',
  'Leave a comment on the back translation first':
      'پہلے بیک ٹرانسلیشن پر تبصرہ کریں',
  'Listen to the target recording in full before sending to @stage.':
      '@stage کو بھیجنے سے پہلے ہدف ریکارڈنگ پوری سنیں۔',
  'Loading...': 'لوڈ ہو رہا ہے...',
  'Maximize': 'بڑا کریں',
  'Menu': 'مینو',
  'Microphone access is needed to record.':
      'ریکارڈ کرنے کے لیے مائیکروفون کی اجازت درکار ہے۔',
  'Next passage': 'اگلا اقتباس',
  'No back translation submitted yet.':
      'ابھی کوئی بیک ٹرانسلیشن جمع نہیں ہوئی۔',
  'No feedback yet.': 'ابھی کوئی رائے نہیں۔',
  'No passages in this Set yet.': 'اس سیٹ میں ابھی کوئی اقتباس نہیں۔',
  'No takes yet.': 'ابھی کوئی ٹیک نہیں۔',
  'Nothing assigned to you yet. Ask your Manager or Admin.':
      'ابھی آپ کو کچھ تفویض نہیں ہوا۔ اپنے منیجر یا ایڈمن سے پوچھیں۔',
  'Open': 'کھلا',
  'Open full-screen waveform': 'پوری اسکرین ویو فارم کھولیں',
  'Page @page of @pages': 'صفحہ @page از @pages',
  'Paused at': 'رکا ہوا',
  'Peer check': 'ساتھی جانچ',
  'Please wait...': 'براہ کرم انتظار کریں...',
  'Previous passage': 'پچھلا اقتباس',
  'Question': 'سوال',
  'Question @n': 'سوال @n',
  'Recorded - tap the mic to re-record':
      'ریکارڈ ہو گیا - دوبارہ ریکارڈ کرنے کے لیے مائیک دبائیں',
  'Recording disabled - source missing': 'ریکارڈنگ بند ہے - ماخذ موجود نہیں',
  'Recording... tap Stop when done':
      'ریکارڈنگ جاری ہے... مکمل ہونے پر روکیں دبائیں',
  'Remove Final - unlock this leaf to pick a different take':
      'حتمی ہٹائیں - دوسری ٹیک چننے کے لیے اس اقتباس کو کھولیں',
  'Resolved': 'حل شدہ',
  'Run QC and get Good first': 'پہلے QC چلائیں اور اچھا نتیجہ حاصل کریں',
  'Run automated QC': 'خودکار QC چلائیں',
  'Send / check for updates': 'بھیجیں / اپ ڈیٹس دیکھیں',
  'Send back to Drafter': 'ڈرافٹر کو واپس بھیجیں',
  'Set name language': 'سیٹ کے نام کی زبان',
  'Signing in...': 'سائن ان ہو رہا ہے...',
  'Source audio and source script are not available yet for this passage - recording is disabled until it\'s added.':
      'اس اقتباس کے لیے ماخذ آڈیو اور ماخذ اسکرپٹ ابھی دستیاب نہیں - ان کے شامل ہونے تک ریکارڈنگ بند ہے۔',
  'Source audio is not available yet for this passage - recording is disabled until it\'s added.':
      'اس اقتباس کے لیے ماخذ آڈیو ابھی دستیاب نہیں - اس کے شامل ہونے تک ریکارڈنگ بند ہے۔',
  'Source script is not available yet for this passage - recording is disabled until it\'s added.':
      'اس اقتباس کے لیے ماخذ اسکرپٹ ابھی دستیاب نہیں - اس کے شامل ہونے تک ریکارڈنگ بند ہے۔',
  'Stop': 'روکیں',
  'Take @n - not recorded yet': 'ٹیک @n - ابھی ریکارڈ نہیں ہوئی',
  'Take @n - recorded': 'ٹیک @n - ریکارڈ ہو چکی',
  'Take @n - recorded, Final': 'ٹیک @n - ریکارڈ ہو چکی، حتمی',
  'Target Recording': 'ہدف ریکارڈنگ',
  'The Consultant sent this back': 'کنسلٹنٹ نے اسے واپس بھیجا',
  'View takes, QC and finalize': 'ٹیکس دیکھیں، QC کریں اور حتمی بنائیں',
  'Back translate': 'بیک ٹرانسلیشن',
  'Community Feedback': 'کمیونٹی کی رائے',
  'Liked': 'پسند کیا',

  // Shut out of the app by the website (account made inactive, or app
  // access switched off): handed in, signed out, phone cleared.
  'You were signed out after 15 minutes without activity.':
      '15 منٹ تک کوئی سرگرمی نہ ہونے کی وجہ سے آپ کو سائن آؤٹ کر دیا گیا۔',
  'Signed out': 'سائن آؤٹ ہو گئے',
  'Your account is no longer active. Your work was handed in and this '
          'phone has been cleared. Contact your administrator.':
      'آپ کا اکاؤنٹ اب فعال نہیں ہے۔ آپ کا کام بھیج دیا گیا اور اس فون کا ڈیٹا '
      'صاف کر دیا گیا ہے۔ اپنے ایڈمنسٹریٹر سے رابطہ کریں۔',
  'The app has been switched off for your account. Your work was '
          'handed in and this phone has been cleared. Contact your '
          'administrator.':
      'آپ کے اکاؤنٹ کے لیے یہ ایپ بند کر دی گئی ہے۔ آپ کا کام بھیج دیا گیا اور '
      'اس فون کا ڈیٹا صاف کر دیا گیا ہے۔ اپنے ایڈمنسٹریٹر سے رابطہ کریں۔',
  '@count recording that could not be sent was saved to your Downloads '
          'folder.':
      '@count ریکارڈنگ جو نہ بھیجی جا سکی، آپ کے Downloads فولڈر میں محفوظ کر دی گئی۔',
  '@count recordings that could not be sent were saved to your Downloads '
          'folder.':
      '@count ریکارڈنگز جو نہ بھیجی جا سکیں، آپ کے Downloads فولڈر میں محفوظ کر دی گئیں۔',
};
