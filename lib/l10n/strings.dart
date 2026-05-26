import '../models/date_idea.dart';
import '../models/moment_item.dart';

class AppStrings {
  final bool isNorwegian;
  const AppStrings({required this.isNorwegian});

  // ── Navigation ──────────────────────────────────────────────────────────
  String get navHome => isNorwegian ? 'Hjem' : 'Home';
  String get navLastTime => isNorwegian ? 'Sist gang' : 'Last Time';
  String get navIdeas => isNorwegian ? 'Ideer' : 'Ideas';
  String get navPlan => isNorwegian ? 'Plan' : 'Plan';

  // ── Home Screen ─────────────────────────────────────────────────────────
  String get greetingMorning => isNorwegian ? 'God morgen, dere to! 👋' : 'Good morning, you two! 👋';
  String get greetingAfternoon => isNorwegian ? 'God ettermiddag, dere to! 👋' : 'Good afternoon, you two! 👋';
  String get greetingEvening => isNorwegian ? 'God kveld, dere to! 👋' : 'Good evening, you two! 👋';
  String get greetingNight => isNorwegian ? 'Fortsatt våkne, dere to? 🌙' : 'Still awake, you two? 🌙';
  String get homeInspirationQuote => isNorwegian ? 'Et lite kompliment kan lyse opp dagen.' : 'A small compliment can brighten the day.';
  String get homeTonightSection => isNorwegian ? 'Kveldens idé' : 'Tonight\'s idea';
  String get homeThisWeekSection => isNorwegian ? 'Denne uken' : 'This week';
  String get homeTonightTag => isNorwegian ? 'Minidate' : 'Mini-date';
  String get homeTonightTitle => isNorwegian ? 'Kort + te' : 'Cards + tea';
  String get homeTonightSubtitle => isNorwegian ? '20 min · bare dere to' : '20 min · just you two';
  String get homeSendIdea => isNorwegian ? 'Send idé' : 'Send idea';
  String get homeWriteOwn => isNorwegian ? 'Skriv din egen' : 'Write your own';
  String homeWaiting(String dots) => isNorwegian ? 'Krysser fingrene... S tenker$dots' : 'Fingers crossed... S is thinking$dots';
  String get homeWalkTogether => isNorwegian ? 'Gå tur sammen' : 'Walk together';
  String get homeDateNight => isNorwegian ? 'Datenatt' : 'Date night';
  String get homePhoneFreeTalk => isNorwegian ? 'Telefonfri prat' : 'Phone-free talk';
  String get homeSendNote => isNorwegian ? 'Send en lapp' : 'Send a note';
  String get homeDoneThisWeek => isNorwegian ? 'Ferdig denne uken' : 'Done this week';
  String get homeWeeklyGoal => isNorwegian ? '0 av 1 denne uken' : '0 of 1 this week';
  String get homeResolveTitle => isNorwegian ? 'Ikke helt enig?' : 'Not quite on the same page?';
  String get homeResolveSubtitle => isNorwegian ? 'La Tom hjelpe dere å finne midten' : 'Let Tom help you find the middle ground';
  String get homeWriteOwnSheetTitle => isNorwegian ? 'Skriv din egen' : 'Write your own';
  String get homeWriteOwnSheetSubtitle => isNorwegian ? 'La det høres ut som deg.' : 'Make it sound like you.';
  String get homeWriteOwnHint => isNorwegian ? 'Skriv meldingen din...' : 'Write your message...';
  String get homeSendToS => isNorwegian ? 'Send til S' : 'Send to S';
  String get homeSentToS => isNorwegian ? 'Sendt til S!' : 'Sent to S!';
  String get homeWeeklyIdeasSection => isNorwegian ? 'Ukens ideer' : 'This week\'s ideas';
  String get homeAiPersonalized => isNorwegian ? 'AI-personalisert denne uken' : 'AI-personalised this week';
  String get homeWeeklyIdeasEmpty => isNorwegian ? 'Ingen ideer ennå — prøv igjen snart.' : 'No ideas yet — check back soon.';
  String get homeIdeaSendToPartner => isNorwegian ? 'Send idé til partner' : 'Send idea to partner';

