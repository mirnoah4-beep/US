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
  String get homeWriteOwn => isNorwegian ? 'Skriv din egen idé' : 'Write your own idea';
  String homeWriteOwnWaiting(String name) =>
      isNorwegian ? 'Venter på $name' : 'Waiting for $name';
  String homeFormattedDate(DateTime date) {
    final day = planFullDayNames[date.weekday - 1];
    final month = planMonthNamesShort[date.month - 1];
    return isNorwegian
        ? '${day.toLowerCase()} ${date.day}. $month'
        : '$day, $month ${date.day}';
  }
  String homeDurationLine(int years, int months) {
    if (isNorwegian) {
      if (years == 0) {
        return '$months ${months == 1 ? "måned" : "måneder"} sammen';
      }
      final yStr = '$years år';
      if (months == 0) return '$yStr sammen';
      return '$yStr og $months ${months == 1 ? "måned" : "måneder"} sammen';
    }
    if (years == 0) {
      return '$months ${months == 1 ? "month" : "months"} together';
    }
    final yStr = '$years ${years == 1 ? "year" : "years"}';
    if (months == 0) return '$yStr together';
    return '$yStr and $months ${months == 1 ? "month" : "months"} together';
  }
  String homeWaiting(String dots) => isNorwegian ? 'Krysser fingrene... S tenker$dots' : 'Fingers crossed... S is thinking$dots';
  String get homeWalkTogether => isNorwegian ? 'Gå tur sammen' : 'Walk together';
  String get homeDateNight => isNorwegian ? 'Datenatt' : 'Date night';
  String get homePhoneFreeTalk => isNorwegian ? 'Telefonfri prat' : 'Phone-free talk';
  String get homeSendNote => isNorwegian ? 'Send en lapp' : 'Send a note';
  String get homeDoneThisWeek => isNorwegian ? 'Ferdig denne uken' : 'Done this week';
  String get homeWeeklyGoal => isNorwegian ? '0 av 1 denne uken' : '0 of 1 this week';
  String get homeResolveTitle => isNorwegian ? 'Hjelp oss' : 'Help us';
  String get homeResolveSubtitle => isNorwegian ? 'Uenige om noe? Start en samtale' : 'Disagreeing? Start a conversation';
  String get homeWriteOwnSheetTitle => isNorwegian ? 'Skriv din egen' : 'Write your own';
  String get homeWriteOwnSheetSubtitle => isNorwegian ? 'La det høres ut som deg.' : 'Make it sound like you.';
  String get homeWriteOwnHint => isNorwegian ? 'Skriv meldingen din...' : 'Write your message...';
  String get homeSendToS => isNorwegian ? 'Send til S' : 'Send to S';
  String get homeSentToS => isNorwegian ? 'Sendt til S!' : 'Sent to S!';
  String get homeWeeklyIdeasSection => isNorwegian ? 'Ukens ideer' : 'This week\'s ideas';
  String get homeAiPersonalized => isNorwegian ? 'AI-personalisert denne uken' : 'AI-personalised this week';
  String get homeWeeklyIdeasEmpty => isNorwegian ? 'Ingen ideer ennå — prøv igjen snart.' : 'No ideas yet — check back soon.';
  String get homeIdeaSendToPartner => isNorwegian ? 'Send idé til partner' : 'Send idea to partner';
  String ideaSentTo(String name) => isNorwegian ? 'Sendt til $name!' : 'Sent to $name!';
  String get ideaWaiting => isNorwegian ? 'Venter på svar' : 'Waiting for reply';
  String get ideaAcceptedTitle => isNorwegian ? 'Partner sa ja! 🎉' : 'Partner said yes! 🎉';
  String get ideaDeclinedTitle => isNorwegian ? 'Kanskje neste gang' : 'Maybe next time';
  String ideaFromPartner(String name) => isNorwegian ? '$name sendte deg en idé' : '$name sent you an idea';
  String get ideaReceiveAccept => isNorwegian ? 'Gjøre dette! 🎉' : "Let's do this! 🎉";
  String get ideaReceiveDecline => isNorwegian ? 'Kanskje ikke' : 'Maybe not';
  String get ideaCancel => isNorwegian ? 'Avbryt' : 'Cancel';
  String get ideaWriteOwnTitle => isNorwegian ? 'Skriv din egen idé' : 'Write your own idea';
  String get ideaWriteOwnHint => isNorwegian ? 'F.eks. Kveldstur til havnen...' : 'E.g. Evening walk to the harbour...';
  String get ideaSendToPartnerShort => isNorwegian ? 'Send til partner' : 'Send to partner';
  String get ideaWaitingLong => isNorwegian ? 'Venter på svar...' : 'Waiting for a response...';
  String ideaPartnerSaidYes(String name) => isNorwegian ? '$name sa ja!' : '$name said yes!';
  String get ideaTonightNice => isNorwegian ? 'I kveld blir det fint.' : 'Tonight is going to be nice.';
  String get ideaAddedToPlan => isNorwegian ? 'Lagt til ukens plan' : "Added to this week's plan";
  String ideaFromLabel(String name) => isNorwegian ? 'Fra $name' : 'From $name';
  String get ideaAcceptButtonText => isNorwegian ? 'Ja, la oss gjøre det!' : "Yes, let's do it!";
  String get ideaDeclineButtonText => isNorwegian ? 'Kanskje senere' : 'Maybe later';
  String get ideaDoneAddedPlan => isNorwegian ? 'Ferdig! Lagt til ukens plan' : "Done! Added to this week's plan";
  String get ideaAccept => isNorwegian ? 'Godkjenn' : 'Accept';
  String get ideaDecline => isNorwegian ? 'Avslå' : 'Decline';
  String get ideasPendingSection => isNorwegian ? 'Forespørsel fra partner' : 'Request from partner';
  String get ideaAddToPlanDialogTitle => isNorwegian ? 'Legg til i planen?' : 'Add to your plan?';
  String ideaAddToPlanDialogBody(String title) => isNorwegian
      ? 'Vil dere sette av en dato for «$title»?'
      : 'Want to pick a date for "$title"?';
  String get ideaAddToPlanConfirm => isNorwegian ? 'Velg dato' : 'Pick a date';
  String get ideaSkipPlan => isNorwegian ? 'Hopp over' : 'Skip';
  String get ideasSentToPartner => isNorwegian ? 'Idé sendt til partner!' : 'Idea sent to your partner!';
  String get ideasAlreadySent => isNorwegian ? 'Allerede én forespørsel på vent' : 'A request is already pending';
  String get ideaLater => isNorwegian ? 'Senere' : 'Later';
  String get ideaSuggestTime => isNorwegian ? 'Foreslå tidspunkt' : 'Suggest a time';
  String get ideaSuggestTimeOptional => isNorwegian ? '(valgfritt)' : '(optional)';
  String get ideaDatePlaceholder => isNorwegian ? 'Dato' : 'Date';
  String get ideaTimePlaceholder => isNorwegian ? 'Tid' : 'Time';
  String get ideaConfirmSend => isNorwegian ? 'Bekreft og send' : 'Confirm and send';
  String get ideaSendWithoutTime =>
      isNorwegian ? 'Du kan sende uten å velge tidspunkt' : 'You can send without choosing a time';
  String get ideaWhenWorksForYou =>
      isNorwegian ? 'Når passer det?' : 'When works for you?';
  String get ideaAlreadyPendingTitle =>
      isNorwegian ? 'Du har allerede en ventende idé' : 'You already have a pending idea';
  String ideaAlreadyPendingBody(String title) => isNorwegian
      ? 'Du venter på svar på «$title». Vil du avbryte den og sende denne i stedet?'
      : 'You\'re waiting for a response to "$title". Cancel it and send this one instead?';
  String get ideaCancelAndSendNew => isNorwegian ? 'Avbryt og send ny' : 'Cancel and send new';
  String get ideaKeepCurrent => isNorwegian ? 'Behold nåværende' : 'Keep current';
  String ideaProposedAt(DateTime dt) {
    final day = planFullDayNames[dt.weekday - 1];
    final month = planMonthNamesShort[dt.month - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return isNorwegian
        ? 'Forslag: ${day.toLowerCase()} ${dt.day}. $month, $h:$m'
        : 'Suggested: $day, $month ${dt.day}, $h:$m';
  }

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
  String get logTitle => isNorwegian ? 'Logg et øyeblikk' : 'Log a moment';
  String get logSubtitle => isNorwegian ? 'Hva gjorde dere sammen?' : 'What did you do together?';
  String get logSuccess => isNorwegian ? 'Logget!' : 'Logged!';
  String get logSuccessMsg => isNorwegian ? 'Flott. Små øyeblikk holder kjærligheten sterk.' : 'Nice. Small moments keep love strong.';
  String get logButton => isNorwegian ? 'Logg øyeblikket' : 'Log the moment';
  String get logCustomHint => isNorwegian ? 'Beskriv hva dere gjorde...' : 'Describe what you did...';
  String get logCancel => isNorwegian ? 'Avbryt' : 'Cancel';
  String logOptionLabel(String id) {
    if (isNorwegian) {
      const nb = {
        'went_out': 'Gikk ut',
        'home_date': 'Hjemmedate',
        'game': 'Game night',
        'date_night': 'Datenatt',
        'phone_free': 'Telefonsfri',
        'custom': 'Annet',
      };
      return nb[id] ?? id;
    }
    const en = {
      'went_out': 'Went out',
      'home_date': 'Home date',
      'game': 'Game night',
      'date_night': 'Date night',
      'phone_free': 'Phone-free',
      'custom': 'Other',
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
  String get ideasSubtitle => isNorwegian ? 'Små idéer, stor tilkobling.' : 'Small ideas, big connection.';
  String get ideasAll => isNorwegian ? 'Alle' : 'All';
  String get ideasChip10min => '10 min';
  String get ideasChip30home => isNorwegian ? '30 min hjemme' : '30 min at home';
  String get ideasChip1hour => isNorwegian ? '1 time ute' : '1 hour out';
  String get ideasChipBabysitter => isNorwegian ? 'Babysitterkveld' : 'Babysitter night';
  String get ideasChipParent => isNorwegian ? 'Foreldremodus' : 'Parent mode';
  String get ideasFilterAtHome => isNorwegian ? 'Hjemme' : 'At home';
  String get ideasFilterOut => isNorwegian ? 'Ute sammen' : 'Out together';
  String get ideasFilter1Hour => isNorwegian ? '1 time+' : '1 hour+';
  String get ideasSaveLater => isNorwegian ? 'Lagre til senere' : 'Save for later';
  String get ideasDismiss => isNorwegian ? 'Avbryt' : 'Dismiss';
  String get adminUploadCover => isNorwegian ? 'Last opp forsidebilde' : 'Upload cover image';
  String get adminUploading => isNorwegian ? 'Laster opp…' : 'Uploading…';
  String get adminUploadSuccess => isNorwegian ? 'Forsidebilde oppdatert' : 'Cover updated';
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
        'send_note': 'Send en lapp',
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
      'send_note': 'Send a note',
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
        'send_note': 'Skriv en kort lapp — legg den på puten eller send den som melding.',
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
      'send_note': 'Write a short note — leave it on their pillow or send it as a message.',
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
        'send_note': '5 min',
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
      'send_note': '5 min',
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
  String get planTitle => isNorwegian ? 'Plan' : 'Plan';
  String get planSubtitle => isNorwegian ? 'Planlegg noe dere to kan glede dere til.' : 'Plan something you two can look forward to.';
  String get planChooseDate => isNorwegian ? 'Velg en dato' : 'Choose a date';
  String get planDateButton => isNorwegian ? 'Planlegg en date' : 'Plan a date';
  String get planUpcomingSection => isNorwegian ? 'Kommende' : 'Upcoming';
  String get planConfirmedBadge => isNorwegian ? 'Avtalt' : 'Confirmed';
  String get planPendingBadge => isNorwegian ? 'Venter' : 'Pending';
  String get planSheetTitle => isNorwegian ? 'Planlegg en date' : 'Plan a date';
  String get planSheetSub => isNorwegian ? 'Hva vil dere gjøre?' : 'What do you want to do?';
  String get planSendProposal => isNorwegian ? 'Send forslag til partner' : 'Send proposal to partner';
  String get planProposalSent => isNorwegian ? 'Forslag sendt til partner!' : 'Proposal sent to partner!';
  String get planNoUpcomingTitle => isNorwegian ? 'Ingen planlagte dates ennå' : 'No upcoming dates yet';
  String get planNoUpcomingSub => isNorwegian ? 'Trykk på en dato og planlegg noe' : 'Tap a date and plan something';
  String get planCustomHint => isNorwegian ? 'Beskriv hva dere vil gjøre...' : 'Describe what you want to do...';
  String get planCoupleGameSection => isNorwegian ? 'Par-spill' : 'Couple game';
  String get planCoupleGameSub => isNorwegian ? '10 spørsmål · 5 min' : '10 questions · 5 min';
  List<String> get planMonthNames => isNorwegian
      ? ['Januar', 'Februar', 'Mars', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Desember']
      : ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  List<String> get planMonthNamesShort => isNorwegian
      ? ['jan', 'feb', 'mar', 'apr', 'mai', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'des']
      : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  List<String> get planFullDayNames => isNorwegian
      ? ['Mandag', 'Tirsdag', 'Onsdag', 'Torsdag', 'Fredag', 'Lørdag', 'Søndag']
      : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  String planMonthYear(DateTime date) => '${planMonthNames[date.month - 1]} ${date.year}';
  String planFormatDate(DateTime date) {
    final day = planFullDayNames[date.weekday - 1];
    final month = planMonthNamesShort[date.month - 1];
    return isNorwegian ? '$day ${date.day}. $month' : '$day, ${date.day} $month';
  }
  String planActivityLabel(String id) {
    if (isNorwegian) {
      const nb = {'walk': 'Kveldtur', 'home_date': 'Hjemmedate', 'date_night': 'Datenatt', 'game': 'Game night', 'coffee': 'Kaffe ute', 'other': 'Annet'};
      return nb[id] ?? id;
    }
    const en = {'walk': 'Evening walk', 'home_date': 'Home date', 'date_night': 'Date night', 'game': 'Game night', 'coffee': 'Coffee out', 'other': 'Other'};
    return en[id] ?? id;
  }
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
  String get languageSub => isNorwegian ? 'Velg appens språk' : 'Choose app language';
  String get settingsDittForhold => isNorwegian ? 'DITT FORHOLD' : 'YOUR RELATIONSHIP';
  String get settingsKonto => isNorwegian ? 'KONTO' : 'ACCOUNT';
  String get settingsProfile => isNorwegian ? 'Min profil' : 'My profile';
  String get settingsProfileSub => isNorwegian ? 'Navn og profilbilde' : 'Name and profile photo';
  String get settingsLifestyleSub => isNorwegian ? 'Tilpass idéer til livet deres' : 'Adapt ideas to your life';
  String settingsTogetherSince(String date) =>
      isNorwegian ? 'Sammen siden $date' : 'Together since $date';
  String coupleDate(DateTime date) {
    final month = planMonthNames[date.month - 1];
    return isNorwegian ? '${month.toLowerCase()} ${date.year}' : '$month ${date.year}';
  }

  String get settingsDisconnect => isNorwegian ? 'Koble fra partner' : 'Disconnect partner';
  String get settingsDisconnectTitle => isNorwegian ? 'Koble fra partner?' : 'Disconnect partner?';
  String settingsDisconnectBody(String partnerName) => isNorwegian
      ? 'Dette kobler deg og $partnerName fra hverandre. Delt innhold som kalender og øyeblikk blir utilgjengelig for begge. Dette kan ikke angres enkelt.'
      : 'This disconnects you and $partnerName from each other. Shared content like the calendar and moments will be inaccessible to both. This cannot easily be undone.';
  String get settingsDisconnectConfirm => isNorwegian ? 'Koble fra' : 'Disconnect';
  String get settingsDisconnectCancel => isNorwegian ? 'Avbryt' : 'Cancel';
  // ── Our Relationship Screen ─────────────────────────────────────────────
  String get ourRelationshipTitle => isNorwegian ? 'Vårt forhold' : 'Our relationship';
  String get ourRelationshipNoDate => isNorwegian ? 'Sett en dato' : 'Set a date';
  String get ourRelationshipNoDateSub =>
      isNorwegian ? 'Ingen jubileumsdato satt ennå' : 'No anniversary date set yet';
  String get ourRelationshipYears => isNorwegian ? 'år' : 'yr';
  String get ourRelationshipMonths => isNorwegian ? 'mnd' : 'mo';
  String get ourRelationshipDays => isNorwegian ? 'dager' : 'days';
  String get ourRelationshipSecs => isNorwegian ? 'sek' : 'sec';
  String get ourRelationshipChangeDate =>
      isNorwegian ? 'Endre dato' : 'Change date';
  String get ourRelationshipProposeDate =>
      isNorwegian ? 'Sett dato' : 'Set date';
  String ourRelationshipFullDate(DateTime date) {
    final month = planMonthNames[date.month - 1];
    return isNorwegian
        ? '${date.day}. ${month.toLowerCase()} ${date.year}'
        : '$month ${date.day}, ${date.year}';
  }
  // Step 2 — anniversary proposal strings
  String get ourRelationshipProposalPending =>
      isNorwegian ? 'Venter på godkjenning' : 'Waiting for approval';
  String ourRelationshipProposedBy(String name, String date) =>
      isNorwegian ? '$name foreslår $date' : '$name proposes $date';
  String get ourRelationshipApprove => isNorwegian ? 'Godkjenn' : 'Approve';
  String get ourRelationshipDecline => isNorwegian ? 'Avvis' : 'Decline';
  // Step 3 — disconnect request strings
  String get ourRelationshipDisconnectRequest =>
      isNorwegian ? 'Be om frakobling' : 'Request disconnect';
  String ourRelationshipDisconnectRequestedBy(String name) =>
      isNorwegian ? '$name ønsker å koble fra' : '$name wants to disconnect';
  String get ourRelationshipDisconnectApprove =>
      isNorwegian ? 'Bekreft frakobling' : 'Confirm disconnect';
  String get ourRelationshipCancelRequest =>
      isNorwegian ? 'Avbryt forespørsel' : 'Cancel request';
  String ourRelationshipWaitingFor(String name) =>
      isNorwegian ? 'Venter på $name...' : 'Waiting for $name...';
  String get ourRelationshipDeclineRequest =>
      isNorwegian ? 'Avslå' : 'Decline';

  // ── Lifestyle Setup Screen ─────────────────────────────────────────────────
  String get lifestyleTitle => isNorwegian ? 'Deres hverdag' : 'Your lifestyle';
  String get lifestyleSkip => isNorwegian ? 'Hopp over' : 'Skip';
  String get lifestyleNext => isNorwegian ? 'Neste' : 'Next';
  String get lifestyleSave => isNorwegian ? 'Lagre og fullfør' : 'Save and finish';
  String get lifestyleCancel => isNorwegian ? 'Avbryt' : 'Cancel';
  String get lifestyleStep1Q => isNorwegian ? 'Hvor mye tid har dere på hverdager?' : 'How much time do you have on weekdays?';
  String get lifestyleStep1Sub => isNorwegian ? 'Vi tilpasser idéenes lengde til hverdagen deres.' : 'We adapt the length of ideas to your everyday life.';
  String get lifestyleUnder30 => isNorwegian ? 'Under 30 min' : 'Under 30 min';
  String get lifestyleUnder30Sub => isNorwegian ? 'Kort og godt etter jobb' : 'Short and sweet after work';
  String get lifestyle30to60 => isNorwegian ? '30–60 min' : '30–60 min';
  String get lifestyle30to60Sub => isNorwegian ? 'Litt tid når kvelden roer seg' : 'A little time when the evening settles';
  String get lifestyle2plus => isNorwegian ? '2+ timer' : '2+ hours';
  String get lifestyle2plusSub => isNorwegian ? 'God tid når hverdagen tillater det' : 'Plenty of time when everyday life allows';
  String get lifestyleStep2Q => isNorwegian ? 'Hva passer dere best?' : 'What suits you best?';
  String get lifestyleStep2Sub => isNorwegian ? 'Hjemme, ute, eller begge deler?' : 'At home, out, or both?';
  String get lifestyleHome => isNorwegian ? 'Hjemme' : 'At home';
  String get lifestyleHomeSub => isNorwegian ? 'Koselig og enkelt' : 'Cosy and simple';
  String get lifestyleOut => isNorwegian ? 'Ute' : 'Out';
  String get lifestyleOutSub => isNorwegian ? 'Ute og eventyrlig' : 'Out and adventurous';
  String get lifestyleBoth => isNorwegian ? 'Begge deler' : 'Both';
  String get lifestyleBothSub => isNorwegian ? 'Vi liker variasjon' : 'We like variety';
  String get lifestyleStep3Q => isNorwegian ? 'Er dere foreldre?' : 'Are you parents?';
  String get lifestyleStep3Sub => isNorwegian ? 'Da tilpasser vi idéene til hverdagen med barn.' : 'We adapt ideas to life with children.';
  String get lifestyleHaveKids => isNorwegian ? 'Vi har barn' : 'We have children';
  String get lifestyleHaveKidsSub => isNorwegian ? 'Idéer tilpasses etter leggetid' : 'Ideas adapted to bedtime';
  String get lifestyleBedtimeQ => isNorwegian ? 'Når legger barna seg?' : 'When do the children go to bed?';
  String get lifestyleWeekdays => isNorwegian ? 'Hverdager' : 'Weekdays';
  String get lifestyleWeekends => isNorwegian ? 'Helger' : 'Weekends';
  String get lifestyleStep4Q => isNorwegian ? 'Helger — hvor mye tid har dere?' : 'Weekends — how much time do you have?';
  String get lifestyleStep4Sub => isNorwegian ? 'Vi foreslår lengre dates når dere har tid til det.' : 'We suggest longer dates when you have the time.';
  String get lifestyleLittle => isNorwegian ? 'Litt tid' : 'A little time';
  String get lifestyleLittleSub => isNorwegian ? 'En time eller to' : 'An hour or two';
  String get lifestyleHalfday => isNorwegian ? 'Halv dag' : 'Half a day';
  String get lifestyleHalfdaySub => isNorwegian ? 'Tid til en skikkelig date' : 'Time for a proper date';
  String get lifestyleFullday => isNorwegian ? 'Hel dag' : 'Full day';
  String get lifestyleFulldaySub => isNorwegian ? 'Vi planlegger skikkelig' : 'We plan properly';
  String get lifestyleDoneTitle => isNorwegian ? 'Alt er klart!' : 'All set!';
  String get lifestyleDoneBody => isNorwegian
      ? 'Vi bruker dette til å lage idéer som faktisk passer hverdagen deres. Du kan endre dette når som helst under innstillinger.'
      : 'We use this to create ideas that actually fit your everyday life. You can change this at any time in settings.';
  String get lifestyleBackToApp => isNorwegian ? 'Tilbake til appen' : 'Back to the app';

  // ── Name Screen ────────────────────────────────────────────────────────
  String get nameScreenTitle => isNorwegian ? 'Hva heter du?' : 'What\'s your name?';
  String get nameScreenSubtitle => isNorwegian ? 'Partneren din ser dette.' : 'Your partner will see this.';
  String get nameScreenHint => isNorwegian ? 'Fornavnet ditt' : 'Your first name';
  String get nameScreenContinue => isNorwegian ? 'Fortsett' : 'Continue';

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
  String get coupleWaitingTitle => isNorwegian ? 'Venter på partneren din...' : 'Waiting for your partner...';
  String get coupleWaitingSubtitle => isNorwegian ? 'Be dem sjekke telefonen — invitasjonen ligger der.' : 'Ask them to check their phone — the invite is there.';
  String get couplePending => isNorwegian ? 'Venter' : 'Pending';
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
  String get resolveNeutralPill => isNorwegian ? 'AI · Nøytral' : 'AI · Neutral';
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
  String get resolveNotifSub => isNorwegian ? 'AI venter 🤝' : 'AI is waiting 🤝';
  String get resolveJoinButton => isNorwegian ? 'Kom inn' : 'Join in';
  String resolveHint(String name) => isNorwegian ? '$name, skriv her…' : '$name, write here…';

  // ── Reminders Screen ────────────────────────────────────────────────────────
  String get remindersTitle => isNorwegian ? 'Påminnelser' : 'Reminders';
  String get remindersSubtitle => isNorwegian
      ? 'Milde nudges som hjelper dere finne tid til hverandre.'
      : 'Gentle nudges to help you find time for each other.';
  String get remindersEveningSectionLabel => isNorwegian ? 'Kveldsreminder' : 'Evening reminder';
  String get remindersEveningTitle => isNorwegian ? 'Kveldsreminder' : 'Evening reminder';
  String get remindersEveningSub => isNorwegian ? 'En vennlig påminnelse om kvelden' : 'A friendly reminder in the evening';
  String get remindersTime => isNorwegian ? 'Tidspunkt' : 'Time';
  String get remindersTapToChange => isNorwegian ? 'Trykk for å endre' : 'Tap to change';
  String get remindersWeeklySectionLabel => isNorwegian ? 'Ukentlig planlegging' : 'Weekly planning';
  String get remindersWeeklyTitle => isNorwegian ? 'Planlegg uken sammen' : 'Plan the week together';
  String remindersWeeklyTimeLabel(String time) =>
      isNorwegian ? 'Søndager kl $time' : 'Sundays at $time';
  String get remindersWeeklyOff => isNorwegian ? 'Skrudd av' : 'Turned off';
  String get remindersWeeklyTimeSub => isNorwegian ? 'Søndager' : 'Sundays';
  String get remindersNewIdeas => isNorwegian ? 'Nye idéer klar' : 'New ideas ready';
  String get remindersNewIdeasSub => isNorwegian
      ? 'Varsle når ukens idéer er klare'
      : "Notify when this week's ideas are ready";
  String get remindersPreviewLabel => isNorwegian ? 'Slik ser varselet ut' : 'This is what the notification looks like';
  String get remindersPreviewTitle => isNorwegian ? 'Tid til dere to?' : 'Time for you two?';
  String get remindersPreviewBody => isNorwegian
      ? 'En liten idé venter — ta en titt når dere har et øyeblikk.'
      : 'A little idea is waiting — take a look when you have a moment.';
  List<String> get remindersDayAbbreviations => isNorwegian
      ? ['Ma', 'Ti', 'On', 'To', 'Fr', 'Lø', 'Sø']
      : ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
}
