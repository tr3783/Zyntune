/// Text for the first-visit tool intros and the Help & FAQ screen.
/// (docs/faq.html has the same FAQ for the website; keep them in step.)

class ToolIntro {
  final String title;
  final List<String> points;
  const ToolIntro(this.title, this.points);
}

const toolIntros = <String, ToolIntro>{
  'home': ToolIntro('Home', [
    'Your daily goal, streak and today\'s objectives at a glance.',
    'Practice every day to grow your streak. Each saved session earns 10 points.',
    'With Pro, spend 50 points on a Streak Freeze to protect your streak on a missed day.',
  ]),
  'metronome': ToolIntro('Metronome', [
    'Tap + or − to change the tempo by 1. Hold to change by 5, or tap the number to type it.',
    'Quick tempos and a slider sit below.',
    'It keeps playing when you lock the screen or switch to another Zyntune tool.',
    'Eighth, triplet and sixteenth subdivisions come with Pro.',
  ]),
  'timer': ToolIntro('Timer', [
    'Stopwatch: tap Start when you begin and Stop & Save when you\'re done. Choose the instrument, piece and movement.',
    'Countdown: pick a length, and Zyntune lets you know when time\'s up.',
    'Forgot to start the timer? Add the session by hand below.',
    'Saved sessions count toward your daily goal and your streak.',
  ]),
  'record': ToolIntro('Record', [
    'Record audio of your practice or a lesson. It keeps recording if you lock the screen or use other tools.',
    'In a recording, slow it down, loop a tricky spot, or add markers with notes.',
    'Recordings stay on your iPhone. Share one only when you choose.',
    'Free accounts keep 3 audio recordings. Pro adds unlimited recordings and video.',
  ]),
  'repertoire': ToolIntro('Repertoire', [
    'Keep a list of your pieces, with the composer, movements, notes and a link to a recording or score.',
    'Set a status for each piece and movement, and a total practice goal.',
    'Tap a piece\'s mic to record it. Its recordings are listed oldest to newest so you can hear your progress.',
    'Free accounts can keep 10 pieces. Pro is unlimited.',
  ]),
  'goals': ToolIntro('Goals', [
    'Set daily, weekly or monthly goals, like "Memorize page 2" or "Learn the C major scale".',
    'Check them off as you go. Finished goals are kept so you can look back.',
  ]),
  'stats': ToolIntro('Stats', [
    'See your practice time by day, by instrument and by piece, plus achievements to unlock.',
    'Tap a session to edit or delete it.',
    'Export your practice history as a spreadsheet.',
    'Pro adds your full history, best day and best week, a 6-month chart and a weekly report card.',
  ]),
  'tuner': ToolIntro('Tuner', [
    'Tap Start Tuner and play one note at a time, close to the microphone. The meter shows whether you\'re flat, sharp or in tune.',
    'The Tone Generator plays a reference note to tune to by ear.',
  ]),
  'notes': ToolIntro('Notes', [
    'Write lesson notes, reminders and ideas. Search them anytime.',
  ]),
  'calendar': ToolIntro('Calendar', [
    'Schedule lessons, recitals, auditions, performances and deadlines.',
    'See the days you practiced at a glance.',
    'The Practice Calendar is part of Zyntune Pro.',
  ]),
  'studio': ToolIntro('Studio', [
    'Your studio code is shown here. Share it with your students; they enter it in Settings → My Teacher / Join Studio.',
    'See each student\'s practice, streak, progress and repertoire.',
    'Send reminders and assignments. Parents who added their email get a copy.',
  ]),
};

class FaqItem {
  final String question;
  final String answer;
  const FaqItem(this.question, this.answer);
}

class FaqSection {
  final String title;
  final List<FaqItem> items;
  const FaqSection(this.title, this.items);
}

const supportEmail = 'zyntuneapp@gmail.com';

const faqSections = <FaqSection>[
  FaqSection('Getting Started', [
    FaqItem('How do I log my practice?',
        'Open Timer and use the stopwatch, or add a session by hand if you forgot. Choose the instrument, and the piece and movement if you like.'),
    FaqItem('What counts toward my streak?',
        'Saving at least one practice session on a day. Miss a day and the streak starts over, unless a Streak Freeze covers it.'),
    FaqItem('What are points for?',
        'Each saved session earns 10 points. With Pro, 50 points buys a Streak Freeze, which protects your streak for one missed day.'),
    FaqItem('Can I practice more than one instrument?',
        'Yes. Add your instruments in Settings and switch between them on Home. Each session remembers its instrument.'),
  ]),
  FaqSection('Recordings', [
    FaqItem('Where are my recordings stored?',
        'Only on your iPhone, never on our servers. A recording leaves your phone only if you share it yourself.'),
    FaqItem('Are recordings backed up?',
        'Audio recordings are included in your iPhone\'s own iCloud Backup. Videos aren\'t, because of their size. Share any you want to keep elsewhere.'),
    FaqItem('I deleted a recording by mistake.',
        'Look in Recently Deleted at the bottom of Recordings. Deleted recordings stay there for 7 days.'),
    FaqItem('Why did my recording stop?',
        'A phone call, Siri, or another app using the microphone stops a recording. Everything up to then is kept, and Zyntune offers to save it.'),
  ]),
  FaqSection('Zyntune Pro', [
    FaqItem('What\'s included in Pro?',
        'Video recording, unlimited recordings and repertoire, metronome subdivisions, Streak Freeze, the Practice Calendar, advanced stats and the weekly report card, shareable session cards, the home-screen widget, and your full practice history.'),
    FaqItem('What does Pro cost?',
        'Choose monthly, yearly or lifetime. Prices are shown in the app in your local currency. Yearly includes a 7-day free trial.'),
    FaqItem('How do I cancel or restore a purchase?',
        'Cancel anytime in your iPhone\'s Settings → your name → Subscriptions. To restore, tap Restore Purchases on the Zyntune Pro screen.'),
  ]),
  FaqSection('Teachers & Parents', [
    FaqItem('How do I link to my teacher?',
        'Ask your teacher for their 6-character studio code. Then go to Settings → My Teacher / Join Studio and enter it.'),
    FaqItem('What can my teacher see?',
        'Your practice sessions, streak, progress and repertoire. Your teacher can\'t see your recordings or notes.'),
    FaqItem('Can my teacher send me reminders?',
        'Yes. Teachers can send reminders and assignments, which show up on your Home screen.'),
    FaqItem('Can a parent get copies?',
        'Yes. Add a parent or guardian email in Settings, and they\'ll get a copy of teacher reminders and assignments.'),
    FaqItem('I\'m a teacher. How do I set up a studio?',
        'Choose Teacher when you create your account. Your Studio on Home shows your studio code; share it with your students, who enter it in Settings → My Teacher / Join Studio.'),
  ]),
  FaqSection('Accounts & Data', [
    FaqItem('Is my practice data backed up?',
        'Yes. Your practice history, repertoire, goals, notes and calendar are saved to your account, so they come back when you sign in on a new device.'),
    FaqItem('We share an iPad. Is that OK?',
        'Yes. Each person signs in to their own account and sees only their own practice data and recordings.'),
    FaqItem('How do I delete my account?',
        'Go to Settings → Delete Account. This permanently deletes your account and data, including recordings on that device.'),
    FaqItem('How do I contact you?', 'Email us at $supportEmail.'),
  ]),
];