  // ── Last Time Screen ────────────────────────────────────────────────────
  String get lastTimeTitle => isNorwegian ? 'Sist gang' : 'Last time';
  String get lastTimeSubtitle => isNorwegian ? 'Når gjorde dere dette sist?' : 'When did you last do this together?';
  String get lastTime07 => isNorwegian ? '0–7 dager' : '0–7 days';
  String get lastTime814 => isNorwegian ? '8–14 dager' : '8–14 days';
  String get lastTime15 => isNorwegian ? '15+ dager' : '15+ days';
  String lastTimeStat(int count) => isNorwegian
      ? '$count øyeblikk denne måneden'
      : '$count moment${count == 1 ? '' : 's'} this month';
  String lastTimeStreak(int weeks) => isNorwegian
      ? '$weeks uke${weeks == 1 ? '' : 'r'} på rad'
      : '$weeks week${weeks == 1 ? '' : 's'} in a row';
  String get lastTimeLogButton => isNorwegian ? 'Vi gjorde noe!' : 'We did something!';

  // ── Log Moment Sheet ────────────────────────────────────────────────────
  String get logTitle => isNorwegian ? 'Vi gjorde noe!' : 'We did something!';
  String get logSubtitle => isNorwegian ? 'Hva gjorde dere sammen?' : 'What did you do together?';
  String get logSuccess => isNorwegian ? 'Logget!' : 'Logged!';
  String get logSuccessMsg => isNorwegian ? 'Flott. Små øyeblikk holder kjærligheten sterk.' : 'Nice. Small moments keep love strong.';
  String get logButton => isNorwegian ? 'Logg det!' : 'Log it!';
  String logOptionLabel(String id) {
    if (isNorwegian) {
      const nb = {
        'date_night': 'Datenatt',
        'home_date': 'Hjemmedate',
        'walk': 'Gå tur sammen',
        'game': 'Spill sammen',
        'phone_free': 'Telefonfri prat',
        'no_kids': 'Tid uten barn',
        'custom': 'Eget øyeblikk',
      };
      return nb[id] ?? id;
    }
    const en = {
      'date_night': 'Date night',
      'home_date': 'Home date',
      'walk': 'Walk together',
      'game': 'Game together',
      'phone_free': 'Phone-free talk',
      'no_kids': 'Time without kids',
      'custom': 'Custom moment',
    };
    return en[id] ?? id;
  }

  // ── Relationship Battery Card ───────────────────────────────────────────
  String get batteryTitle => isNorwegian ? 'Relasjonsladning' : 'Relationship battery';
  String batteryMood(int pct) {
    if (isNorwegian) {
      if (pct >= 90) return 'På topp!';
      if (pct >= 70) return 'Kosemodus';
      if (pct >= 50) return 'Trenger en gnist';
      if (pct >= 30) return 'Trenger en lading';
      return 'Lav ladning';
    }
    if (pct >= 90) return 'On fire!';
    if (pct >= 70) return 'Cozy mode';
    if (pct >= 50) return 'Could use a spark';
    if (pct >= 30) return 'Need a recharge';
    return 'Low battery';
  }
  String batteryPillLabel(int pct) {
    if (isNorwegian) {
      if (pct >= 80) return 'Bra';
      if (pct >= 65) return 'OK';
      return 'Lavt';
    }
    if (pct >= 80) return 'Great';
    if (pct >= 65) return 'Good';
    return 'Low';
  }
  String batteryStatus(int pct) {
    if (isNorwegian) {
      if (pct >= 80) return 'Dere gjør det kjempebra! 💚';
      if (pct >= 65) return 'Dere gjør det bra! 💛';
      return 'Tid for å koble til igjen. 🤍';
    }
    if (pct >= 80) return 'You\'re doing great! 💚';
    if (pct >= 65) return 'You\'re doing well! 💛';
    return 'Time to reconnect. 🤍';
  }
  String batteryMsg(int pct) {
    if (isNorwegian) {
      if (pct >= 80) return 'Forbindelsen deres er sterk. Fortsett!';
      if (pct >= 65) return 'Lad opp med små øyeblikk sammen.';
      return 'Det har gått en stund. Planlegg noe snart.';
    }
    if (pct >= 80) return 'Your connection is strong. Keep it up.';
    if (pct >= 65) return 'Recharge with small moments together.';
    return 'It\'s been a while. Plan something soon.';
  }

