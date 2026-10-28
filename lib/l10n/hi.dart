/// Hindi. Keys are the English sentences exactly as the screens write them.
///
/// "Set", "Final", "QC" and "take" are left as the team says them - they are
/// the project's own words, used aloud in training, and a translated term
/// nobody has heard before is harder to follow than the one they know.
const Map<String, String> hi = {
  // ---- stages
  'Draft': 'मसौदा',
  'Sent back': 'वापस भेजा गया',
  'New Draft': 'नया मसौदा',
  'In Progress': 'प्रगति पर',
  'User Manual': 'उपयोगकर्ता मार्गदर्शिका',
  'Peer Check': 'साथी जाँच',
  'Community Setup': 'समुदाय की तैयारी',
  'Community Test': 'समुदाय परीक्षण',
  'Community Review': 'समुदाय समीक्षा',
  'Back Translation': 'वापसी अनुवाद',
  'Consultant Check': 'सलाहकार जाँच',
  'Finished': 'पूर्ण',
  'Feedback': 'प्रतिक्रिया',
  'Workbench': 'वर्कबेंच',

  // ---- roles
  'Drafter': 'मसौदाकार',
  'Peer checker': 'साथी जाँचकर्ता',
  'Back translator': 'वापसी अनुवादक',
  'Consultant': 'सलाहकार',

  // ---- stage actions
  'Send to Peer Check': 'साथी जाँच को भेजें',
  'Send to the Back Translator': 'वापसी अनुवादक को भेजें',
  'Send back to the Drafter': 'मसौदाकार को वापस भेजें',
  'Send to Community Setup': 'समुदाय की तैयारी को भेजें',
  'Send to Community Test': 'समुदाय परीक्षण को भेजें',
  'Send to Community Review': 'समुदाय समीक्षा को भेजें',
  'Send to Back Translation': 'वापसी अनुवाद को भेजें',
  'Submit to Consultant': 'सलाहकार को जमा करें',
  'Send back to the Back Translator': 'वापसी अनुवादक को वापस भेजें',
  'Approve': 'स्वीकृत करें',

  // ---- confirmations
  'Send this Set to Peer Check?': 'क्या यह Set साथी जाँच को भेजें?',
  'Send this Set to Community Test?': 'क्या यह Set समुदाय परीक्षण को भेजें?',
  'Send this Set to Community Review?': 'क्या यह Set समुदाय समीक्षा को भेजें?',
  'Send this Set to Community Setup?': 'क्या यह Set समुदाय की तैयारी को भेजें?',
  'Send this Set to Back Translation?': 'क्या यह Set वापसी अनुवाद को भेजें?',
  'Send this Set to the Back Translator?':
      'क्या यह Set वापसी अनुवादक को भेजें?',
  'Submit this back translation to the Consultant?':
      'क्या यह वापसी अनुवाद सलाहकार को जमा करें?',
  'Approve this Set? It will be marked finished.':
      'क्या यह Set स्वीकृत करें? इसे पूर्ण चिह्नित कर दिया जाएगा।',
  'Send this Set back to the Drafter?': 'क्या यह Set मसौदाकार को वापस भेजें?',
  'Send this Set back to the Back Translator?':
      'क्या यह Set वापसी अनुवादक को वापस भेजें?',
  'Remove Final from this take? You can mark a different one Final afterward.':
      'क्या इस take से Final हटाएँ? आप बाद में किसी और को Final बना सकते हैं।',
  'Remove this take? This cannot be undone.':
      'क्या यह take हटाएँ? इसे वापस नहीं किया जा सकता।',
  "Delete this comment? This can't be undone.":
      'क्या यह टिप्पणी हटाएँ? इसे वापस नहीं किया जा सकता।',
  'Send': 'भेजें',
  'Send back': 'वापस भेजें',
  'Submit': 'जमा करें',
  'Yes': 'हाँ',
  'Remove': 'हटाएँ',
  'Delete': 'हटाएँ',
  'Cancel': 'रद्द करें',
  'Close': 'बंद करें',
  'Reply': 'उत्तर दें',
  'Try again': 'फिर कोशिश करें',

  // ---- listen gates and other reasons a button is held
  'Play the source audio to the end before the first take.':
      'पहले take से पहले स्रोत ऑडियो को अंत तक सुनें।',
  'Play the recording to the end before deciding.':
      'निर्णय लेने से पहले रिकॉर्डिंग को अंत तक सुनें।',
  'Play the target recording to the end before sending it on.':
      'आगे भेजने से पहले लक्ष्य रिकॉर्डिंग अंत तक सुनें।',
  'Play the target recording to the end first.':
      'पहले लक्ष्य रिकॉर्डिंग अंत तक सुनें।',
  'Play the target recording to the end before submitting.':
      'जमा करने से पहले लक्ष्य रिकॉर्डिंग अंत तक सुनें।',
  'Play the back translation recording to the end before approving.':
      'स्वीकृत करने से पहले वापसी अनुवाद की रिकॉर्डिंग अंत तक सुनें।',
  'Skipping ahead does not count - play from where you left off to finish '
          'listening.':
      'आगे कूदना गिना नहीं जाता - जहाँ छोड़ा था वहीं से सुनकर पूरा करें।',
  'Leave a comment on the recording to send it back.':
      'वापस भेजने के लिए रिकॉर्डिंग पर टिप्पणी करें।',
  'Write or record the back translation before submitting it.':
      'जमा करने से पहले वापसी अनुवाद लिखें या रिकॉर्ड करें।',
  'You have open comments on the recording - send it back to the Drafter, '
          'or delete them first.':
      'रिकॉर्डिंग पर आपकी खुली टिप्पणियाँ हैं - इसे मसौदाकार को वापस भेजें, या '
      'पहले उन्हें हटाएँ।',
  'An open comment blocks Approve. Delete it, or send the Set back to the '
          'Back Translator.':
      'खुली टिप्पणी स्वीकृति को रोकती है। इसे हटाएँ, या Set वापसी अनुवादक को '
      'वापस भेजें।',
  'There is no back translation to approve yet.':
      'अभी स्वीकृत करने के लिए कोई वापसी अनुवाद नहीं है।',
  'Comment on the back translation to send it back.':
      'वापस भेजने के लिए वापसी अनुवाद पर टिप्पणी करें।',
  'Dislike at least one answer first, so the Drafter knows what to fix.':
      'पहले कम से कम एक उत्तर को नापसंद करें, ताकि मसौदाकार जान सके कि क्या '
      'ठीक करना है।',
  'A disliked answer has to go back to the Drafter - it cannot go on to Back '
          'Translation.':
      'नापसंद किया गया उत्तर मसौदाकार को वापस जाना है - यह वापसी अनुवाद को नहीं '
      'जा सकता।',
  'Like every answer before sending this on.':
      'आगे भेजने से पहले हर उत्तर को पसंद करें।',
  'No answer yet.': 'अभी कोई उत्तर नहीं।',
  'Like': 'पसंद',
  'Dislike': 'नापसंद',
  'A Dislike needs a comment.': 'नापसंद के साथ टिप्पणी ज़रूरी है।',
  'Only a take graded Good can be made Final.':
      'केवल वही take जिसे Good मिला हो Final बन सकता है।',
  'Tap to record a take': 'take रिकॉर्ड करने के लिए दबाएँ',
  'Microphone is off - tap to try again':
      'माइक्रोफ़ोन बंद है - फिर कोशिश के लिए दबाएँ',

  // ---- sync
  'Sync status': 'सिंक की स्थिति',
  'Help': 'सहायता',
  'User manual': 'उपयोगकर्ता पुस्तिका',
  'How to do each stage on this phone': 'इस फ़ोन पर हर चरण कैसे करें',
  'Check for updates': 'अपडेट देखें',
  'Done Synchronization.': 'सिंक पूरा हुआ।',
  'Everything is up to date.': 'सब कुछ अद्यतन है।',
  'Everything has been sent.': 'सब कुछ भेज दिया गया है।',
  'No connection': 'कनेक्शन नहीं है',
  'Waiting': 'प्रतीक्षा में',
  'Not sent': 'नहीं भेजा गया',
  'Save recordings': 'रिकॉर्डिंग सहेजें',
  'Not sent. Your work stays on this phone until there is a connection.':
      'नहीं भेजा गया। कनेक्शन मिलने तक आपका काम इसी फ़ोन पर सुरक्षित है।',

  // ---- settings
  'Settings': 'सेटिंग्स',
  'App language': 'ऐप की भाषा',
  'Roles': 'भूमिकाएँ',
  'Languages': 'भाषाएँ',
  'Sign Out': 'साइन आउट',

  // ---- workbench and sending
  'The Offline OBT App': 'ऑफ़लाइन OBT ऐप',
  'Starting up...': 'शुरू हो रहा है...',
  'The audio Bible translation recorder, powered by AI':
      'ऑडियो बाइबल अनुवाद रिकॉर्डर, AI द्वारा संचालित',
  '@count Set': '@count Set',
  '@count Sets': '@count Set',
  'Nothing assigned to you yet.\nAsk your admin.':
      'अभी आपको कोई काम नहीं दिया गया है।\nअपने एडमिन से पूछें।',
  'Nothing assigned to you here yet.':
      'यहाँ अभी आपको कोई काम नहीं दिया गया है।',
  'Send (@count)': 'भेजें (@count)',
  'Send now (@count)': 'अभी भेजें (@count)',
  'Sending...': 'भेजा जा रहा है...',
  'Sending Set @index of @total...':
      '@total में से Set @index भेजा जा रहा है...',
  'Checking with the server...': 'सर्वर से पूछा जा रहा है...',
  'Checking for updates...': 'अपडेट देखे जा रहे हैं...',
  'Keep this screen open until it finishes.':
      'पूरा होने तक यह स्क्रीन खुली रखें।',
  'Still sending. Please wait until this finishes.':
      'अभी भेजा जा रहा है। कृपया पूरा होने तक प्रतीक्षा करें।',
  'A recording that was interrupted has been recovered. You will '
          'find it among the takes.':
      'जो रिकॉर्डिंग बीच में रुक गई थी वह वापस मिल गई है। वह आपको takes '
      'में मिलेगी।',
  'A recording that was interrupted has been recovered for @passage. '
          'You will find it among the takes.':
      '@passage की जो रिकॉर्डिंग बीच में रुक गई थी वह वापस मिल गई है। वह '
      'आपको takes में मिलेगी।',
  'The update check failed: @reason': 'अपडेट नहीं देखे जा सके: @reason',
  'Nothing new to download.': 'डाउनलोड के लिए कुछ नया नहीं है।',
  'Downloaded @count new file.': '@count नई फ़ाइल डाउनलोड हुई।',
  'Downloaded @count new files.': '@count नई फ़ाइलें डाउनलोड हुईं।',
  'Sent @rows change.': '@rows बदलाव भेज दिया गया।',
  'Sent @rows changes.': '@rows बदलाव भेज दिए गए।',
  'Sent @rows change and @files recording.':
      '@rows बदलाव और @files रिकॉर्डिंग भेज दी गई।',
  'Sent @rows changes and @files recording.':
      '@rows बदलाव और @files रिकॉर्डिंग भेज दिए गए।',
  'Sent @rows change and @files recordings.':
      '@rows बदलाव और @files रिकॉर्डिंग भेज दिए गए।',
  'Sent @rows changes and @files recordings.':
      '@rows बदलाव और @files रिकॉर्डिंग भेज दिए गए।',
  'Not sent.': 'नहीं भेजा गया।',
  '@count Set was not sent.': '@count Set नहीं भेजा गया।',
  '@count Sets were not sent.': '@count Set नहीं भेजे गए।',
  'Not sent. Something went wrong. Your work is still here.':
      'नहीं भेजा गया। कुछ गड़बड़ हो गई। आपका काम अब भी यहीं है।',

  // ---- signing in and out
  'Welcome back': 'फिर से स्वागत है',
  'Sign in to continue to your workbench.':
      'अपने वर्कबेंच पर जाने के लिए साइन इन करें।',
  'Email': 'ईमेल',
  'Password': 'पासवर्ड',
  'Sign in': 'साइन इन',
  'Trouble signing in? Contact your project administrator.':
      'साइन इन में परेशानी है? अपने प्रोजेक्ट के एडमिन से संपर्क करें।',
  'Are you sure you want to sign out?':
      'क्या आप वाकई साइन आउट करना चाहते हैं?',
  'Cannot reach the OBT server. The first sign-in on this phone needs a connection - that is when your work is downloaded.':
      'OBT सर्वर तक नहीं पहुँचा जा सका। इस फ़ोन पर पहली बार साइन इन करने के लिए कनेक्शन चाहिए - तभी आपका काम डाउनलोड होता है।',
  'No connection, and this is not the password that signed in with this email on this phone.':
      'कनेक्शन नहीं है, और यह वह पासवर्ड नहीं है जिससे इस ईमेल ने इस फ़ोन पर साइन इन किया था।',
  'Your last download did not finish. Connect to the internet and sign in again to complete it.':
      'आपका पिछला डाउनलोड पूरा नहीं हुआ। इंटरनेट से जुड़कर फिर से साइन इन करें ताकि वह पूरा हो सके।',
  'Please enter both email and password.': 'कृपया ईमेल और पासवर्ड दोनों लिखें।',
  'Cannot reach the OBT server. Check your connection and try again '
          '- your work is downloaded at sign-in.':
      'OBT सर्वर तक पहुँच नहीं हो रही। अपना कनेक्शन देखें और फिर कोशिश '
      'करें - आपका काम साइन इन के समय डाउनलोड होता है।',
  'Invalid server response.': 'सर्वर का जवाब सही नहीं है।',
  'Something went wrong. Please try again.':
      'कुछ गड़बड़ हो गई। कृपया फिर कोशिश करें।',
  'Sign in failed. Please try again.':
      'साइन इन नहीं हो सका। कृपया फिर कोशिश करें।',
  'The download did not finish. Please sign in again.':
      'डाउनलोड पूरा नहीं हुआ। कृपया फिर से साइन इन करें।',
  'Preparing your files...': 'आपकी फ़ाइलें तैयार की जा रही हैं...',
  'Securing your files...': 'आपकी फ़ाइलें सुरक्षित की जा रही हैं...',
  '@saved / @total files ready': '@saved / @total फ़ाइलें तैयार',
  'Swipe left for the next passage': 'अगले अंश के लिए बाएँ स्वाइप करें',
  'Swipe right for the next passage': 'अगले अंश के लिए दाएँ स्वाइप करें',
  'Collecting your data...': 'आपका डेटा इकट्ठा किया जा रहा है...',
  'Preparing...': 'तैयारी हो रही है...',
  '@saved / @total files downloaded': '@saved / @total फ़ाइलें डाउनलोड हो गईं',
  'Ready for a fresh start?': 'नए सिरे से शुरू करना चाहते हैं?',
  "You're currently offline": 'आप इस समय ऑफ़लाइन हैं',
  'Keep My Data': 'मेरा डेटा रखें',
  'Stay Signed In': 'साइन इन रहें',
  'Sign out': 'साइन आउट',
  'Signed in': 'साइन इन हैं',
  'Signing out will remove the *sets, recordings, and scripts* '
          'stored on this device.':
      'साइन आउट करने से इस फ़ोन पर रखे *Sets, रिकॉर्डिंग और स्क्रिप्ट* '
      'हट जाएँगे।',
  'Any work that has not been uploaded or synced will also be '
          'permanently removed.':
      'जो काम अभी अपलोड या सिंक नहीं हुआ है वह भी हमेशा के लिए हट जाएगा।',
  'If you do not need the work saved on this device, you can sign '
          'out safely. *Sign in again any time to download your content '
          'fresh and get back to work.*':
      'अगर आपको इस फ़ोन पर रखे काम की ज़रूरत नहीं है तो आप बेफ़िक्र होकर '
      'साइन आउट कर सकते हैं। *किसी भी समय फिर से साइन इन करके अपनी '
      'सामग्री नए सिरे से डाउनलोड करें और काम जारी रखें।*',
  'There is no internet connection on this phone right now.':
      'इस समय इस फ़ोन पर इंटरनेट कनेक्शन नहीं है।',
  '*Signing out will remove everything stored on this device*, '
          'including your *sets, recordings, and scripts*. Any work that has '
          'not been uploaded or synced will also be permanently removed.':
      '*साइन आउट करने से इस फ़ोन पर रखा सब कुछ हट जाएगा*, जिसमें आपके '
      '*Sets, रिकॉर्डिंग और स्क्रिप्ट* भी शामिल हैं। जो काम अभी अपलोड या '
      'सिंक नहीं हुआ है वह भी हमेशा के लिए हट जाएगा।',
  'To get your content back, you will need *to sign in again with an '
          'internet connection* and download it again.':
      'अपनी सामग्री वापस पाने के लिए आपको *इंटरनेट कनेक्शन के साथ फिर से '
      'साइन इन* करके उसे दोबारा डाउनलोड करना होगा।',
  'No internet available? It is safest to stay signed in and '
          'continue working offline.':
      'इंटरनेट नहीं है? सबसे सुरक्षित यही है कि साइन इन रहें और ऑफ़लाइन '
      'काम जारी रखें।',

  // ---- settings drawer
  'No role assigned yet.': 'अभी कोई भूमिका नहीं दी गई है।',
  'No Sets assigned yet.': 'अभी कोई Set नहीं दिया गया है।',
  'Reading...': 'पढ़ा जा रहा है...',
  'Source': 'स्रोत',

  // ---- Set lists and progress
  'Sent back - needs changes': 'वापस भेजा गया - बदलाव चाहिए',
  'In progress': 'काम जारी है',
  'Add community questions': 'समुदाय के प्रश्न जोड़ें',
  'Run community test': 'समुदाय परीक्षण करें',
  'Ready for your check': 'आपकी जाँच के लिए तैयार',
  'Ready for review': 'समीक्षा के लिए तैयार',
  'Needs back translation': 'वापसी अनुवाद चाहिए',
  'Ready for consultant check': 'सलाहकार जाँच के लिए तैयार',
  'Back Translator': 'वापसी अनुवादक',
  'Sent back from @stage': '@stage से वापस भेजा गया',
  '@where - @done of @total recorded':
      '@where - @total में से @done रिकॉर्ड हो गए',
  '@count more Set after this one': 'इसके बाद @count और Set है',
  '@count more Sets after this one': 'इसके बाद @count और Set हैं',
  'Jump to a pending work item (@count pending)':
      'किसी बाकी काम पर जाएँ (@count बाकी)',
  '@done of @total passage recorded': '@total में से @done भाग रिकॉर्ड हो गया',
  '@done of @total passages recorded': '@total में से @done भाग रिकॉर्ड हो गए',
  'No Set has been approved yet.': 'अभी कोई Set स्वीकृत नहीं हुआ है।',
  'Listen': 'सुनें',
  'Download': 'डाउनलोड करें',
  'Downloading @done of @total': '@total में से @done डाउनलोड हो रहा है',
  'Checking this device...': 'इस फ़ोन को देखा जा रहा है...',
  'No finished recording': 'कोई पूर्ण रिकॉर्डिंग नहीं',
  'On this device - @count passage': 'इस फ़ोन पर मौजूद है - @count भाग',
  'On this device - @count passages': 'इस फ़ोन पर मौजूद हैं - @count भाग',
  '@done of @total passage downloaded':
      '@total में से @done भाग डाउनलोड हो गया',
  '@done of @total passages downloaded':
      '@total में से @done भाग डाउनलोड हो गए',
  'Tap to download @count passage': '@count भाग डाउनलोड करने के लिए दबाएँ',
  'Tap to download @count passages': '@count भाग डाउनलोड करने के लिए दबाएँ',
  '@set is on this device.': '@set इस फ़ोन पर मौजूद है।',
  'Task Done': 'कार्य पूर्ण',
  '@set has no finished recording to download.':
      '@set की कोई पूर्ण रिकॉर्डिंग डाउनलोड के लिए मौजूद नहीं है।',
  '@done of @total passages downloaded - the rest could not be '
          'fetched.':
      '@total में से @done भाग डाउनलोड हुए - बाकी नहीं मिल सके।',
  'Could not download @set: @error': '@set डाउनलोड नहीं हो सका: @error',
  'No feedback yet.\nLiked answers that come with a comment will '
          'show here.':
      'अभी कोई प्रतिक्रिया नहीं।\nपसंद किए गए वे उत्तर जिनके साथ टिप्पणी '
      'हो यहाँ दिखेंगे।',
  '@count comment': '@count टिप्पणी',
  '@count comments': '@count टिप्पणियाँ',

  // ---- sync status and problems
  'never': 'कभी नहीं',
  'Last full sync: @when': 'पिछला पूरा सिंक: @when',
  'Last full sync: @when · offline now': 'पिछला पूरा सिंक: @when · अभी ऑफ़लाइन',
  '@count change is only on this phone.': '@count बदलाव केवल इसी फ़ोन पर है।',
  '@count changes are only on this phone.':
      '@count बदलाव केवल इसी फ़ोन पर हैं।',
  '@count recording': '@count रिकॉर्डिंग',
  '@count recordings': '@count रिकॉर्डिंग',
  '@count comment / question': '@count टिप्पणी / प्रश्न',
  '@count comments / questions': '@count टिप्पणियाँ / प्रश्न',
  '@count other change': '@count अन्य बदलाव',
  '@count other changes': '@count अन्य बदलाव',
  'hand-off to @stage': '@stage को सौंपना',
  'Set @id': 'Set @id',
  '@when · your work on this Set is still on this phone.':
      '@when · इस Set पर आपका काम अब भी इसी फ़ोन पर है।',
  '@when · your work on this Set is still on this phone and will be '
          'tried again.':
      '@when · इस Set पर आपका काम अब भी इसी फ़ोन पर है और इसे फिर से '
      'भेजने की कोशिश की जाएगी।',
  'Give up this work': 'यह काम छोड़ दें',
  'Give up': 'छोड़ दें',
  'Give up the unsent work on this Set? It will not be sent. Save '
          'the recordings to Downloads first if you want to keep them.':
      'क्या इस Set का न भेजा गया काम छोड़ दें? यह नहीं भेजा जाएगा। अगर '
      'रिकॉर्डिंग रखना चाहते हैं तो पहले उन्हें Downloads में सहेज लें।',
  'There were no recordings to save for this Set.':
      'इस Set की सहेजने के लिए कोई रिकॉर्डिंग नहीं थी।',
  'Saved @count recording to Downloads.':
      '@count रिकॉर्डिंग Downloads में सहेज दी गई।',
  'Saved @count recordings to Downloads.':
      '@count रिकॉर्डिंग Downloads में सहेज दी गईं।',
  'A send is already running.': 'भेजने का काम पहले से चल रहा है।',
  'This Set is no longer assigned to you. Your work on it is still '
          'on this phone - ask your manager before it is removed.':
      'यह Set अब आपके ज़िम्मे नहीं है। इस पर आपका काम अब भी इसी फ़ोन पर '
      'है - इसे हटाने से पहले अपने मैनेजर से पूछें।',
  'This Set was changed somewhere else while you were offline - it '
          'is now at "@stage". Your hand-off was not sent, and your work is '
          'still on this phone.':
      'जब आप ऑफ़लाइन थे तब यह Set कहीं और से बदल दिया गया - अब यह '
      '"@stage" पर है। आपका सौंपना नहीं भेजा गया, और आपका काम अब भी इसी '
      'फ़ोन पर है।',
  'A recording is missing from this phone (@file). Record it again, '
          'or remove that take.':
      'एक रिकॉर्डिंग इस फ़ोन पर नहीं मिल रही (@file)। इसे फिर से रिकॉर्ड '
      'करें, या वह take हटा दें।',
  'The server refused it (@code).': 'सर्वर ने इसे स्वीकार नहीं किया (@code)।',
  'Your sign-in has expired. Sign in again to send your work - it '
          'stays on this phone until then.':
      'आपके साइन इन की अवधि समाप्त हो गई है। अपना काम भेजने के लिए फिर '
      'से साइन इन करें - तब तक वह इसी फ़ोन पर सुरक्षित है।',
  'The server had a problem (@code). Your work stays on this phone - '
          'try again later.':
      'सर्वर में कोई समस्या थी (@code)। आपका काम इसी फ़ोन पर सुरक्षित है '
      '- बाद में फिर कोशिश करें।',
  'The connection was too slow to finish. Your work stays on this '
          'phone - try again where the signal is better.':
      'कनेक्शन इतना धीमा था कि काम पूरा नहीं हो सका। आपका काम इसी फ़ोन '
      'पर सुरक्षित है - जहाँ सिग्नल बेहतर हो वहाँ फिर कोशिश करें।',
  'Could not reach the server.': 'सर्वर तक पहुँच नहीं हो सकी।',
  'The server refused the refresh (@code).':
      'सर्वर ने अपडेट स्वीकार नहीं किया (@code)।',
  'The server sent something unusable.':
      'सर्वर ने ऐसा जवाब भेजा जो इस्तेमाल नहीं हो सकता।',
  '@action - saved. It will be sent with your next sync.':
      '@action - सहेज लिया गया। यह आपके अगले सिंक के साथ भेज दिया जाएगा।',
  'Could not send it: @error': 'इसे भेजा नहीं जा सका: @error',

  // ---- players and recordings
  'Recording': 'रिकॉर्डिंग',
  'Merged recording': 'पूरी रिकॉर्डिंग',
  'Merged draft audio': 'पूरे मसौदे का ऑडियो',
  'Source audio': 'स्रोत ऑडियो',
  'Source script': 'स्रोत स्क्रिप्ट',
  'Target script': 'अनुवाद की स्क्रिप्ट',
  'Source Content': 'स्रोत सामग्री',
  'Target Content': 'अनुवाद की सामग्री',
  'No source audio yet.': 'अभी कोई स्रोत ऑडियो नहीं।',
  'No source script yet.': 'अभी कोई स्रोत स्क्रिप्ट नहीं।',
  'No target script yet.': 'अभी अनुवाद की कोई स्क्रिप्ट नहीं।',
  'No source script on this device yet. Press Send on the workbench '
          'to fetch it.':
      'इस फ़ोन पर अभी कोई स्रोत स्क्रिप्ट नहीं है। इसे लाने के लिए '
      'वर्कबेंच पर "भेजें" दबाएँ।',
  'Full screen': 'पूरी स्क्रीन',
  'Playback speed': 'चलाने की गति',
  'ZOOM': 'ज़ूम',
  'Back 5 seconds': '5 सेकंड पीछे',
  'Forward 5 seconds': '5 सेकंड आगे',
  'Play': 'चलाएँ',
  'Pause': 'रोकें',
  'Add comment': 'टिप्पणी जोड़ें',
  'Comment here': 'यहाँ टिप्पणी करें',
  'A passage could not be played, so this does not count as a full '
          'listen yet.':
      'एक भाग चल नहीं सका, इसलिए अभी इसे पूरा सुनना नहीं गिना जाएगा।',
  'This recording could not be read: @error':
      'यह रिकॉर्डिंग पढ़ी नहीं जा सकी: @error',
  'Audio file is not available offline': 'ऑडियो फ़ाइल ऑफ़लाइन मौजूद नहीं है',
  '@missing of @total passages are not in this recording.':
      '@total में से @missing भाग इस रिकॉर्डिंग में नहीं हैं।',
  'No source audio has been added for this passage.':
      'इस भाग के लिए कोई स्रोत ऑडियो नहीं जोड़ा गया है।',
  'The source audio has not been downloaded to this device yet.':
      'स्रोत ऑडियो अभी इस फ़ोन पर डाउनलोड नहीं हुआ है।',
  'This set has no passages on this device. Log out and back in to '
          're-sync.':
      'इस फ़ोन पर इस Set का कोई भाग नहीं है। फिर से सिंक के लिए साइन आउट '
      'करके दोबारा साइन इन करें।',
  'None of the @count passages here has a final take on this device. '
          'The final_takes table did not sync - check it in the database '
          'viewer.':
      'यहाँ के @count भागों में से किसी का भी Final take इस फ़ोन पर नहीं '
      'है। final_takes तालिका सिंक नहीं हुई - इसे डेटाबेस व्यूअर में '
      'देखें।',
  '@missing of @total passages have no final take yet, so they are '
          'not in this recording.':
      '@total में से @missing भागों का अभी कोई Final take नहीं है, इसलिए '
      'वे इस रिकॉर्डिंग में शामिल नहीं हैं।',

  // ---- writing or recording a comment, question or answer
  'Type it here': 'यहाँ लिखें',
  'Save': 'सहेजें',
  'Voice': 'आवाज़',
  'Text': 'लिखकर',
  'Tap to stop': 'रोकने के लिए दबाएँ',
  'Tap to record': 'रिकॉर्ड करने के लिए दबाएँ',
  'Tap to record audio': 'ऑडियो रिकॉर्ड करने के लिए दबाएँ',
  'Discard': 'छोड़ दें',
  'Record again': 'फिर से रिकॉर्ड करें',
  'Discard recording': 'रिकॉर्डिंग छोड़ दें',
  'Previously recorded': 'पहले की रिकॉर्डिंग',
  'Microphone permission is needed to record.':
      'रिकॉर्ड करने के लिए माइक्रोफ़ोन की अनुमति ज़रूरी है।',
  'Could not start recording: @error': 'रिकॉर्डिंग शुरू नहीं हो सकी: @error',
  'At @time': '@time पर',
  'Pinned at @time': '@time पर लगाया गया',
  'Reviewer': 'समीक्षक',
  'You': 'आप',
  'Voice note': 'आवाज़ में नोट',
  'Voice comment': 'आवाज़ में टिप्पणी',
  'Voice answer': 'आवाज़ में उत्तर',
  'Voice reply': 'आवाज़ में जवाब',
  'Voice question': 'आवाज़ में प्रश्न',
  'Delete comment': 'टिप्पणी हटाएँ',
  'Delete question': 'प्रश्न हटाएँ',

  // ---- the Set screen
  'This set could not be opened.': 'यह Set खुल नहीं सका।',
  'No passages in this set yet.': 'इस Set में अभी कोई भाग नहीं है।',
  '@count passage still needs a final take before this can go to '
          '@stage.':
      '@stage को भेजने से पहले @count भाग का Final take अभी बाकी है।',
  '@count passages still need a final take before this can go to '
          '@stage.':
      '@stage को भेजने से पहले @count भागों के Final take अभी बाकी हैं।',
  '@count passage still needs a final take before this can move on.':
      'आगे बढ़ने से पहले @count भाग का Final take अभी बाकी है।',
  '@count passages still need a final take before this can move on.':
      'आगे बढ़ने से पहले @count भागों के Final take अभी बाकी हैं।',
  'Tap the waveform to jump to a spot, then leave a note there.':
      'किसी जगह पर जाने के लिए तरंग पर दबाएँ, फिर वहाँ नोट लिखें।',
  'Tap the waveform to jump to a spot.':
      'किसी जगह पर जाने के लिए तरंग पर दबाएँ।',
  'Add a note here': 'यहाँ नोट जोड़ें',
  'Note - @passage': 'नोट - @passage',
  'What needs to change here?': 'यहाँ क्या बदलना ज़रूरी है?',
  'Play the recording first, then leave a note there.':
      'पहले रिकॉर्डिंग चलाएँ, फिर वहाँ नोट लिखें।',
  'Could not save the note: @error': 'नोट सहेजा नहीं जा सका: @error',
  'Could not delete the comment: @error': 'टिप्पणी हटाई नहीं जा सकी: @error',
  'There is no finished audio on this device to save.':
      'इस फ़ोन पर सहेजने के लिए कोई पूर्ण ऑडियो नहीं है।',
  'Nothing could be saved - the audio is not on this device.':
      'कुछ भी सहेजा नहीं जा सका - ऑडियो इस फ़ोन पर नहीं है।',
  'Could not save the audio: @error': 'ऑडियो सहेजा नहीं जा सका: @error',
  '@count passage left': '@count भाग बाकी है',
  '@count passages left': '@count भाग बाकी हैं',
  'Finalized': 'Final हो गया',
  'No takes': 'कोई take नहीं',
  '@count take': '@count take',
  '@count takes': '@count takes',

  // ---- the recorder
  '@count takes is the limit - remove one on the Takes screen to '
          'record another.':
      '@count takes की सीमा है - नया रिकॉर्ड करने के लिए Takes स्क्रीन '
      'पर से एक हटाएँ।',
  'Source audio and source script are both missing.':
      'स्रोत ऑडियो और स्रोत स्क्रिप्ट दोनों मौजूद नहीं हैं।',
  'Source audio is missing.': 'स्रोत ऑडियो मौजूद नहीं है।',
  'Source script is missing.': 'स्रोत स्क्रिप्ट मौजूद नहीं है।',
  'Microphone is off': 'माइक्रोफ़ोन बंद है',
  'Recording needs the microphone, and it has been turned off for '
          'this app. Open settings to switch it back on.':
      'रिकॉर्डिंग के लिए माइक्रोफ़ोन ज़रूरी है, और इस ऐप के लिए इसे बंद '
      'कर दिया गया है। इसे फिर से चालू करने के लिए सेटिंग्स खोलें।',
  'Recording needs the microphone. Tap record again to allow it.':
      'रिकॉर्डिंग के लिए माइक्रोफ़ोन ज़रूरी है। अनुमति देने के लिए '
      'रिकॉर्ड का बटन फिर से दबाएँ।',
  'Open settings': 'सेटिंग्स खोलें',
  'Could not pause - the recording is still running.':
      'रोका नहीं जा सका - रिकॉर्डिंग अभी चल रही है।',
  'Could not resume. Stop to keep what has been recorded.':
      'फिर से शुरू नहीं हो सका। जो रिकॉर्ड हो चुका है उसे रखने के लिए '
      'बंद करें।',
  'No voice was detected. Speak clearly, close to the phone, and '
          'record again.':
      'कोई आवाज़ नहीं मिली। फ़ोन के पास साफ़ बोलें और फिर से रिकॉर्ड करें।',
  'The recording the Drafter and the Peer listen to for this passage.':
      'वह रिकॉर्डिंग जिसे Drafter और Peer इस अंश के लिए सुनते हैं।',
  'The text of this passage in the source language.':
      'स्रोत भाषा में इस अंश का पाठ।',
  'The text of this passage in the target language.':
      'लक्ष्य भाषा में इस अंश का पाठ।',
  'Take recording': 'take की रिकॉर्डिंग',
  'A recording of this passage. Without it the take cannot be played.':
      'इस अंश की रिकॉर्डिंग। इसके बिना take चलाया नहीं जा सकता।',
  "A reviewer's spoken comment on a recording.":
      'रिकॉर्डिंग पर समीक्षक की बोली हुई टिप्पणी।',
  'Question recording': 'प्रश्न की रिकॉर्डिंग',
  'A community question or its answer, spoken.':
      'समुदाय का प्रश्न या उसका उत्तर, बोला हुआ।',
  'Back translation recording': 'वापसी अनुवाद की रिकॉर्डिंग',
  'The spoken back translation of this Set.':
      'इस Set का बोला हुआ वापसी अनुवाद।',
  'A recording this Set refers to.': 'इस Set से जुड़ी एक रिकॉर्डिंग।',
  '@count file did not download': '@count फ़ाइल डाउनलोड नहीं हुई',
  '@count files did not download': '@count फ़ाइलें डाउनलोड नहीं हुईं',
  'Choose for each file: try again, or skip it. A skipped file is tried again at the next Check for updates.':
      'हर फ़ाइल के लिए चुनें: दोबारा कोशिश करें, या छोड़ दें। छोड़ी गई फ़ाइल अगली बार अपडेट जाँचने पर फिर आज़माई जाएगी।',
  'Try all again': 'सब दोबारा आज़माएँ',
  'Skip all': 'सब छोड़ें',
  'Continue without these files': 'इन फ़ाइलों के बिना आगे बढ़ें',
  'Try @count file again': '@count फ़ाइल दोबारा आज़माएँ',
  'Try @count files again': '@count फ़ाइलें दोबारा आज़माएँ',
  'Skip': 'छोड़ें',
  'Used for': 'किस काम की',
  'File': 'फ़ाइल',
  'Problem': 'समस्या',
  'The file could not be downloaded.': 'फ़ाइल डाउनलोड नहीं हो सकी।',
  'The download stopped part way and was given up.':
      'डाउनलोड बीच में रुक गया और छोड़ दिया गया।',
  'No connection to the server.': 'सर्वर से संपर्क नहीं है।',
  'The file could not be saved on this phone.':
      'फ़ाइल इस फ़ोन पर सहेजी नहीं जा सकी।',
  'The server sent an empty file.': 'सर्वर ने खाली फ़ाइल भेजी।',
  'The server did not send the file (error @code).':
      'सर्वर ने फ़ाइल नहीं भेजी (त्रुटि @code)।',
  'The server asked for a sign-in instead of sending the file.':
      'सर्वर ने फ़ाइल भेजने के बजाय साइन-इन माँगा।',
  'No network. @count change is waiting to be sent.':
      'नेटवर्क नहीं है। @count बदलाव भेजे जाने की प्रतीक्षा में है।',
  'No network. @count changes are waiting to be sent.':
      'नेटवर्क नहीं है। @count बदलाव भेजे जाने की प्रतीक्षा में हैं।',
  'No answer was given.': 'कोई उत्तर नहीं दिया गया।',
  'This take cannot be made Final': 'इस take को Final नहीं बनाया जा सकता',
  'Recording stopped because audio started playing.':
      'ऑडियो चलने लगा, इसलिए रिकॉर्डिंग रोक दी गई।',
  'Nothing was recorded.': 'कुछ भी रिकॉर्ड नहीं हुआ।',
  'This phone cannot play this recording at another speed. Playing at '
          'normal speed.':
      'यह फ़ोन इस रिकॉर्डिंग को दूसरी गति पर नहीं चला सकता। सामान्य गति '
      'पर चल रही है।',
  'This recording could not be played. Tap play to try again.':
      'यह रिकॉर्डिंग नहीं चल सकी। फिर से कोशिश करने के लिए प्ले दबाएँ।',
  'No sound was picked up in this recording. Check the microphone and '
          'record again.':
      'इस रिकॉर्डिंग में कोई आवाज़ नहीं आई। माइक्रोफ़ोन जाँचें और फिर से '
      'रिकॉर्ड करें।',
  'Too short to keep - a take must be at least @count seconds.':
      'रखने के लिए बहुत छोटा है - एक take कम से कम @count सेकंड का होना '
      'चाहिए।',
  'Checking audio...': 'ऑडियो जाँचा जा रहा है...',
  'Saving...': 'सहेजा जा रहा है...',
  'Deleting...': 'हटाया जा रहा है...',
  'This recording is not a WAV file and was not saved.':
      'यह रिकॉर्डिंग WAV फ़ाइल नहीं है और सहेजी नहीं गई।',
  'QC passed': 'QC में पास',
  'QC @status - see the take for why':
      'QC @status - कारण जानने के लिए take देखें',
  'QC @status': 'QC @status',
  'QC: @status': 'QC: @status',
  'The audio for this take is not on this device.':
      'इस take का ऑडियो इस फ़ोन पर नहीं है।',
  'Unmark it as final before deleting it.': 'हटाने से पहले इससे Final हटाएँ।',
  'Something went wrong: @error': 'कुछ गड़बड़ हो गई: @error',
  '@passage - Takes': '@passage - Takes',
  'Listen to the final take and mark anything that needs to change.':
      'Final take सुनें और जो कुछ बदलना ज़रूरी हो उस पर निशान लगाएँ।',
  'No takes yet': 'अभी कोई take नहीं',
  'All takes (@count/@max)': 'सभी takes (@count/@max)',
  'Takes recorded (@count/@max)': 'रिकॉर्ड किए गए takes (@count/@max)',
  'Nothing recorded on this passage yet. Step back to the recorder '
          'to make the first take.':
      'इस भाग पर अभी कुछ रिकॉर्ड नहीं हुआ है। पहला take बनाने के लिए '
      'रिकॉर्डर पर वापस जाएँ।',
  'Why this was sent back': 'यह क्यों वापस भेजा गया',
  'Marks': 'निशान',
  'Take @index': 'Take @index',
  'Not synced': 'सिंक नहीं हुआ',
  'Deleted': 'हटाया गया',
  'Not run': 'नहीं चलाया गया',
  'Run QC': 'QC चलाएँ',
  'Run QC again': 'QC फिर से चलाएँ',
  'Make final': 'Final बनाएँ',
  'Remove final': 'Final हटाएँ',
  'Delete take': 'take हटाएँ',
  'QC details (@count checks)': 'QC का विवरण (@count जाँचें)',
  '@failed of @count checks failed': '@count में से @failed जाँचें असफल हुईं',
  'Clipping': 'आवाज़ का फटना (Clipping)',
  // ---- QC feedback, in the recorder's words
  'Clear audio with no distortion from excessive volume.':
      'साफ़ ऑडियो, ज़्यादा आवाज़ से कोई विकृति नहीं।',
  'Audio distortion detected due to excessive volume. Reduce speaking volume or increase the distance from the microphone.':
      'ज़्यादा आवाज़ के कारण ऑडियो में विकृति मिली। बोलने की आवाज़ कम करें या माइक्रोफ़ोन से दूरी बढ़ाएँ।',
  'Recording begins and ends naturally, with minimal silence.':
      'रिकॉर्डिंग स्वाभाविक रूप से शुरू और ख़त्म होती है, बहुत कम ख़ामोशी के साथ।',
  'Excessive silence detected at the beginning or end. Start promptly and stop shortly after the final word.':
      'शुरुआत या अंत में ज़रूरत से ज़्यादा ख़ामोशी मिली। तुरंत बोलना शुरू करें और आख़िरी शब्द के थोड़ी देर बाद रोक दें।',
  'A quiet recording environment ensures clear speech.':
      'शांत माहौल में रिकॉर्डिंग से बोली साफ़ रहती है।',
  'Background noise is affecting speech clarity. Record in a quieter environment away from fans, traffic, and other people.':
      'पीछे का शोर बोली की स्पष्टता पर असर डाल रहा है। पंखे, ट्रैफ़िक और दूसरे लोगों से दूर, शांत माहौल में रिकॉर्ड करें।',
  'Recording duration matches the expected passage length.':
      'रिकॉर्डिंग की अवधि अंश की अपेक्षित लंबाई से मेल खाती है।',
  'Recording duration differs significantly from the expected length. Check passage completeness and avoid extra content.':
      'रिकॉर्डिंग की अवधि अपेक्षित लंबाई से काफ़ी अलग है। देखें कि अंश पूरा है और अतिरिक्त सामग्री न हो।',
  'Audio format meets the project requirements.':
      'ऑडियो प्रारूप परियोजना की आवश्यकताओं के अनुसार है।',
  'Audio format does not meet project requirements. Record directly through the app to ensure compatibility.':
      'ऑडियो प्रारूप परियोजना की आवश्यकताओं के अनुसार नहीं है। संगतता के लिए सीधे ऐप से रिकॉर्ड करें।',
  'The complete passage is captured, including the final word.':
      'पूरा अंश रिकॉर्ड हुआ है, आख़िरी शब्द सहित।',
  'The recording may have ended before speech was complete. Allow a brief pause after the final word before stopping.':
      'रिकॉर्डिंग शायद बोली पूरी होने से पहले ख़त्म हो गई। रोकने से पहले आख़िरी शब्द के बाद थोड़ा रुकें।',
  'Speech is clearly audible throughout the recording.':
      'पूरी रिकॉर्डिंग में बोली साफ़ सुनाई देती है।',
  'Little or no speech was detected. Improve speech clarity and maintain an appropriate distance from the microphone.':
      'बोली बहुत कम या बिल्कुल नहीं मिली। साफ़ बोलें और माइक्रोफ़ोन से उचित दूरी रखें।',
  'Speech volume remains consistent throughout the recording.':
      'पूरी रिकॉर्डिंग में बोली की आवाज़ एक जैसी बनी रहती है।',
  'Significant volume variations detected. Maintain a steady speaking volume from beginning to end.':
      'आवाज़ में काफ़ी उतार-चढ़ाव मिला। शुरू से अंत तक एक जैसी आवाज़ में बोलें।',
  'Speech remains clear without distracting competing sounds.':
      'बोली साफ़ है, ध्यान भटकाने वाली दूसरी ध्वनियाँ नहीं हैं।',
  'Competing sounds are affecting speech clarity. Choose a quieter recording environment for better results.':
      'दूसरी ध्वनियाँ बोली की स्पष्टता पर असर डाल रही हैं। बेहतर नतीजे के लिए शांत जगह चुनें।',
  // ---- QC checks and their details
  'Voice detected':
      'आवाज़ पहचानी गई',
  'Volume consistency':
      'आवाज़ की एकरूपता',
  'Background noise':
      'पीछे का शोर',
  'Every Language. Beyond Words.':
      'हर भाषा। शब्दों से परे।',
  'Language • Intelligence • Voice • Understanding • Knowledge • Augmentation':
      'भाषा • बुद्धिमत्ता • आवाज़ • समझ • ज्ञान • संवर्धन',
  'Peak @peak dBFS, @pct% samples at/near full scale':
      'शिखर @peak dBFS, @pct% सैंपल पूरे स्तर पर/उसके पास',
  '@before before the first word, @after after the last (limit @limit)':
      'पहले शब्द से पहले @before, आख़िरी के बाद @after (सीमा @limit)',
  'Recording is too uniform to isolate a background level - treated as clean':
      'रिकॉर्डिंग इतनी एकसमान है कि पीछे का स्तर अलग नहीं हो सका - साफ़ माना गया',
  'Background level @level dBFS (limit @limit dBFS)':
      'पीछे का स्तर @level dBFS (सीमा @limit dBFS)',
  '@seconds recorded. No source audio to compare against, expected roughly @range':
      '@seconds रिकॉर्ड हुआ। तुलना के लिए स्रोत ऑडियो नहीं है, लगभग @range अपेक्षित',
  '@seconds recorded. Source audio is @source, expected roughly @range':
      '@seconds रिकॉर्ड हुआ। स्रोत ऑडियो @source है, लगभग @range अपेक्षित',
  '@rate Hz, 1 channel':
      '@rate Hz, 1 चैनल',
  '@rate Hz, @channels channels':
      '@rate Hz, @channels चैनल',
  'Last @tail at @level dBFS (limit @limit dBFS)':
      'आख़िरी @tail @level dBFS पर (सीमा @limit dBFS)',
  '@seconds (@pct%) of this take is a voice':
      'इस टेक का @seconds (@pct%) आवाज़ है',
  'Only @seconds (@pct%) of this take is a voice - speak clearly, close to the phone, and record again':
      'इस टेक का केवल @seconds (@pct%) आवाज़ है - साफ़ बोलें, फ़ोन के पास रहें, और फिर से रिकॉर्ड करें',
  'No voice was detected in this recording - speak clearly, close to the phone, and record again':
      'इस रिकॉर्डिंग में कोई आवाज़ नहीं मिली - साफ़ बोलें, फ़ोन के पास रहें, और फिर से रिकॉर्ड करें',
  'Not enough speech detected to judge volume consistency':
      'आवाज़ की एकरूपता आँकने के लिए पर्याप्त बोली नहीं मिली',
  'Speech volume ranged @spread dB across the take (limit @limit dB) - stays fairly even throughout':
      'टेक में बोली की आवाज़ @spread dB के दायरे में रही (सीमा @limit dB) - लगभग एकसमान बनी रही',
  'Speech volume ranged @spread dB across the take (limit @limit dB) - volume changes noticeably partway through':
      'टेक में बोली की आवाज़ @spread dB के दायरे में रही (सीमा @limit dB) - बीच में आवाज़ साफ़ तौर पर बदलती है',
  'Not enough speech detected to judge background noise':
      'पीछे का शोर आँकने के लिए पर्याप्त बोली नहीं मिली',
  'Found @seconds of sound that is not the voice and is about as loud (limit @limit) - have a listen, this may be background noise':
      '@seconds ऐसी ध्वनि मिली जो आवाज़ नहीं है और लगभग उतनी ही तेज़ है (सीमा @limit) - सुनकर देखें, यह पीछे का शोर हो सकता है',
  'No other sound near the level of the voice':
      'आवाज़ के स्तर के पास कोई और ध्वनि नहीं',
  'Head / tail silence': 'शुरू / अंत की ख़ामोशी',
  'Noise floor': 'पीछे का शोर',
  'Duration': 'अवधि',
  'Sample rate / channels': 'Sample rate / channels',
  'Truncation': 'रिकॉर्डिंग का कट जाना',

  // ---- community setup, test and review
  'Community setup': 'समुदाय की तैयारी',
  'Community test': 'समुदाय परीक्षण',
  'Community review': 'समुदाय समीक्षा',
  'Question - @passage': 'प्रश्न - @passage',
  'What should the community be asked here?': 'यहाँ समुदाय से क्या पूछा जाए?',
  'General question': 'सामान्य प्रश्न',
  'General questions': 'सामान्य प्रश्न',
  'About the whole set, not one passage.':
      'पूरे Set के बारे में, किसी एक भाग के बारे में नहीं।',
  'What should the community be asked?': 'समुदाय से क्या पूछा जाए?',
  'Could not save the question: @error': 'प्रश्न सहेजा नहीं जा सका: @error',
  'Add a question here': 'यहाँ प्रश्न जोड़ें',
  'Add a general question': 'सामान्य प्रश्न जोड़ें',
  'Add a question first': 'पहले एक प्रश्न जोड़ें',
  'Tap the waveform to jump to the spot you mean, then add the '
          'question there.':
      'जिस जगह की बात है वहाँ जाने के लिए तरंग पर दबाएँ, फिर वहाँ प्रश्न '
      'जोड़ें।',
  '@count question pinned to the recording - tap a marker to read '
          'one.':
      '@count प्रश्न रिकॉर्डिंग पर लगा है - पढ़ने के लिए निशान पर दबाएँ।',
  '@count questions pinned to the recording - tap a marker to read '
          'one.':
      '@count प्रश्न रिकॉर्डिंग पर लगे हैं - कोई पढ़ने के लिए निशान पर '
      'दबाएँ।',
  'Questions': 'प्रश्न',
  'all answered': 'सबके उत्तर मिल गए',
  '@count unanswered': '@count का उत्तर बाकी',
  '@count question left': '@count प्रश्न बाकी है',
  '@count questions left': '@count प्रश्न बाकी हैं',
  'Listen to the whole recording above first - the questions will '
          'appear here once you have.':
      'पहले ऊपर वाली पूरी रिकॉर्डिंग सुनें - उसके बाद प्रश्न यहाँ '
      'दिखेंगे।',
  'Answer': 'उत्तर दें',
  'Answered': 'उत्तर मिल गया',
  'Answered - @answer': 'उत्तर मिल गया - @answer',
  'Answer this question': 'इस प्रश्न का उत्तर दें',
  'Type what they said': 'जो उन्होंने कहा वह लिखें',
  'Could not save the answer: @error': 'उत्तर सहेजा नहीं जा सका: @error',
  'Passage': 'भाग',
  'No questions to test yet.': 'अभी परीक्षण के लिए कोई प्रश्न नहीं।',
  'One question has no answer yet. It needs one before this Set can '
          'go anywhere.':
      'एक प्रश्न का अभी कोई उत्तर नहीं है। उसका उत्तर मिले बिना यह Set '
      'कहीं नहीं जा सकता।',
  '@count questions have no answer yet. They need one before this '
          'Set can go anywhere.':
      '@count प्रश्नों के अभी कोई उत्तर नहीं हैं। उनके उत्तर मिले बिना '
      'यह Set कहीं नहीं जा सकता।',
  'Tell the Drafter what worked': 'मसौदाकार को बताएँ क्या अच्छा रहा',
  'Optional - this is the only praise the Drafter sees.':
      'वैकल्पिक - मसौदाकार को केवल यही तारीफ़ दिखती है।',
  'What is wrong with this answer?': 'इस उत्तर में क्या ग़लत है?',
  'A Dislike needs a comment - the Drafter works from it.':
      'नापसंद के साथ टिप्पणी ज़रूरी है - मसौदाकार उसी को देखकर काम करता '
      'है।',
  'Could not save it: @error': 'इसे सहेजा नहीं जा सका: @error',
  'Change your comment': 'अपनी टिप्पणी बदलें',
  'Add a comment for the Drafter (optional)':
      'मसौदाकार के लिए टिप्पणी जोड़ें (वैकल्पिक)',
  'The community test produced no questions.':
      'समुदाय परीक्षण से कोई प्रश्न नहीं मिला।',

  // ---- back translation and consultant check
  'Back translation': 'वापसी अनुवाद',
  'Consultant check': 'सलाहकार जाँच',
  'Reply to the Consultant': 'सलाहकार को जवाब दें',
  'What would you like to say back?': 'आप जवाब में क्या कहना चाहेंगे?',
  'Could not save the reply: @error': 'जवाब सहेजा नहीं जा सका: @error',
  'Could not delete it: @error': 'इसे हटाया नहीं जा सका: @error',
  'Comment - @passage': 'टिप्पणी - @passage',
  'What is wrong here?': 'यहाँ क्या ग़लत है?',
  'Could not save the comment: @error': 'टिप्पणी सहेजी नहीं जा सकी: @error',
  'Tap the waveform to jump to the spot you mean, then comment there.':
      'जिस जगह की बात है वहाँ जाने के लिए तरंग पर दबाएँ, फिर वहाँ '
      'टिप्पणी करें।',
  'Not satisfied? Comment on it': 'संतुष्ट नहीं? इस पर टिप्पणी करें',
  "The Consultant's comments": 'सलाहकार की टिप्पणियाँ',
  'Submitting a new back translation closes all of these.':
      'नया वापसी अनुवाद जमा करने से ये सब बंद हो जाते हैं।',
  'Back translation (text or voice - either is fine)':
      'वापसी अनुवाद (लिखकर या आवाज़ में - दोनों में से कोई भी ठीक है)',
  'Type the back translation...': 'वापसी अनुवाद यहाँ लिखें...',
  'Comment on the back translation': 'वापसी अनुवाद पर टिप्पणी करें',
  'What does not match?': 'क्या मेल नहीं खाता?',
  'Your comments': 'आपकी टिप्पणियाँ',
  'The back translator has not submitted one yet.':
      'वापसी अनुवादक ने अभी कोई जमा नहीं किया है।',
  'An open comment blocks sending this on. Delete it, or send the Set back to the Drafter.':
      'खुली टिप्पणी आगे भेजने को रोकती है। इसे हटाएँ, या Set मसौदाकार को वापस भेजें।',
  'This recording has not been downloaded to this phone yet. Use Check for updates when there is a connection.':
      'यह रिकॉर्डिंग अभी इस फ़ोन पर डाउनलोड नहीं हुई है। कनेक्शन मिलने पर "अपडेट देखें" का उपयोग करें।',
  'Automated QC': 'स्वचालित QC',
  'QC: @status - passed automatically': 'QC: @status - अपने आप पास हो गया',
  'This is a mechanical check, not a judgement on the translation - use your own judgement too.':
      'यह एक यांत्रिक जाँच है, अनुवाद पर निर्णय नहीं - अपनी समझ का भी उपयोग करें।',
  'OK': 'ठीक है',
  '@length window': '@length की विंडो',
  'Zoom in': 'ज़ूम इन',
  'Zoom out': 'ज़ूम आउट',
  'Re-record': 'फिर से रिकॉर्ड करें',
  'Record': 'रिकॉर्ड करें',
  'Not started': 'शुरू नहीं हुआ',
  'Sent back from @stage - needs changes':
      '@stage से वापस भेजा गया - बदलाव चाहिए',
  'Your recording': 'आपकी रिकॉर्डिंग',
  'Home': 'होम',
  'This take was sent back with a comment from @reviewer - record a new take to fix it before marking one Final.':
      'यह take @reviewer की टिप्पणी के साथ वापस भेजा गया था - इसे ठीक करने के लिए नया take रिकॉर्ड करें, फिर किसी को Final बनाएँ।',
  'This take was sent back with a reply from @reviewer - record a new take to fix it before marking one Final.':
      'यह take @reviewer के उत्तर के साथ वापस भेजा गया था - इसे ठीक करने के लिए नया take रिकॉर्ड करें, फिर किसी को Final बनाएँ।',
  'This passage was sent back with a comment from @reviewer - record a new take to fix it before marking one Final.':
      'यह अंश @reviewer की टिप्पणी के साथ वापस भेजा गया था - इसे ठीक करने के लिए नया take रिकॉर्ड करें, फिर किसी को Final बनाएँ।',
  'the Back Translator': 'वापसी अनुवादक',
  'a reviewer': 'समीक्षक',
  'This take is no longer Final - it did not pass QC this time. Mark another take Final, or record a new one.':
      'यह take अब Final नहीं रहा - इस बार यह QC में पास नहीं हुआ। किसी और take को Final बनाएँ, या नया रिकॉर्ड करें।',
  'Play both recordings to the end to send this on - or leave a comment to send it back.':
      'आगे भेजने के लिए दोनों रिकॉर्डिंग अंत तक सुनें - या वापस भेजने के लिए टिप्पणी करें।',
  'Approved': 'स्वीकृत',
  'CC Checked': 'CC जाँचा गया',
  'just now': 'अभी-अभी',
  '@count minute ago': '@count मिनट पहले',
  '@count minutes ago': '@count मिनट पहले',
  '@count hour ago': '@count घंटा पहले',
  '@count hours ago': '@count घंटे पहले',
  '@count day ago': '@count दिन पहले',
  '@count days ago': '@count दिन पहले',
  '@count week ago': '@count सप्ताह पहले',
  '@count weeks ago': '@count सप्ताह पहले',
  '@count month ago': '@count महीना पहले',
  '@count months ago': '@count महीने पहले',
  '@count year ago': '@count साल पहले',
  '@count years ago': '@count साल पहले',
  'Asking the server what is new...':
      'सर्वर से पूछा जा रहा है कि नया क्या है...',
  'Downloading file @count...': 'फ़ाइल @count डाउनलोड हो रही है...',
  'Updating @table (@count)': '@table अपडेट हो रहे हैं (@count)',
  'Attaching recording @index of @total':
      'रिकॉर्डिंग @index / @total जोड़ी जा रही है',
  'Sending @count changes...': '@count बदलाव भेजे जा रहे हैं...',
  'Uploading @count recordings...': '@count रिकॉर्डिंग अपलोड हो रही हैं...',
  'Set @index of @total - @what': 'Set @index / @total - @what',
  'assignments': 'असाइनमेंट',
  'Sets': 'Sets',
  'books': 'किताबें',
  'passages': 'अंश',
  'sub-passages': 'उप-अंश',
  'takes': 'takes',
  'final takes': 'Final takes',
  'comments and questions': 'टिप्पणियाँ और प्रश्न',
  'back translations': 'वापसी अनुवाद',
  'workflow': 'वर्कफ़्लो',
  'users': 'उपयोगकर्ता',
  'App preferences': 'ऐप की प्राथमिकताएँ',
  'Data & storage': 'डेटा और स्टोरेज',
  'Storage used': 'उपयोग किया गया स्टोरेज',
  'Measuring...': 'मापा जा रहा है...',
  '@size on this phone': 'इस फ़ोन पर @size',
  'Downloaded recordings': 'डाउनलोड की गई रिकॉर्डिंग',
  'Your recordings': 'आपकी रिकॉर्डिंग',
  'Scripts': 'स्क्रिप्ट',
  'Database': 'डेटाबेस',
  'Other': 'अन्य',
  '@count Set was not sent': '@count Set नहीं भेजा गया',
  '@count Sets were not sent': '@count Sets नहीं भेजे गए',
  '@count change waiting to send': '@count बदलाव भेजने की प्रतीक्षा में',
  '@count changes waiting to send': '@count बदलाव भेजने की प्रतीक्षा में',
  'I have read': 'मैंने पढ़ लिया',
  'Tick "I have read" under the source script.':
      'स्रोत स्क्रिप्ट के नीचे "मैंने पढ़ लिया" पर सही का निशान लगाएँ।',
  'Tick "I have read" under the target script.':
      'लक्ष्य स्क्रिप्ट के नीचे "मैंने पढ़ लिया" पर सही का निशान लगाएँ।',
  'Part of a whole-Set send back - record a new take to replace it.':
      'पूरे Set की वापसी का हिस्सा - इसकी जगह नया take रिकॉर्ड करें।',
  'Someone': 'कोई',
  'Peer Checker': 'साथी जाँचकर्ता',
  'Community Reviewer': 'समुदाय समीक्षक',
  '- tap mic to continue': '- जारी रखने के लिए माइक दबाएँ',
  '- tap to stop': '- रोकने के लिए दबाएँ',
  '@count change not sent yet': '@count बदलाव अभी नहीं भेजा गया',
  '@count changes not sent yet': '@count बदलाव अभी नहीं भेजे गए',
  '@count feedback item': '@count प्रतिक्रिया',
  '@count feedback items': '@count प्रतिक्रियाएँ',
  '@count item could not be sent': '@count आइटम नहीं भेजा जा सका',
  '@count items could not be sent': '@count आइटम नहीं भेजे जा सके',
  '@done of @total recorded': '@total में से @done रिकॉर्ड हो चुके',
  'Add a comment here': 'यहाँ टिप्पणी जोड़ें',
  'Audio already recorded': 'ऑडियो पहले ही रिकॉर्ड हो चुका है',
  'Automated QC result': 'स्वचालित QC का परिणाम',
  'Back to list': 'सूची पर वापस',
  'Back to passage': 'अंश पर वापस',
  'Choose a Set…': 'एक सेट चुनें…',
  'Comment': 'टिप्पणी',
  'Community Review feedback': 'समुदाय समीक्षा की प्रतिक्रिया',
  'Download audio to this computer': 'ऑडियो इस कंप्यूटर पर डाउनलोड करें',
  'Eng': 'अंग्रेज़ी',
  'Enter your email': 'अपना ईमेल दर्ज करें',
  'Enter your password': 'अपना पासवर्ड दर्ज करें',
  'Final': 'अंतिम',
  'Interface language': 'ऐप की भाषा',
  'Leave a comment on the back translation first':
      'पहले बैक ट्रांसलेशन पर टिप्पणी करें',
  'Listen to the target recording in full before sending to @stage.':
      '@stage को भेजने से पहले लक्ष्य रिकॉर्डिंग पूरी सुनें।',
  'Loading...': 'लोड हो रहा है...',
  'Maximize': 'बड़ा करें',
  'Menu': 'मेनू',
  'Microphone access is needed to record.':
      'रिकॉर्ड करने के लिए माइक्रोफ़ोन की अनुमति चाहिए।',
  'Next passage': 'अगला अंश',
  'No back translation submitted yet.': 'अभी कोई बैक ट्रांसलेशन जमा नहीं हुआ।',
  'No feedback yet.': 'अभी कोई प्रतिक्रिया नहीं।',
  'No passages in this Set yet.': 'इस सेट में अभी कोई अंश नहीं।',
  'No takes yet.': 'अभी कोई टेक नहीं।',
  'Nothing assigned to you yet. Ask your Manager or Admin.':
      'अभी आपको कुछ सौंपा नहीं गया। अपने मैनेजर या एडमिन से पूछें।',
  'Open': 'खुला',
  'Open full-screen waveform': 'पूरी स्क्रीन वेवफ़ॉर्म खोलें',
  'Page @page of @pages': 'पृष्ठ @page / @pages',
  'Paused at': 'रुका हुआ',
  'Peer check': 'साथी जाँच',
  'Please wait...': 'कृपया प्रतीक्षा करें...',
  'Previous passage': 'पिछला अंश',
  'Question': 'प्रश्न',
  'Question @n': 'प्रश्न @n',
  'Recorded - tap the mic to re-record':
      'रिकॉर्ड हो गया - फिर से रिकॉर्ड करने के लिए माइक दबाएँ',
  'Recording disabled - source missing': 'रिकॉर्डिंग बंद है - स्रोत मौजूद नहीं',
  'Recording... tap Stop when done':
      'रिकॉर्डिंग जारी है... पूरा होने पर रोकें दबाएँ',
  'Remove Final - unlock this leaf to pick a different take':
      'अंतिम हटाएँ - दूसरी टेक चुनने के लिए इस अंश को खोलें',
  'Resolved': 'हल हो गया',
  'Run QC and get Good first': 'पहले QC चलाएँ और अच्छा परिणाम पाएँ',
  'Run automated QC': 'स्वचालित QC चलाएँ',
  'Send / check for updates': 'भेजें / अपडेट देखें',
  'Send back to Drafter': 'ड्राफ़्टर को वापस भेजें',
  'Set name language': 'सेट के नाम की भाषा',
  'Signing in...': 'साइन इन हो रहा है...',
  'Source audio and source script are not available yet for this passage - recording is disabled until it\'s added.':
      'इस अंश के लिए स्रोत ऑडियो और स्रोत स्क्रिप्ट अभी उपलब्ध नहीं - इनके जुड़ने तक रिकॉर्डिंग बंद है।',
  'Source audio is not available yet for this passage - recording is disabled until it\'s added.':
      'इस अंश के लिए स्रोत ऑडियो अभी उपलब्ध नहीं - इसके जुड़ने तक रिकॉर्डिंग बंद है।',
  'Source script is not available yet for this passage - recording is disabled until it\'s added.':
      'इस अंश के लिए स्रोत स्क्रिप्ट अभी उपलब्ध नहीं - इसके जुड़ने तक रिकॉर्डिंग बंद है।',
  'Stop': 'रोकें',
  'Take @n - not recorded yet': 'टेक @n - अभी रिकॉर्ड नहीं हुई',
  'Take @n - recorded': 'टेक @n - रिकॉर्ड हो चुकी',
  'Take @n - recorded, Final': 'टेक @n - रिकॉर्ड हो चुकी, अंतिम',
  'Target Recording': 'लक्ष्य रिकॉर्डिंग',
  'The Consultant sent this back': 'कंसल्टेंट ने इसे वापस भेजा',
  'View takes, QC and finalize': 'टेक देखें, QC करें और अंतिम बनाएँ',
  'Back translate': 'बैक ट्रांसलेशन',
  'Community Feedback': 'समुदाय की प्रतिक्रिया',
  'Liked': 'पसंद किया',

  // Shut out of the app by the website (account made inactive, or app
  // access switched off): handed in, signed out, phone cleared.
  'You were signed out after 15 minutes without activity.':
      '15 मिनट तक कोई गतिविधि न होने के कारण आपको साइन आउट कर दिया गया।',
  'Signed out': 'साइन आउट हो गए',
  'Your account is no longer active. Your work was handed in and this '
          'phone has been cleared. Contact your administrator.':
      'आपका खाता अब सक्रिय नहीं है। आपका काम भेज दिया गया और इस फ़ोन का डेटा '
      'हटा दिया गया है। अपने व्यवस्थापक से संपर्क करें।',
  'The app has been switched off for your account. Your work was '
          'handed in and this phone has been cleared. Contact your '
          'administrator.':
      'आपके खाते के लिए यह ऐप बंद कर दिया गया है। आपका काम भेज दिया गया और इस '
      'फ़ोन का डेटा हटा दिया गया है। अपने व्यवस्थापक से संपर्क करें।',
  '@count recording that could not be sent was saved to your Downloads '
          'folder.':
      '@count रिकॉर्डिंग जो भेजी नहीं जा सकी, आपके Downloads फ़ोल्डर में सहेज दी गई।',
  '@count recordings that could not be sent were saved to your Downloads '
          'folder.':
      '@count रिकॉर्डिंग जो भेजी नहीं जा सकीं, आपके Downloads फ़ोल्डर में सहेज दी गईं।',
};