  // ── Ideas Screen ────────────────────────────────────────────────────────
  String get ideasTitle => isNorwegian ? 'Dateideer' : 'Date ideas';
  String get ideasSubtitle => isNorwegian ? 'Små ideer, stor forbindelse.' : 'Small ideas, big connection.';
  String get ideasAll => isNorwegian ? 'Alle' : 'All';
  String get ideasChip10min => '10 min';
  String get ideasChip30home => isNorwegian ? '30 min hjemme' : '30 min at home';
  String get ideasChip1hour => isNorwegian ? '1 time ute' : '1 hour out';
  String get ideasChipBabysitter => isNorwegian ? 'Babysitterkveld' : 'Babysitter night';
  String get ideasChipParent => isNorwegian ? 'Foreldremodus' : 'Parent mode';
  String get ideasEmpty => isNorwegian ? 'Ingen ideer i denne kategorien.' : 'No ideas in this category.';
  String get ideasSuggestionSent => isNorwegian ? 'Forslag sendt til partneren din!' : 'Suggestion sent to your partner!';
  String get ideaSendLabel => isNorwegian ? 'Send' : 'Send';
  String get ideaSentLabel => isNorwegian ? 'Sendt til S!' : 'Sent to S!';

  String ideaTitle(String id) {
    if (isNorwegian) {
      const nb = {
        'question_cards': 'Spørsmålskort i sofaen',
        'tea_dessert': 'Te + dessert hjemme',
        'evening_walk': 'Kveldstur uten telefoner',
        'bowling_cafe': 'Bowling eller kafé',
        'cook_together': 'Lag mat sammen etter leggetid',
        'babysitter_night': 'Planlegg babysitterkveld',
      };
      return nb[id] ?? id;
    }
    const en = {
      'question_cards': 'Question cards on the couch',
      'tea_dessert': 'Tea + dessert at home',
      'evening_walk': 'Evening walk without phones',
      'bowling_cafe': 'Bowling or café',
      'cook_together': 'Cook together after bedtime',
      'babysitter_night': 'Plan babysitter night',
    };
    return en[id] ?? id;
  }

  String ideaDuration(String id) {
    if (isNorwegian) {
      const nb = {
        'question_cards': '10 min',
        'tea_dessert': '20 min',
        'evening_walk': '30–45 min',
        'bowling_cafe': '1 time',
        'cook_together': '30 min',
        'babysitter_night': '1 time+',
      };
      return nb[id] ?? '';
    }
    const en = {
      'question_cards': '10 min',
      'tea_dessert': '20 min',
      'evening_walk': '30–45 min',
      'bowling_cafe': '1 hour',
      'cook_together': '30 min',
      'babysitter_night': '1 hour+',
    };
    return en[id] ?? '';
  }

  String ideaCategoryLabel(IdeaCategory category) {
    if (isNorwegian) {
      switch (category) {
        case IdeaCategory.tenMin: return '10 min';
        case IdeaCategory.thirtyAtHome: return '30 min hjemme';
        case IdeaCategory.oneHourOut: return '1 time ute';
        case IdeaCategory.babysitterNight: return 'Babysitterkveld';
        case IdeaCategory.parentMode: return 'Foreldremodus';
      }
    }
    switch (category) {
      case IdeaCategory.tenMin: return '10 min';
      case IdeaCategory.thirtyAtHome: return '30 min at home';
      case IdeaCategory.oneHourOut: return '1 hour out';
      case IdeaCategory.babysitterNight: return 'Babysitter night';
      case IdeaCategory.parentMode: return 'Parent mode';
    }
  }

  // ── Moment data ─────────────────────────────────────────────────────────
  String momentTitle(String id) {
    if (isNorwegian) {
      const nb = {
        'date_night': 'Datenatt',
        'home_date': 'Hjemmedate',
        'went_out': 'Gikk ut sammen',
        'game': 'Spillkveld',
        'walk': 'Tok en tur',
        'no_kids': 'Tid uten barn',
        'phone_free': 'Telefonfri prat',
      };
      return nb[id] ?? id;
    }
    const en = {
      'date_night': 'Date night',
      'home_date': 'Home date',
      'went_out': 'Went out together',
      'game': 'Game night',
      'walk': 'Took a walk',
      'no_kids': 'Time without kids',
      'phone_free': 'Phone-free talk',
    };
    return en[id] ?? id;
  }

  String momentStatusLabel(MomentStatus status) {
    if (isNorwegian) {
      switch (status) {
        case MomentStatus.good: return 'Alt bra';
        case MomentStatus.needsAttention: return 'Snart';
        case MomentStatus.reconnectSoon: return 'Knytt bånd';
      }
    }
    switch (status) {
      case MomentStatus.good: return 'All good';
      case MomentStatus.needsAttention: return 'Soon';
      case MomentStatus.reconnectSoon: return 'Reconnect';
    }
  }

  String daysAgoLabel(int days) {
    if (isNorwegian) {
      if (days == 0) return 'I dag';
      if (days == 1) return 'I går';
      return '$days dager siden';
    }
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }

  String? momentSuggestionText(String momentId) {
    if (isNorwegian) {
      const nb = {
        'date_night': 'Prøv en ny restaurant — la hverandre bestille for den andre.',
        'home_date': 'Velg en film fra den andres liste. Ingen telefoner etter at den starter.',
        'went_out': 'Gå til et nytt nabolag og finn en kaffebar dere aldri har prøvd.',
        'game': 'Finn frem et brettspill eller lær hverandre et kortspill dere elsker.',
        'walk': 'En kveldsrunde rundt kvartalet — telefoner i lomma, bare prat.',
        'no_kids': 'Be et familiemedlem passe barna noen timer denne helgen.',
        'phone_free': 'Sett dere ned med te i kveld — telefoner i et annet rom — og bare prat.',
      };
      return nb[momentId];
    }
    const en = {
      'date_night': 'Try a new restaurant — let each other order for the other.',
      'home_date': 'Pick a film from the other\'s list. No phones after it starts.',
      'went_out': 'Walk to a new neighbourhood and find a coffee spot you\'ve never tried.',
      'game': 'Dig out a board game or teach each other a card game you love.',
      'walk': 'An evening loop around the block — phones in pockets, just talking.',
      'no_kids': 'Ask a family member to take the kids for a few hours this weekend.',
      'phone_free': 'Sit down with tea tonight — phones in another room — and just catch up.',
    };
    return en[momentId];
  }

  String momentSuggestionDuration(String momentId) {
    if (isNorwegian) {
      const nb = {
        'date_night': '2–3 timer',
        'home_date': '1–2 timer',
        'went_out': '1–2 timer',
        'game': '45–90 min',
        'walk': '20–30 min',
        'no_kids': '2–4 timer',
        'phone_free': '30 min',
      };
      return nb[momentId] ?? '';
    }
    const en = {
      'date_night': '2–3 hours',
      'home_date': '1–2 hours',
      'went_out': '1–2 hours',
      'game': '45–90 min',
      'walk': '20–30 min',
      'no_kids': '2–4 hours',
      'phone_free': '30 min',
    };
    return en[momentId] ?? '';
  }

  // ── Activity Sheet ──────────────────────────────────────────────────────
  String get activitySuccess => isNorwegian ? 'Logget!' : 'Logged!';
  String get activitySuccessMsg => isNorwegian ? 'Små øyeblikk holder kjærligheten sterk.' : 'Small moments keep love strong.';
  String get activityIdeaLabel => isNorwegian ? 'IDÉTIPS' : 'IDEA FOR YOU';
  String get activitySendToS => isNorwegian ? 'Send til S' : 'Send to S';
  String get activitySentToS => isNorwegian ? 'Sendt til S!' : 'Sent to S!';
  String get activityWeDidThis => isNorwegian ? 'Vi gjorde dette!' : 'We did this!';
  String get activityAllGood => isNorwegian ? 'Alt bra' : 'All good';
  String get activityTimeAgain => isNorwegian ? 'På tide igjen?' : 'Time for this again?';

  // ── Plan Screen ─────────────────────────────────────────────────────────
  String get planTitle => isNorwegian ? 'Denne uken' : 'This week';
  String get planSubtitle => isNorwegian ? 'Deres felles intensjoner.' : 'Your shared intentions.';
  String get planCardTitle => isNorwegian ? 'Planen vår denne uken' : 'Our plan this week';
  String get planActive => isNorwegian ? 'Aktiv' : 'Active';
  String get planCardSubtitle => isNorwegian
      ? 'Begge partnere kan godkjenne en plan før den blir aktiv.'
      : 'Both partners can approve a plan before it becomes active.';
  String get plan1HomeDate => isNorwegian ? '1 hjemmedate' : '1 home date';
  String get plan1Walk => isNorwegian ? '1 tur' : '1 walk';
  String get plan1PhoneFree => isNorwegian ? '1 telefonfri prat' : '1 phone-free talk';
  String get coupleGameLabel => isNorwegian ? 'Parspill' : 'Couple game';
  String get coupleGameTitle => isNorwegian ? 'Hvem kjenner hvem best?' : 'Who knows whom best?';
  String get coupleGameStart => isNorwegian ? 'Start' : 'Start';
  String get weeklyReminderLabel => isNorwegian ? 'Ukentlig påminnelse' : 'Weekly reminder';
  String get weeklyReminderTitle => isNorwegian
      ? 'Søndag kveld — planlegg uken sammen.'
      : 'Sunday evening — plan your week together.';
  String get weeklyReminderSub => isNorwegian ? '10 min, før uken starter.' : '10 min, before the week starts.';
  String get gameBack => isNorwegian ? 'Tilbake' : 'Back';
  String get gameNext => isNorwegian ? 'Neste' : 'Next';
  String get gameDone => isNorwegian ? 'Ferdig' : 'Done';
  List<String> get gameQuestions => isNorwegian
      ? [
          'Hva er favorittemåten deres å slappe av etter en tøff dag?',
          'Nevn én ting dere alltid har ønsket å prøve sammen.',
          'Hva er kjærlighetsspråket deres?',
          'Hvilken sang minner dem om de første dagene?',
          'Hva synes de er en perfekt søndagsmorgen?',
        ]
      : [
          'What is their favorite way to unwind after a tough day?',
          'Name one thing they\'ve always wanted to try together.',
          'What is their love language?',
          'What song reminds them of the early days?',
          'What do they consider a perfect Sunday morning?',
        ];

  // ── Settings Screen ─────────────────────────────────────────────────────
  String get settingsTitle => isNorwegian ? 'Innstillinger' : 'Settings';
  String get settingsEdit => isNorwegian ? 'Rediger' : 'Edit';
  String get settingsTogether => isNorwegian ? 'Sammen siden 2020' : 'Together since 2020';
  String get settingsUpgrade => isNorwegian ? 'Oppgrader til Premium' : 'Upgrade to Premium';
  String get settingsUnlock => isNorwegian ? 'Lås opp alle funksjoner for forholdet ditt' : 'Unlock all features for your relationship';
  String get settingsCoupleSetup => isNorwegian ? 'Paroppset' : 'Couple setup';
  String get settingsCoupleSetupSub => isNorwegian ? 'Partnerprofil og felles preferanser' : 'Partner profile and shared preferences';
  String get settingsParentMode => isNorwegian ? 'Foreldremodus' : 'Parent mode';
  String get settingsParentModeSub => isNorwegian ? 'Barnevennlige ideer og påminnelser' : 'Child-friendly ideas and reminders';
  String get settingsReminders => isNorwegian ? 'Påminnelser' : 'Reminders';
  String get settingsRemindersSub => isNorwegian ? 'Milde påminnelser for kvalitetstid' : 'Gentle nudges for quality time';
  String get settingsQuietHours => isNorwegian ? 'Stilletimer' : 'Quiet hours';
  String get settingsQuietHoursSub => isNorwegian ? 'Stopp varsler under søvn' : 'Pause notifications during sleep';
  String get settingsPrivacy => isNorwegian ? 'Personvern' : 'Privacy';
  String get settingsPrivacySub => isNorwegian ? 'Kontroller hva som lagres og deles' : 'Control what is saved and shared';
  String get settingsAppearance => isNorwegian ? 'Utseende' : 'Appearance';
  String get settingsAppearanceSub => isNorwegian ? 'Tema og visningsinnstillinger' : 'Theme and display settings';
  String get settingsLanguage => isNorwegian ? 'Språk' : 'Language';
  String get settingsLanguageSub => isNorwegian ? 'Appens språk og region' : 'App language and region';
  String get settingsSignOut => isNorwegian ? 'Logg ut' : 'Sign out';
  String get settingsSignOutSub => isNorwegian ? 'Logg ut av kontoen din' : 'Sign out of your account';
  String get settingsSubscription => isNorwegian ? 'Abonnement' : 'Subscription';
  String get settingsSubscriptionSub => isNorwegian ? 'Administrer planen din' : 'Manage your plan';
  String get settingsLanguagePickerTitle => isNorwegian ? 'Velg språk' : 'Choose language';

  // ── Couple Setup Screen ─────────────────────────────────────────────────
  String get coupleSetupTitle => isNorwegian ? 'Paroppset' : 'Couple setup';
  String get coupleYourProfile => isNorwegian ? 'Din profil' : 'Your profile';
  String get coupleYourPartner => isNorwegian ? 'Din partner' : 'Your partner';
  String get coupleTogetherSince => isNorwegian ? 'Sammen siden' : 'Together since';
  String get coupleTapToEdit => isNorwegian ? 'Trykk på navnet for å redigere' : 'Tap name to edit';
  String get coupleSave => isNorwegian ? 'Lagre' : 'Save';
  String get coupleNoPartner => isNorwegian ? 'Ingen partner tilkoblet ennå' : 'No partner connected yet';
  String get coupleInviteSubtitle => isNorwegian ? 'Inviter dem til å bli med deg på Us' : 'Invite them to join you on Us';
  String get coupleInviteButton => isNorwegian ? 'Inviter partneren din' : 'Invite your partner';
  String get coupleInviteSent => isNorwegian ? 'Invitasjon sendt!' : 'Invite sent!';
  String get coupleWaiting => isNorwegian ? 'Venter på at de blir med...' : 'Waiting for them to join...';
  String get coupleResendInvite => isNorwegian ? 'Send invitasjon på nytt' : 'Resend invite';
  String get coupleCancelInvite => isNorwegian ? 'Avbryt invitasjon' : 'Cancel invite';
  String get coupleConnected => isNorwegian ? 'Tilkoblet' : 'Connected';
  String get coupleRemovePartner => isNorwegian ? 'Fjern partner' : 'Remove partner';
  String coupleDaysTogether(int days) => isNorwegian ? '$days dager sammen' : '$days days together';
  String get coupleChangeDate => isNorwegian ? 'Endre dato' : 'Change date';
  String get coupleSetDatePlaceholder => isNorwegian ? 'Sett en dato' : 'Set a date';
  String coupleRemoveTitle(String name) => isNorwegian ? 'Fjern $name som din partner?' : 'Remove $name as your partner?';
  String get coupleRemoveContent => isNorwegian ? 'Dette vil koble fra begge kontoer.' : 'This will disconnect both accounts.';
  String get coupleRemoveCancel => isNorwegian ? 'Avbryt' : 'Cancel';
  String get coupleRemoveConfirm => isNorwegian ? 'Fjern' : 'Remove';
  String get coupleChooseColor => isNorwegian ? 'Velg din farge' : 'Choose your color';
  List<String> get coupleColorLabels => isNorwegian
      ? ['Korall', 'Grønn', 'Rav', 'Blågrønn', 'Rosa', 'Lilla']
      : ['Coral', 'Green', 'Amber', 'Teal', 'Pink', 'Purple'];
  String get coupleInviteSheetTitle => isNorwegian ? 'Inviter partneren din' : 'Invite your partner';
  String get coupleInviteSheetSubtitle => isNorwegian
      ? 'Del denne lenken med partneren din for å koble til på Us.'
      : 'Share this link with your partner to connect on Us.';
  String get coupleCopy => isNorwegian ? 'Kopier' : 'Copy';
  String get coupleLinkCopied => isNorwegian ? 'Lenke kopiert!' : 'Link copied!';
  String get coupleShareLink => isNorwegian ? 'Del lenke' : 'Share link';
  String coupleUpcoming(String years, String date) =>
      isNorwegian ? 'Kommer opp: $years den $date' : 'Coming up: $years on $date';
  String coupleYearsLabel(int years) => isNorwegian
      ? (years == 1 ? '1 år' : '$years år')
      : (years == 1 ? '1 year' : '$years years');

  // ── Resolve Together Screen ─────────────────────────────────────────────
  String get resolveNeutralPill => isNorwegian ? 'Tom · Nøytral' : 'Tom · Neutral';
  String resolveP1Intro(String name) => isNorwegian
      ? 'Hei $name! Jeg er her for å hjelpe dere å finne midten — og jeg tar ikke sider. '
          'Informasjonen dere deler her blir ikke lagret og slettes automatisk når dere forlater samtalen. '
          '🤝 Hva føler du er urettferdig?'
      : 'Hi $name! I\'m here to help you two find the middle ground — and I never take sides. '
          'What you share here is not stored and is automatically deleted when you leave the conversation. '
          '🤝 What feels unfair to you?';
  String resolveP1Ack(String p1Name, String p2Name) => isNorwegian
      ? 'Takk $p1Name, jeg hørte deg. Jeg sender dette videre til $p2Name nå — de får beskjed om å komme inn.'
      : 'Thank you $p1Name, I heard you. I\'m passing this on to $p2Name now — they\'ll get notified to join.';
  String resolveP2Intro(String p1Name, String p2Name) => isNorwegian
      ? 'Hei $p2Name! $p1Name har delt noe med meg. Jeg har lyttet til dem — nå vil jeg høre din side. Hva føler du?'
      : 'Hi $p2Name! $p1Name has shared something with me. I\'ve listened to them — now I want to hear your side. How do you feel?';
  String get resolveError => isNorwegian ? 'Noe gikk galt. Prøv igjen om litt.' : 'Something went wrong. Try again in a bit.';
  String get resolveConnectError => isNorwegian ? 'Kunne ikke koble til. Sjekk internett.' : 'Couldn\'t connect. Check your internet.';
  String resolveNotifTitle(String name) => isNorwegian
      ? '$name vil løse noe sammen med deg.'
      : '$name wants to resolve something with you.';
  String get resolveNotifSub => isNorwegian ? 'Tom venter 🤝' : 'Tom is waiting 🤝';
  String get resolveJoinButton => isNorwegian ? 'Kom inn' : 'Join in';
  String resolveHint(String name) => isNorwegian ? '$name, skriv her…' : '$name, write here…';
}
